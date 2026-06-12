import Foundation
import ServiceManagement

/// ログイン項目登録の状態。`SMAppService.Status` を lib の語彙に正規化したもの。
///
/// `SMAppService.Status` を View 層へ直接露出すると consumer が `ServiceManagement`
/// を import する必要が生じ、`@unknown default` の扱いも各 consumer に分散する。
/// lib 側で 4 状態に畳んで公開する。
public enum LaunchAtLoginStatus: Equatable, Sendable {
    /// 登録済みで有効。
    case enabled
    /// 未登録 (= トグル OFF の通常状態)。
    case notRegistered
    /// System Settings › ログイン項目でのユーザー許可が必要な状態。
    /// 初回登録後の承認待ちだけでなく、**ユーザーが System Settings で実行同意を
    /// 取り消した場合にも** この status が返る。いずれもアプリ側から有効化を完了
    /// できないため、System Settings への誘導が必要 (`register()` を再発行しても
    /// already registered / launch denied エラーになり得る)。
    case requiresApproval
    /// 利用不可 (`.notFound` および将来追加されうる未知 status)。
    /// UI はトグルを無効化して登録操作を受け付けないこと。
    case unavailable

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .notRegistered
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .unavailable
        @unknown default:
            self = .unavailable
        }
    }
}

/// `SMAppService.mainApp` の薄いラッパー。
/// アプリ Bundle を「ログイン項目」として登録/解除する macOS 標準 API
/// (`SMAppService` family, macOS 13+) の boilerplate を集約する。
///
/// 想定 consumer:
///   - Settings の General タブ等で `LaunchAtLoginToggle` を介して使う
///   - `LaunchAtLoginToggle` を使わず自前 UI で制御したい場合は本 service を直接呼ぶ
///
/// Bundle ID は `Bundle.main` (= consumer アプリ自身) から `SMAppService.mainApp`
/// が読むため、lib 側に渡す引数は無い。テスト等で他 Bundle を使いたい場合は
/// `SMAppService(plistName:)` を直接使うこと (本 lib のスコープ外)。
///
/// - Important: `SMAppService` 自身が thread-safe なため、本 service には
///   `@MainActor` 制約を **付けない**。`applicationDidFinishLaunching` の
///   早期チェック (= MainActor 上だが MainActor isolation を強制したくない)
///   や、Background `Task` から `isEnabled` を polling したいケースを
///   阻害しないため。`LaunchAtLoginToggle` 側 (View) は MainActor。
public enum LaunchAtLoginService {
    /// 現在ログイン項目として登録されているか。`status == .enabled` のみ true。
    /// `.requiresApproval` (System Settings 側で承認待ち) や `.unavailable` は false 扱い。
    /// - Important: ユーザーが System Settings → ログイン項目から手動で外した場合、
    ///   `status` が変わるため、UI 側で適切なタイミングで再読込すること
    ///   (`LaunchAtLoginToggle` は `onAppear` + `Scene.scenePhase` 変化で再読込する)。
    public static var isEnabled: Bool {
        status == .enabled
    }

    /// 現在の登録状態 (`SMAppService.mainApp.status` の正規化値)。
    /// `SMAppService.Status` は KVO / publish 非対応のため、UI は表示タイミングで
    /// 読み直すこと。
    public static var status: LaunchAtLoginStatus {
        LaunchAtLoginStatus(SMAppService.mainApp.status)
    }

    /// ログイン項目登録を有効/無効に切り替える。
    /// - Throws: `SMAppService.register()/unregister()` がそのまま throw する。
    ///   呼び出し側は ja/en 等で一般的なエラーメッセージを表示するか、
    ///   無音で fallback (UI を元の値に戻す) するか選択する。
    /// - Important: `register()` が成功しても直後の `status` は `.requiresApproval`
    ///   になり得る (System Settings 側の承認が必要なケース)。呼び出し側は
    ///   呼び出し後に必ず `status` を読み直して UI を同期すること。
    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// System Settings › 一般 › ログイン項目 を開く。
    /// `.requiresApproval` 状態でユーザーに承認操作を促すときに使う。
    public static func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
