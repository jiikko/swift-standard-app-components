import AppKit

/// `NSCursor.hide()` / `unhide()` を抽象化してテスト時に差し替え可能にする。
public protocol CursorActuator: AnyObject {
    func hide()
    func unhide()
}

/// 本番実装。`NSCursor` の hide/unhide はリファレンスカウント方式。
/// 呼び出し回数の対称性は呼び出し側 (`FullscreenCursorVisibilityController`) で担保する。
public final class SystemCursorActuator: CursorActuator {
    public init() {}
    public func hide() { NSCursor.hide() }
    public func unhide() { NSCursor.unhide() }
}

/// フルスクリーン中のマウスカーソル可視性を管理する。
/// マウス静止で自動非表示、移動で即時再表示する。
///
/// 不変条件:
/// - `start(window:)` 後、マウス静止 `idleTimeout` 秒でカーソルを隠す
/// - マウス移動／ドラッグでカーソルを即時再表示し、idle タイマを再起動する
/// - `stop()` 時、カーソルが隠れていれば必ず再表示する (hide/unhide の対称性)
/// - `start` / `stop` は冪等
///
/// **caller 契約**: フルスクリーン終了経路で必ず `stop()` を呼ぶこと。deinit での
/// 自動クリーンアップは行わない (`@MainActor` クラスの deinit は非隔離で、
/// consumer が MainActor 外で最終解放した場合の実行時保証が取れないため)。
/// `stop()` を呼ばずに解放するとイベント監視が leak し、カーソルが隠れたままになりうる。
///
/// イベント監視は local monitor だが `return event` の観測のみで、イベントを消費しない
/// (キー入力の所有には使わない)。
@MainActor
public final class FullscreenCursorVisibilityController {
    private let idleTimeout: TimeInterval
    private let cursorActuator: any CursorActuator
    private var idleTimer: Timer?
    private var eventMonitor: Any?
    private weak var trackedWindow: NSWindow?
    private var isHidden = false
    private var isRunning = false

    /// - Parameters:
    ///   - idleTimeout: マウス静止からカーソルを隠すまでの秒数
    ///   - cursorActuator: hide/unhide の実行体 (テストで差し替え可能)
    public init(
        idleTimeout: TimeInterval = 2.0,
        cursorActuator: any CursorActuator = SystemCursorActuator()
    ) {
        self.idleTimeout = idleTimeout
        self.cursorActuator = cursorActuator
    }

    /// 監視を開始する。二重呼び出しは無視される (冪等)。
    public func start(window: NSWindow) {
        guard !isRunning else { return }
        isRunning = true

        // mouseMoved を local monitor に届かせるためにウィンドウ側で受信を有効化する。
        // フルスクリーン窓は専用なので副作用は限定的。
        window.acceptsMouseMovedEvents = true
        trackedWindow = window

        // ドラッグ中の動きでも復帰させるため、移動系イベントを広めに監視する。
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.notifyMouseMoved()
            return event
        }

        scheduleIdleHide()
    }

    /// 監視を停止し、隠れていればカーソルを必ず再表示する。二重呼び出しは無視される (冪等)。
    public func stop() {
        guard isRunning else { return }
        isRunning = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil

        if isHidden {
            cursorActuator.unhide()
            isHidden = false
        }

        trackedWindow = nil
    }

    /// マウス移動通知。本番では NSEvent モニタから、テストでは直接呼ばれる。
    public func notifyMouseMoved() {
        guard isRunning else { return }
        if isHidden {
            cursorActuator.unhide()
            isHidden = false
        }
        scheduleIdleHide()
    }

    private func scheduleIdleHide() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            // Timer のコールバックは main run loop から呼ばれるが、strict concurrency では
            // 明示的な MainActor 隔離が必要。
            Task { @MainActor [weak self] in
                self?.hideForIdle()
            }
        }
    }

    private func hideForIdle() {
        guard isRunning, !isHidden else { return }
        cursorActuator.hide()
        isHidden = true
    }
}
