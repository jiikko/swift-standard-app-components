import Foundation

/// `StandardAppComponents` が同梱しているローカライズ辞書 (`Localizable.xcstrings`)
/// の検証 API。
///
/// この lib が提供する SettingsWindow / GeneralTabContent 等が必要とするキー一覧と、
/// それらが全 supported locale で揃っているかを検証する手段を公開する。
///
/// - Important: 検証は build pipeline によって 2 通りの経路を持つ:
///   1. **SPM CLI build (`swift build` / `swift test`)**: `Localizable.xcstrings` は
///      per-locale `.strings` に compile されず生 file 同梱のため、xcstrings JSON を
///      直接 parse する。
///   2. **Xcode build (xcodebuild)**: Xcode の `stringcatalogtool` が xcstrings を
///      per-locale `.strings` に compile し、xcstrings 自体は bundle から消える。
///      そのため `Bundle.module.localizations` + `localizedString(forKey:value:table:)`
///      を sentinel 値で走査して欠けを検出する。
public enum StandardAppComponentsLocalization {
    /// Settings 関連の View が必要とする全ローカライズキー。lib 内で `Text(key, bundle: .module)`
    /// 等で参照されているもの。新しいキーを追加する時はここにも追加し、`Localizable.xcstrings`
    /// に対応する翻訳を入れること (`validateRequiredKeys()` が CI / 起動時に検出する)。
    public static let requiredKeys: [String] = [
        "General",
        "Appearance",
        "Language",
        "Open at Login",
        "Show in Menu Bar",
        // LanguageSection
        "System Default",
        "Language Changed",
        "Restart the app to apply the new language.",
        "Restart Now",
        "Quit Now",
        "Later",
        // ShortcutSettingsTab
        "Press a key...",
        "Reset to Default",
        "Reset All to Default",
        // Generic section header (lib screenshot demos / consumer 側 misc section にも使える)
        "Other"
    ]

    /// Lib のリソース bundle (`Bundle.module`) を public に露出する。
    ///
    /// `Bundle.module` は Swift Package Manager が target ごとに auto-generate するため、
    /// 他 target (例: `ScreenshotGenerator` executable, consumer アプリの一部) からは見えない。
    /// lib 同梱の xcstrings に直接アクセスしたい場合はこのプロパティ経由で bundle を取得する。
    ///
    /// **通常の consumer は使う必要がない**。lib 内の `Text("...", bundle: .module)` 経由で
    /// 自動的に lib bundle が解決されるため、consumer アプリからは何もしなくても日英切替
    /// (システム言語 or `LanguageSection` 経由の `AppleLanguages` 切替) が機能する。
    public static var bundle: Bundle { .module }

