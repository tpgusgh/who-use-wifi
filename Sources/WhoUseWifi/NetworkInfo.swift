import Foundation

enum NetworkInfo {
    static func subnetHosts(fromIP ip: String) -> [String] {
        let octets = ip.split(separator: ".")
        guard octets.count == 4 else { return [] }
        let prefix = octets[0...2].joined(separator: ".")
        return (1...254).map { "\(prefix).\($0)" }
    }

    static func primaryIPv4Address() -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var candidate: String?
        var ptr: UnsafeMutablePointer<ifaddrs> = firstAddr
        while true {
            let interface = ptr.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            if isUp, !isLoopback, interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") {
                    var addr = interface.ifa_addr.pointee
                    var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(addr.sa_len), &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                    candidate = String(cString: buf)
                    if name == "en0" { break }
                }
            }
            guard let next = interface.ifa_next else { break }
            ptr = next
        }
        return candidate
    }

    static func homeSubnetHosts() -> [String] {
        guard let ip = primaryIPv4Address() else { return [] }
        return subnetHosts(fromIP: ip)
    }
}
