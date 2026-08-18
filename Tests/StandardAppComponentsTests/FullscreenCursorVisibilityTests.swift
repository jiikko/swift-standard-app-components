import AppKit
@testable import StandardAppComponents
import XCTest

/// `FullscreenCursorVisibilityController` の振る舞いを検証する。
///
/// 不変条件:
/// - start() 後 idleTimeout 秒でカーソルを隠す
/// - notifyMouseMoved() でカーソルが復帰する
/// - stop() 時、隠れていたカーソルは必ず再表示される（hide/unhide の対称性）
/// - start/stop は冪等
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

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    // MARK: - 開始時の挙動

    func test_start直後はカーソルを隠さない() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 0.05, cursorActuator: actuator)

        sut.start(window: makeWindow())

        // タイマー発火前
        XCTAssertEqual(actuator.hideCount, 0, "start 直後は hide が呼ばれない")
        XCTAssertEqual(actuator.unhideCount, 0)

        sut.stop()
    }

    func test_start後idleTimeout経過で1回だけhideされる() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 0.05, cursorActuator: actuator)

        sut.start(window: makeWindow())

        let exp = expectation(description: "idle hide")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(actuator.hideCount, 1, "idleTimeout 後に hide が一度だけ呼ばれる")
        XCTAssertEqual(actuator.unhideCount, 0)

        sut.stop()
    }

    // MARK: - マウス移動

    func test_notifyMouseMoved_隠れていれば即座にunhideされる() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 0.05, cursorActuator: actuator)

        sut.start(window: makeWindow())

        let exp = expectation(description: "idle hide")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(actuator.hideCount, 1, "前提: idle で hide 済み")

        sut.notifyMouseMoved()

        XCTAssertEqual(actuator.unhideCount, 1, "マウス移動で unhide される")
        XCTAssertFalse(actuator.isHidden)

        sut.stop()
    }

    func test_notifyMouseMoved_隠れていなければunhideは呼ばれない() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 1.0, cursorActuator: actuator)

        sut.start(window: makeWindow())

        // hide 前にマウスが動いた状況
        sut.notifyMouseMoved()

        XCTAssertEqual(actuator.unhideCount, 0, "隠れていない状態での移動では unhide されない")

        sut.stop()
    }

    // MARK: - stop() の対称性

    func test_stop_隠れていればunhideする() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 0.05, cursorActuator: actuator)

        sut.start(window: makeWindow())

        let exp = expectation(description: "idle hide")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(actuator.hideCount, 1)

        sut.stop()

        XCTAssertEqual(
            actuator.hideCount,
            actuator.unhideCount,
            "stop 後は hide/unhide が対称（カーソル必ず復帰）"
        )
    }

    func test_stop_隠れていなければunhideしない() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 1.0, cursorActuator: actuator)

        sut.start(window: makeWindow())
        sut.stop()

        XCTAssertEqual(actuator.hideCount, 0)
        XCTAssertEqual(actuator.unhideCount, 0, "隠れていなければ余計な unhide を呼ばない")
    }

    func test_stop_未startでも安全() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 0.05, cursorActuator: actuator)

        // start を呼ばずに stop（クラッシュしない）
        sut.stop()

        XCTAssertEqual(actuator.hideCount, 0)
        XCTAssertEqual(actuator.unhideCount, 0)
    }

    // MARK: - 冪等性

    func test_start二重呼出しは無視される() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 1.0, cursorActuator: actuator)
        let window = makeWindow()

        sut.start(window: window)
        sut.start(window: window)  // 二度目は無視される（イベントモニタが二重登録されない）

        sut.stop()
        // 検証はクラッシュしないことと、stop 1回で hide/unhide が対称になること
        XCTAssertEqual(actuator.hideCount, actuator.unhideCount)
    }

    func test_stop二重呼出しは無視される() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 0.05, cursorActuator: actuator)

        sut.start(window: makeWindow())

        let exp = expectation(description: "idle hide")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        sut.stop()
        sut.stop()  // 二度目は no-op（unhide が二重に呼ばれない）

        XCTAssertEqual(actuator.unhideCount, 1, "stop の二重呼び出しでも unhide は1回のみ")
    }

    // MARK: - ウィンドウへの副作用

    func test_start_acceptsMouseMovedEventsを有効化する() {
        let actuator = FakeCursorActuator()
        let sut = FullscreenCursorVisibilityController(idleTimeout: 1.0, cursorActuator: actuator)
        let window = makeWindow()
        XCTAssertFalse(window.acceptsMouseMovedEvents, "前提: デフォルトは false")

        sut.start(window: window)

        XCTAssertTrue(window.acceptsMouseMovedEvents, "mouseMoved を受け取れるようにする")

        sut.stop()
    }
}
