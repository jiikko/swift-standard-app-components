import SwiftUI

// MARK: - Toast Manager

/// `ToastManaging` のデフォルト実装。キュー方式で 1 件ずつトーストを表示し、
/// 自動消去 + 次トースト処理を行う。
///
/// 通常はアプリ側で 1 インスタンス作って Environment 等に注入する:
///
/// ```swift
/// @MainActor
/// enum AppServices {
///     static let toast: any ToastManaging = ToastManager()
/// }
/// ```
///
/// `lib` 側では `static let shared` を持たない (アプリ側 DI 構造を強制しないため)。
@MainActor
@Observable
public final class ToastManager: ToastManaging {
    // MARK: - Constants

    /// トースト表示に関する定数。
    private enum DisplayConstants {
        /// エラートーストのデフォルト表示時間 (秒)。
        static let errorDuration: TimeInterval = 5.0

        /// 消去アニメーションの継続時間 (秒)。
        static let dismissAnimationDuration: TimeInterval = 0.2

        /// dismiss から次トースト表示までの待機時間 (秒)。
        static let processingDelay: TimeInterval = 0.3

        /// スプリングアニメーションのレスポンス。
        static let springResponse: Double = 0.4

        /// スプリングアニメーションのダンピング係数。
        static let springDampingFraction: Double = 0.8

        /// キュー内に保持する最大トースト数。これを超える古いトーストは破棄。
        static let maxQueueSize = 5
    }

    // MARK: - Properties

    /// 現在表示中のトースト。
    public private(set) var currentToast: Toast?

    /// トーストのキュー。
    private var queue: [Toast] = []

    /// 処理中フラグ。
    private var isProcessing = false

    /// 自動消去用のタスク。
    private var dismissSwiftTask: Task<Void, Never>?

    /// dismiss 後のキュー処理タスク。
    private var queueProcessingTask: Task<Void, Never>?

    // MARK: - Init

    public init() {}

    // MARK: - Public Methods

    public func show(_ toast: Toast) {
        queue.append(toast)
        // キュー上限を超えたら古い通知を破棄
        while queue.count > DisplayConstants.maxQueueSize {
            queue.removeFirst()
        }
        processQueue()
    }

    public func showSuccess(
        _ title: LocalizedStringResource,
        message: ToastText? = nil,
        duration: TimeInterval = 3.0
    ) {
        show(Toast(
            style: .success,
            title: String(localized: title),
            message: message?.resolve(),
            duration: duration
        ))
    }

    public func showError(_ title: LocalizedStringResource, message: ToastText? = nil) {
        // エラーは長めに表示 (手動で閉じる必要がある場合もある)
        show(Toast(
            style: .error,
            title: String(localized: title),
            message: message?.resolve(),
            duration: DisplayConstants.errorDuration
        ))
    }

    public func showInfo(
        _ title: LocalizedStringResource,
        message: ToastText? = nil,
        duration: TimeInterval = 3.0
    ) {
        show(Toast(
            style: .info,
            title: String(localized: title),
            message: message?.resolve(),
            duration: duration
        ))
    }

    public func showWarning(
        _ title: LocalizedStringResource,
        message: ToastText? = nil,
        duration: TimeInterval = 4.0
    ) {
        show(Toast(
            style: .warning,
            title: String(localized: title),
            message: message?.resolve(),
            duration: duration
        ))
    }

    public func showWithAction(
        style: Toast.Style,
        title: LocalizedStringResource,
        message: ToastText? = nil,
        duration: TimeInterval = 5.0,
        action: ToastAction
    ) {
        show(Toast(
            style: style,
            title: String(localized: title),
            message: message?.resolve(),
            duration: duration,
            action: action
        ))
    }

    public func dismiss() {
        dismissSwiftTask?.cancel()
        dismissSwiftTask = nil

        withAnimation(.easeOut(duration: DisplayConstants.dismissAnimationDuration)) {
            currentToast = nil
        }

        // 少し待ってから次のトーストを処理
        queueProcessingTask?.cancel()
        queueProcessingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(DisplayConstants.processingDelay))
            self?.isProcessing = false
            self?.processQueue()
        }
    }

    public func clearAll() {
        dismissSwiftTask?.cancel()
        dismissSwiftTask = nil
        queueProcessingTask?.cancel()
        queueProcessingTask = nil
        queue.removeAll()
        isProcessing = false

        withAnimation {
            currentToast = nil
        }
    }

    // MARK: - Private Methods

    private func processQueue() {
        guard !isProcessing, !queue.isEmpty else { return }

        isProcessing = true
        let toast = queue.removeFirst()

        withAnimation(.spring(
            response: DisplayConstants.springResponse,
            dampingFraction: DisplayConstants.springDampingFraction
        )) {
            currentToast = toast
        }

        // 自動消去をスケジュール
        scheduleDismiss(after: toast.duration)
    }

    private func scheduleDismiss(after duration: TimeInterval) {
        dismissSwiftTask?.cancel()
        dismissSwiftTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            self?.dismiss()
        }
    }
}
