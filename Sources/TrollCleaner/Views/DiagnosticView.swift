import SwiftUI

struct DiagnosticView: View {

    @State private var probes: [DiagnosticsService.Probe] = []
    @State private var isRunning = false

    var body: some View {
        List {
            Section {
                Button(action: runDiagnostics) {
                    HStack {
                        if isRunning {
                            ProgressView()
                        } else {
                            Image(systemName: "stethoscope")
                        }
                        Text(isRunning ? "诊断中..." : "运行诊断")
                            .font(.headline)
                    }
                }
                .tint(.klBlue)
                .disabled(isRunning)
            }

            Section("TrollCleaner 状态摘要") {
                statusRow("iOS Bundle", Bundle.main.bundleIdentifier ?? "-")
                statusRow("Bundle 路径", Bundle.main.bundleURL.path)
                statusRow("可执行路径", Bundle.main.executablePath ?? "-")
            }

            if !probes.isEmpty {
                Section("文件系统访问测试") {
                    ForEach(probes) { probe in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(probe.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)

                            HStack(spacing: 6) {
                                Text(probe.status)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if probe.accessible && probe.itemCount > 0 {
                                    Text("\(probe.itemCount) 项")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if probe.accessible && !probe.samples.isEmpty {
                                Text(probe.detailText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            } else if !probe.accessible {
                                Text(probe.detailText)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("结论") {
                    Text(verdict)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("诊断")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if probes.isEmpty {
                runDiagnostics()
            }
        }
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func runDiagnostics() {
        isRunning = true
        Task {
            let service = DiagnosticsService()
            let result = await service.probeAll()
            probes = result
            isRunning = false
        }
    }

    private var verdict: String {
        let containers = probes.first { $0.path.contains("Containers/Data/Application") }
        let sysCaches = probes.first { $0.path.contains("/var/mobile/Library/Caches/") }

        if let c = containers, c.accessible && c.itemCount > 0 {
            return "✅ 文件系统权限正常。如果你仍然看到 0B 可清理空间，说明 /var/mobile/Containers/Data/Application/ 下确实没有大缓存文件。可以试试打开 iOS 设置 → 通用 → iPhone 存储，查看哪些 App 缓存大。"
        }
        if let sys = sysCaches, sys.accessible && sys.itemCount > 0 {
            return "⚠️ 系统库可访问，但 App 数据容器拒绝访问。ldid 注入的 entitlements 没有生效。检查 ldid 步骤是否成功运行（GitHub Actions 日志）。"
        }
        return "❌ 文件系统受限。TrollStore entitlements 没有被正确应用。可能需要：1) 检查 ldid 步骤是否成功；2) 重新生成权限文件；3) 确认设备是 rootless 越狱或原生 iOS 15.5-16.6.1 + TrollStore 2。"
    }
}

#Preview {
    NavigationView {
        DiagnosticView()
    }
}
