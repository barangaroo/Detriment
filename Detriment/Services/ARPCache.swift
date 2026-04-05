import Foundation
import Darwin

// Constants not bridged to Swift
private let RTF_LLINFO: Int32 = 0x400
private let RTM_VERSION: Int32 = 5

// rt_msghdr layout matching <net/route.h>
private struct rt_msghdr_swift {
    var rtm_msglen: UInt16
    var rtm_version: UInt8
    var rtm_type: UInt8
    var rtm_index: UInt16
    var rtm_flags: Int32
    var rtm_addrs: Int32
    var rtm_pid: Int32
    var rtm_seq: Int32
    var rtm_errno: Int32
    var rtm_use: Int32
    var rtm_inits: UInt32
    var rtm_rmx: rt_metrics_swift
}

private struct rt_metrics_swift {
    var rmx_locks: UInt32
    var rmx_mtu: UInt32
    var rmx_hopcount: UInt32
    var rmx_expire: Int32
    var rmx_recvpipe: UInt32
    var rmx_sendpipe: UInt32
    var rmx_ssthresh: UInt32
    var rmx_rtt: UInt32
    var rmx_rttvar: UInt32
    var rmx_pksent: UInt32
    var rmx_state: UInt32
    var rmx_filler: (UInt32, UInt32, UInt32)
}

/// Reads MAC addresses from the system ARP cache using sysctl.
final class ARPCache {
    static let shared = ARPCache()

    private init() {}

    func lookup(ip: String) -> String? {
        guard let entries = readARPTable() else { return nil }
        return entries[ip]
    }

    func readARPTable() -> [String: String]? {
        var mib: [Int32] = [
            CTL_NET,
            PF_ROUTE,
            0,
            AF_INET,
            NET_RT_FLAGS,
            RTF_LLINFO
        ]

        var bufferSize: Int = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0) == 0,
              bufferSize > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: bufferSize)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &bufferSize, nil, 0) == 0 else {
            return nil
        }

        var results: [String: String] = [:]
        var offset = 0
        let headerSize = MemoryLayout<rt_msghdr_swift>.size

        while offset + headerSize <= bufferSize {
            let msgLen: Int = buffer.withUnsafeBufferPointer { ptr in
                let raw = UnsafeRawPointer(ptr.baseAddress! + offset)
                let rtm = raw.load(as: rt_msghdr_swift.self)
                return Int(rtm.rtm_msglen)
            }

            guard msgLen > 0, offset + msgLen <= bufferSize else { break }

            let flags: Int32 = buffer.withUnsafeBufferPointer { ptr in
                let raw = UnsafeRawPointer(ptr.baseAddress! + offset)
                return raw.load(as: rt_msghdr_swift.self).rtm_flags
            }

            if flags & RTF_LLINFO != 0 {
                let saStart = offset + headerSize

                if saStart + MemoryLayout<sockaddr_in>.size <= bufferSize {
                    buffer.withUnsafeBufferPointer { ptr in
                        let sinPtr = UnsafeRawPointer(ptr.baseAddress! + saStart)
                        let sin = sinPtr.load(as: sockaddr_in.self)
                        let ip = String(cString: inet_ntoa(sin.sin_addr))

                        let sdlOffset = saStart + Int(sin.sin_len)
                        if sdlOffset + MemoryLayout<sockaddr_dl>.size <= bufferSize {
                            let sdlPtr = UnsafeRawPointer(ptr.baseAddress! + sdlOffset)
                            let sdl = sdlPtr.load(as: sockaddr_dl.self)

                            if sdl.sdl_alen == 6 {
                                let nameLen = Int(sdl.sdl_nlen)
                                let dataOffset = sdlOffset + 8 + nameLen
                                if dataOffset + 6 <= bufferSize {
                                    let mac = (0..<6).map { i in
                                        String(format: "%02X", ptr[dataOffset + i])
                                    }.joined(separator: ":")

                                    if mac != "00:00:00:00:00:00" {
                                        results[ip] = mac
                                    }
                                }
                            }
                        }
                    }
                }
            }

            offset += msgLen
        }

        return results
    }
}
