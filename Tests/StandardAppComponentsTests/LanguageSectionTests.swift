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

    // MARK: - PrimaryAlertButton (R1 fix の契約を直接ロック)

    /// `onRestart = nil` で initialize した場合、alert primary ボタンが `.quit` 経路を
    /// 選ぶこと。これが `.restart` に戻ると Quit Now ボタンが Restart Now と表示されて
    /// 終了するだけ、というユーザー混乱が再発する (Codex R1 #2 / R2 #3)。
    func testPrimaryAlertButtonIsQuitWhenOnRestartIsNil() {
        let button = LanguageSection.primaryAlertButton(onRestart: nil)
        switch button {
        case .quit:
            break // OK
        case .restart:
            XCTFail("Expected .quit when onRestart is nil")
        }
        XCTAssertEqual(button.titleKey, "Quit Now")
    }

    /// `onRestart` を渡して initialize した場合、alert primary ボタンが `.restart` 経路を
    /// 選び、associated closure が consumer 由来であることを担保する。
    func testPrimaryAlertButtonIsRestartWithCustomActionWhenOnRestartIsProvided() {
        let invoked = expectation(description: "consumer onRestart invoked via .restart case")
        let button = LanguageSection.primaryAlertButton(onRestart: { invoked.fulfill() })
        switch button {
        case .quit:
            XCTFail("Expected .restart when onRestart is provided")
        case .restart(let action):
            action()
        }
        wait(for: [invoked], timeout: 0.1)
        XCTAssertEqual(button.titleKey, "Restart Now")
    }

    /// `titleKey` は xcstrings の wire-format。値が変わると catalog 検証 / SwiftUI
    /// `Text(_, bundle: .module)` のキー解決が無言で壊れるため、test で固定する。
    func testPrimaryAlertButtonTitleKeysAreStable() {
        XCTAssertEqual(LanguageSection.PrimaryAlertButton.quit.titleKey, "Quit Now")
        XCTAssertEqual(LanguageSection.PrimaryAlertButton.restart({}).titleKey, "Restart Now")
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
