import SwiftUI

/// 「メニューバーに表示」切替の labeled Toggle。
///
/// **lib 側で持つのは UI と localization のみ**。NSStatusItem の生成 / 破棄、
/// アイコン / メニュー項目 / クリックハンドラの実装は consumer 側に閉じる
/// (各アプリの責務であり、lib に持ち込むには consumer 固有の知識が多すぎるため)。
///
/// consumer は `Binding<Bool>` を受け取り、その変化を観測して NSStatusItem の
/// 生成 / 破棄を行う:
///
/// ```swift
/// @AppStorage("showInMenuBar") private var showInMenuBar = false
///
/// SettingsWindow(
///     general: GeneralTabContract(
///         appearance: { ... },
///         language:   { ... },
///         appSections: {
///             Section { MenuBarVisibilityToggle(isOn: $showInMenuBar) }
///                 header: { Text("Menu Bar") }
///         }
///     )
/// )
///
/// // 別の場所で
/// .onChange(of: showInMenuBar) { _, isOn in
///     statusItemController.setVisible(isOn)
/// }
/// ```
///
/// `LaunchAtLoginToggle` と違って system 側の真実 (`SMAppService` のような
/// 標準 API) は無いため、本 Toggle は consumer の binding にのみ依存する。
/// 永続化キーや NSStatusItem ライフサイクルは consumer の関心。
public struct MenuBarVisibilityToggle: View {
    /// label の解決先 bundle を型で区別する。
    /// - `.libDefault`: lib 同梱 xcstrings ("Show in Menu Bar" / "メニューバーに表示") を使う。
    ///   `Text(_, bundle: .module)` で lib bundle を明示するため `LocalizedStringKey`
    ///   経由 (= consumer main bundle 解決) ではなく専用 case を持つ。
    /// - `.custom`: consumer 側で解決する `LocalizedStringKey` をそのまま `Text` に渡す。
    private enum LabelSource {
        case libDefault
        case custom(LocalizedStringKey)
    }

    private let labelSource: LabelSource
    @Binding private var isOn: Bool

    /// lib 同梱の "Show in Menu Bar" (ja: "メニューバーに表示") をラベルに使う。
    ///
    /// - Parameter isOn: 表示状態の binding。consumer が `@AppStorage` 等で永続化することが多い。
    public init(isOn: Binding<Bool>) {
        self._isOn = isOn
        self.labelSource = .libDefault
    }

    /// アプリ固有の文言をラベルに使う。`label` は **consumer 側 bundle で解決される** ため、
    /// consumer の `.xcstrings` / `.strings` で対応する key を提供すること。lib 同梱 catalog
    /// の文言を流用したい場合はラベル無しの init を使う。
    ///
    /// - Parameters:
    ///   - isOn: 表示状態の binding。
    ///   - label: Toggle のラベル文言 (consumer bundle で解決される)。
    public init(isOn: Binding<Bool>, label: LocalizedStringKey) {
        self._isOn = isOn
        self.labelSource = .custom(label)
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            switch labelSource {
            case .libDefault:
                Text("Show in Menu Bar", bundle: .module)
            case .custom(let key):
                Text(key)
            }
        }
    }
}
