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

    /// validateRequiredKeys が、言語の表を欠いた状態で vacuously pass していないことを担保する。
    /// missingKeys はバンドルにある言語だけを見るので、ja の表がまるごと入らなければ ja は検査されない。
    /// バンドルの形は toolchain で違う (Swift 6.4 の SwiftPM は .xcstrings を言語ごとの .strings に変換して入れる。issue 006)
    /// ので、ファイルではなく言語の一覧と missingKeys で見る。
    func testBundleHasEnAndJaAndEveryRequiredKeyInBoth() throws {
        let localizations = Set(Bundle.module.localizations)
        XCTAssertTrue(localizations.contains("en"), "en is not in Bundle.module: \(localizations)")
        XCTAssertTrue(localizations.contains("ja"), "ja is not in Bundle.module: \(localizations)")
        let missing = try StandardAppComponentsLocalization.missingKeys(in: StandardAppComponentsLocalization.requiredKeys)
        XCTAssertTrue(missing.isEmpty, "missing: \(missing)")
    }
}
