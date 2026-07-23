import Foundation

// MARK: - 诊断服务

actor DiagnosticsService {

    struct Probe: Identifiable {
        let id = UUID()
        let path: String
        let accessible: Bool
        let itemCount: Int
        let samples: [String]
        let error: String?

        var status: String {
            if !accessible { return error ?? "❌ 拒绝访问" }
            if itemCount == 0 { return "⚠️ 路径存在但为空" }
            return "✅ 有内容"
        }
    }

    /// 探测一整套文件系统路径
    func probeAll() async -> [Probe] {
        var probes: [Probe] = []

        // 1. 自身容器（验证 NSFileManager 起码能工作）
        probes.append(await probe("/var/mobile/Containers/Data/Application/"))
        probes.append(await probe("/var/mobile/Containers/Shared/AppGroup/"))
        probes.append(await probe("/var/mobile/Containers/Bundle/Application/"))

        // 2. 系统库
        probes.append(await probe("/var/mobile/Library/"))
        probes.append(await probe("/var/mobile/Library/Caches/"))
        probes.append(await probe("/var/mobile/Library/Logs/"))

        // 3. 变体路径
        probes.append(await probe("/var/mobile/"))
        probes.append(await probe("/private/var/mobile/Containers/Data/Application/"))
        probes.append(await probe("/private/var/mobile/Library/Caches/"))

        return probes
    }

    private func probe(_ path: String) async -> Probe {
        let fm = FileManager.default

        // 检查路径是否存在
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return Probe(
                path: path,
                accessible: false,
                itemCount: 0,
                samples: [],
                error: "路径不存在"
            )
        }

        // 尝试列举内容
        do {
            let contents = try fm.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            return Probe(
                path: path,
                accessible: true,
                itemCount: contents.count,
                samples: Array(contents.prefix(3)).map { $0.lastPathComponent },
                error: nil
            )
        } catch {
            return Probe(
                path: path,
                accessible: false,
                itemCount: 0,
                samples: [],
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - 直接展示用

extension DiagnosticsService.Probe {
    var detailText: String {
        if !accessible {
            return error ?? "未知错误"
        }
        if itemCount == 0 {
            return "目录存在但是空的"
        }
        let preview = samples.joined(separator: ", ")
        let suffix = itemCount > samples.count ? " 等" : ""
        return "\(preview)\(suffix)"
    }
}
