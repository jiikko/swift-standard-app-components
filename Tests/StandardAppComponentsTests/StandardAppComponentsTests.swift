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
    /// 言語一覧の取得元はバンドルの形で違う (生カタログはカタログ自体、compile 済みは Bundle.localizations)。
    func testBundleHasEnAndJaAndEveryRequiredKeyInBoth() throws {
        let localizations = try bundledLanguages()
        XCTAssertTrue(localizations.contains("en"), "en is not in Bundle.module: \(localizations)")
        XCTAssertTrue(localizations.contains("ja"), "ja is not in Bundle.module: \(localizations)")
        let missing = try StandardAppComponentsLocalization.missingKeys(in: StandardAppComponentsLocalization.requiredKeys)
        XCTAssertTrue(missing.isEmpty, "missing: \(missing)")
    }

    /// バンドルが持つ言語一覧を、バンドルの形に依らず返す。
    ///
    /// 生の `Localizable.xcstrings` が同梱される toolchain では `.lproj` が無いため
    /// `Bundle.localizations` に言語が出ない。その場合はカタログ自体から集める
    /// (本体 `collectMissingFromCatalog` の `allLocales()` と同じ定義: sourceLanguage +
    /// 各エントリの localizations キー)。
    /// compile 済み `.strings` の形では `Bundle.localizations` がそのまま言語一覧になる。
    private func bundledLanguages() throws -> Set<String> {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") else {
            return Set(Bundle.module.localizations)
        }
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Localizable.xcstrings is not a JSON object"
        )
        var languages: Set<String> = []
        if let sourceLanguage = json["sourceLanguage"] as? String {
            languages.insert(sourceLanguage)
        }
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]], "missing strings in catalog")
        for entry in strings.values {
            if let localizations = entry["localizations"] as? [String: Any] {
                languages.formUnion(localizations.keys)
            }
        }
        return languages
    }
}
