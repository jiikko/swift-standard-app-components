import AppKit
import SwiftUI

/// Settings ウィンドウ「General」タブの Language セクション標準実装。
///
/// `GeneralTabContract.language` の slot にそのまま流し込んで使う:
///
/// ```swift
/// // (1) consumer が relaunch 経路を持っていない場合: onRestart 省略 (default = nil)。
/// //     alert のボタンは "Quit Now" になり、押すと NSApp.terminate(nil) で終了するだけ。
/// //     ユーザーは自分でアプリを再度開く必要がある。
/// LanguageSection(supportedLanguages: [
///     .init(code: "en", displayName: "English"),
///     .init(code: "ja", displayName: "日本語")
/// ])
///
/// // (2) consumer が relaunch を提供できる場合: onRestart に relaunch closure を渡す。
/// //     alert のボタンは "Restart Now" になり、押すと onRestart() が呼ばれる。
/// LanguageSection(
///     supportedLanguages: [.init(code: "en", displayName: "English")],
///     onRestart: { /* consumer 側の relaunch 実装 (Sparkle relaunch / launch helper 等) */ }
/// )
/// ```
///
/// 設計:
/// - `Picker` の選択変更で **即時 apply** (macOS System Settings の言語変更フローに揃える)。
///   Apply ボタン経由の確定 step は持たない。
/// - apply 後は alert で 2 択を出す:
///   - **`onRestart` を渡した場合**: 「Later / Restart Now」。Restart Now で `onRestart`
///     を呼ぶ。consumer が relaunch 経路を持っている時に使う。
///   - **`onRestart` を渡さなかった場合 (デフォルト)**: 「Later / Quit Now」。
///     Quit Now で `NSApp.terminate(nil)` を呼ぶ (= 終了するだけで再起動はしない)。
///     ボタン文言と挙動を一致させるため、デフォルトでは "Restart Now" は表示しない。
/// - System Default オプションは lib 側で先頭に自動追加するので consumer の
///   `supportedLanguages` には含めない。
public struct LanguageSection: View {
    private let supportedLanguages: [LanguageOption]
    /// consumer から渡された restart 関数。`nil` ならデフォルト挙動 (Quit Now: terminate)。
    /// closure 有無でアラートのボタン文言が変わる (Restart Now / Quit Now) ため、
    /// 「relaunch 可否」の真実の所在をここで保持する。
    private let onRestart: (() -> Void)?

    @State private var selectedLanguage: String?
    /// 初回 onAppear で system 値を流し込む間、`onChange` を発火させないためのガード。
    /// `selectedLanguage` 自体の `nil` 初期値と区別するために別フラグで管理する
    /// (system 値が `nil` (= System Default) の場合と区別不能になるため)。
    @State private var isInitialLoad = true
    @State private var showRestartAlert = false

    public init(
        supportedLanguages: [LanguageOption],
        onRestart: (() -> Void)? = nil
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
            // VoiceOver / accessibility 用の意味のある label。
            // `.labelsHidden()` で視覚的には消すが、`EmptyView` だと control label が
            // 失われ accessibility が弱くなるため `Text` を渡しておく (Codex review #3)。
            Text("Language", bundle: .module)
        }
        .labelsHidden()
        // GeneralTabContent.swift の anti-pattern ガイダンス (`.labelsHidden()` は避ける)
        // に対する **意図的な例外**: LanguageSection は section header (= "Language") が
        // 既に row の意味を表しているため、視覚的に label を 2 重に出さないように
        // `.labelsHidden()` で隠す。VoiceOver には上の Text("Language") が伝わる。
        // macOS Form の慣例「label 左 / field 右」のうち field を行末に揃えるため、
        // alignment: .trailing で row 全幅に広げて picker を右端へ寄せる。
        .frame(maxWidth: .infinity, alignment: .trailing)
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

            // onRestart が渡された場合は「再起動」を約束できるので Restart Now、
            // 渡されていない場合は terminate するだけなので Quit Now と表記して
            // ボタン文言と挙動を一致させる。
            if let onRestart {
                Button {
                    onRestart()
                } label: {
                    Text("Restart Now", bundle: .module)
                }
            } else {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit Now", bundle: .module)
                }
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
