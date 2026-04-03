import Foundation
import Darwin

// Get PIDs
let maxPids = 2048
var pids = [pid_t](repeating: 0, count: maxPids)
let pidsSize = Int32(maxPids * MemoryLayout<pid_t>.stride)
let returnedBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, pidsSize)
let numPids = Int(returnedBytes) / MemoryLayout<pid_t>.stride

print("numPids scanned: \(numPids)")
var found = false
for i in 0..<numPids {
    let pid = pids[i]
    if pid <= 0 { continue }
    
    var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
    if pathLen > 0 {
        let path = String(cString: pathBuffer)
        if path.contains("Code") || path.contains("java") || path.contains("python") || path.contains("language_server") || path.contains("antigravity") { // loosen matching just to see if it works
            print("Found PID: \(pid), Path: \(path)")
            found = true
        }
    }
}
if !found { print("No target processes found") }
