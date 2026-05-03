import XCTest
@testable import StandardAppComponents

final class StandardAppComponentsTests: XCTestCase {
    func testVersionIsExposed() {
        XCTAssertFalse(StandardAppComponents.version.isEmpty)
    }

    /// requiredKeys が全 supported locale で揃っていることを CI で担保する。
    /// validateRequiredKeys() は欠けがあると fatalError で停止するので、
    /// 通常テスト実行で何も起きない = 全キーが揃っているという assertion になる。
    func testAllRequiredLocalizationKeysAreProvided() {
        StandardAppComponentsLocalization.validateRequiredKeys()
    }

    /// validateRequiredKeys がキー皆無の状態で vacuously pass していないことを担保する。
    /// xcstrings が bundle に同梱され、parse して中身の key が requiredKeys 全件を含むことを直接確認する。
    func testLocalizableXCStringsBundlesAllRequiredKeysWithJaTranslation() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
            "Localizable.xcstrings should be bundled in Bundle.module"
        )
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in StandardAppComponentsLocalization.requiredKeys {
            let entry = try XCTUnwrap(strings[key], "missing entry: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            XCTAssertNotNil(localizations["en"], "missing en for \(key)")
            XCTAssertNotNil(localizations["ja"], "missing ja for \(key)")
        }
    }
}
