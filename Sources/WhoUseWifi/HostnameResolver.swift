import Foundation

enum HostnameResolver {
    static func resolve(ip: String, timeout: TimeInterval = 1.0) async -> String? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeOnce: (String?) -> Void = { name in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: name)
            }

            DispatchQueue.global(qos: .utility).async {
                var sin = sockaddr_in()
                sin.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                sin.sin_family = sa_family_t(AF_INET)
                inet_pton(AF_INET, ip, &sin.sin_addr)

                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let sinLen = socklen_t(sin.sin_len)
                let result = withUnsafePointer(to: &sin) { ptr -> Int32 in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                        getnameinfo(sockPtr, sinLen, &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NAMEREQD)
                    }
                }
                if result == 0 {
                    resumeOnce(String(cString: hostBuf))
                } else {
                    resumeOnce(nil)
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resumeOnce(nil)
            }
        }
    }
}
