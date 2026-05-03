import Foundation
import ServiceManagement

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
@MainActor
public enum LaunchAtLoginService {
    /// 現在ログイン項目として登録されているか。
    /// `SMAppService` の `.status` を読む。`.enabled` のみ true。
    /// `.requiresApproval` (System Settings 側で承認待ち) や `.notFound` 等は false 扱い。
    /// - Important: ユーザーが System Settings → ログイン項目から手動で外した場合、
    ///   `.status` は `.notFound` 等に変わるため、UI 側で適切なタイミングで再読込すること
    ///   (`LaunchAtLoginToggle` は `onAppear` + `Scene.scenePhase` 変化で再読込する)。
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// ログイン項目登録を有効/無効に切り替える。
    /// - Throws: `SMAppService.register()/unregister()` がそのまま throw する。
    ///   呼び出し側は ja/en 等で一般的なエラーメッセージを表示するか、
    ///   無音で fallback (UI を元の値に戻す) するか選択する。
    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
