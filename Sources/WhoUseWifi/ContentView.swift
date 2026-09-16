import SwiftUI
import AppKit

struct ContentView: View {
    @State private var results: [HostResult] = []
    @State private var isScanning = false
    @State private var progress = PortScanner.Progress(completed: 0, total: 0)
    private let scanner = PortScanner()

    private var totalOpenPorts: Int {
        results.reduce(0) { $0 + $1.ports.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(isScanning ? "스캔 중..." : "다시 스캔") {
                    startScan()
                }
                .disabled(isScanning)
                .buttonStyle(.borderedProminent)

                if isScanning {
                    ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                        .frame(width: 180)
                    Text("\(progress.completed) / \(progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if !results.isEmpty {
                    Text("\(results.count)대 · 포트 \(totalOpenPorts)개 열림")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)

            Divider()

            if results.isEmpty && !isScanning {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("스캔 버튼을 눌러 홈 네트워크를 확인하세요")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(results) { host in
                            Section {
                                VStack(spacing: 8) {
                                    ForEach(host.ports) { port in
                                        PortRow(host: host.id, port: port) {
                                            removePort(hostID: host.id, portID: port.id)
                                        }
                                    }
                                }
                            } header: {
                                HostHeader(host: host)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 460)
    }

    private func startScan() {
        isScanning = true
        results = []
        progress = PortScanner.Progress(completed: 0, total: 0)
        Task {
            let hosts = NetworkInfo.homeSubnetHosts()
            let localIP = NetworkInfo.primaryIPv4Address()
            let scanned = await scanner.scan(hosts: hosts, localIP: localIP) { p in
                Task { @MainActor in progress = p }
            }
            await MainActor.run {
                results = scanned
                isScanning = false
            }
        }
    }

    private func removePort(hostID: String, portID: Int) {
        guard let hostIndex = results.firstIndex(where: { $0.id == hostID }) else { return }
        results[hostIndex].ports.removeAll { $0.id == portID }
    }
}

private struct HostHeader: View {
    let host: HostResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: host.isLocalMachine ? "desktopcomputer" : "server.rack")
                .foregroundStyle(.secondary)
            Text(host.isLocalMachine ? "\(host.id) (이 기기)" : host.id)
                .font(.headline)
                .fontDesign(.monospaced)
            Text("포트 \(host.ports.count)개")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(.background)
    }
}

private struct PortRow: View {
    let host: String
    let port: PortResult
    var onTerminate: (() -> Void)? = nil

    @State private var showKillConfirm = false

    private var looksLikeWeb: Bool {
        port.title != nil || port.banner != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(":\(port.id)")
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .frame(width: 64, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Capsule().fill(.quaternary))

            VStack(alignment: .leading, spacing: 2) {
                if let title = port.title {
                    Text(title).font(.body).lineLimit(1)
                }
                if let processName = port.processName {
                    Text("\(processName) · pid \(port.pid ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let banner = port.banner {
                    Text(banner).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if !looksLikeWeb && port.processName == nil {
                    Text("웹 응답 없음").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if looksLikeWeb {
                Button("브라우저로 열기") {
                    if let url = URL(string: "http://\(host):\(port.id)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }

            if let pid = port.pid {
                Button("종료") {
                    showKillConfirm = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .confirmationDialog(
                    "\(port.processName ?? "프로세스") (pid \(pid)) 종료할까요?",
                    isPresented: $showKillConfirm,
                    titleVisibility: .visible
                ) {
                    Button("종료", role: .destructive) {
                        if LocalPortInspector.terminate(pid: pid) {
                            onTerminate?()
                        }
                    }
                    Button("취소", role: .cancel) {}
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}
