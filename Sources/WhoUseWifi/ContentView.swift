import SwiftUI
import AppKit

struct ContentView: View {
    @State private var results: [HostResult] = []
    @State private var isScanning = false
    @State private var progress = PortScanner.Progress(completed: 0, total: 0)
    private let scanner = PortScanner()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(isScanning ? "스캔 중..." : "스캔") {
                    startScan()
                }
                .disabled(isScanning)

                if isScanning {
                    ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                        .frame(width: 200)
                    Text("\(progress.completed) / \(progress.total)")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding([.horizontal, .top])

            if results.isEmpty && !isScanning {
                Spacer()
                Text("스캔 버튼을 눌러 홈 네트워크를 확인하세요")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List {
                    ForEach(results) { host in
                        Section(host.id) {
                            ForEach(host.ports) { port in
                                PortRow(host: host.id, port: port)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    private func startScan() {
        isScanning = true
        results = []
        progress = PortScanner.Progress(completed: 0, total: 0)
        Task {
            let hosts = NetworkInfo.homeSubnetHosts()
            let scanned = await scanner.scan(hosts: hosts) { p in
                Task { @MainActor in progress = p }
            }
            await MainActor.run {
                results = scanned
                isScanning = false
            }
        }
    }
}

private struct PortRow: View {
    let host: String
    let port: PortResult

    var body: some View {
        HStack {
            Text(":\(port.id)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading) {
                if let title = port.title {
                    Text(title).font(.body)
                }
                if let banner = port.banner {
                    Text(banner).font(.caption).foregroundStyle(.secondary)
                }
                if port.title == nil && port.banner == nil {
                    Text("포트 열림").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("브라우저로 열기") {
                if let url = URL(string: "http://\(host):\(port.id)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
