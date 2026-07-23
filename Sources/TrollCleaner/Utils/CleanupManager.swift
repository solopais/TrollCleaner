import Foundation

// MARK: - 清理管理器

actor CleanupManager {

    private let fm = FileManager.default
    private let trashRoot = "/var/mobile/Documents/TrollCleanerTrash/"

    // MARK: - 删除指定路径（先移入回收站）

    func deleteItems(_ items: [CleanableItem], progress: @escaping (Double, String) -> Void) async -> Int64 {
        let total = items.count
        var freed: Int64 = 0

        // 创建回收站目录
        let trashDir = URL(fileURLWithPath: trashRoot)
            .appendingPathComponent(DateFormatter.localizedString(
                from: Date(),
                dateStyle: .short,
                timeStyle: .short
            ).replacingOccurrences(of: "/", with: "-"))

        try? fm.createDirectory(at: trashDir, withIntermediateDirectories: true, attributes: nil)

        for (index, item) in items.enumerated() {
            let pct = Double(index) / Double(total)
            let name = URL(fileURLWithPath: item.path).lastPathComponent
            await progress(pct, "\(item.appName): \(name)")

            let src = URL(fileURLWithPath: item.path)
            let dest = trashDir.appendingPathComponent("\(item.appName)-\(name)")

            do {
                try fm.moveItem(at: src, to: dest)
                freed += item.size
            } catch {
                // 移动失败，尝试直接删除
                try? fm.removeItem(at: src)
                freed += item.size
            }
        }

        await progress(1.0, "清理完成")
        return freed
    }

    // MARK: - 清理单个 App 的缓存

    func cleanApp(_ app: AppInfo, types: Set<CleanableItem.CleanableType>) async -> Int64 {
        let container = URL(fileURLWithPath: app.containerPath)
        var freed: Int64 = 0

        if types.contains(.cache) {
            let cacheDir = container.appendingPathComponent("Library/Caches")
            freed += await deleteDirectoryContents(cacheDir)
        }
        if types.contains(.temp) {
            let tmpDir = container.appendingPathComponent("tmp")
            freed += await deleteDirectoryContents(tmpDir)
        }
        if types.contains(.splashBoard) {
            let sbDir = container.appendingPathComponent("Library/SplashBoard")
            freed += await deleteDirectoryContents(sbDir)
        }

        return freed
    }

    // MARK: - 微信专项清理

    func cleanWeChat(containerPath: String, options: WeChatCleanOptions) async -> Int64 {
        let container = URL(fileURLWithPath: containerPath)
        var freed: Int64 = 0

        // 微信的缓存目录结构
        let library = container.appendingPathComponent("Library")

        if options.clearCache {
            let cacheDir = library.appendingPathComponent("Caches")
            freed += await deleteDirectoryContents(cacheDir)
        }

        if options.clearTmp {
            let tmpDir = container.appendingPathComponent("tmp")
            freed += await deleteDirectoryContents(tmpDir)
        }

        if options.clearMomentsCache {
            let moments = library.appendingPathComponent("Caches/com.tencent.xin.moments")
            freed += await deleteDirectoryContents(moments)
        }

        if options.clearWebViewCache {
            let webview = library.appendingPathComponent("Caches/com.tencent.xin.WebKit")
            freed += await deleteDirectoryContents(webview)
        }

        // 清理接收的文件缓存（非文档）
        if options.clearReceivedFilesCache {
            let fileCache = library.appendingPathComponent("Caches/MMResourceMgr")
            freed += await deleteDirectoryContents(fileCache)
        }

        return freed
    }

    // MARK: - 清空回收站

    func emptyTrash() async -> Int64 {
        let trashDir = URL(fileURLWithPath: trashRoot)
        guard fm.fileExists(atPath: trashDir.path) else { return 0 }

        guard let contents = try? fm.contentsOfDirectory(
            at: trashDir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var freed: Int64 = 0
        for item in contents {
            if let size = try? item.directorySize() {
                freed += size
            }
            try? fm.removeItem(at: item)
        }
        return freed
    }

    // MARK: - 回收站大小

    func trashSize() async -> Int64 {
        let trashDir = URL(fileURLWithPath: trashRoot)
        guard fm.fileExists(atPath: trashDir.path) else { return 0 }
        return await FileScanner().calculateDirectorySize(at: trashDir)
    }

    // MARK: - 回收站文件数

    func trashFileCount() async -> Int {
        let trashDir = URL(fileURLWithPath: trashRoot)
        guard let enumerator = fm.enumerator(at: trashDir, includingPropertiesForKeys: nil) else { return 0 }
        var count = 0
        for _ in enumerator { count += 1 }
        return count
    }

    // MARK: - 私有方法

    private func deleteDirectoryContents(_ dir: URL) async -> Int64 {
        guard fm.fileExists(atPath: dir.path) else { return 0 }
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var freed: Int64 = 0
        for item in contents {
            if let size = try? item.directorySize() {
                freed += size
            }
            try? fm.removeItem(at: item)
        }
        return freed
    }
}

// MARK: - 微信清理选项

struct WeChatCleanOptions {
    let clearCache: Bool
    let clearTmp: Bool
    let clearMomentsCache: Bool
    let clearWebViewCache: Bool
    let clearReceivedFilesCache: Bool

    static let `default` = WeChatCleanOptions(
        clearCache: true,
        clearTmp: true,
        clearMomentsCache: true,
        clearWebViewCache: true,
        clearReceivedFilesCache: false
    )

    static let aggressive = WeChatCleanOptions(
        clearCache: true,
        clearTmp: true,
        clearMomentsCache: true,
        clearWebViewCache: true,
        clearReceivedFilesCache: true
    )

    static let safe = WeChatCleanOptions(
        clearCache: true,
        clearTmp: true,
        clearMomentsCache: false,
        clearWebViewCache: false,
        clearReceivedFilesCache: false
    )
}

// MARK: - URL 扩展

extension URL {
    func directorySize() throws -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            let attrs = try resourceValues(forKeys: [.fileSizeKey])
            return Int64(attrs.fileSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: self,
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
