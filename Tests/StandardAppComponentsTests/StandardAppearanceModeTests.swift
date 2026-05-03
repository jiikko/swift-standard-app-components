import XCTest
import SwiftUI
@testable import StandardAppComponents

final class StandardAppearanceModeTests: XCTestCase {
    func testRawValuesAreStableForPersistence() {
        // @AppStorage 永続化済みの値が将来 enum case 追加で壊れないよう
        // 既存 raw value の一致を担保する。
        XCTAssertEqual(StandardAppearanceMode.system.rawValue, "system")
        XCTAssertEqual(StandardAppearanceMode.light.rawValue, "light")
        XCTAssertEqual(StandardAppearanceMode.dark.rawValue, "dark")
    }

    func testPreferredColorSchemeMappingMatchesApplyAppAppearance() {
        // applyAppAppearance(.light/.dark/nil) の入力規格に揃っていることを担保する。
        // ここが崩れると Picker 選択 → 外観反映の経路が無言で壊れる。
        XCTAssertNil(StandardAppearanceMode.system.preferredColorScheme)
        XCTAssertEqual(StandardAppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(StandardAppearanceMode.dark.preferredColorScheme, .dark)
    }

    func testAllCasesEnumeratesThreeStates() {
        // CaseIterable の挙動。Picker の ForEach 等で全件展開する consumer 側で
        // 取りこぼしがないことを担保する。
        XCTAssertEqual(StandardAppearanceMode.allCases, [.system, .light, .dark])
    }

    func testRawValueRoundtrip() {
        for mode in StandardAppearanceMode.allCases {
            let restored = StandardAppearanceMode(rawValue: mode.rawValue)
            XCTAssertEqual(restored, mode)
        }
    }

    func testInvalidRawValueReturnsNil() {
        // 未知の文字列で復元できないこと (consumer 側で `?? .system` フォールバックする
        // 想定の "復元失敗を検出可能" な状態を維持する)。
        XCTAssertNil(StandardAppearanceMode(rawValue: "bogus"))
        XCTAssertNil(StandardAppearanceMode(rawValue: ""))
    }

    func testCodableRoundTrip() throws {
        // Codable 対応: consumer が AppSettings 等の Codable struct field として
        // 持つケースを想定。raw value の文字列で encode され、復元できることを担保する。
        for mode in StandardAppearanceMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let restored = try JSONDecoder().decode(StandardAppearanceMode.self, from: data)
            XCTAssertEqual(restored, mode)
        }
    }

    func testCodableUsesRawStringRepresentation() throws {
        // Codable の wire format が `"system"` / `"light"` / `"dark"` の文字列であることを
        // 担保する (= 既存 consumer の AppSettings.json 等が壊れない条件)。
        let data = try JSONEncoder().encode(StandardAppearanceMode.dark)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(json, "\"dark\"")
    }
}
