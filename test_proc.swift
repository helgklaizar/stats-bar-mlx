import Foundation
import Darwin

print("Checking proc_listpids...")
var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
let res = proc_name(1, &nameBuffer, UInt32(nameBuffer.count))
if res > 0 {
    print(String(cString: nameBuffer))
} else {
    print("Failed")
}
