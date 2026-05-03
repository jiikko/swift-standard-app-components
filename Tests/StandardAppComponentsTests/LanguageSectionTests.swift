import XCTest
import SwiftUI
@testable import StandardAppComponents

@MainActor
final class LanguageSectionTests: XCTestCase {
    // MARK: - LanguageSection init contracts

    /// `onRestart` 省略 (default = nil) で初期化できること、body が評価できることを担保する。
    /// nil の場合 alert は "Quit Now" を出して `NSApp.terminate(nil)` だけ呼ぶ契約 (Quit Now を
    /// 押した時の実挙動はホストアプリを終了させてしまうので unit test では検証しない)。
    func testInitWithoutOnRestartCompiles() {
        let section = LanguageSection(
            supportedLanguages: [.init(code: "en", displayName: "English")]
        )
        _ = section.body
    }

    /// `onRestart` 渡しで初期化できることを担保する。
    /// 渡されている場合 alert は "Restart Now" を出して `onRestart()` を呼ぶ契約。
    func testInitWithCustomOnRestartCompiles() {
        let section = LanguageSection(
            supportedLanguages: [.init(code: "en", displayName: "English")],
            onRestart: { /* relaunch placeholder */ }
        )
        _ = section.body
    }

    /// 空の `supportedLanguages` でも初期化できること (System Default のみが Picker に並ぶ)。
    func testInitWithEmptySupportedLanguagesCompiles() {
        let section = LanguageSection(supportedLanguages: [])
        _ = section.body
    }

    // MARK: - LanguageOption value semantics

    func testLanguageOptionEquatable() {
        let a = LanguageOption(code: "en", displayName: "English")
        let b = LanguageOption(code: "en", displayName: "English")
        let differentCode = LanguageOption(code: "ja", displayName: "English")
        let differentDisplay = LanguageOption(code: "en", displayName: "Eng")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, differentCode)
        // Hashable 合成は全フィールドを使う前提なので displayName 違いも不等。
        // consumer が同じ code に異なる表示名を渡しても安全に区別される。
        XCTAssertNotEqual(a, differentDisplay)
    }

    func testLanguageOptionHashable() {
        let a = LanguageOption(code: "en", displayName: "English")
        let b = LanguageOption(code: "en", displayName: "English")
        let set: Set<LanguageOption> = [a, b]
        XCTAssertEqual(set.count, 1)
    }
}
