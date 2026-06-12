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
///   (System Settings から手動 off にした時等) ため、毎回 `LaunchAtLoginService.status`
///   を読む。
/// - 切替操作後は **成功・失敗を問わず system status を読み直して UI を同期** する。
///   `register()` が成功しても `.requiresApproval` で止まるケースがあり (System
///   Settings 側の承認待ち)、操作結果を楽観反映すると ON 表示なのに実際は無効、
///   という解離が起きるため。失敗時の rollback もこの再同期が兼ねる。
/// - `.requiresApproval` では承認待ちの説明と System Settings › ログイン項目への
///   誘導ボタンを表示する。`.unavailable` (`.notFound` / 未知 status) ではトグルを
///   無効化する。
/// - **lib は consumer 不在で stdout / OSLog にログを書かない**。切替失敗のエラーは
///   インライン footnote (`error.localizedDescription`) として表示しつつ、解析したい
///   consumer は `onError` callback で受け取り、自前の logger / toast / alert に流す。
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
    @State private var status: LaunchAtLoginStatus = .notRegistered
    @State private var errorText: String?

    /// lib 同梱の "Open at Login" (ja: "ログイン時に開く") をラベルに使う。
    ///
    /// - Parameter onError: `SMAppService.register/unregister` が throw した時に呼ばれる
    ///   callback。エラー文言は callback の有無に関わらずトグル直下に footnote 表示される。
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
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: bindingToService) {
                switch labelSource {
                case .libDefault:
                    Text("Open at Login", bundle: .module)
                case .custom(let key):
                    Text(key)
                }
            }
            .disabled(status == .unavailable)

            switch status {
            case .requiresApproval:
                Text("Waiting for approval in System Settings › Login Items.", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    LaunchAtLoginService.openSystemSettingsLoginItems()
                } label: {
                    Text("Open Login Items Settings…", bundle: .module)
                        .font(.footnote)
                }
                .buttonStyle(.link)
            case .unavailable:
                Text("Open at Login is not available for this app.", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .enabled, .notRegistered:
                EmptyView()
            }

            if let errorText {
                // OS が返す localizedDescription をそのまま出す (catalog lookup させない)。
                Text(verbatim: errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
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
                isOn = newValue
                do {
                    try LaunchAtLoginService.setEnabled(newValue)
                    errorText = nil
                } catch {
                    errorText = error.localizedDescription
                    onError?(error)
                }
                // 成功時も .requiresApproval で止まり得るため、操作結果の楽観反映は
                // せず system status を読み直す。失敗時の rollback もこれが兼ねる。
                syncFromSystem()
            }
        )
    }

    private func syncFromSystem() {
        status = LaunchAtLoginService.status
        isOn = status == .enabled
    }
}
