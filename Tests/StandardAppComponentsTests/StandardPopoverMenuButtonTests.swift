import AppKit
@testable import StandardAppComponents
import SwiftUI
import XCTest

/// `StandardPopoverMenuButton`: 押した時点で上にポップオーバーを開き、押したまま項目まで動かして離すと選ぶ。
/// ポップオーバーは画面に出さず (`present` を差し替え)、位置の変換 (`locateInContent`) はどの位置も項目 1 の上と答える形に差し替える
/// (本物のポップオーバーでの位置の一致は `SplitMenuPopoverDragTests` が確かめる。作ったイベントの位置は窓の高さの分ずれて届く)
@MainActor
final class StandardPopoverMenuButtonTests: XCTestCase {
    private final class Log {
        var calls: [String] = []
    }

    private var retained: [AnyObject] = []

    override func tearDown() {
        retained.removeAll()
        super.tearDown()
    }

    private func makeButton(log: Log, highlighted: @escaping (Bool) -> Void = { _ in }, disabled: Bool = false) throws
        -> (NSWindow, PopoverMenuPressView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        retained.append(window)
        let view = StandardPopoverMenuButton(items: [
            .init("1.00x") { log.calls.append("1.00x") },
            .init("1.50x") { log.calls.append("1.50x") }
        ]) { isHighlighted in
            Text(verbatim: "1.50x").frame(width: 80, height: 30)
                .onChange(of: isHighlighted, initial: true) { _, value in highlighted(value) }
        }
        .disabled(disabled)
        let host = NSHostingView(rootView: view)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let pressView = try XCTUnwrap(find(PopoverMenuPressView.self, in: host))
        pressView.presenter.present = { [weak pressView] _, _, _ in
            pressView?.presenter.drag?.rowFrames = [0: CGRect(x: 0, y: 0, width: 100, height: 20), 1: CGRect(x: 0, y: 20, width: 100, height: 20)]
        }
        pressView.presenter.locateInContent = { _, _ in CGPoint(x: 10, y: 30) }
        return (window, pressView)
    }

    func test_押した時点で開き_押したまま動かして離すと離した位置の項目を選ぶ() throws {
        let log = Log()
        let (window, pressView) = try makeButton(log: log)
        var presentedCount = 0
        let present = pressView.presenter.present
        pressView.presenter.present = { popover, rect, view in
            presentedCount += 1
            present(popover, rect, view)
        }
        let inWindow = pressView.convert(NSPoint(x: pressView.bounds.midX, y: pressView.bounds.midY), to: nil)
        window.postEvent(try mouseEvent(.leftMouseDragged, at: inWindow, in: window), atStart: false)
        window.postEvent(try mouseEvent(.leftMouseUp, at: inWindow, in: window), atStart: false)

        pressView.mouseDown(with: try mouseEvent(.leftMouseDown, at: inWindow, in: window))

        XCTAssertEqual(presentedCount, 1, "押した時点で開く")
        XCTAssertEqual(log.calls, ["1.50x"])
    }

    func test_押せない間は押しても開かない() throws {
        let log = Log()
        let (window, pressView) = try makeButton(log: log, disabled: true)
        var presentedCount = 0
        pressView.presenter.present = { _, _, _ in presentedCount += 1 }
        let inWindow = pressView.convert(NSPoint(x: pressView.bounds.midX, y: pressView.bounds.midY), to: nil)
        // 退行して開いてしまうと離すまで追うので、離したイベントを先に積んでおく (積まないと退行で止まったまま戻らない)
        window.postEvent(try mouseEvent(.leftMouseUp, at: inWindow, in: window), atStart: false)

        pressView.mouseDown(with: try mouseEvent(.leftMouseDown, at: inWindow, in: window))

        XCTAssertEqual(presentedCount, 0)
        XCTAssertNil(pressView.presenter.popover)
    }

