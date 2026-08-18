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

/// マウス移動イベント監視の登録/解除を抽象化してテスト時に差し替え可能にする。
/// (登録・解除の対称性はテストでしか観測できないため seam にする)
@MainActor
public protocol CursorEventMonitorInstalling: AnyObject {
    /// マウス移動系イベントの監視を登録し、解除用トークンを返す。
    /// handler は観測のみでイベントを消費しないこと。
    func installMouseMovementMonitor(handler: @escaping () -> Void) -> Any?
    /// `installMouseMovementMonitor` が返したトークンで監視を解除する。
    func removeMonitor(_ monitor: Any)
}

/// 本番実装。local monitor だが handler は `return event` の観測のみで、
/// イベントを消費しない (キー入力の所有には使わない)。
@MainActor
public final class SystemCursorEventMonitor: CursorEventMonitorInstalling {
    // 既定引数 (非隔離文脈) から生成できるよう nonisolated にする。stored state を持たない。
    public nonisolated init() {}

    public func installMouseMovementMonitor(handler: @escaping () -> Void) -> Any? {
        // ドラッグ中の動きでも復帰させるため、移動系イベントを広めに監視する。
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        return NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            handler()
            return event
        }
    }

    public func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

/// フルスクリーン中のマウスカーソル可視性を管理する。
/// マウス静止で自動非表示、移動で即時再表示する。
///
/// 不変条件:
/// - `start(window:)` 後、マウス静止 `idleTimeout` 秒でカーソルを隠す
/// - マウス移動／ドラッグでカーソルを即時再表示し、idle タイマを再起動する
/// - `stop()` 時、カーソルが隠れていれば必ず再表示する (hide/unhide の対称性)
/// - `start` / `stop` は冪等。stop → start の再利用も可 (旧セッションの idle 判定は
///   世代トークンで無効化され、新セッションへ持ち越されない)
///
/// **caller 契約**: フルスクリーン終了経路で必ず `stop()` を呼ぶこと。deinit での
/// 自動クリーンアップは行わない (`@MainActor` クラスの deinit は非隔離で、
/// consumer が MainActor 外で最終解放した場合の実行時保証が取れないため)。
/// `stop()` を呼ばずに解放するとイベント監視が leak する (debug ビルドでは
/// deinit の assert が契約違反を検出する)。
@MainActor
public final class FullscreenCursorVisibilityController {
    private let idleTimeout: TimeInterval
    private let cursorActuator: any CursorActuator
    private let eventMonitorInstaller: any CursorEventMonitorInstalling
    private var idleTimer: Timer?
    private var eventMonitor: Any?
    private var isHidden = false
    // deinit (非隔離) から契約違反 assert のために read するので nonisolated(unsafe)。
    // 書き込みは全て MainActor 上 (start/stop) に限定されている。
    private nonisolated(unsafe) var isRunning = false

    /// start/stop のたびに進む世代トークン。Timer 発火は `Task { @MainActor }` を
    /// 1 hop 挟むため、`stop()` → `start()` の再起動が hop の間に入ると
    /// `invalidate()` では旧セッションの idle 判定を止められない (発火済み)。
    /// 旧世代のコールバックはここで無効化する。
    private var generation = 0

    /// - Parameters:
    ///   - idleTimeout: マウス静止からカーソルを隠すまでの秒数
    ///   - cursorActuator: hide/unhide の実行体 (テストで差し替え可能)
    ///   - eventMonitorInstaller: マウス移動監視の登録/解除 (テストで差し替え可能)
    public init(
        idleTimeout: TimeInterval = 2.0,
        cursorActuator: any CursorActuator = SystemCursorActuator(),
        eventMonitorInstaller: any CursorEventMonitorInstalling = SystemCursorEventMonitor()
    ) {
        self.idleTimeout = idleTimeout
        self.cursorActuator = cursorActuator
        self.eventMonitorInstaller = eventMonitorInstaller
    }

    /// 監視を開始する。二重呼び出しは無視される (冪等)。
    public func start(window: NSWindow) {
        guard !isRunning else { return }
        isRunning = true
        generation += 1

        // mouseMoved を monitor に届かせるためにウィンドウ側で受信を有効化する。
        // フルスクリーン窓は専用なので副作用は限定的。
        window.acceptsMouseMovedEvents = true

        eventMonitor = eventMonitorInstaller.installMouseMovementMonitor { [weak self] in
            self?.notifyMouseMoved()
        }

        scheduleIdleHide()
    }

    /// 監視を停止し、隠れていればカーソルを必ず再表示する。二重呼び出しは無視される (冪等)。
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        generation += 1

        if let monitor = eventMonitor {
            eventMonitorInstaller.removeMonitor(monitor)
            eventMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil

        if isHidden {
            cursorActuator.unhide()
            isHidden = false
        }
    }

    /// マウス移動通知。本番では イベント monitor から、テストでは直接呼ばれる。
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
        let scheduledGeneration = generation
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            // Timer のコールバックは main run loop から呼ばれるが、strict concurrency では
            // 明示的な MainActor 隔離が必要。
            Task { @MainActor [weak self] in
                self?.hideForIdle(ifGeneration: scheduledGeneration)
            }
        }
    }

    /// 世代が一致するときだけ hide する (テストから直接呼んで stale 世代の
    /// 無効化を決定的に検証できるよう internal)。
    func hideForIdle(ifGeneration scheduledGeneration: Int) {
        guard scheduledGeneration == generation, isRunning, !isHidden else { return }
        cursorActuator.hide()
        isHidden = true
    }

    /// 現在の世代トークン (テスト専用)。
    var generationForTesting: Int { generation }

    deinit {
        // caller 契約 (解放前に stop()) の違反を debug ビルドで検出する。
        // nonisolated deinit だが、解放中のインスタンスの stored property read は安全。
        assert(!isRunning, "FullscreenCursorVisibilityController: stop() を呼ばずに解放された (イベント監視が leak する)")
    }
}
