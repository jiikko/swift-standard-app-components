import AppKit
@testable import StandardAppComponents
import SwiftUI
import XCTest

/// 分割ボタンの配線: 左のクリックで主の操作、右のクリックでメニュー、メニューの項目、押せない状態、入力先を取らないこと。
/// 長押しでメニューが出ることは AppKit (`setMenu(_:forSegment:)`) の挙動で、ここでは左の区画にメニューが付いていることまでを見る
@MainActor
final class StandardSplitMenuButtonTests: XCTestCase {
    private final class Log {
        var calls: [String] = []
    }

    private func makeButton(log: Log, disabled: Bool = false) throws -> NSSegmentedControl {
        let view = StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
            .init("-30s") { log.calls.append("-30s") },
            .init("-3m") { log.calls.append("-3m") }
        ]) { log.calls.append("primary") }
            .controlSize(.large)
            .disabled(disabled)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        let control = try XCTUnwrap(segmentedControl(in: host))
        retained.append(host)
        return control
    }

    private var retained: [NSView] = []

    override func tearDown() {
        retained.removeAll()
        super.tearDown()
    }

    func test_左の区画のクリックは主の操作だけを呼び_右の区画のクリックはメニューを開く() throws {
        let log = Log()
        let control = try makeButton(log: log)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var presented: [[String]] = []
        coordinator.presentMenu = { menu, _ in presented.append(menu.items.map(\.title)) }

        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)
        XCTAssertEqual(log.calls, ["primary"])
        XCTAssertEqual(presented, [])

        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)
        XCTAssertEqual(log.calls, ["primary"], "右の区画は主の操作を呼ばない")
        XCTAssertEqual(presented, [["-30s", "-3m"]])

        coordinator.handleClick(segment: -1, in: control)
        XCTAssertEqual(log.calls, ["primary"], "押していない (-1) ときは何もしない")
        XCTAssertEqual(presented.count, 1)

        // 配線: control の操作が coordinator の segmentClicked に向いている
        XCTAssertEqual(control.action, #selector(StandardSplitMenuButton.Coordinator.segmentClicked(_:)))
    }

    func test_左の区画と右クリックに同じメニューを付け_項目を選ぶとその操作を呼ぶ() throws {
        let log = Log()
        let control = try makeButton(log: log)

        let segmentMenu = try XCTUnwrap(control.menu(forSegment: StandardSplitMenuButton.actionSegment),
                                        "左の区画のメニュー (長押しで出る)")
        XCTAssertEqual(segmentMenu.items.map(\.title), ["-30s", "-3m"])
        XCTAssertNil(control.menu(forSegment: StandardSplitMenuButton.menuSegment),
                     "右の区画にメニューを付けると長押しでしか開かないので付けない")
        XCTAssertEqual(control.menu?.items.map(\.title), ["-30s", "-3m"], "右クリックのメニュー")

        segmentMenu.performActionForItem(at: 1)
        XCTAssertEqual(log.calls, ["-3m"])
    }

    func test_見た目と入力先の設定() throws {
        let control = try makeButton(log: Log())
        XCTAssertEqual(control.segmentCount, 2)
        XCTAssertEqual(control.label(forSegment: StandardSplitMenuButton.actionSegment), "-1 Min")
        XCTAssertTrue(control.cell is LongPressHintSegmentedCell, "左の区画に ▼ を描く cell")
        XCTAssertTrue(control.refusesFirstResponder, "クリックで入力先を取らない (consumer の単キーのショートカットを止めない)")
        XCTAssertEqual(control.controlSize, .large)
        XCTAssertEqual(control.width(forSegment: StandardSplitMenuButton.menuSegment), 26)
        XCTAssertTrue(control.isEnabled)
    }

    func test_disabledなら押せない() throws {
        let control = try makeButton(log: Log(), disabled: true)
        XCTAssertFalse(control.isEnabled)
    }

    func test_右の区画のメニューは右の区画の左端の下に開く() throws {
        let control = try makeButton(log: Log())
        control.frame = NSRect(x: 0, y: 0, width: 150, height: 30)
        let origin = StandardSplitMenuButton.menuOrigin(in: control)
        XCTAssertEqual(origin.x, 150 - 26 - 4, accuracy: 0.5)
        XCTAssertEqual(origin.y, control.isFlipped ? 34 : -4, accuracy: 0.5)
    }

    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = segmentedControl(in: subview) { return found }
        }
        return nil
    }
}
