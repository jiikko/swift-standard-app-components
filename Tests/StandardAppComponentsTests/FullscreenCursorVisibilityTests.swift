import AppKit
@testable import StandardAppComponents
import XCTest

/// `FullscreenCursorVisibilityController` の振る舞いを検証する。
///
/// 不変条件:
/// - start() 後 idleTimeout 秒でカーソルを隠す
/// - notifyMouseMoved() でカーソルが復帰する
/// - stop() 時、隠れていたカーソルは必ず再表示される（hide/unhide の対称性）
/// - start/stop は冪等（イベント監視が二重登録・解除漏れしない）
/// - stop → start の再起動で旧セッションの idle 判定が持ち越されない（世代トークン）
@MainActor
final class FullscreenCursorVisibilityTests: XCTestCase {

    /// hide/unhide 呼び出しを記録する fake。NSCursor の副作用を避ける。
    final class FakeCursorActuator: CursorActuator {
        private(set) var hideCount = 0
        private(set) var unhideCount = 0
        var isHidden: Bool { hideCount > unhideCount }
        func hide() { hideCount += 1 }
        func unhide() { unhideCount += 1 }
    }

    /// 監視の登録/解除回数を記録する fake。AppKit の local monitor を避ける。
    @MainActor
    final class FakeEventMonitor: CursorEventMonitorInstalling {
        private(set) var installCount = 0
        private(set) var removeCount = 0
        private(set) var lastHandler: (() -> Void)?

        func installMouseMovementMonitor(handler: @escaping () -> Void) -> Any? {
            installCount += 1
            lastHandler = handler
            return installCount as Any
        }

        func removeMonitor(_ monitor: Any) {
            removeCount += 1
        }
    }

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    private func makeSUT(
        idleTimeout: TimeInterval = 1.0
    ) -> (FullscreenCursorVisibilityController, FakeCursorActuator, FakeEventMonitor) {
        let actuator = FakeCursorActuator()
        let monitor = FakeEventMonitor()
        let sut = FullscreenCursorVisibilityController(
            idleTimeout: idleTimeout,
            cursorActuator: actuator,
            eventMonitorInstaller: monitor
        )
        return (sut, actuator, monitor)
    }

    // MARK: - 開始時の挙動

