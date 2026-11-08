import Foundation

/// 保存文件名的生成规则，见 `DESIGN.md` §3.5 / §6.3：
///
/// - 默认名 `Cap 2026-11-08 at 01.30.00.png`（本地时间，零填充）
/// - 重名自动追加 ` 2`、` 3`（序号在扩展名之前）
/// - 文件名中的非法字符替换为 `-`
enum FileNaming {
    private static let prefix = "Cap"
    private static let nameFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    private static let replacement = "-"

    /// `Cap 2026-11-08 at 01.30.00`
    ///
    /// - Parameters:
    ///   - date: 要格式化的时间。
    ///   - timeZone: 决定“本地时间”的时区；测试注入固定时区，默认跟随系统。
    static func baseName(for date: Date = Date(), timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = nameFormat
        return "\(prefix) \(formatter.string(from: date))"
    }

    /// `Cap 2026-11-08 at 01.30.00.png`；`fileExtension` 不带点，传空串则没有扩展名。
    static func fileName(
        for date: Date = Date(),
        fileExtension: String = "png",
        timeZone: TimeZone = .current
    ) -> String {
        let extensionPart = fileExtension.isEmpty ? "" : ".\(fileExtension)"
        return baseName(for: date, timeZone: timeZone) + extensionPart
    }

    /// 把路径分隔符、冒号、反斜杠与控制字符替换为 `-`；合法字符原样保留。
    static func sanitize(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        var sanitized = ""
        sanitized.unicodeScalars.reserveCapacity(name.unicodeScalars.count)
        for scalar in name.unicodeScalars {
            if forbidden.contains(scalar) {
                sanitized.append(contentsOf: replacement)
            } else {
                sanitized.unicodeScalars.append(scalar)
            }
        }
        return sanitized
    }

    /// 在 `directory` 中为 `fileName` 找一个不冲突的 URL：
    /// `Cap ….png` → `Cap … 2.png` → `Cap … 3.png` …
    static func uniqueURL(
        in directory: URL,
        fileName: String,
        fileManager: FileManager = .default
    ) -> URL {
        let candidate = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: candidate.path) else {
            return candidate
        }

        let fileURL = URL(fileURLWithPath: fileName)
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension
        let baseStem = stem.isEmpty ? prefix : stem

        var sequence = 2
        while true {
            let suffixedStem = "\(baseStem) \(sequence)"
            let suffixedName = fileExtension.isEmpty
                ? suffixedStem
                : "\(suffixedStem).\(fileExtension)"
            let suffixedURL = directory.appendingPathComponent(suffixedName)
            if !fileManager.fileExists(atPath: suffixedURL.path) {
                return suffixedURL
            }
            sequence += 1
        }
    }
}
