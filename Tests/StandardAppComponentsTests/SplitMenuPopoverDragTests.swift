import AppKit
@testable import StandardAppComponents
import SwiftUI
import XCTest

/// ポップオーバーを開いたボタンを押したまま項目まで動かして離すと選ぶ (`ChevronPresentation.popover`。2026-11-05 ユーザー指示)。
/// 本物のポップオーバーの位置は画面に出さないと決まらないので、画面の座標からポップオーバーの中身の座標への変換
/// (`SplitMenuPopoverPresenter.locateInContent`) はそのまま返す形に差し替え、行の範囲もその座標で置く
@MainActor
final class SplitMenuPopoverDragTests: XCTestCase {
    private final class Log {
        var calls: [String] = []
    }

    private let border = StandardSplitMenuButton.Border(
        fill: .white, hoveredFill: .lightGray, pressedFill: .gray,
        stroke: .black, hoveredStroke: .blue, divider: .red, height: 30
    )
    private var retained: [AnyObject] = []

    override func tearDown() {
        retained.removeAll()
        super.tearDown()
    }

    /// 行 0 は y 0..20、行 1 は y 20..40 (中身の座標 = 差し替えた変換では画面の座標と同じ)
    private let rowFrames: [Int: CGRect] = [0: CGRect(x: 0, y: 0, width: 100, height: 20), 1: CGRect(x: 0, y: 20, width: 100, height: 20)]

