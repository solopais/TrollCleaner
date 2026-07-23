import SwiftUI

struct WeChatCleaningView: View {

    let app: AppInfo

    @State private var clearCache = true
    @State private var clearTmp = true
    @State private var clearMoments = true
    @State private var clearWebView = true
    @State private var clearReceivedFiles = false

    @State private var isCleaning = false
    @State private var showResult = false
    @State private var freedBytes: Int64 = 0
    @State private var estimatedSize: Int64 = 0
    @State private var isEstimating = true

    var body: some View {
        List {
            // MARK: 功能介绍
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("微信专项清理", systemImage: "message.fill")
                        .font(.headline)
                        .foregroundColor(.klBlue)
                    Text("安全清理微信缓存，保留聊天记录和重要文件。清理后微信可能需要重新加载部分内容。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            // MARK: 清理选项
            Section("清理内容") {
                Toggle(isOn: $clearCache) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("缓存文件")
                            .font(.subheadline)
                        Text("图片、视频、表情等缓存（可重新下载）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.klBlue)

                Toggle(isOn: $clearTmp) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("临时文件")
                            .font(.subheadline)
                        Text("运行产生的临时数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.klBlue)

                Toggle(isOn: $clearMoments) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("朋友圈缓存")
                            .font(.subheadline)
                        Text("朋友圈图片和视频缓存")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.klBlue)

                Toggle(isOn: $clearWebView) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("网页浏览缓存")
                            .font(.subheadline)
                        Text("微信内置浏览器产生的缓存")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.klBlue)

                Toggle(isOn: $clearReceivedFiles) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("接收文件缓存")
                                .font(.subheadline)
                            Text("⚠️ 谨慎")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                        Text("清理已接收文件的缓存副本（不影响聊天记录中的文件）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.klBlue)
            }

            // MARK: 预估大小
            Section {
                HStack {
                    Text("预估可清理")
                    Spacer()
                    if isEstimating {
                        ProgressView()
                    } else {
                        Text(Formatters.formatBytes(estimatedSize))
                            .font(.headline)
                            .foregroundColor(estimatedSize > 100 * 1024 * 1024 ? .klBlue : .secondary)
                    }
                }
            }

            // MARK: 清理按钮
            Section {
                Button(action: { startCleaning() }) {
                    HStack {
                        Spacer()
                        if isCleaning {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "trash")
                            Text("开始清理")
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.klBlue)
                .disabled(isCleaning || estimatedSize == 0)
            }

            // MARK: 安全提示
            Section(footer: Text("清理后微信可能需要重新登录部分服务，聊天记录不会受影响。如果遇到问题，请尝试重启微信。").font(.caption2)) {
                EmptyView()
            }
        }
        .navigationTitle("微信清理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("清理完成", isPresented: $showResult) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("成功释放 \(Formatters.formatBytes(freedBytes)) 存储空间")
        }
        .task {
            await estimateCleaning()
        }
    }

    // MARK: - 预估清理大小

    private func estimateCleaning() async {
        isEstimating = true
        let scanner = FileScanner()
        let container = URL(fileURLWithPath: app.containerPath)

        // 模拟预估（实际应该走更快的预估方式）
        let cacheSize = await scanner.quickEstimateDirectorySize(at: container.appendingPathComponent("Library/Caches"))
        let tmpSize = await scanner.quickEstimateDirectorySize(at: container.appendingPathComponent("tmp"))

        estimatedSize = cacheSize + tmpSize
        isEstimating = false
    }

    // MARK: - 执行清理

    private func startCleaning() {
        isCleaning = true

        let options = WeChatCleanOptions(
            clearCache: clearCache,
            clearTmp: clearTmp,
            clearMomentsCache: clearMoments,
            clearWebViewCache: clearWebView,
            clearReceivedFilesCache: clearReceivedFiles
        )

        Task {
            let manager = CleanupManager()
            let freed = await manager.cleanWeChat(containerPath: app.containerPath, options: options)
            freedBytes = freed
            isCleaning = false
            showResult = true
            estimatedSize = 0
        }
    }
}

// MARK: - 文件大小估算（在调用方文件内直接实现）

extension FileScanner {
    /// 快速估算目录总大小（用于 UI 显示估算，不要求精确）
    func quickEstimateDirectorySize(at url: URL) async -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  attrs.isRegularFile == true,
                  let size = attrs.fileSize
            else { continue }
            total += Int64(size)
        }
        return total
    }
}
