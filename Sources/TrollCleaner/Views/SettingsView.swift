import SwiftUI

struct SettingsView: View {

    @AppStorage("excludeSystemApps") private var excludeSystemApps = true
    @AppStorage("minCacheSizeMB") private var minCacheSizeMB = 1.0
    @AppStorage("autoMoveToTrash") private var autoMoveToTrash = true
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false

    @State private var trashSize: String = "计算中..."

    var body: some View {
        NavigationView {
            Form {
                // MARK: 通用
                Section("通用") {
                    Toggle("排除系统 App", isOn: $excludeSystemApps)
                        .tint(.klBlue)
                    Toggle("清理时移入回收站", isOn: $autoMoveToTrash)
                        .tint(.klBlue)
                    Toggle("显示隐藏文件", isOn: $showHiddenFiles)
                        .tint(.klBlue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("最低显示缓存大小: \(Int(minCacheSizeMB)) MB")
                            .font(.subheadline)
                        Slider(value: $minCacheSizeMB, in: 0.1...100, step: 0.1)
                            .tint(.klBlue)
                    }
                }

                // MARK: 安全
                Section(footer: Text("开启后，清理时将跳过可能影响 App 正常运行的系统文件。")) {
                    Toggle("安全模式", isOn: .constant(true))
                        .tint(.klBlue)
                        .disabled(true)
                }

                // MARK: 回收站
                Section("回收站") {
                    HStack {
                        Text("回收站大小")
                        Spacer()
                        Text(trashSize)
                            .foregroundColor(.secondary)
                    }

                    Button("清空回收站", role: .destructive) {
                        Task {
                            let manager = CleanupManager()
                            let freed = await manager.emptyTrash()
                            trashSize = Formatters.formatBytes(0)
                        }
                    }
                }

            // MARK: 关于
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("作者")
                    Spacer()
                    Text("TrollCleaner")
                        .foregroundColor(.secondary)
                }

                NavigationLink(destination: DiagnosticView()) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.klBlue)
                        Text("诊断")
                            .foregroundColor(.klBlue)
                    }
                }

                Link("源代码", destination: URL(string: "https://github.com/solopais/TrollCleaner")!)
                    .foregroundColor(.klBlue)
            }
            }
            .navigationTitle("设置")
        }
        .task {
            let manager = CleanupManager()
            let size = await manager.trashSize()
            trashSize = Formatters.formatBytes(size)
        }
    }
}

#Preview {
    SettingsView()
}
