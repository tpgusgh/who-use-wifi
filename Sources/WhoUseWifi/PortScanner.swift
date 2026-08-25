import Foundation
import Network

enum CommonPorts {
    static let list: [UInt16] = [
        80, 443, 3000, 3001, 3306, 5000, 5432, 6379, 7000, 8000,
        8008, 8080, 8081, 8443, 8888, 9000, 9090, 9200, 27017
    ]
}

actor PortScanner {
    struct Progress: Sendable {
        var completed: Int
        var total: Int
    }

    func scan(
        hosts: [String],
        ports: [UInt16] = CommonPorts.list,
        maxConcurrent: Int = 160,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async -> [HostResult] {
        let pairs = hosts.flatMap { host in ports.map { (host, $0) } }
        var openByHost: [String: [PortResult]] = [:]
        var completed = 0
        let total = pairs.count

        await withTaskGroup(of: (String, UInt16, Bool).self) { group in
            var iterator = pairs.makeIterator()

            func addNext() {
                guard let (host, port) = iterator.next() else { return }
                group.addTask {
                    let open = await Self.isPortOpen(host: host, port: port)
                    return (host, port, open)
                }
            }

            for _ in 0..<maxConcurrent { addNext() }

            while let (host, port, open) = await group.next() {
                completed += 1
                onProgress(Progress(completed: completed, total: total))
                if open {
                    openByHost[host, default: []].append(PortResult(id: Int(port)))
                }
                addNext()
            }
        }

        var hostResults: [HostResult] = []
        await withTaskGroup(of: HostResult.self) { group in
            for (host, ports) in openByHost {
                group.addTask {
                    var enriched: [PortResult] = []
                    for p in ports {
                        let (banner, title) = await BannerFetcher.fetch(host: host, port: UInt16(p.id))
                        enriched.append(PortResult(id: p.id, banner: banner, title: title))
                    }
                    return HostResult(id: host, ports: enriched.sorted { $0.id < $1.id })
                }
            }
            for await result in group {
                hostResults.append(result)
            }
        }

        return hostResults.sorted { ipLess($0.id, $1.id) }
    }

    private static func isPortOpen(host: String, port: UInt16, timeout: TimeInterval = 0.3) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            var didResume = false
            let resumeOnce: (Bool) -> Void = { open in
                guard !didResume else { return }
                didResume = true
                connection.cancel()
                continuation.resume(returning: open)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeOnce(true)
                case .failed, .cancelled:
                    resumeOnce(false)
                default:
                    break
                }
            }

            let queue = DispatchQueue(label: "portscan.\(host).\(port)")
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                resumeOnce(false)
            }
        }
    }
}

private func ipLess(_ a: String, _ b: String) -> Bool {
    let ao = a.split(separator: ".").compactMap { Int($0) }
    let bo = b.split(separator: ".").compactMap { Int($0) }
    return ao.lexicographicallyPrecedes(bo)
}
