import SwiftUI

/// 「ログイン時に開く」を切り替える labeled Toggle。
/// `LaunchAtLoginService` と双方向同期し、System Settings 側で外部変更されても
/// アプリがフォアグラウンドに戻ったタイミングで再読込する。
///
/// 使い方:
/// ```swift
/// SettingsWindow(
///     general: GeneralTabContract(
///         appearance: { AppearanceSection() },
///         language:   { LanguageSection() },
///         appSections: {
///             Section { LaunchAtLoginToggle() } header: { Text("Startup") }
///         }
///     )
/// )
/// ```
///
/// 設計方針:
/// - 真実の所在は **system 側** (`SMAppService` の status) であり、UserDefaults 等に
///   別途キャッシュしない。`@AppStorage` で状態を持つと system との解離が容易に発生する
///   (System Settings から手動 off にした時等) ため、毎回 `isEnabled` を読む。
/// - `register()` / `unregister()` は throw し得るので失敗時は `@State` を元の値に
///   ロールバックして UI を整合させる。errror toast 等の表示はしない (lib 単独では
///   トースト基盤を持たないため)。consumer がエラー UI を出したい場合は service を
///   直接使う。
public struct LaunchAtLoginToggle: View {
    private let label: LocalizedStringKey
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOn: Bool = false

    /// - Parameter label: Toggle の文言。デフォルトは lib 同梱 xcstrings の "Open at Login"
    ///   (ja: "ログイン時に開く")。アプリ独自の文言を出したい場合のみ override。
    public init(label: LocalizedStringKey = LocalizedStringKey("Open at Login")) {
        self.label = label
    }

    public var body: some View {
        Toggle(label, isOn: bindingToService)
            .onAppear { syncFromSystem() }
            .onChange(of: scenePhase) { _, newPhase in
                // 他のアプリで System Settings 側のログイン項目を編集して戻ってきたケースに追従。
                if newPhase == .active { syncFromSystem() }
            }
    }

    private var bindingToService: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                let previous = isOn
                isOn = newValue
                do {
                    try LaunchAtLoginService.setEnabled(newValue)
                } catch {
                    // system 側更新失敗。UI を元の値に戻し、log のみ。
                    // consumer がエラーを掴みたい場合は LaunchAtLoginService を直接呼ぶこと。
                    isOn = previous
                    #if DEBUG
                    print("LaunchAtLoginToggle: setEnabled(\(newValue)) failed: \(error)")
                    #endif
                }
            }
        )
    }

    private func syncFromSystem() {
        isOn = LaunchAtLoginService.isEnabled
    }
}
