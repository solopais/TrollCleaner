import Foundation

struct Formatters {

    // MARK: - 文件大小格式化

    static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while abs(value) >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        let formatted = String(format: "%.1f", value)
        // 去掉末尾的 .0
        let display = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        return "\(display) \(units[unitIndex])"
    }

    // MARK: - 百分比

    static func formatPercent(_ fraction: Double) -> String {
        String(format: "%.0f%%", fraction * 100)
    }

    // MARK: - 时间格式化

    static func formatDuration(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return String(format: "%.1f 秒", interval)
        }
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return "\(minutes) 分 \(seconds) 秒"
    }

    // MARK: - 日期

    static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: "zh_CN")
        return df.string(from: date)
    }

    // MARK: - 文件数量

    static func formatFileCount(_ count: Int) -> String {
        if count > 10000 {
            String(format: "%.1f 万个", Double(count) / 10000)
        } else {
            "\(count) 个"
        }
    }
}