    private func makeControl(log: Log, in window: NSWindow? = nil) throws -> (SplitMenuSegmentedControl, StandardSplitMenuButton.Coordinator) {
        let view = StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
            .init("-30s") { log.calls.append("-30s") },
            .init("-3m") { log.calls.append("-3m") }
        ], border: border, chevronPresentation: .popover) { log.calls.append("primary") }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        window?.contentView = host
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        let presenter = coordinator.popoverPresenter
        presenter.present = { [rowFrames, weak presenter] _, _, _ in presenter?.drag?.rowFrames = rowFrames }
        presenter.locateInContent = { _, point in CGPoint(x: point.x, y: point.y) }
        return (control, coordinator)
    }

    func test_押したまま動かすとカーソルの下の行を塗り_行の上で離すとその項目を選ぶ() throws {
        let log = Log()
        let (control, coordinator) = try makeControl(log: log)
        let presenter = coordinator.popoverPresenter
        coordinator.presentItemsPopover(in: control)
        let drag = try XCTUnwrap(presenter.drag)

        presenter.dragMoved(toScreen: NSPoint(x: 10, y: 30))
        XCTAssertTrue(drag.isTracking)
        XCTAssertEqual(drag.highlighted, 1)
        presenter.dragMoved(toScreen: NSPoint(x: 10, y: 80))
        XCTAssertNil(drag.highlighted, "行の外は塗らない")
        XCTAssertEqual(log.calls, [], "動かすだけでは選ばない")

        presenter.dragEnded(atScreen: NSPoint(x: 10, y: 5))
        XCTAssertEqual(log.calls, ["-30s"])
        XCTAssertFalse(drag.isTracking, "離したらカーソルを乗せたかで塗る")
    }

    func test_行の外で離すと何も選ばず開いたまま_続けてクリックで選べる() throws {
        let log = Log()
        let (control, coordinator) = try makeControl(log: log)
        let presenter = coordinator.popoverPresenter
        coordinator.presentItemsPopover(in: control)

        presenter.dragEnded(atScreen: NSPoint(x: 10, y: 80))
        XCTAssertEqual(log.calls, [])
        XCTAssertNotNil(presenter.popover, "閉じない")
        XCTAssertNotNil(presenter.drag)
    }

    func test_閉じ始めたポップオーバーの上で離しても選ばない() throws {
        let log = Log()
        let (control, coordinator) = try makeControl(log: log)
        let presenter = coordinator.popoverPresenter
        coordinator.presentItemsPopover(in: control)
        let popover = try XCTUnwrap(presenter.popover)

        presenter.popoverWillClose(Notification(name: NSPopover.willCloseNotification, object: popover))
        presenter.dragEnded(atScreen: NSPoint(x: 10, y: 30))
        XCTAssertEqual(log.calls, [])
    }

    func test_枠付きのpopoverなら押下の追跡をポップオーバーへ配線し_menuなら配線しない() throws {
        let (control, _) = try makeControl(log: Log())
        XCTAssertNotNil(control.popoverDragMoved)
        XCTAssertNotNil(control.popoverDragEnded)

        let host = NSHostingView(rootView: StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [.init("-30s") {}], border: border) {})
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let menuControl = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        XCTAssertNil(menuControl.popoverDragMoved, "menu なら標準のメニューが押下を追う")
        XCTAssertNil(menuControl.popoverDragEnded)
    }

    /// ⌄ を押してポップオーバーを開いた押下を、control が離すまで追い、動かしたイベントと離したイベントをポップオーバーへ渡す
    /// (イベントはウィンドウに先に積む)。作ったイベントの位置は窓の高さの分ずれて届くので、ここでは位置を見ず、
    /// どの位置も項目 1 の上と答える変換に差し替える (位置の変換は本物のポップオーバーでしか確かめられない)
    func test_右の区画を押したまま動かして離すと_controlが離すまで追ってポップオーバーで選ぶ() throws {
        let log = Log()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        retained.append(window)
        let (control, coordinator) = try makeControl(log: log, in: window)
        var received: [NSPoint] = []
        coordinator.popoverPresenter.locateInContent = { _, point in
            received.append(point)
            return CGPoint(x: 10, y: 30)
        }
        let inWindow = control.convert(NSPoint(x: control.bounds.maxX - 4, y: control.bounds.midY), to: nil)
        window.postEvent(try mouseEvent(.leftMouseDragged, at: inWindow, in: window), atStart: false)
        window.postEvent(try mouseEvent(.leftMouseUp, at: inWindow, in: window), atStart: false)

        control.mouseDown(with: try mouseEvent(.leftMouseDown, at: inWindow, in: window))

        XCTAssertEqual(received.count, 2, "動かしたイベントと離したイベントの両方を渡す")
        XCTAssertEqual(log.calls, ["-3m"], "離した位置の項目を選ぶ")
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }

    /// 行の位置は `StandardPopoverMenu.coordinateSpaceName` (中身の左上が原点) で測り、上から順に並ぶ
    func test_ポップオーバーの中身は行の範囲を中身の左上を原点に測る() throws {
        let drag = StandardPopoverMenuDrag()
        let host = NSHostingView(rootView: StandardPopoverMenu(items: [.init("-30s") {}, .init("-3m") {}], drag: drag) { _ in })
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        retained.append(host)

        let first = try XCTUnwrap(drag.rowFrames[0])
        let second = try XCTUnwrap(drag.rowFrames[1])
        XCTAssertEqual(first.minY, 6, accuracy: 1, "上の余白 (padding 6) の下から")
        XCTAssertEqual(second.minY, first.maxY, accuracy: 1, "行 1 は行 0 の下")
        XCTAssertLessThanOrEqual(second.maxY, host.bounds.height)
        XCTAssertEqual(drag.row(at: CGPoint(x: second.midX, y: second.midY)), 1)
    }

    /// 本物のポップオーバーを画面に出して行 1 を塗り、中身を画像にして塗られた帯 (描かれた本物の位置) を探す。
    /// 帯の真ん中と上下の端の近くを、画面の座標から `locateInContent` と `rowFrames` で引くと行 1 になる
    /// (ポップオーバーの中身の原点と行を測る原点がずれていれば、端で隣の行になる。2026-11-05 の red team の P2-1)
    func test_本物のポップオーバーで画面の位置から引いた行が_その位置に描かれた行と一致する() throws {
        let window = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 300, height: 60), styleMask: [.titled], backing: .buffered, defer: false)
        retained.append(window)
        let view = StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
            .init("-30s") {}, .init("-3m") {}, .init("-5m") {}
        ], border: border, chevronPresentation: .popover) {}
        let host = NSHostingView(rootView: view)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.orderFront(nil)
        let control = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        let presenter = coordinator.popoverPresenter
        coordinator.presentItemsPopover(in: control)
        let popover = try XCTUnwrap(presenter.popover)
        defer {
            popover.close()
            window.orderOut(nil)
        }
        let drag = try XCTUnwrap(presenter.drag)
        drag.isTracking = true
        drag.highlighted = 1
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
        XCTAssertTrue(popover.isShown)
        let content = try XCTUnwrap(popover.contentViewController?.view)
        let contentWindow = try XCTUnwrap(content.window)

        let band = try XCTUnwrap(highlightedBand(in: content), "塗った行が描かれている")
        for y in [band.midY, band.minY + 2, band.maxY - 2] {
            let inWindow = content.convert(NSPoint(x: band.midX, y: y), to: nil)
            let inScreen = contentWindow.convertPoint(toScreen: inWindow)
            let point = try XCTUnwrap(presenter.locateInContent(popover, inScreen))
            XCTAssertEqual(drag.row(at: point), 1, "view の y=\(y)")
        }
    }

    /// 選択の色で塗られた横の帯 (view の座標)。左右の真ん中の列を上から下へ見て、青の強い画素が続く範囲
    private func highlightedBand(in view: NSView) -> NSRect? {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsHigh) / view.bounds.height
        let column = bitmap.pixelsWide / 2
        let blue = (0..<bitmap.pixelsHigh).filter { row in
            guard let color = bitmap.colorAt(x: column, y: row)?.usingColorSpace(.sRGB) else { return false }
            return color.blueComponent - color.redComponent > 0.3
        }
        guard let top = blue.min(), let bottom = blue.max() else { return nil }
        // bitmap の行 0 は上端。view が flipped でなければ y を下から数える
        let minY = CGFloat(top) / scale
        let maxY = CGFloat(bottom + 1) / scale
        let frame = view.isFlipped
            ? NSRect(x: 0, y: minY, width: view.bounds.width, height: maxY - minY)
            : NSRect(x: 0, y: view.bounds.height - maxY, width: view.bounds.width, height: maxY - minY)
        return frame
    }

    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = segmentedControl(in: subview) { return found }
        }
        return nil
    }
}
