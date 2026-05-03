import Foundation

/// `StandardAppComponents` が同梱しているローカライズ辞書 (`Localizable.xcstrings`)
/// の検証 API。
///
/// この lib が提供する SettingsWindow / GeneralTabContent 等が必要とするキー一覧と、
/// それらが xcstrings 内の全 supported locale で揃っているかを検証する手段を公開する。
///
/// - Important: 検証は **`Localizable.xcstrings` JSON を直接 parse する実装**。
///   `swift build` (SPM CLI) は xcstrings を per-locale `.strings` にコンパイルしない
///   (Xcode の `stringcatalogtool` の役割) ため、`Bundle.module.localizations` を
///   見るだけだと SPM テストでは vacuously pass してしまう。xcstrings JSON を見れば
///   build pipeline によらず確実に欠けを検出できる。
public enum StandardAppComponentsLocalization {
    /// Settings 関連の View が必要とする全ローカライズキー。lib 内で `Text(key, bundle: .module)`
    /// 等で参照されているもの。新しいキーを追加する時はここにも追加し、`Localizable.xcstrings`
    /// に対応する翻訳を入れること (`validateRequiredKeys()` が CI / 起動時に検出する)。
    public static let requiredKeys: [String] = [
        "General",
        "Appearance",
        "Language"
    ]

    /// `Localizable.xcstrings` を直接 parse して、全 supported locale で `requiredKeys` の
    /// キーが翻訳済みエントリを持っているか検証する。**1 つでも欠けていれば `fatalError`
    /// で停止する**。
    ///
    /// アプリ起動の早い段階で 1 度呼び出すことで、ローカライズ漏れを実行時に確実に検出できる。
    /// Debug / Release 共通で fatalError するため、production でも漏れを黙って出荷することを防ぐ。
    public static func validateRequiredKeys(file: StaticString = #file, line: UInt = #line) {
        let catalog: StringCatalog
        do {
            catalog = try loadCatalog()
        } catch {
            fatalError(
                "StandardAppComponents: failed to load Localizable.xcstrings: \(error)",
                file: file,
                line: line
            )
        }

        let supportedLocales = catalog.allLocales()
        var missing: [(locale: String, key: String)] = []

        for key in requiredKeys {
            guard let entry = catalog.strings[key] else {
                for locale in supportedLocales {
                    missing.append((locale, key))
                }
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

    private static func loadCatalog() throws -> StringCatalog {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") else {
            throw LocalizationError.catalogResourceMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StringCatalog.self, from: data)
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
