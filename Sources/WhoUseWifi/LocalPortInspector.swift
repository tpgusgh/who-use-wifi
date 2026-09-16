import Foundation
import Darwin

enum LocalPortInspector {
    struct Entry {
        let port: Int
        let pid: Int32
        let processName: String
    }

    static func listListeningPorts() -> [Entry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var seenPorts = Set<Int>()
        var entries: [Entry] = []

        for line in output.split(separator: "\n").dropFirst() {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 9,
                  let pid = Int32(fields[1]),
                  let portString = fields[8].split(separator: ":").last,
                  let port = Int(portString),
                  !seenPorts.contains(port)
            else { continue }

            seenPorts.insert(port)
            entries.append(Entry(port: port, pid: pid, processName: String(fields[0])))
        }

        return entries.sorted { $0.port < $1.port }
    }

    @discardableResult
    static func terminate(pid: Int32) -> Bool {
        kill(pid, SIGTERM) == 0
    }
}
