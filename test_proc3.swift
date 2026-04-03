import Foundation
import Darwin

let pid = Int32(8758) // 8758 was language_server_macos_arm from previous run
var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
var size: Int = 0

// Find size
sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0)

if size > 0 {
    var buffer = [CChar](repeating: 0, count: size)
    if sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 {
        // argc is at the beginning (first Int32)
        let argc = buffer.withUnsafeBufferPointer { ptr -> Int32 in
            return ptr.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        }
        
        // Skip argc
        var offset = MemoryLayout<Int32>.size
        
        // Find exe path (null terminated)
        let exePathStart = offset
        while offset < buffer.count && buffer[offset] != 0 { offset += 1 }
        
        // Skip null padding
        while offset < buffer.count && buffer[offset] == 0 { offset += 1 }
        
        var args = [String]()
        for _ in 0..<argc {
            let argStart = offset
            while offset < buffer.count && buffer[offset] != 0 { offset += 1 }
            let arg = String(cString: Array(buffer[argStart...offset]))
            args.append(arg)
            offset += 1
        }
        
        print("ARGC: \(argc)")
        print("ARGS: \(args)")
    } else {
        print("Failed to read args buffer")
    }
} else {
    print("Failed to read size")
}