    /// 指定 `key` を `locale` (例: `"ja"` / `"en"`) で lib catalog から **明示的に** lookup する。
    ///
    /// 通常の consumer は `Text("...", bundle: .module)` でシステム言語に従って lib catalog
    /// を引けるため、本 API は不要。次のような **dev tool** ユースケースのみで使う:
    ///
    /// - SPM CLI build (`swift run ...`) では xcstrings が compiled `.strings` に変換されない
    ///   ため、`String(localized: LocalizedStringResource(..., locale: ...))` が指定 locale を
    ///   尊重せず source language にフォールバックする。本 API は xcstrings JSON を直接 parse
    ///   して locale-specific 値を取り出す。
    /// - Xcode build では compiled `.strings` から `Bundle.localizedString(forKey:value:table:)`
    ///   経由で取り出す。両 build mode で同じ結果。
    ///
    /// - Parameters:
    ///   - key: catalog の key (例: `"Open at Login"`)。`requiredKeys` に含まれること推奨。
    ///   - locale: BCP-47 タグ (例: `"ja"`, `"en"`)。
    /// - Returns: 該当 locale の翻訳値。entry が無い / 未翻訳 / I/O 失敗時は `nil`。
    public static func lookupString(forKey key: String, locale: String) -> String? {
        // Mode 1: Xcode build → compiled .strings (lproj)
        if let lprojURL = Bundle.module.url(forResource: locale, withExtension: "lproj"),
           let lprojBundle = Bundle(url: lprojURL) {
            let sentinel = "__StandardAppComponents.MISSING__"
            let value = lprojBundle.localizedString(forKey: key, value: sentinel, table: nil)
            if value != sentinel {
                return value
            }
        }

        // Mode 2: SPM CLI build → xcstrings JSON 直接 parse
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data),
              let entry = catalog.strings[key],
              let unit = entry.localizations[locale]?.stringUnit,
              unit.state == "translated", !unit.value.isEmpty else {
            return nil
        }
        return unit.value
    }

    /// 必須キーが全 supported locale で翻訳済みエントリを持っているか検証する。
    /// **1 つでも欠けていれば `fatalError` で停止する**。
    ///
    /// アプリ起動の早い段階で 1 度呼び出すことで、ローカライズ漏れを実行時に確実に検出できる。
    /// Debug / Release 共通で fatalError するため、production でも漏れを黙って出荷することを防ぐ。
    public static func validateRequiredKeys(file: StaticString = #file, line: UInt = #line) {
        let missing: [(locale: String, key: String)]
        do {
            missing = try missingKeys(in: requiredKeys)
        } catch {
            fatalError(
                "StandardAppComponents: failed to load Localizable.xcstrings: \(error)",
                file: file,
                line: line
            )
        }

        guard missing.isEmpty else {
            let report = missing
                .sorted(by: { ($0.locale, $0.key) < ($1.locale, $1.key) })
                .map { "  \($0.locale): \($0.key)" }
                .joined(separator: "\n")
            fatalError(
                """
                StandardAppComponents: missing required localization keys.
                \(report)
                Add the missing entries to Sources/StandardAppComponents/Resources/Localizable.xcstrings.
                """,
                file: file,
                line: line
            )
        }
    }

    /// **Test 用**。validateRequiredKeys を fatalError なしに、欠けている `(locale, key)`
    /// 組を非空配列で返す形に展開した実装。production code は `validateRequiredKeys()`
    /// を使うこと。
    ///
    /// - Parameter keys: チェックしたいキー列。production では `requiredKeys` が渡される。
    ///   テストでは「本物のキー + 故意に存在しないキー」を混ぜて、missing 検出経路が
    ///   生きていることを担保する。
    /// - Returns: 欠けている `(locale, key)` のリスト。空配列なら全 locale で
    ///   全キーが揃っている。
    /// - Throws: xcstrings JSON が壊れている / 読み込めない場合のみ。
    static func missingKeys(in keys: [String]) throws -> [(locale: String, key: String)] {
        if Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil {
            return try collectMissingFromCatalog(keys: keys)
        } else {
            return collectMissingFromCompiledStrings(keys: keys)
        }
    }

    // MARK: - Mode 1: xcstrings JSON parse (SPM CLI build)

    private static func collectMissingFromCatalog(keys: [String]) throws -> [(locale: String, key: String)] {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") else {
            throw LocalizationError.catalogResourceMissing
        }
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)
        let supportedLocales = catalog.allLocales()

        var missing: [(locale: String, key: String)] = []
        for key in keys {
            guard let entry = catalog.strings[key] else {
                supportedLocales.forEach { missing.append(($0, key)) }
                continue
            }
            for locale in supportedLocales {
                let unit = entry.localizations[locale]?.stringUnit
                let isValid = unit.map { $0.state == "translated" && !$0.value.isEmpty } ?? false
                if !isValid {
                    missing.append((locale, key))
                }
            }
        }
        return missing
    }

    // MARK: - Mode 2: compiled .strings lookup (Xcode build)

    private static func collectMissingFromCompiledStrings(keys: [String]) -> [(locale: String, key: String)] {
        let sentinel = "###StandardAppComponents.MISSING_LOCALIZATION###"
        let locales = Bundle.module.localizations
        guard !locales.isEmpty else {
            // ここが空 = .xcstrings も per-locale .strings も無い、resource processing が
            // 想定どおり走っていない致命状態。production の validateRequiredKeys 経路で
            // 上位 fatalError を投げるためここでは空 missing を返さず全キーを missing 扱いにする。
            return keys.map { ("?", $0) }
        }

        var missing: [(locale: String, key: String)] = []
        for locale in locales {
            guard let lprojURL = Bundle.module.url(forResource: locale, withExtension: "lproj"),
                  let lprojBundle = Bundle(url: lprojURL) else {
                keys.forEach { missing.append((locale, $0)) }
                continue
            }
            for key in keys {
                let value = lprojBundle.localizedString(forKey: key, value: sentinel, table: nil)
                if value == sentinel {
                    missing.append((locale, key))
                }
            }
        }
        return missing
    }
}

private enum LocalizationError: Error, CustomStringConvertible {
    case catalogResourceMissing

    var description: String {
        switch self {
        case .catalogResourceMissing:
            "Localizable.xcstrings not found in Bundle.module"
        }
    }
}

// MARK: - String Catalog JSON shape (https://developer.apple.com/xcode/localization/)

private struct StringCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: StringEntry]
    let version: String

    /// xcstrings 内に存在する全 locale (sourceLanguage + 各エントリの localizations キー)。
    func allLocales() -> [String] {
        var locales: Set<String> = [sourceLanguage]
        for entry in strings.values {
            for locale in entry.localizations.keys {
                locales.insert(locale)
            }
        }
        return locales.sorted()
    }
}

private struct StringEntry: Decodable {
    let comment: String?
    let extractionState: String?
    let localizations: [String: StringLocalization]

    private enum CodingKeys: String, CodingKey {
        case comment
        case extractionState
        case localizations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        extractionState = try container.decodeIfPresent(String.self, forKey: .extractionState)
        localizations = try container.decodeIfPresent([String: StringLocalization].self, forKey: .localizations) ?? [:]
    }
}

private struct StringLocalization: Decodable {
    let stringUnit: StringUnit?
}

private struct StringUnit: Decodable {
    let state: String
    let value: String
}
