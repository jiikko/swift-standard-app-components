import XCTest
@testable import StandardAppComponents

/// `validateRequiredKeys` 内部の missing 検出経路がちゃんと動いているかを担保する。
///
/// 既存の `testAllRequiredLocalizationKeysAreProvided` は happy path
/// (= 欠けがない) のみを観測するため、何かの拍子で常に空配列を返す回帰
/// (例: `keys` を引数で受け忘れて空ループになる、bundle url の参照が壊れる等)
/// が起きても緑のままで通過してしまう。本テストでは故意に存在しないキーを
/// 渡して missing が拾えていることを確認する。
final class LocalizationMissingKeyTests: XCTestCase {
    func testMissingKeyIsReportedForEachSupportedLocale() throws {
        let bogusKey = "____non_existent_key_for_testing____"
        let missing = try StandardAppComponentsLocalization.missingKeys(in: [bogusKey])

        XCTAssertFalse(missing.isEmpty, "Expected the bogus key to be reported as missing in at least one locale")
        let missingKeys = Set(missing.map { $0.key })
        XCTAssertEqual(missingKeys, [bogusKey], "Only the bogus key should be missing")

        // 全 supported locale で missing として上がっている (= per-locale 走査が
        // 機能していること) を担保する。lib は `en` / `ja` 両方に対応しているので
        // この 2 locale は最低限含まれる。
        let missingLocales = Set(missing.map { $0.locale })
        XCTAssertTrue(missingLocales.contains("en"), "en locale should have the bogus key as missing")
        XCTAssertTrue(missingLocales.contains("ja"), "ja locale should have the bogus key as missing")
    }

    func testKnownKeysAreNotReportedAsMissingWhenMixedWithBogus() throws {
        let bogusKey = "____non_existent_key_for_testing____"
        let mixedKeys = StandardAppComponentsLocalization.requiredKeys + [bogusKey]
        let missing = try StandardAppComponentsLocalization.missingKeys(in: mixedKeys)

        // 既知キーは missing 扱いされず、bogus のみが拾われる。
        let missingKeys = Set(missing.map { $0.key })
        XCTAssertEqual(missingKeys, [bogusKey])
    }

    func testKnownKeysReturnEmptyWhenAlone() throws {
        // production の validateRequiredKeys が呼ぶ経路と同じ。requiredKeys 全件
        // 揃っていれば空配列が返る (これが happy path)。
        let missing = try StandardAppComponentsLocalization.missingKeys(in: StandardAppComponentsLocalization.requiredKeys)
        XCTAssertTrue(
            missing.isEmpty,
            "All required keys should be present in every locale; missing = \(missing)"
        )
    }
}