    func test_start直後はカーソルを隠さない() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())

        XCTAssertEqual(actuator.hideCount, 0, "start 直後は hide が呼ばれない")
        XCTAssertEqual(actuator.unhideCount, 0)

        sut.stop()
    }

    func test_idle判定で1回だけhideされる() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())
        sut.hideForIdle(ifGeneration: sut.generationForTesting)
        sut.hideForIdle(ifGeneration: sut.generationForTesting)

        XCTAssertEqual(actuator.hideCount, 1, "idle 判定が重複しても hide は一度だけ")
        XCTAssertEqual(actuator.unhideCount, 0)

        sut.stop()
    }

    // MARK: - マウス移動

    func test_notifyMouseMoved_隠れていれば即座にunhideされる() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())
        sut.hideForIdle(ifGeneration: sut.generationForTesting)
        XCTAssertEqual(actuator.hideCount, 1, "前提: idle で hide 済み")

        sut.notifyMouseMoved()

        XCTAssertEqual(actuator.unhideCount, 1, "マウス移動で unhide される")
        XCTAssertFalse(actuator.isHidden)

        sut.stop()
    }

    func test_notifyMouseMoved_隠れていなければunhideは呼ばれない() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())
        sut.notifyMouseMoved()

        XCTAssertEqual(actuator.unhideCount, 0, "隠れていない状態での移動では unhide されない")

        sut.stop()
    }

    func test_monitorのhandler経由でもマウス移動が届く() {
        let (sut, actuator, monitor) = makeSUT()

        sut.start(window: makeWindow())
        sut.hideForIdle(ifGeneration: sut.generationForTesting)

        monitor.lastHandler?()

        XCTAssertEqual(actuator.unhideCount, 1, "monitor handler がマウス移動として配線されている")

        sut.stop()
    }

    // MARK: - stop() の対称性

    func test_stop_隠れていればunhideする() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())
        sut.hideForIdle(ifGeneration: sut.generationForTesting)
        XCTAssertEqual(actuator.hideCount, 1)

        sut.stop()

        XCTAssertEqual(
            actuator.hideCount,
            actuator.unhideCount,
            "stop 後は hide/unhide が対称（カーソル必ず復帰）"
        )
    }

    func test_stop_隠れていなければunhideしない() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())
        sut.stop()

        XCTAssertEqual(actuator.hideCount, 0)
        XCTAssertEqual(actuator.unhideCount, 0, "隠れていなければ余計な unhide を呼ばない")
    }

    func test_stop_未startでも安全() {
        let (sut, actuator, monitor) = makeSUT()

        sut.stop()

        XCTAssertEqual(actuator.hideCount, 0)
        XCTAssertEqual(actuator.unhideCount, 0)
        XCTAssertEqual(monitor.removeCount, 0, "未登録の監視を解除しない")
    }

    // MARK: - 冪等性 (監視の登録/解除回数で検証する)

    func test_start二重呼出しで監視が二重登録されない() {
        let (sut, _, monitor) = makeSUT()
        let window = makeWindow()

        sut.start(window: window)
        sut.start(window: window)

        XCTAssertEqual(monitor.installCount, 1, "二度目の start は監視を登録しない")

        sut.stop()
        XCTAssertEqual(monitor.removeCount, 1, "stop 1 回で監視が過不足なく解除される")
    }

    func test_stop二重呼出しで解除とunhideが重複しない() {
        let (sut, actuator, monitor) = makeSUT()

        sut.start(window: makeWindow())
        sut.hideForIdle(ifGeneration: sut.generationForTesting)

        sut.stop()
        sut.stop()

        XCTAssertEqual(monitor.removeCount, 1, "stop の二重呼び出しでも解除は 1 回のみ")
        XCTAssertEqual(actuator.unhideCount, 1, "stop の二重呼び出しでも unhide は 1 回のみ")
    }

    // MARK: - 再起動 (世代トークン)

    func test_再起動後は旧セッションのidle判定が無効化される() {
        let (sut, actuator, _) = makeSUT()
        let window = makeWindow()

        sut.start(window: window)
        let staleGeneration = sut.generationForTesting

        // Timer 発火 → Task hop の間に stop → start (再起動) が入った状況を再現する。
        sut.stop()
        sut.start(window: window)

        sut.hideForIdle(ifGeneration: staleGeneration)
        XCTAssertEqual(actuator.hideCount, 0, "旧世代の idle 判定は新セッションでカーソルを隠さない")

        sut.hideForIdle(ifGeneration: sut.generationForTesting)
        XCTAssertEqual(actuator.hideCount, 1, "現行世代の idle 判定は通常どおり効く")

        sut.stop()
    }

    func test_stop後のstaleなidle判定は何もしない() {
        let (sut, actuator, _) = makeSUT()

        sut.start(window: makeWindow())
        let staleGeneration = sut.generationForTesting
        sut.stop()

        sut.hideForIdle(ifGeneration: staleGeneration)

        XCTAssertEqual(actuator.hideCount, 0, "停止後に旧世代の idle 判定が発火しても隠さない")
    }

    // MARK: - 停止後 / 開始前の入力

    func test_stop後にmonitorのhandlerが残発火しても何もしない() {
        let (sut, actuator, monitor) = makeSUT()

        sut.start(window: makeWindow())
        sut.hideForIdle(ifGeneration: sut.generationForTesting)
        sut.stop()

        monitor.lastHandler?()

        XCTAssertEqual(actuator.hideCount, actuator.unhideCount, "停止後の残発火で対称性が崩れない")
        XCTAssertEqual(actuator.unhideCount, 1, "停止後の残発火で追加の unhide が走らない")
    }

    func test_start前のnotifyMouseMovedは何もしない() {
        let (sut, actuator, _) = makeSUT()

        sut.notifyMouseMoved()

        XCTAssertEqual(actuator.hideCount, 0)
        XCTAssertEqual(actuator.unhideCount, 0)
    }

    // MARK: - 実時間経路 (Timer -> Task hop の配線を 1 本だけ実測する)

    func test_実時間でidleTimeout経過後にhideされる() {
        let (sut, actuator, _) = makeSUT(idleTimeout: 0.05)

        sut.start(window: makeWindow())

        // 固定待ちではなく polling で待つ (負荷時の flake 回避)。
        let exp = expectation(description: "idle hide")
        let deadline = Date().addingTimeInterval(2.0)
        func poll() {
            if actuator.hideCount >= 1 || Date() > deadline {
                exp.fulfill()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { MainActor.assumeIsolated { poll() } }
        }
        poll()
        wait(for: [exp], timeout: 3.0)

        XCTAssertEqual(actuator.hideCount, 1, "Timer -> Task hop 経由で hide が届く")

        sut.stop()
    }

    // MARK: - ウィンドウへの副作用

    func test_start_acceptsMouseMovedEventsを有効化する() {
        let (sut, _, _) = makeSUT()
        let window = makeWindow()
        XCTAssertFalse(window.acceptsMouseMovedEvents, "前提: デフォルトは false")

        sut.start(window: window)

        XCTAssertTrue(window.acceptsMouseMovedEvents, "mouseMoved を受け取れるようにする")

        sut.stop()
    }
}
