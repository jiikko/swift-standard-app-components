import XCTest
import SwiftUI
@testable import StandardAppComponents

final class ToastTextTests: XCTestCase {
    // MARK: - Resolve

    func testVerbatimResolvesUnchanged() {
        // verbatim は catalog ルックアップを経由せずそのまま返ること。
        // error.localizedDescription / url.lastPathComponent 等の
        // 「既に locale 解決済み・ユーザー入力由来」を catalog バイパスを起こさず通すため。
        let raw = "ファイル: /tmp/foo.txt"
        XCTAssertEqual(ToastText.verbatim(raw).resolve(), raw)
    }

    func testVerbatimResolvesEmptyAndUnicodeUnchanged() {
        // 空文字 / 絵文字 / 多言語を verbatim で渡しても加工されないこと。
        XCTAssertEqual(ToastText.verbatim("").resolve(), "")
        XCTAssertEqual(ToastText.verbatim("🍣").resolve(), "🍣")
        XCTAssertEqual(ToastText.verbatim("Привет").resolve(), "Привет")
    }

    func testLocalizedResolveReturnsNonEmptyString() {
        // catalog にキーが無い場合、`String(localized:)` はキー文字列をそのまま返す。
        // ここでは「resolve() が String を返す」契約だけ担保する (catalog の中身は
        // LocalizationMissingKeyTests の責務)。
        let text = ToastText.localized(LocalizedStringResource("ToastTextTests-UnknownKey"))
        XCTAssertFalse(text.resolve().isEmpty)
    }

    // MARK: - ExpressibleByStringLiteral

    func testStringLiteralProducesLocalizedCase() {
        // リテラル渡しは自動的に .localized になる (catalog バイパスを型レベルで防ぐ #344)。
        // verbatim を選ぶには明示的に `.verbatim(...)` と書く必要があることを担保する。
        let text: ToastText = "Saved"
        switch text {
        case .localized:
            break  // OK
        case .verbatim:
            XCTFail("String literal should produce .localized case, not .verbatim")
        }
    }
}
