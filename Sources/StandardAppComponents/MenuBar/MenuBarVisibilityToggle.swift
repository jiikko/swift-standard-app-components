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
    private let label: LocalizedStringKey
    @Binding private var isOn: Bool

    /// - Parameters:
    ///   - isOn: 表示状態の binding。consumer が `@AppStorage` 等で永続化することが多い。
    ///   - label: Toggle の文言。デフォルトは lib 同梱 xcstrings の "Show in Menu Bar"
    ///     (ja: "メニューバーに表示")。
    public init(
        isOn: Binding<Bool>,
        label: LocalizedStringKey = LocalizedStringKey("Show in Menu Bar")
    ) {
        self._isOn = isOn
        self.label = label
    }

    public var body: some View {
        Toggle(label, isOn: $isOn)
    }
}
