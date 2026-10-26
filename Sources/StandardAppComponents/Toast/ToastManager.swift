import SwiftUI

// MARK: - Toast Manager

/// `ToastManaging` のデフォルト実装。キューに積んだトーストを順に表示し、
/// トーストごとの自動消去 + 次トースト処理を行う。
///
/// - `.oneAtATime` (既定): 1 件ずつ出す。表示中に来たトーストはキューで待つ
/// - `.stacked(maxVisible:)`: 最大 `maxVisible` 件を同時に出す (`ToastContainerView` が縦に並べる)。
///   あふれた分はキューで待ち、表示中のどれかが消えたら出る
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
    /// トーストの出し方。
    public enum Presentation: Sendable, Equatable {
        /// 1 件ずつ出す。
        case oneAtATime
        /// 最大 `maxVisible` 件を同時に出す (1 未満は 1 として扱う)。
        case stacked(maxVisible: Int)

        var maxVisible: Int {
            switch self {
            case .oneAtATime:
                1
            case .stacked(let maxVisible):
                max(1, maxVisible)
            }
        }
    }

    // MARK: - Constants

    /// トースト表示に関する定数。
    private enum DisplayConstants {
        /// エラートーストのデフォルト表示時間 (秒)。
        static let errorDuration: TimeInterval = 5.0

        /// 消去アニメーションの継続時間 (秒)。
        static let dismissAnimationDuration: TimeInterval = 0.2

        /// dismiss から次トースト表示までの待機時間 (秒)。消えかけの吹き出しと次の吹き出しを重ねない。
        static let processingDelay: TimeInterval = 0.3

        /// スプリングアニメーションのレスポンス。
        static let springResponse: Double = 0.4

        /// スプリングアニメーションのダンピング係数。
        static let springDampingFraction: Double = 0.8

        /// キュー内に保持する最大トースト数。これを超える古いトーストは破棄。
        static let maxQueueSize = 5
    }

    // MARK: - Properties

    /// トーストの出し方。
    public let presentation: Presentation

    /// 表示中のトースト (古い順)。
    public private(set) var visibleToasts: [Toast] = []

    /// 表示中のいちばん新しいトースト。
    public var currentToast: Toast? { visibleToasts.last }

    /// 表示を待っているトースト (古い順)。
    private var queue: [Toast] = []

    /// どれかが消えてから `processingDelay` の間は、キューから出さない。
    private var isCoolingDown = false

    /// `isCoolingDown` を解くタスク。
    private var cooldownTask: Task<Void, Never>?

    /// トーストごとの自動消去のタスク。
    private var dismissTasks: [Toast.ID: Task<Void, Never>] = [:]

    /// 自動消去を止めているトーストの id (ホバー中)。
    private var pausedToastIDs: Set<Toast.ID> = []

    // MARK: - Init

    public init(presentation: Presentation = .oneAtATime) {
        self.presentation = presentation
    }

    // MARK: - Public Methods

    /// トーストを出す (空きが無ければキューで待つ)。
    ///
    /// 同じ `id`、または同じ `uniqueKey` のトーストが表示中かキューに居れば、新しく足さずにそれを置き換える。
    /// 不変条件: 表示中とキューを合わせて、同じ id・同じ `uniqueKey` は 1 件だけ。
    public func show(_ toast: Toast) {
        if replaceExisting(with: toast) { return }
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
        guard let toast = currentToast else { return }
        dismiss(id: toast.id)
    }

    public func dismiss(id: Toast.ID) {
        guard let index = visibleToasts.firstIndex(where: { $0.id == id }) else { return }
        dismissTasks.removeValue(forKey: id)?.cancel()
        pausedToastIDs.remove(id)

        withAnimation(.easeOut(duration: DisplayConstants.dismissAnimationDuration)) {
            _ = visibleToasts.remove(at: index)
        }

        // 少し待ってから次のトーストを処理
        startCooldown()
    }

    public func clearAll() {
        dismissTasks.values.forEach { $0.cancel() }
        dismissTasks.removeAll()
        pausedToastIDs.removeAll()
        cooldownTask?.cancel()
        cooldownTask = nil
        isCoolingDown = false
        queue.removeAll()

        withAnimation {
            visibleToasts.removeAll()
        }
    }

    public func pauseAutoDismiss(for id: Toast.ID) {
        guard visibleToasts.contains(where: { $0.id == id }) else { return }
        pausedToastIDs.insert(id)
        dismissTasks.removeValue(forKey: id)?.cancel()
    }

    public func resumeAutoDismiss(for id: Toast.ID) {
        // 消えた吹き出しの onHover(false) が、次のトーストを止めた後に届くことがある。止めた id と
        // 違う呼び出しは何もしない (次のトーストの停止を解かない)。
        guard pausedToastIDs.contains(id), let toast = visibleToasts.first(where: { $0.id == id }) else { return }
        pausedToastIDs.remove(id)
        scheduleDismiss(of: toast)
    }

    // MARK: - Private Methods

    /// 同じ id か同じ `uniqueKey` のトーストがあれば置き換えて true を返す。
    /// 探す順は、表示中の同じ id → 表示中の同じ key → キューの同じ id → キューの同じ key。
    /// 最初に当たったものを置き換え (元の id を引き継ぐ)、ほかに当たったものは捨てる。
    private func replaceExisting(with toast: Toast) -> Bool {
        func matches(_ other: Toast) -> Bool {
            other.id == toast.id || (toast.uniqueKey != nil && other.uniqueKey == toast.uniqueKey)
        }
        let key = toast.uniqueKey
        let visibleIndex = visibleToasts.firstIndex { $0.id == toast.id }
            ?? key.flatMap { key in visibleToasts.firstIndex { $0.uniqueKey == key } }
        if let visibleIndex {
            let keptID = visibleToasts[visibleIndex].id
            let replaced = toast.replacingID(with: keptID)
            visibleToasts[visibleIndex] = replaced
            queue.removeAll(where: matches)
            for other in visibleToasts where other.id != keptID && matches(other) {
                dismiss(id: other.id)
            }
            // ホバーで止めている間は止めたまま (外れたときに数え直す)
            if !pausedToastIDs.contains(keptID) {
                scheduleDismiss(of: replaced)
            }
            return true
        }
        let queueIndex = queue.firstIndex { $0.id == toast.id }
            ?? key.flatMap { key in queue.firstIndex { $0.uniqueKey == key } }
        guard let queueIndex else { return false }
        let keptID = queue[queueIndex].id
        queue[queueIndex] = toast.replacingID(with: keptID)
        queue = queue.enumerated().filter { index, other in index == queueIndex || !matches(other) }.map(\.element)
        return true
    }

    /// 待ちの間でなければ、空きを全部埋めるまでキューの先頭から出す。
    private func processQueue() {
        guard !isCoolingDown else { return }
        while visibleToasts.count < presentation.maxVisible, !queue.isEmpty {
            let toast = queue.removeFirst()
            withAnimation(.spring(
                response: DisplayConstants.springResponse,
                dampingFraction: DisplayConstants.springDampingFraction
            )) {
                visibleToasts.append(toast)
            }
            scheduleDismiss(of: toast)
        }
    }

    /// `processingDelay` の間キューから出さず、終わったら空きを埋める。待ちの間にまた呼ばれたら数え直す。
    private func startCooldown() {
        isCoolingDown = true
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(DisplayConstants.processingDelay))
            // sleep が cancel された場合は何もしない (try? が CancellationError を
            // 握り潰すため、Task.isCancelled で明示的にチェックしないと cancel された
            // タスクが processQueue を呼んでキューが多重に進む)。
            guard !Task.isCancelled else { return }
            self?.isCoolingDown = false
            self?.processQueue()
        }
    }

    /// そのトーストだけの自動消去を予約する (前の予約は取り消す)。
    private func scheduleDismiss(of toast: Toast) {
        dismissTasks.removeValue(forKey: toast.id)?.cancel()
        let id = toast.id
        dismissTasks[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(toast.duration))
            // sleep が cancel された場合は何もしない (try? が CancellationError を
            // 握り潰すため、Task.isCancelled で明示的にチェックしないと cancel された
            // タスクが dismiss を呼んでキューが多重に進む)。
            guard !Task.isCancelled else { return }
            self?.dismiss(id: id)
        }
    }
}
