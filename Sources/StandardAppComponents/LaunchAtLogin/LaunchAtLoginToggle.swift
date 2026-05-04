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
///                 Text("Startup", bundle: .main)   // consumer 自身のラベル
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
    /// label の解決先 bundle を型で区別する。
    /// - `.libDefault`: lib 同梱 xcstrings ("Open at Login" / "ログイン時に開く") を使う。
    ///   `Text(_, bundle: .module)` で lib bundle を明示するため `LocalizedStringKey`
    ///   経由 (= consumer main bundle 解決) ではなく専用 case を持つ。
    /// - `.custom`: consumer 側で解決する `LocalizedStringKey` をそのまま `Text` に渡す。
    private enum LabelSource {
        case libDefault
        case custom(LocalizedStringKey)
    }

    private let labelSource: LabelSource
    private let onError: ((Error) -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOn: Bool = false

    /// lib 同梱の "Open at Login" (ja: "ログイン時に開く") をラベルに使う。
    ///
    /// - Parameter onError: `SMAppService.register/unregister` が throw した時に呼ばれる
    ///   callback。`nil` の場合エラーは無視される (UI は元の値にロールバック)。
    public init(onError: ((Error) -> Void)? = nil) {
        self.labelSource = .libDefault
        self.onError = onError
    }

    /// アプリ固有の文言をラベルに使う。`label` は **consumer 側 bundle で解決される** ため、
    /// consumer の `.xcstrings` / `.strings` で対応する key を提供すること。lib 同梱 catalog
    /// の文言を流用したい場合はラベル無しの init を使う。
    ///
    /// - Parameters:
    ///   - label: Toggle のラベル文言 (consumer bundle で解決される)。
    ///   - onError: `SMAppService.register/unregister` が throw した時に呼ばれる callback。
    public init(label: LocalizedStringKey, onError: ((Error) -> Void)? = nil) {
        self.labelSource = .custom(label)
        self.onError = onError
    }

    public var body: some View {
        Toggle(isOn: bindingToService) {
            switch labelSource {
            case .libDefault:
                Text("Open at Login", bundle: .module)
            case .custom(let key):
                Text(key)
            }
        }
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
