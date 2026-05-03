import SwiftUI

// MARK: - ToastManaging Protocol

/// トースト通知を管理するためのプロトコル。
/// テスト時にモック実装を注入可能にする / アプリ側で `Environment` に乗せる時の型。
///
/// - `title` は `LocalizedStringResource`。常に catalog でロケール解決される。
///   リテラル渡しは Xcode の xcstrings 抽出と実行時解決の両方を自動で経る。
/// - `message` は `ToastText?`。リテラルは `.localized`、動的値は明示的に
///   `.verbatim(...)` で渡す。
///
/// 設計の経緯 (ThumbnailThumb 由来):
/// - #340: catalog バイパス (ラップ忘れ) をコンパイル時に潰すため
///   `LocalizedStringResource` に移行
/// - #344: 動的値まで catalog lookup される副作用を是正するため、`message` は
///   `ToastText` で localized / verbatim を分離
@MainActor
public protocol ToastManaging: AnyObject, Sendable {
    /// 現在表示中のトースト。
    var currentToast: Toast? { get }

    /// トーストを表示する (キューに追加)。
    func show(_ toast: Toast)

    /// 成功トーストを表示 (便利メソッド)。
    func showSuccess(_ title: LocalizedStringResource, message: ToastText?, duration: TimeInterval)

    /// エラートーストを表示 (便利メソッド)。エラーは長めに表示。
    func showError(_ title: LocalizedStringResource, message: ToastText?)

    /// 情報トーストを表示 (便利メソッド)。
    func showInfo(_ title: LocalizedStringResource, message: ToastText?, duration: TimeInterval)

    /// 警告トーストを表示 (便利メソッド)。
    func showWarning(_ title: LocalizedStringResource, message: ToastText?, duration: TimeInterval)

    /// アクション付きトーストを表示。
    func showWithAction(
        style: Toast.Style,
        title: LocalizedStringResource,
        message: ToastText?,
        duration: TimeInterval,
        action: ToastAction
    )

    /// 現在のトーストを即座に消去。
    func dismiss()

    /// 全てのトーストをクリア。
    func clearAll()
}

// MARK: - Default Parameter Extensions

extension ToastManaging {
    /// `message` / `duration` 省略可能な便利オーバーロード。
    public func showSuccess(_ title: LocalizedStringResource, message: ToastText? = nil, duration: TimeInterval = 3.0) {
        showSuccess(title, message: message, duration: duration)
    }

    /// `message` 省略可能な便利オーバーロード (エラーは duration 固定で 5 秒)。
    public func showError(_ title: LocalizedStringResource, message: ToastText? = nil) {
        showError(title, message: message)
    }

    /// `message` / `duration` 省略可能な便利オーバーロード。
    public func showInfo(_ title: LocalizedStringResource, message: ToastText? = nil, duration: TimeInterval = 3.0) {
        showInfo(title, message: message, duration: duration)
    }

    /// `message` / `duration` 省略可能な便利オーバーロード (警告は default 4 秒)。
    public func showWarning(_ title: LocalizedStringResource, message: ToastText? = nil, duration: TimeInterval = 4.0) {
        showWarning(title, message: message, duration: duration)
    }

    /// `message` / `duration` 省略可能な便利オーバーロード (action 付きは default 5 秒)。
    public func showWithAction(
        style: Toast.Style,
        title: LocalizedStringResource,
        message: ToastText? = nil,
        duration: TimeInterval = 5.0,
        action: ToastAction
    ) {
        showWithAction(
            style: style,
            title: title,
            message: message,
            duration: duration,
            action: action
        )
    }
}
