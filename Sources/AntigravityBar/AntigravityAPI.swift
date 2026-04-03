import Foundation
import AppKit
import Darwin

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

struct CascadeUserStatus: Decodable {
    let userStatus: UserStatusContainer
}

struct UserStatusContainer: Decodable {
    let cascadeModelConfigData: CascadeModelConfigData
}

struct CascadeModelConfigData: Decodable {
    let clientModelConfigs: [ClientModelConfig]
}

struct ClientModelConfig: Decodable {
    let label: String?
    let quotaInfo: QuotaInfo?
}

struct QuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
}

// MARK: - API

class AntigravityAPI: @unchecked Sendable {
    @MainActor static let shared = AntigravityAPI()
    
    let env: SystemEnvironment
    
    init(env: SystemEnvironment = DefaultSystemEnvironment()) {
        self.env = env
    }

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

    /// Parse running language_server process args natively to get csrf_token,
    /// then find LISTEN ports using targeted lsof and validate via HTTP
    private func findDaemonFromProcess() -> DaemonInfo? {
        // 1. Get all language_server processes with csrf tokens
        let psInfo = findLanguageServerProcesses()
        guard !psInfo.isEmpty else { return nil }

        // 2. Try each process: match PID → ports via lsof -p PID → validate HTTP
        for info in psInfo {
            let ports = findListenPorts(forPID: info.pid)
            guard !ports.isEmpty else { continue }

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

    /// Find all language_server_macos processes and extract PID + csrf_token natively
    private func findLanguageServerProcesses() -> [LSProcessInfo] {
        var results: [LSProcessInfo] = []
        let maxPids = 2048
        var pids = [pid_t](repeating: 0, count: maxPids)
        let returnedBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(maxPids * MemoryLayout<pid_t>.stride))
        let numPids = Int(returnedBytes) / MemoryLayout<pid_t>.stride
        
        for i in 0..<numPids {
            let pid = pids[i]
            if pid <= 0 { continue }
            
            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            if pathLen > 0 {
                let path = String(cString: pathBuffer)
                if path.contains("language_server_macos") {
                    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
                    var size: Int = 0
                    sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0)
                    if size > 0 {
                        var buffer = [CChar](repeating: 0, count: size)
                        if sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 {
                            let argc = buffer.withUnsafeBufferPointer { ptr -> Int32 in
                                ptr.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
                            }
                            var offset = MemoryLayout<Int32>.size
                            while offset < buffer.count && buffer[offset] != 0 { offset += 1 }
                            while offset < buffer.count && buffer[offset] == 0 { offset += 1 }
                            
                            var args = [String]()
                            for _ in 0..<argc {
                                let argStart = offset
                                while offset < buffer.count && buffer[offset] != 0 { offset += 1 }
                                args.append(String(cString: Array(buffer[argStart...offset])))
                                offset += 1
                            }
                            
                            if let tokenIdx = args.firstIndex(of: "--csrf_token"), tokenIdx + 1 < args.count {
                                results.append(LSProcessInfo(pid: Int(pid), csrfToken: args[tokenIdx + 1]))
                            }
                        }
                    }
                }
            }
        }
        return results
    }

    /// Run targeted lsof for a specific PID to find listening TCP ports
    private func findListenPorts(forPID pid: Int) -> [Int] {
        let lsof = Process()
        lsof.launchPath = "/usr/sbin/lsof"
        lsof.arguments = ["-P", "-n", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]
        let pipe = Pipe()
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice
        guard (try? lsof.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        lsof.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var ports: [Int] = []
        for line in output.components(separatedBy: "\n") {
            guard line.contains("LISTEN") else { continue }

            // Extract port from last meaningful field "127.0.0.1:PORT"
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let nameField = fields.last else { continue }
            
            if let colonIdx = nameField.lastIndex(of: ":") {
                let portStr = String(nameField[nameField.index(after: colonIdx)...])
                if let port = Int(portStr) {
                    ports.append(port)
                }
            }
        }
        return ports
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
        final class ReachableStatus: @unchecked Sendable { var ok = false }
        let status = ReachableStatus()
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                status.ok = true
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return status.ok
    }

    /// Fallback: original JSON file-based discovery
    private func findDaemonFromJSON() -> DaemonInfo? {
        for _ in 0..<3 {
            guard let files = try? env.contentsOfDirectory(
                at: daemonDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else {
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            // Clean up stale JSONs (>2 mins)
            let now = Date()
            for file in jsonFiles {
                if let attrs = try? env.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   now.timeIntervalSince(modDate) > 120 {
                    try? env.removeItem(at: file)
                }
            }

            let sorted = jsonFiles.sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }

            for file in sorted {
                if let data = try? env.readData(contentsOf: file),
                   let info = try? JSONDecoder().decode(DaemonInfo.self, from: data) {
                    if isHTTPReachable(port: info.httpPort, csrfToken: info.csrfToken) {
                        return info
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
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
                  let parsed = try? JSONDecoder().decode(CascadeUserStatus.self, from: data)
            else {
                completion(nil)
                return
            }
            completion(self.parseQuota(parsed))
        }.resume()
    }

    func parseQuota(_ parsed: CascadeUserStatus) -> QuotaData? {
        let configs = parsed.userStatus.cascadeModelConfigData.clientModelConfigs

        let models: [ModelQuota] = configs.compactMap { config in
            guard let quotaInfo = config.quotaInfo,
                  let label = config.label
            else { return nil }

            let remainingFraction = quotaInfo.remainingFraction ?? 0.0
            let resetTimeStr = quotaInfo.resetTime ?? ""
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

    func formatTime(_ ms: Int) -> String {
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

    func clearCache() {
        let dirsToClear = [brainDir, conversationsDir]
        for dir in dirsToClear {
            guard let contents = try? env.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []) else { continue }
            for item in contents {
                let name = item.lastPathComponent
                if name == ".DS_Store" { continue }
                try? env.removeItem(at: item)
            }
        }
    }

    func clearBrain() {
        guard let contents = try? env.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: nil, options: []) else { return }
        for item in contents {
            let name = item.lastPathComponent
            if name == ".DS_Store" { continue }
            try? env.removeItem(at: item)
        }
    }

    func clearCodeTracker() {
        guard let contents = try? env.contentsOfDirectory(at: codeTrackerDir, includingPropertiesForKeys: nil, options: []) else { return }
        for item in contents {
            try? env.removeItem(at: item)
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
        guard let enumerator = env.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
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