    func test_開いている間は中身に塗るよう伝え_閉じたら戻す() throws {
        var highlights: [Bool] = []
        let (_, pressView) = try makeButton(log: Log(), highlighted: { highlights.append($0) })
        let presenter = pressView.presenter
        presenter.present = { _, _, _ in }

        presenter.toggle(items: [.init("1.00x") {}], relativeTo: pressView.bounds, of: pressView) { _ in }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(highlights.last, true, "開いている間は塗る")

        let popover = try XCTUnwrap(presenter.popover)
        presenter.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: popover))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(highlights.last, false, "閉じたら戻す")
    }

    func test_分割ボタンの長押しの時間は渡した値をcontrolへ渡す() throws {
        let border = StandardSplitMenuButton.Border(
            fill: .white, hoveredFill: .lightGray, pressedFill: .gray,
            stroke: .black, hoveredStroke: .blue, divider: .red, height: 30
        )
        let host = NSHostingView(rootView: StandardSplitMenuButton(
            "-1m", systemImage: "gobackward", items: [.init("-30s") {}], border: border, longPressDelay: 0.1
        ) {})
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(find(SplitMenuSegmentedControl.self, in: host))
        XCTAssertEqual(control.longPressDelay, 0.1)
    }

    func test_開いている間に項目が変わったら_中身を描き直す() throws {
        let (_, pressView) = try makeButton(log: Log())
        let presenter = pressView.presenter
        presenter.present = { _, _, _ in }
        pressView.items = [.init("1.00x", isChecked: true) {}, .init("1.50x") {}]
        presenter.toggle(items: pressView.items, relativeTo: pressView.bounds, of: pressView) { _ in }

        pressView.items = [.init("1.00x") {}, .init("1.50x", isChecked: true) {}]

        let hosting = try XCTUnwrap(presenter.popover?.contentViewController as? NSHostingController<StandardPopoverMenu>)
        XCTAssertEqual(hosting.rootView.items.map(\.isChecked), [false, true], "今の倍率に ✓ を付け直す")
    }

    /// 枠付きの分割ボタンの主の区画を押し、0.2 秒後に離す。渡した長押しの時間 (0.1 秒) で判定し、離す前にリストを開く
    /// (既定の 0.3 秒のままなら、離した時点で主の操作になる)。離すイベントは追跡のループの中で流す
    func test_分割ボタンの主の区画は_渡した長押しの時間で判定する() throws {
        let log = Log()
        let border = StandardSplitMenuButton.Border(
            fill: .white, hoveredFill: .lightGray, pressedFill: .gray,
            stroke: .black, hoveredStroke: .blue, divider: .red, height: 30
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        retained.append(window)
        let host = NSHostingView(rootView: StandardSplitMenuButton(
            "-1m", systemImage: "gobackward", items: [.init("-30s") { log.calls.append("-30s") }],
            border: border, chevronPresentation: .popover, longPressDelay: 0.1
        ) { log.calls.append("primary") })
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let control = try XCTUnwrap(find(SplitMenuSegmentedControl.self, in: host))
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var presented = 0
        coordinator.popoverPresenter.present = { _, _, _ in presented += 1 }
        let inWindow = control.convert(NSPoint(x: 10, y: control.bounds.midY), to: nil)
        let release = try mouseEvent(.leftMouseUp, at: inWindow, in: window)
        let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
            MainActor.assumeIsolated { window.postEvent(release, atStart: false) }
        }
        RunLoop.current.add(timer, forMode: .eventTracking)

        control.mouseDown(with: try mouseEvent(.leftMouseDown, at: inWindow, in: window))

        XCTAssertEqual(presented, 1, "0.1 秒で長押しになり、リストを開く")
        XCTAssertEqual(log.calls, [], "主の操作は呼ばない")
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }

    private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let found = view as? T { return found }
        for subview in view.subviews {
            if let found = find(type, in: subview) { return found }
        }
        return nil
    }
}
