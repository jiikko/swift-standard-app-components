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
        "Show in Menu Bar"
    ]

    /// 必須キーが全 supported locale で翻訳済みエントリを持っているか検証する。
    /// **1 つでも欠けていれば `fatalError` で停止する**。
    ///
    /// アプリ起動の早い段階で 1 度呼び出すことで、ローカライズ漏れを実行時に確実に検出できる。
    /// Debug / Release 共通で fatalError するため、production でも漏れを黙って出荷することを防ぐ。
    public static func validateRequiredKeys(file: StaticString = #file, line: UInt = #line) {
        let missing: [(locale: String, key: String)]
        if Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil {
            do {
                missing = try collectMissingFromCatalog()
            } catch {
                fatalError(
                    "StandardAppComponents: failed to load Localizable.xcstrings: \(error)",
                    file: file,
                    line: line
                )
            }
        } else {
            missing = collectMissingFromCompiledStrings(file: file, line: line)
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

    // MARK: - Mode 1: xcstrings JSON parse (SPM CLI build)

    private static func collectMissingFromCatalog() throws -> [(locale: String, key: String)] {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") else {
            throw LocalizationError.catalogResourceMissing
        }
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)
        let supportedLocales = catalog.allLocales()

        var missing: [(locale: String, key: String)] = []
        for key in requiredKeys {
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

    private static func collectMissingFromCompiledStrings(file: StaticString, line: UInt) -> [(locale: String, key: String)] {
        let sentinel = "###StandardAppComponents.MISSING_LOCALIZATION###"
        let locales = Bundle.module.localizations
        guard !locales.isEmpty else {
            // ここが空 = .xcstrings も per-locale .strings も無い、resource processing が
            // 想定どおり走っていない致命状態。
            fatalError(
                "StandardAppComponents: Bundle.module.localizations is empty (no .xcstrings, no compiled .strings). Resource processing may have failed.",
                file: file,
                line: line
            )
        }

        var missing: [(locale: String, key: String)] = []
        for locale in locales {
            guard let lprojURL = Bundle.module.url(forResource: locale, withExtension: "lproj"),
                  let lprojBundle = Bundle(url: lprojURL) else {
                requiredKeys.forEach { missing.append((locale, $0)) }
                continue
            }
            for key in requiredKeys {
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
