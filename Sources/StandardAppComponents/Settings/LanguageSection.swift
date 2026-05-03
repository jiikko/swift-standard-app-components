import AppKit
import SwiftUI

/// Settings ウィンドウ「General」タブの Language セクション標準実装。
///
/// `GeneralTabContract.language` の slot にそのまま流し込んで使う:
///
/// ```swift
/// SettingsWindow(
///     general: GeneralTabContract(
///         appearance: { ... },
///         language: {
///             LanguageSection(
///                 supportedLanguages: [
///                     .init(code: "en", displayName: "English"),
///                     .init(code: "ja", displayName: "日本語")
///                 ],
///                 onRestart: { NSApp.terminate(nil) }
///             )
///         }
///     )
/// )
/// ```
///
/// 設計:
/// - `Picker` の選択変更で **即時 apply** (macOS System Settings の言語変更フローに揃える)。
///   Apply ボタン経由の確定 step は持たない。
/// - apply 後は alert で **Later / Restart Now** の 2 択を出す。Restart Now で
///   `onRestart` callback を呼ぶ。デフォルトは `NSApp.terminate(nil)` で、自動再起動が
///   必要な consumer は relaunch 関数を渡す。
/// - System Default オプションは lib 側で先頭に自動追加するので consumer の
///   `supportedLanguages` には含めない。
public struct LanguageSection: View {
    private let supportedLanguages: [LanguageOption]
    private let onRestart: () -> Void

    @State private var selectedLanguage: String?
    /// 初回 onAppear で system 値を流し込む間、`onChange` を発火させないためのガード。
    /// `selectedLanguage` 自体の `nil` 初期値と区別するために別フラグで管理する
    /// (system 値が `nil` (= System Default) の場合と区別不能になるため)。
    @State private var isInitialLoad = true
    @State private var showRestartAlert = false

    public init(
        supportedLanguages: [LanguageOption],
        onRestart: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.supportedLanguages = supportedLanguages
        self.onRestart = onRestart
    }

    public var body: some View {
        Picker(selection: $selectedLanguage) {
            Text("System Default", bundle: .module).tag(String?.none)
            ForEach(supportedLanguages, id: \.code) { lang in
                Text(lang.displayName).tag(String?.some(lang.code))
            }
        } label: {
            EmptyView()
        }
        .labelsHidden()
        .onAppear {
            if isInitialLoad {
                selectedLanguage = loadCurrentLanguage()
                // 次 RunLoop tick まで guard を残し、`selectedLanguage` への
                // 上記代入が呼び出す `onChange` を巻き込まないようにする。
                DispatchQueue.main.async { isInitialLoad = false }
            }
        }
        .onChange(of: selectedLanguage) { _, newValue in
            guard !isInitialLoad else { return }
            applyLanguage(newValue)
            showRestartAlert = true
        }
        .alert(
            Text("Language Changed", bundle: .module),
            isPresented: $showRestartAlert
        ) {
            Button(role: .cancel) {
                // 何もしない (Later: ユーザーは自分のタイミングで再起動する)
            } label: {
                Text("Later", bundle: .module)
            }

            Button {
                onRestart()
            } label: {
                Text("Restart Now", bundle: .module)
            }
        } message: {
            Text("Restart the app to apply the new language.", bundle: .module)
        }
    }

    /// `AppleLanguages` を直接読んで「単一指定が supportedLanguages に含まれる場合のみ」を
    /// 「明示選択中」と扱う。それ以外 (複数指定 / 未設定 / 想定外言語) は System Default として表示する。
    private func loadCurrentLanguage() -> String? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let appDomain = UserDefaults.standard.persistentDomain(forName: bundleId),
              let languages = appDomain["AppleLanguages"] as? [String],
              languages.count == 1 else {
            return nil
        }
        let lang = languages[0]
        return supportedLanguages.contains(where: { $0.code == lang }) ? lang : nil
    }

    private func applyLanguage(_ language: String?) {
        if let language {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}

/// `LanguageSection` で選べる言語オプション。System Default は lib 側で自動追加する
/// (consumer 側で渡す配列には含めない)。
public struct LanguageOption: Hashable, Sendable {
    /// `AppleLanguages` UserDefaults に書き込む言語コード (ISO 639-1)。例: "en", "ja"
    public let code: String

    /// Picker に表示する文字列。各言語の native 表記を使うのが慣例。
    /// 例: "English", "日本語", "Français"
    public let displayName: String

    public init(code: String, displayName: String) {
        self.code = code
        self.displayName = displayName
    }
}
