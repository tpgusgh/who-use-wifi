import Foundation

struct PortResult: Identifiable, Hashable, Sendable {
    let id: Int
    var banner: String?
    var title: String?
    var pid: Int32?
    var processName: String?
}

struct HostResult: Identifiable, Hashable, Sendable {
    let id: String
    var ports: [PortResult]
    var isLocalMachine: Bool = false
}
