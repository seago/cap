import Foundation
import Testing
@testable import Cap

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CapFileNamingTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// 2026-11-08 01:30:00 +0800
private let fixedDate: Date = {
    let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    var components = DateComponents()
    components.timeZone = timeZone
    components.year = 2026
    components.month = 11
    components.day = 8
    components.hour = 1
    components.minute = 30
    components.second = 0
    return calendar.date(from: components)!
}()

@Test func defaultFileNameMatchesDesignExample() {
    let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    #expect(FileNaming.baseName(for: fixedDate, timeZone: shanghai) == "Cap 2026-11-08 at 01.30.00")
    #expect(FileNaming.fileName(for: fixedDate, timeZone: shanghai) == "Cap 2026-11-08 at 01.30.00.png")
    #expect(FileNaming.fileName(for: fixedDate, fileExtension: "jpg", timeZone: shanghai) == "Cap 2026-11-08 at 01.30.00.jpg")
    #expect(FileNaming.fileName(for: fixedDate, fileExtension: "", timeZone: shanghai) == "Cap 2026-11-08 at 01.30.00")
}

@Test func fileNameUsesInjectedLocalTimeZone() {
    // 同一时刻在不同时区应得到不同的本地时间字符串。
    #expect(FileNaming.fileName(for: fixedDate, timeZone: TimeZone(identifier: "UTC")!) == "Cap 2026-11-07 at 17.30.00.png")
    #expect(FileNaming.fileName(for: fixedDate, timeZone: TimeZone(identifier: "Asia/Tokyo")!) == "Cap 2026-11-08 at 02.30.00.png")
}

@Test func uniqueURLAppendsSequenceBeforeExtension() throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileName = "Cap 2026-11-08 at 01.30.00.png"

    let first = FileNaming.uniqueURL(in: directory, fileName: fileName)
    #expect(first.lastPathComponent == fileName)

    try Data().write(to: first)
    let second = FileNaming.uniqueURL(in: directory, fileName: fileName)
    #expect(second.lastPathComponent == "Cap 2026-11-08 at 01.30.00 2.png")

    try Data().write(to: second)
    let third = FileNaming.uniqueURL(in: directory, fileName: fileName)
    #expect(third.lastPathComponent == "Cap 2026-11-08 at 01.30.00 3.png")

    try Data().write(to: third)
    let fourth = FileNaming.uniqueURL(in: directory, fileName: fileName)
    #expect(fourth.lastPathComponent == "Cap 2026-11-08 at 01.30.00 4.png")
    #expect(fourth.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
}

@Test func uniqueURLPicksFirstFreeSlot() throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    // 只有 ` 2` 存在时，不应该跳过空着的基名，也不应该重复使用 ` 2`。
    try Data().write(to: directory.appendingPathComponent("Cap 2026-11-08 at 01.30.00 2.png"))

    let picked = FileNaming.uniqueURL(in: directory, fileName: "Cap 2026-11-08 at 01.30.00.png")
    #expect(picked.lastPathComponent == "Cap 2026-11-08 at 01.30.00.png")
}

@Test func uniqueURLKeepsExtensionForOtherFormats() throws {
    let directory = try makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileName = "Cap 2026-11-08 at 01.30.00.jpg"
    try Data().write(to: directory.appendingPathComponent(fileName))

    let picked = FileNaming.uniqueURL(in: directory, fileName: fileName)
    #expect(picked.lastPathComponent == "Cap 2026-11-08 at 01.30.00 2.jpg")
}

@Test func sanitizeReplacesIllegalCharacters() {
    #expect(FileNaming.sanitize("Cap: 2026/11/08") == "Cap- 2026-11-08")
    #expect(FileNaming.sanitize("a\\b:c/d") == "a-b-c-d")
    #expect(FileNaming.sanitize("Cap\u{0}Shot\u{7}") == "Cap-Shot-")
    #expect(
        FileNaming.sanitize("Cap 2026-11-08 at 01.30.00.png") == "Cap 2026-11-08 at 01.30.00.png",
        "合法文件名应原样保留"
    )
}
