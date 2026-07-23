import Foundation

// MARK: - 应用信息

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let bundleIdentifier: String
    let displayName: String
    let containerPath: String
    let bundlePath: String?
    let version: String?
    let iconData: Data?

    var cacheSize: Int64 = 0
    var tmpSize: Int64 = 0
    var splashBoardSize: Int64 = 0
    var totalCleanableSize: Int64 { cacheSize + tmpSize + splashBoardSize }

    var isWeChat: Bool {
        bundleIdentifier == "com.tencent.xin"
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}

// MARK: - 扫描结果

struct ScanResult {
    let totalScanTime: TimeInterval
    let totalCleanableBytes: Int64
    let totalFiles: Int
    let apps: [AppInfo]
    let systemCacheSize: Int64
    let logSize: Int64
}

// MARK: - 清理项

struct CleanableItem: Identifiable {
    let id = UUID()
    let path: String
    let size: Int64
    let type: CleanableType
    let appName: String

    enum CleanableType: String {
        case cache = "缓存"
        case temp = "临时文件"
        case splashBoard = "快照缓存"
        case log = "系统日志"
        case systemCache = "系统缓存"
    }
}

// MARK: - 扫描状态

enum ScanState {
    case idle
    case scanning(progress: Double, currentApp: String)
    case completed(ScanResult)
    case failed(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

// MARK: - 清理状态

enum CleanupState {
    case idle
    case cleaning(progress: Double, current: String)
    case completed(freedBytes: Int64)
    case failed(String)
}
