import Foundation
import Darwin

let pid: Int32 = 8758

// 1. Get FDs length
let fdCount = Int(proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)) / MemoryLayout<proc_fdinfo>.size
if fdCount <= 0 { print("No FDs"); exit(1) }

var fdInfos = [proc_fdinfo](repeating: proc_fdinfo(), count: fdCount)
let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fdInfos, Int32(fdInfos.count * MemoryLayout<proc_fdinfo>.size))
let actualCount = Int(bytes) / MemoryLayout<proc_fdinfo>.size

for i in 0..<actualCount {
    let fdInfo = fdInfos[i]
    if fdInfo.proc_fdtype == PROX_FDTYPE_SOCKET {
        var sockInfo = socket_fdinfo()
        let sb = proc_pidfdinfo(pid, fdInfo.proc_fd, PROC_PIDFDSOCKETINFO, &sockInfo, Int32(MemoryLayout<socket_fdinfo>.size))
        if sb == MemoryLayout<socket_fdinfo>.size {
            // Check if TCP
            if sockInfo.psi.so_protocol == IPPROTO_TCP {
                let tcpInfo = sockInfo.psi.so_xti.xti_tcp
                
                // TSI_S_LISTEN is 1 (or 2 sometimes) depending on Darwin networking headers, actually TCP_LISTEN is typically state 1.
                // Wait, TSI_S_LISTEN = 1.
                let state = sockInfo.psi.so_ti.ti_tstate
                print("Socket FD: \(fdInfo.proc_fd) TCP State \(state)")
                
                if state == 1 /* TSI_S_LISTEN */ {
                    // Extract port. It's stored in in4_sockinfo (if IPv4)
                    let family = sockInfo.psi.so_family
                    if family == AF_INET {
                        let port = Int(sockInfo.psi.so_in.insi_lport).byteSwapped
                        print("Listening IPv4 Port: \(port)")
                    } else if family == AF_INET6 {
                        let port = Int(sockInfo.psi.so_in.insi_lport).byteSwapped
                        print("Listening IPv6 Port: \(port)")
                    }
                }
            }
        }
    }
}
