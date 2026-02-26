import Foundation
import AppKit

// MARK: - Daemon Discovery

struct DaemonInfo: Codable {
    let pid: Int
    let httpsPort: Int
    let httpPort: Int
    let csrfToken: String
}

struct ModelQuota {
    let label: String
    let remainingPercentage: Double  // 0..100
    let isExhausted: Bool
    let timeUntilReset: String
    let secondsUntilReset: Double
}

struct QuotaData {
    let models: [ModelQuota]
    let timestamp: Date
}

// MARK: - API

class AntigravityAPI: @unchecked Sendable {
    @MainActor static let shared = AntigravityAPI()
    private let daemonDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".gemini/antigravity/daemon")
    private let brainDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".gemini/antigravity/brain")
    private let codeTrackerDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".gemini/antigravity/code_tracker/active")
    private let conversationsDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".gemini/antigravity/conversations")

    // MARK: - Daemon Discovery (process-based + JSON fallback)

    func findActiveDaemon() -> DaemonInfo? {
        // Primary: find running language_server process and extract info
        if let info = findDaemonFromProcess() {
            return info
        }
        // Fallback: try JSON discovery files (may exist briefly after LS start)
        return findDaemonFromJSON()
    }

    /// Parse running language_server process args to get csrf_token,
    /// then find LISTEN ports and validate via HTTP
    private func findDaemonFromProcess() -> DaemonInfo? {
        // 1. Get all language_server processes with csrf tokens
        let psInfo = findLanguageServerProcesses()
        guard !psInfo.isEmpty else { return nil }

        // 2. Get all language_server LISTEN ports grouped by PID
        let portsByPid = findAllLSListenPorts()

        // 3. Try each process: match PID → ports → validate HTTP
        for info in psInfo {
            guard let ports = portsByPid[info.pid], !ports.isEmpty else { continue }

            // Try each port (sorted descending — HTTP is usually the second/higher port)
            let sortedPorts = ports.sorted(by: >)
            for port in sortedPorts {
                if isHTTPReachable(port: port, csrfToken: info.csrfToken) {
                    return DaemonInfo(
                        pid: info.pid,
                        httpsPort: sortedPorts.first(where: { $0 != port }) ?? port,
                        httpPort: port,
                        csrfToken: info.csrfToken
                    )
                }
            }
        }
        return nil
    }

    private struct LSProcessInfo {
        let pid: Int
        let csrfToken: String
    }

    /// Find all language_server_macos processes and extract PID + csrf_token
    private func findLanguageServerProcesses() -> [LSProcessInfo] {
        let ps = Process()
        ps.launchPath = "/bin/ps"
        ps.arguments = ["-eo", "pid,args"]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = FileHandle.nullDevice
        guard (try? ps.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results: [LSProcessInfo] = []
        for line in output.components(separatedBy: "\n") {
            guard line.contains("language_server_macos"), !line.contains("grep") else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let pid = Int(parts[0]),
                  let token = extractArg("--csrf_token", from: String(parts[1]))
            else { continue }
            results.append(LSProcessInfo(pid: pid, csrfToken: token))
        }
        return results
    }

    private func extractArg(_ flag: String, from args: String) -> String? {
        let parts = args.components(separatedBy: " ")
        guard let idx = parts.firstIndex(of: flag), idx + 1 < parts.count else { return nil }
        return parts[idx + 1]
    }

    /// Run lsof ONCE (no -p flag) and filter language_server lines by PID
    private func findAllLSListenPorts() -> [Int: [Int]] {
        let lsof = Process()
        lsof.launchPath = "/usr/sbin/lsof"
        lsof.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        let pipe = Pipe()
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice
        guard (try? lsof.run()) != nil else { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        lsof.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        // Parse: "language_ 1298 klai 4u IPv4 ... TCP 127.0.0.1:49574 (LISTEN)"
        // Fields: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
        var result: [Int: [Int]] = [:]
        for line in output.components(separatedBy: "\n") {
            guard line.contains("language_"), line.contains("LISTEN") else { continue }

            // Extract PID (second field)
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 9, let pid = Int(fields[1]) else { continue }

            // Extract port from last meaningful field "127.0.0.1:PORT"
            let nameField = String(fields[8]) // e.g. "127.0.0.1:49574"
            if let colonIdx = nameField.lastIndex(of: ":") {
                let portStr = String(nameField[nameField.index(after: colonIdx)...])
                if let port = Int(portStr) {
                    result[pid, default: []].append(port)
                }
            }
        }
        return result
    }

    /// Lightweight HTTP check — send minimal request, expect any response
    private func isHTTPReachable(port: Int, csrfToken: String) -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 2
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["metadata": ["ideName": "antigravity"]])

        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                reachable = true
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return reachable
    }

    /// Fallback: original JSON file-based discovery
    private func findDaemonFromJSON() -> DaemonInfo? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: daemonDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        let sorted = jsonFiles.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return d1 > d2
        }

        for file in sorted {
            if let data = try? Data(contentsOf: file),
               let info = try? JSONDecoder().decode(DaemonInfo.self, from: data) {
                if isHTTPReachable(port: info.httpPort, csrfToken: info.csrfToken) {
                    return info
                }
            }
        }
        return nil
    }

    // Fetch quota using Connect/Protobuf JSON over HTTP
    func fetchQuota(daemon: DaemonInfo, completion: @Sendable @escaping (QuotaData?) -> Void) {
        let url = URL(string: "http://127.0.0.1:\(daemon.httpPort)/exa.language_server_pb.LanguageServerService/GetUserStatus")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(daemon.csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        let body = ["metadata": ["ideName": "antigravity", "extensionName": "antigravity", "locale": "en"]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                completion(nil)
                return
            }
            completion(self.parseQuota(json))
        }.resume()
    }

    private func parseQuota(_ json: [String: Any]) -> QuotaData? {
        guard let userStatus = json["userStatus"] as? [String: Any],
              let cascadeData = userStatus["cascadeModelConfigData"] as? [String: Any],
              let configs = cascadeData["clientModelConfigs"] as? [[String: Any]]
        else { return nil }

        let models: [ModelQuota] = configs.compactMap { config in
            guard let quotaInfo = config["quotaInfo"] as? [String: Any],
                  let label = config["label"] as? String
            else { return nil }

            let remainingFraction = (quotaInfo["remainingFraction"] as? Double) ?? 0.0
            let resetTimeStr = quotaInfo["resetTime"] as? String ?? ""
            let resetDate = ISO8601DateFormatter().date(from: resetTimeStr) ?? Date()
            let secsLeft = max(0, resetDate.timeIntervalSinceNow)
            let timeStr = formatTime(Int(secsLeft * 1000))

            return ModelQuota(
                label: label,
                remainingPercentage: remainingFraction * 100,
                isExhausted: remainingFraction == 0,
                timeUntilReset: timeStr,
                secondsUntilReset: secsLeft
            )
        }

        return QuotaData(models: models, timestamp: Date())
    }

    private func formatTime(_ ms: Int) -> String {
        if ms <= 0 { return "Ready" }
        let minutes = Int(ceil(Double(ms) / 60000))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours >= 24 {
            let days = hours / 24
            let rem = hours % 24
            return "\(days)d \(rem)h"
        }
        return "\(hours)h \(minutes % 60)m"
    }

    // MARK: - Actions

    func clearBrain() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: nil) else { return }
        for item in contents {
            let name = item.lastPathComponent
            if name == ".DS_Store" { continue }
            try? fm.removeItem(at: item)
        }
    }

    func clearCodeTracker() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: codeTrackerDir, includingPropertiesForKeys: nil) else { return }
        for item in contents {
            try? fm.removeItem(at: item)
        }
    }

    func openBrain() {
        NSWorkspace.shared.open(brainDir)
    }

    func openFile(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    // MARK: - Brain size

    func brainSize() -> String {
        return formatDirSize(dirSize(brainDir))
    }

    func cacheSize() -> (formatted: String, megabytes: Double) {
        let total = dirSize(brainDir) + dirSize(conversationsDir)
        return (formatDirSize(total), Double(total) / (1024 * 1024))
    }

    private func dirSize(_ dir: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                total += Int64(vals.fileSize ?? 0)
            }
        }
        return total
    }

    private func formatDirSize(_ total: Int64) -> String {
        if total < 1024 { return "\(total) B" }
        if total < 1024*1024 { return String(format: "%.1f KB", Double(total)/1024) }
        return String(format: "%.1f MB", Double(total)/(1024*1024))
    }
}
