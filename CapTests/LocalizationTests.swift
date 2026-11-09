import AppKit
import Foundation
import Testing
@testable import Cap

/// 用 App target 里的类型定位 App bundle（测试宿主）。
private func appBundle() -> Bundle {
    Bundle(for: HistoryStore.self)
}

private func strings(for language: String) -> [String: String] {
    guard let path = appBundle().path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path),
          let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
          let dictionary = NSDictionary(contentsOf: url) as? [String: String] else {
        return [:]
    }
    return dictionary
}

@Test func appShipsThreeLocalizations() {
    let localizations = Set(appBundle().localizations)
    #expect(localizations.contains("en"))
    #expect(localizations.contains("zh-Hant"))
}

@Test func englishTableCoversUIStrings() {
    let en = strings(for: "en")
    #expect(en.count >= 100)
    #expect(en["设置"] == "Settings")
    #expect(en["截图"] == "Capture")
    #expect(en["历史"] == "History")
    #expect(en["长截图"] == "Scroll")
    #expect(en["快捷键"] == "Shortcuts")
    #expect(en["还没有截图，按 %@ 开始"]?.contains("Press %@") == true)
}

@Test func traditionalChineseTableCoversUIStrings() {
    let hant = strings(for: "zh-Hant")
    #expect(hant.count >= 100)
    #expect(hant["设置"] == "設定")
    #expect(hant["截图"] == "截圖")
    #expect(hant["历史"] == "歷史")
    #expect(hant["快捷键"] == "快速鍵")
}

@Test func translationTablesHaveSameKeysAndNoEmptyValues() {
    let en = strings(for: "en")
    let hant = strings(for: "zh-Hant")
    #expect(Set(en.keys) == Set(hant.keys))
    #expect(en.values.allSatisfy { !$0.isEmpty })
    #expect(hant.values.allSatisfy { !$0.isEmpty })
}

@Test func placeholdersArePreserved() {
    let en = strings(for: "en")
    let hant = strings(for: "zh-Hant")
    let formatKeys = en.keys.filter { $0.contains("%@") || $0.contains("%lld") }
    #expect(!formatKeys.isEmpty)
    for key in formatKeys {
        let atCount = key.components(separatedBy: "%@").count - 1
        let ldCount = key.components(separatedBy: "%lld").count - 1
        #expect(en[key]?.components(separatedBy: "%@").count == atCount + 1, "en 占位符数量不一致: \(key)")
        #expect(en[key]?.components(separatedBy: "%lld").count == ldCount + 1, "en 占位符数量不一致: \(key)")
        #expect(hant[key]?.components(separatedBy: "%@").count == atCount + 1, "zh-Hant 占位符数量不一致: \(key)")
        #expect(hant[key]?.components(separatedBy: "%lld").count == ldCount + 1, "zh-Hant 占位符数量不一致: \(key)")
    }
}
