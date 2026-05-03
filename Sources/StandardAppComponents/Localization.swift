import Foundation

/// `StandardAppComponents` が同梱しているローカライズ辞書の検証 API。
///
/// この lib が提供する SettingsWindow / GeneralTabContent 等が必要とするキー一覧と、
/// それらが lib bundle の全 supported locale で揃っているかを検証する手段を公開する。
public enum StandardAppComponentsLocalization {
    /// Settings 関連の View が必要とする全ローカライズキー。lib 内で `Text(key, bundle: .module)`
    /// 等で参照されているもの。新しいキーを追加する時はここにも追加し、`Localizable.strings`
    /// に対応する翻訳を入れること (`validateRequiredKeys()` が CI / 起動時に検出する)。
    public static let requiredKeys: [String] = [
        "General",
        "Appearance",
        "Language"
    ]

    /// lib bundle (`Bundle.module`) の全 supported locale で `requiredKeys` のキーが
    /// 揃っているかを検証する。**1 つでも欠けていれば `fatalError` で停止する**。
    ///
    /// アプリ起動の早い段階で 1 度呼び出すことで、ローカライズ漏れを実行時に確実に
    /// 検出できる。Debug / Release 共通で fatalError するため、production でも漏れを
    /// 黙って出荷することを防ぐ。
    ///
    /// - Note: 「`Localizable.strings` 自体の存在」だけでなく、各キーが現に翻訳エントリを
    ///   持っているかまでチェックする (`localizedString(forKey:value:table:)` が
    ///   sentinel 値で返ってきた場合を欠けと判定する)。
    public static func validateRequiredKeys(file: StaticString = #file, line: UInt = #line) {
        let sentinel = "###StandardAppComponents.MISSING_LOCALIZATION###"
        var missing: [(locale: String, key: String)] = []

        for locale in Bundle.module.localizations {
            guard let lprojURL = Bundle.module.url(forResource: locale, withExtension: "lproj"),
                  let lprojBundle = Bundle(url: lprojURL) else {
                missing.append((locale, "<lproj bundle missing>"))
                continue
            }
            for key in requiredKeys {
                let value = lprojBundle.localizedString(forKey: key, value: sentinel, table: nil)
                if value == sentinel {
                    missing.append((locale, key))
                }
            }
        }

        guard missing.isEmpty else {
            let report = missing
                .map { "  \($0.locale).lproj: \($0.key)" }
                .joined(separator: "\n")
            fatalError(
                """
                StandardAppComponents: missing required localization keys.
                \(report)
                Add the missing entries to Sources/StandardAppComponents/Resources/<locale>.lproj/Localizable.strings.
                """,
                file: file,
                line: line
            )
        }
    }
}
