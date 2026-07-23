import Foundation
import UIKit

// MARK: - 文件扫描引擎

actor FileScanner {

    private let fm = FileManager.default

    /// 数据容器根目录（TrollStore 环境下可访问）
    private let appDataRoot = "/var/mobile/Containers/Data/Application/"
    private let systemCachesPath = "/var/mobile/Library/Caches/"
    private let logPaths = [
        "/var/mobile/Library/Logs/",
        "/var/log/",
    ]

    // MARK: - 扫描所有 App 的缓存

    func scanAll(progress: @escaping (Double, String) -> Void) async -> ScanResult {
        let startTime = Date()

        // 获取所有 App 容器
        let appDirs = await listAppContainers()
        let total = max(appDirs.count, 1)

        var apps: [AppInfo] = []

        for (index, dir) in appDirs.enumerated() {
            let pct = Double(index) / Double(total)
            let name = await appName(from: dir)
            await progress(pct, name)

            var info = await readAppMetadata(at: dir)
            if info == nil {
                info = AppInfo(
                    bundleIdentifier: dir.lastPathComponent,
                    displayName: dir.lastPathComponent,
                    containerPath: dir.path,
                    bundlePath: nil,
                    version: nil,
                    iconData: nil
                )
            }

            // 扫描缓存
            if let infoUnwrapped = info {
                var mutableInfo = infoUnwrapped
                mutableInfo.cacheSize = await calculateDirectorySize(at: dir.appendingPathComponent("Library/Caches"))
                mutableInfo.tmpSize = await calculateDirectorySize(at: dir.appendingPathComponent("tmp"))
                mutableInfo.splashBoardSize = await calculateDirectorySize(at: dir.appendingPathComponent("Library/SplashBoard"))
                apps.append(mutableInfo)
            }
        }

        await progress(1.0, "扫描系统缓存")
        let sysCache = await calculateDirectorySize(at: URL(fileURLWithPath: systemCachesPath))
        let logSize = await calculateLogSize()

        let totalBytes = apps.reduce(0) { $0 + $1.totalCleanableSize } + sysCache + logSize
        let totalFiles = apps.reduce(0) { _,_ in 0 } // 简化，不精确统计文件数

        return ScanResult(
            totalScanTime: Date().timeIntervalSince(startTime),
            totalCleanableBytes: totalBytes,
            totalFiles: 0,
            apps: apps.sorted { $0.totalCleanableSize > $1.totalCleanableSize },
            systemCacheSize: sysCache,
            logSize: logSize
        )
    }

    // MARK: - 列出 App 数据容器

    private func listAppContainers() async -> [URL] {
        let root = URL(fileURLWithPath: appDataRoot)
        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return entries.filter { url in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return false }
            // 过滤 UUID 格式的目录
            let name = url.lastPathComponent
            return name.count == 36 && name.contains("-")
        }
    }

    // MARK: - 读取 App 元数据

    private func readAppMetadata(at containerURL: URL) async -> AppInfo? {
        let metaPath = containerURL.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        let iTunesMetaPath = containerURL.appendingPathComponent("iTunesMetadata.plist")

        guard let meta = try? NSDictionary(contentsOf: metaPath),
              let bundleID = meta["MCMMetadataIdentifier"] as? String
        else {
            // 尝试通过 iTunesMetadata 读取
            if let iTunesMeta = try? NSDictionary(contentsOf: iTunesMetaPath),
               let bid = iTunesMeta["softwareIdentifier"] as? String ?? iTunesMeta["itemId"] as? String {
                let name = iTunesMeta["itemName"] as? String ?? bid
                let ver = iTunesMeta["bundleVersion"] as? String
                return AppInfo(
                    bundleIdentifier: bid,
                    displayName: name,
                    containerPath: containerURL.path,
                    bundlePath: nil,
                    version: ver,
                    iconData: nil
                )
            }
            return nil
        }

        let displayName = meta["MCMMetadataDisplayName"] as? String ?? bundleID
        let version = meta["MCMMetadataBundleVersion"] as? String

        // 尝试获取图标（从 bundle 路径）
        var iconData: Data? = nil
        if let bundlePathStr = meta["MCMMetadataBundlePath"] as? String {
            let bundleURL = URL(fileURLWithPath: bundlePathStr)
            iconData = await extractAppIcon(from: bundleURL)
        }

        return AppInfo(
            bundleIdentifier: bundleID,
            displayName: displayName,
            containerPath: containerURL.path,
            bundlePath: meta["MCMMetadataBundlePath"] as? String,
            version: version,
            iconData: iconData
        )
    }

    // MARK: - 提取 App 图标

    private func extractAppIcon(from bundleURL: URL) async -> Data? {
        // 常见的图标文件名
        let candidates = [
            "AppIcon60x60@2x.png",
            "AppIcon60x60@3x.png",
            "AppIcon57x57.png",
            "Icon-60@2x.png",
            "Icon-60@3x.png",
            "Icon.png",
        ]

        // 先检查 Assets.car（大多数现代 App 使用）
        let assetsPath = bundleURL.appendingPathComponent("Assets.car")
        if fm.fileExists(atPath: assetsPath.path) {
            // Assets.car 需要外部工具提取，暂时跳过
        }

        for candidate in candidates {
            let path = bundleURL.appendingPathComponent(candidate)
            if let data = try? Data(contentsOf: path) {
                return data
            }
        }

        // 扫描 .app 目录查找 Icon 开头的文件
        if let appDir = try? fm.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for file in appDir {
                let name = file.lastPathComponent
                if name.hasPrefix("Icon") || name.hasPrefix("AppIcon") {
                    if let data = try? Data(contentsOf: file) {
                        return data
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 计算目录大小

    func calculateDirectorySize(at url: URL) async -> Int64 {
        guard fm.fileExists(atPath: url.path) else { return 0 }

        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let attrs = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if attrs.isRegularFile == true, let size = attrs.fileSize {
                total += Int64(size)
            } else if attrs.isDirectory == true {
                // 递归子目录
                total += await calculateDirectorySize(at: fileURL)
            }
        }
        return total
    }

    // MARK: - 系统日志大小

    private func calculateLogSize() async -> Int64 {
        var total: Int64 = 0
        for path in logPaths {
            total += await calculateDirectorySize(at: URL(fileURLWithPath: path))
        }
        return total
    }

    // MARK: - 获取显示名（用于扫描进度）

    private func appName(from url: URL) async -> String {
        let metaPath = url.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        guard let meta = try? NSDictionary(contentsOf: metaPath),
              let name = meta["MCMMetadataDisplayName"] as? String
        else {
            return "未知 App"
        }
        return name
    }
}
