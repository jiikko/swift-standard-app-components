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
///             Section {
///                 LaunchAtLoginToggle(onError: { error in
///                     toastManager.show("起動時起動の切替に失敗: \(error.localizedDescription)")
///                 })
///             } header: {
///                 Text("Startup")
///             }
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
///   ロールバックして UI を整合させる。
/// - **lib は consumer 不在で stdout / OSLog にログを書かない**。エラーを画面に
///   出したい / 解析したい consumer は `onError` callback で受け取り、自前の
///   logger / toast / alert に流す。`onError` が `nil` の場合エラーは黙殺される
///   (UI 状態のロールバックのみ行われる)。
public struct LaunchAtLoginToggle: View {
    private let label: LocalizedStringKey
    private let onError: ((Error) -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOn: Bool = false

    /// - Parameters:
    ///   - label: Toggle の文言。デフォルトは lib 同梱 xcstrings の "Open at Login"
    ///     (ja: "ログイン時に開く")。アプリ独自の文言を出したい場合のみ override。
    ///   - onError: `SMAppService.register/unregister` が throw した時に呼ばれる callback。
    ///     `nil` の場合エラーは無視される (UI は元の値にロールバックされる)。
    ///     consumer がエラーを Toast / alert / log に出したい場合に渡す。
    public init(
        label: LocalizedStringKey = LocalizedStringKey("Open at Login"),
        onError: ((Error) -> Void)? = nil
    ) {
        self.label = label
        self.onError = onError
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
                    // system 側更新失敗。UI を元の値に戻し、consumer に通知。
                    isOn = previous
                    onError?(error)
                }
            }
        )
    }

    private func syncFromSystem() {
        isOn = LaunchAtLoginService.isEnabled
    }
}
