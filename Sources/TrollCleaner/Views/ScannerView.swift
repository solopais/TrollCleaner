import SwiftUI

struct ScannerView: View {

    @StateObject private var viewModel = ScannerViewModel()

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.state {
                case .idle:
                    idleView
                case .scanning:
                    scanningView
                case let .done(result):
                    resultView(result)
                case let .error(msg):
                    errorView(msg)
                }
            }
            .navigationTitle("App 缓存")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.state.isScanning == false {
                        Button(action: { viewModel.startScan() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear {
            if case .idle = viewModel.state {
                viewModel.startScan()
            }
        }
    }

    // MARK: - 闲置状态

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 56))
                .foregroundColor(.klBlue)
            Text("准备扫描 App 缓存")
                .font(.headline)
            Button("开始扫描") {
                viewModel.startScan()
            }
            .buttonStyle(.borderedProminent)
            .tint(.klBlue)
        }
    }

    // MARK: - 扫描中

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.klBlue)

            VStack(spacing: 4) {
                Text("正在扫描...")
                    .font(.headline)
                Text(viewModel.scanningApp)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if viewModel.scanProgress > 0 {
                ProgressView(value: viewModel.scanProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .klBlue))
                    .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - 结果

    private func resultView(_ result: ScanResult) -> some View {
        List {
            Section {
                HStack {
                    Text("总计可清理")
                    Spacer()
                    Text(Formatters.formatBytes(result.totalCleanableBytes))
                        .font(.title3.weight(.bold))
                        .foregroundColor(.klBlue)
                }
            }

            ForEach(result.apps.filter { $0.totalCleanableSize > 0 }) { app in
                NavigationLink(destination: AppDetailView(app: app)) {
                    AppRow(app: app)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 错误

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(msg)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("重试") {
                viewModel.startScan()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - ViewModel

@MainActor
class ScannerViewModel: ObservableObject {

    enum ViewState {
        case idle
        case scanning
        case done(ScanResult)
        case error(String)

        var isScanning: Bool {
            if case .scanning = self { return true }
            return false
        }
    }

    @Published var state: ViewState = .idle
    @Published var scanProgress: Double = 0
    @Published var scanningApp: String = ""

    func startScan() {
        state = .scanning
        scanProgress = 0

        Task {
            let scanner = FileScanner()
            let result = await scanner.scanAll { [weak self] progress, appName in
                Task { @MainActor in
                    self?.scanProgress = progress
                    self?.scanningApp = appName
                }
            }
            state = .done(result)
        }
    }
}
