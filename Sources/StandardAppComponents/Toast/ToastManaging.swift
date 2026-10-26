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
///
/// Actor isolation: protocol 自体は actor-agnostic (Sendable のみ要求)。各メソッドは
/// 個別に `@MainActor` で UI 操作を強制する。protocol 全体に `@MainActor` を付けると、
/// `any ToastManaging` を `EnvironmentValues` に乗せた時に `WritableKeyPath` が
/// 作れなくなる (consumer 側で `View.environment(\.toastManager, ...)` が型エラー)。
public protocol ToastManaging: AnyObject, Sendable {
    /// 現在表示中のトースト (複数を並べて出す manager では、いちばん新しいもの)。
    @MainActor var currentToast: Toast? { get }

    /// 表示中のトースト (古い順)。`ToastContainerView` はこれを並べて描く。
    @MainActor var visibleToasts: [Toast] { get }

    /// トーストを表示する (キューに追加)。
    @MainActor func show(_ toast: Toast)

    /// 成功トーストを表示 (便利メソッド)。
    @MainActor func showSuccess(_ title: LocalizedStringResource, message: ToastText?, duration: TimeInterval)

    /// エラートーストを表示 (便利メソッド)。エラーは長めに表示。
    @MainActor func showError(_ title: LocalizedStringResource, message: ToastText?)

    /// 情報トーストを表示 (便利メソッド)。
    @MainActor func showInfo(_ title: LocalizedStringResource, message: ToastText?, duration: TimeInterval)

    /// 警告トーストを表示 (便利メソッド)。
    @MainActor func showWarning(_ title: LocalizedStringResource, message: ToastText?, duration: TimeInterval)

    /// アクション付きトーストを表示。
    @MainActor func showWithAction(
        style: Toast.Style,
        title: LocalizedStringResource,
        message: ToastText?,
        duration: TimeInterval,
        action: ToastAction
    )

    /// 現在のトーストを即座に消去。
    @MainActor func dismiss()

    /// 指定した id の表示中のトーストを消す (吹き出しの閉じるボタン)。表示中に無ければ何もしない。
    @MainActor func dismiss(id: Toast.ID)

    /// 全てのトーストをクリア。
    @MainActor func clearAll()

    /// 表示中のトースト (`id` が `currentToast` と同じとき) の自動消去を止める。
    /// `ToastContainerView` が、吹き出しにマウスが乗ったときに呼ぶ (長い文を読み切るため)。
    @MainActor func pauseAutoDismiss(for id: Toast.ID)

    /// `pauseAutoDismiss(for:)` で止めた自動消去を再開する。残り時間ではなく、そのトーストの
    /// `duration` を数え直す。止めていない・別のトーストに替わったあとの呼び出しは何もしない。
    @MainActor func resumeAutoDismiss(for id: Toast.ID)
}

// MARK: - Default Parameter Extensions

extension ToastManaging {
    /// 既定は `currentToast` の 0〜1 件 (1 件ずつ出す manager と同じ)。後から足した要件なので、既存の conformer を
    /// ビルドで落とさないための既定。
    /// 🚨 複数を並べる manager (`ToastManager(presentation: .stacked)`) を包む proxy は、`visibleToasts` と
    /// `dismiss(id:)` も転送する。転送しないと最新の 1 件しか描かれず、他は見えないまま時間切れで消える。
    @MainActor
    public var visibleToasts: [Toast] {
        currentToast.map { [$0] } ?? []
    }

    /// 既定は、表示中が同じ id なら `dismiss()`。`visibleToasts` を参照。
    @MainActor
    public func dismiss(id: Toast.ID) {
        if currentToast?.id == id { dismiss() }
    }

    /// 既定は何もしない (ホバーで止めない)。後から足した要件なので、既存の conformer をビルドで落とさないための既定。
    /// 🚨 本物の manager を包む proxy (ログ付きの wrapper など) は、包んだ先へ転送しないとホバーで止まらない。
    @MainActor
    public func pauseAutoDismiss(for id: Toast.ID) {}

    /// 既定は何もしない。`pauseAutoDismiss(for:)` を参照。
    @MainActor
    public func resumeAutoDismiss(for id: Toast.ID) {}

    /// `message` / `duration` 省略可能な便利オーバーロード。
    @MainActor
    public func showSuccess(_ title: LocalizedStringResource, message: ToastText? = nil, duration: TimeInterval = 3.0) {
        showSuccess(title, message: message, duration: duration)
    }

    /// `message` 省略可能な便利オーバーロード (エラーは duration 固定で 5 秒)。
    @MainActor
    public func showError(_ title: LocalizedStringResource, message: ToastText? = nil) {
        showError(title, message: message)
    }

    /// `message` / `duration` 省略可能な便利オーバーロード。
    @MainActor
    public func showInfo(_ title: LocalizedStringResource, message: ToastText? = nil, duration: TimeInterval = 3.0) {
        showInfo(title, message: message, duration: duration)
    }

    /// `message` / `duration` 省略可能な便利オーバーロード (警告は default 4 秒)。
    @MainActor
    public func showWarning(_ title: LocalizedStringResource, message: ToastText? = nil, duration: TimeInterval = 4.0) {
        showWarning(title, message: message, duration: duration)
    }

    /// `message` / `duration` 省略可能な便利オーバーロード (action 付きは default 5 秒)。
    @MainActor
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
