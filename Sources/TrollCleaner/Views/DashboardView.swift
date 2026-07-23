import SwiftUI

struct DashboardView: View {

    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部状态卡
                    statusCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // 扫描结果
                    if case let .completed(result) = viewModel.scanState {
                        resultSummary(result)
                            .padding(.horizontal, 20)

                        appList(result)
                            .padding(.horizontal, 20)

                        systemCleanupSection(result)
                            .padding(.horizontal, 20)
                    }

                    // 回收站
                    trashSection
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("TrollCleaner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.scanState.isScanning {
                        ProgressView()
                    } else {
                        Button(action: { viewModel.startScan() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isCleaning)
                    }
                }
            }
            .alert("提示", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }

    // MARK: - 状态卡

    private var statusCard: some View {
        VStack(spacing: 12) {
            switch viewModel.scanState {
            case .idle:
                Image(systemName: "trash.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.klBlue)
                Text("点击右上角刷新开始扫描")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case let .scanning(progress, appName):
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .klBlue))
                    .padding(.horizontal, 40)
                VStack(spacing: 4) {
                    Text("正在扫描...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.klBlue)
                        .lineLimit(1)
                }

            case let .completed(result):
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("可清理空间")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(Formatters.formatBytes(result.totalCleanableBytes))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.klBlue)
                    }
                    Spacer()
                    Button(action: { viewModel.cleanAll() }) {
                        Text("一键清理")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.klBlue)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isCleaning || result.totalCleanableBytes == 0)
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)

            case let .failed(msg):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") { viewModel.startScan() }
                        .font(.subheadline)
                        .foregroundColor(.klBlue)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - 结果摘要

    private func resultSummary(_ result: ScanResult) -> some View {
        HStack(spacing: 12) {
            statCard(
                icon: "app.badge",
                value: "\(result.apps.count)",
                label: "App 数"
            )
            statCard(
                icon: "clock",
                value: Formatters.formatDuration(result.totalScanTime),
                label: "扫描耗时"
            )
            statCard(
                icon: "externaldrive.badge.checkmark",
                value: Formatters.formatBytes(result.systemCacheSize + result.logSize),
                label: "系统缓存"
            )
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.klBlue)
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }

    // MARK: - App 列表

    private func appList(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App 缓存排行")
                .font(.headline)

            ForEach(Array(result.apps.filter { $0.totalCleanableSize > 0 }.prefix(10))) { app in
                NavigationLink(destination: AppDetailView(app: app)) {
                    AppRow(app: app)
                }
                .buttonStyle(.plain)
            }

            if result.apps.filter({ $0.totalCleanableSize > 0 }).count > 10 {
                Text("及更多...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 系统清理

    private func systemCleanupSection(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("系统清理")
                .font(.headline)

            if result.systemCacheSize > 0 {
                Button(action: { viewModel.cleanSystemCaches() }) {
                    HStack {
                        Image(systemName: "icloud.slash")
                            .foregroundColor(.klBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("系统缓存")
                                .font(.subheadline.weight(.medium))
                            Text(Formatters.formatBytes(result.systemCacheSize))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            if result.logSize > 0 {
                Button(action: { viewModel.cleanLogs() }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.klBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("系统日志")
                                .font(.subheadline.weight(.medium))
                            Text(Formatters.formatBytes(result.logSize))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 回收站

    private var trashSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("回收站")
                .font(.headline)

            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.klBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TrollCleaner 回收站")
                        .font(.subheadline.weight(.medium))
                    Text("已清理的文件暂存于此")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.trashCount > 0 {
                    Text("\(viewModel.trashCount) 个文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("清空") {
                        viewModel.emptyTrash()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - App 行

struct AppRow: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 12) {
            // App 图标
            if let iconData = app.iconData, let uiImage = UIImage(data: iconData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(9)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Image(systemName: "app.fill")
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let ver = app.version {
                    Text("v\(ver)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 2) {
                if app.cacheSize > 0 {
                    cacheBadge(size: app.cacheSize, label: "缓")
                }
                if app.tmpSize > 0 {
                    cacheBadge(size: app.tmpSize, label: "临")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private func cacheBadge(size: Int64, label: String) -> some View {
        Text("\(label)\(Formatters.formatBytes(size))")
            .font(.system(size: 10, design: .rounded))
            .foregroundColor(.klBlue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.klBlue.opacity(0.1))
            .cornerRadius(4)
    }
}

// MARK: - App 详情

struct AppDetailView: View {
    let app: AppInfo

    @State private var isCleaning = false
    @State private var freedBytes: Int64 = 0
    @State private var showResult = false

    var body: some View {
        List {
            Section("信息") {
                detailRow("名称", app.displayName)
                detailRow("包名", app.bundleIdentifier)
                if let ver = app.version {
                    detailRow("版本", ver)
                }
                detailRow("容器路径", app.containerPath)
            }

            Section("可清理内容") {
                if app.cacheSize > 0 {
                    cleanRow(label: "缓存 (Caches)", size: app.cacheSize, type: .cache)
                }
                if app.tmpSize > 0 {
                    cleanRow(label: "临时文件 (tmp)", size: app.tmpSize, type: .temp)
                }
                if app.splashBoardSize > 0 {
                    cleanRow(label: "快照缓存 (SplashBoard)", size: app.splashBoardSize, type: .splashBoard)
                }
                if app.totalCleanableSize == 0 {
                    Text("没有可清理的缓存")
                        .foregroundColor(.secondary)
                }
            }

            if app.isWeChat {
                Section("微信专项清理") {
                    NavigationLink(destination: WeChatCleaningView(app: app)) {
                        Label("进入微信专项清理", systemImage: "message.fill")
                            .foregroundColor(.klBlue)
                    }
                }
            }

            if isCleaning {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(app.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("清理完成", isPresented: $showResult) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("释放了 \(Formatters.formatBytes(freedBytes)) 空间")
        }
    }

    private func cleanRow(label: String, size: Int64, type: CleanableItem.CleanableType) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(Formatters.formatBytes(size))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("清理") {
                Task {
                    isCleaning = true
                    let manager = CleanupManager()
                    let freed = await manager.cleanApp(app, types: [type])
                    freedBytes = freed
                    isCleaning = false
                    showResult = true
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.klBlue)
            .disabled(isCleaning)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
    }
}

// MARK: - ViewModel

@MainActor
class DashboardViewModel: ObservableObject {

    @Published var scanState: ScanState = .idle
    @Published var isCleaning = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var trashCount = 0

    private var currentResult: ScanResult?

    func startScan() {
        scanState = .scanning(progress: 0, currentApp: "准备扫描...")
        Task {
            let scanner = FileScanner()
            let result = await scanner.scanAll { [weak self] progress, appName in
                Task { @MainActor in
                    self?.scanState = .scanning(progress: progress, currentApp: appName)
                }
            }
            currentResult = result
            scanState = .completed(result)
            await updateTrashCount()
        }
    }

    func cleanAll() {
        guard let result = currentResult, result.totalCleanableBytes > 0 else { return }
        isCleaning = true

        Task {
            var items: [CleanableItem] = []
            for app in result.apps where app.totalCleanableSize > 0 {
                if app.cacheSize > 0 {
                    items.append(CleanableItem(
                        path: "\(app.containerPath)/Library/Caches",
                        size: app.cacheSize,
                        type: .cache,
                        appName: app.displayName
                    ))
                }
                if app.tmpSize > 0 {
                    items.append(CleanableItem(
                        path: "\(app.containerPath)/tmp",
                        size: app.tmpSize,
                        type: .temp,
                        appName: app.displayName
                    ))
                }
            }

            let manager = CleanupManager()
            let freed = await manager.deleteItems(items) { _, _ in }

            isCleaning = false
            alertMessage = "清理完成！释放了 \(Formatters.formatBytes(freed))"
            showAlert = true
            // 重新扫描
            startScan()
        }
    }

    func cleanSystemCaches() {
        isCleaning = true
        Task {
            let manager = CleanupManager()
            let path = "/var/mobile/Library/Caches/"
            let item = CleanableItem(path: path, size: currentResult?.systemCacheSize ?? 0, type: .systemCache, appName: "系统")
            let freed = await manager.deleteItems([item]) { _, _ in }
            isCleaning = false
            alertMessage = "系统缓存已清理，释放 \(Formatters.formatBytes(freed))"
            showAlert = true
            startScan()
        }
    }

    func cleanLogs() {
        isCleaning = true
        Task {
            let manager = CleanupManager()
            let logPaths = ["/var/mobile/Library/Logs/", "/var/log/"]
            var freed: Int64 = 0
            for path in logPaths {
                let item = CleanableItem(path: path, size: 0, type: .log, appName: "系统")
                freed += await manager.deleteItems([item]) { _, _ in }
            }
            isCleaning = false
            alertMessage = "系统日志已清理，释放 \(Formatters.formatBytes(freed))"
            showAlert = true
            startScan()
        }
    }

    func emptyTrash() {
        Task {
            let manager = CleanupManager()
            let freed = await manager.emptyTrash()
            trashCount = 0
            alertMessage = "回收站已清空，释放 \(Formatters.formatBytes(freed))"
            showAlert = true
        }
    }

    private func updateTrashCount() async {
        let manager = CleanupManager()
        trashCount = await manager.trashFileCount()
    }
}

// MARK: - 颜色扩展

extension Color {
    static let klBlue = Color(red: 0, green: 0.184, blue: 0.973) // #002FA7 的近似
}

// MARK: - Preview

#Preview {
    DashboardView()
}
