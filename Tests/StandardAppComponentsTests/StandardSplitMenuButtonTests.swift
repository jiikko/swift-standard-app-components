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

    func test_disabledなら操作もメニューの項目も呼ばない() throws {
        let log = Log()
        let control = try makeButton(log: log, disabled: true)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var presented = 0
        coordinator.presentMenu = { _, _ in presented += 1 }

        XCTAssertFalse(control.isEnabled)
        XCTAssertNil(control.menu, "右クリックのメニューは control が押せるかを見ずに開くので、押せない間は付けない")

        let segmentMenu = try XCTUnwrap(control.menu(forSegment: StandardSplitMenuButton.actionSegment))
        let item = try XCTUnwrap(segmentMenu.items.first)
        XCTAssertFalse(coordinator.validateMenuItem(item), "どの経路で開いても項目は無効")
        coordinator.menuItemChosen(item)
        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)
        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)
        XCTAssertEqual(log.calls, [])
        XCTAssertEqual(presented, 0)
    }

    func test_押せる_押せないを行き来すると右クリックのメニューと操作が付いてくる() throws {
        let log = Log()
        func view(disabled: Bool) -> some View {
            StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
                .init("-30s") { log.calls.append("-30s") }
            ]) { log.calls.append("primary") }
                .disabled(disabled)
        }
        let host = NSHostingView(rootView: view(disabled: false))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        let control = try XCTUnwrap(segmentedControl(in: host))
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        XCTAssertNotNil(control.menu)

        host.rootView = view(disabled: true)
        host.layoutSubtreeIfNeeded()
        XCTAssertNil(control.menu, "押せなくなったら右クリックのメニューを外す")
        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)
        XCTAssertEqual(log.calls, [], "押せなくなった後は操作を呼ばない")

        host.rootView = view(disabled: false)
        host.layoutSubtreeIfNeeded()
        XCTAssertNotNil(control.menu, "押せるようになったら右クリックのメニューが戻る")
        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)
        XCTAssertEqual(log.calls, ["primary"])
    }

    func test_右の区画のメニューは右の区画の左端の下に開く() throws {
        let control = try makeButton(log: Log())
        control.frame = NSRect(x: 0, y: 0, width: 150, height: 30)
        let origin = StandardSplitMenuButton.menuOrigin(in: control)
        XCTAssertEqual(origin.x, 150 - 26 - 4, accuracy: 0.5)
        XCTAssertEqual(origin.y, control.isFlipped ? 34 : -4, accuracy: 0.5)
    }

    // MARK: - 枠付きの見た目

    private let border = StandardSplitMenuButton.Border(
        fill: .white, hoveredFill: .lightGray, pressedFill: .gray,
        stroke: .black, hoveredStroke: .blue, divider: .red, height: 30
    )

    func test_枠を渡すと高さを揃え_渡さなければ標準の描画のまま() throws {
        let plain = try XCTUnwrap(makeButton(log: Log()) as? SplitMenuSegmentedControl)
        XCTAssertNil(plain.border)
        XCTAssertNotEqual(plain.intrinsicContentSize.height, 30, "標準の描画の高さは controlSize で決まる (この前提が崩れたら下の検査が空振りする)")

        let view = StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [], border: border) {}
            .controlSize(.large)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let bordered = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        XCTAssertEqual(bordered.border, border)
        XCTAssertEqual(bordered.intrinsicContentSize.height, 30)
    }

    func test_塗りは押している区画_カーソルを乗せた区画_地の順() {
        XCTAssertEqual(SplitMenuButtonLook.segmentFill(0, hovered: 0, pressed: 0, border: border), .gray)
        XCTAssertEqual(SplitMenuButtonLook.segmentFill(0, hovered: 0, pressed: nil, border: border), .lightGray)
        XCTAssertNil(SplitMenuButtonLook.segmentFill(1, hovered: 0, pressed: nil, border: border), "カーソルが乗っていない区画は地の塗り")
        XCTAssertNil(SplitMenuButtonLook.segmentFill(1, hovered: 1, pressed: 0, border: border), "押している間は他の区画を強調しない")
        XCTAssertEqual(SplitMenuButtonLook.stroke(hovered: nil, pressed: nil, border: border), .black)
        XCTAssertEqual(SplitMenuButtonLook.stroke(hovered: 1, pressed: nil, border: border), .blue)
        XCTAssertEqual(SplitMenuButtonLook.stroke(hovered: nil, pressed: 0, border: border), .blue)
    }

    func test_カーソルの位置から乗っている区画を決め_外へ出る_押せない_枠を外すと消す() throws {
        let control = SplitMenuSegmentedControl()
        control.segmentCount = 2
        control.setWidth(26, forSegment: StandardSplitMenuButton.menuSegment)
        control.frame = NSRect(x: 0, y: 0, width: 150, height: 30)
        control.border = border

        XCTAssertEqual(control.segment(atX: 130), StandardSplitMenuButton.menuSegment)
        XCTAssertEqual(control.segment(atX: 100), StandardSplitMenuButton.actionSegment)
        control.updateHover(locationInWindow: NSPoint(x: 100, y: 15))
        XCTAssertEqual(control.hoveredSegment, StandardSplitMenuButton.actionSegment)
        control.updateHover(locationInWindow: NSPoint(x: 140, y: 15))
        XCTAssertEqual(control.hoveredSegment, StandardSplitMenuButton.menuSegment)
        control.updateHover(locationInWindow: NSPoint(x: 400, y: 15))
        XCTAssertNil(control.hoveredSegment, "外へ出たら消す")

        control.updateHover(locationInWindow: NSPoint(x: 100, y: 15))
        control.isEnabled = false
        control.updateHover(locationInWindow: NSPoint(x: 100, y: 15))
        XCTAssertNil(control.hoveredSegment, "押せない間は強調しない")

        control.isEnabled = true
        control.updateHover(locationInWindow: NSPoint(x: 100, y: 15))
        control.border = nil
        XCTAssertNil(control.hoveredSegment, "枠を外したら強調も消す")
    }

    private func hostedControl<V: View>(_ view: V) throws -> SplitMenuSegmentedControl {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        return try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
    }

    func test_項目が空なら区画1つの普通のボタンでメニューを持たない() throws {
        let log = Log()
        let control = try hostedControl(
            StandardSplitMenuButton("Mute All", systemImage: "speaker.wave.2.fill", items: [], border: border) {
                log.calls.append("primary")
            }
        )
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var presented = 0
        coordinator.presentMenu = { _, _ in presented += 1 }

        XCTAssertEqual(control.segmentCount, 1)
        XCTAssertNil(control.menu(forSegment: StandardSplitMenuButton.actionSegment), "長押しのメニューも無い")
        XCTAssertNil(control.menu, "右クリックのメニューも無い")
        XCTAssertEqual(control.segment(atX: control.bounds.width - 1), StandardSplitMenuButton.actionSegment, "右端も左の区画")
        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)
        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)
        XCTAssertEqual(log.calls, ["primary"])
        XCTAssertEqual(presented, 0)
    }

    func test_名前が切り替わっても幅を揃える() throws {
        let alternatives: [(title: String, systemImage: String)] = [
            (title: "Mute All", systemImage: "speaker.wave.2.fill"),
            (title: "Unmute", systemImage: "speaker.slash.fill")
        ]
        let muted = try hostedControl(StandardSplitMenuButton(
            "Unmute", systemImage: "speaker.slash.fill", items: [], border: border, reservingWidthFor: alternatives
        ) {})
        let unmuted = try hostedControl(StandardSplitMenuButton(
            "Mute All", systemImage: "speaker.wave.2.fill", items: [], border: border, reservingWidthFor: alternatives
        ) {})
        let plainShort = try hostedControl(StandardSplitMenuButton(
            "Unmute", systemImage: "speaker.slash.fill", items: [], border: border
        ) {})
        let plainLong = try hostedControl(StandardSplitMenuButton(
            "Mute All", systemImage: "speaker.wave.2.fill", items: [], border: border
        ) {})
        XCTAssertNotEqual(plainShort.width(forSegment: 0), plainLong.width(forSegment: 0), "揃えなければ幅が違う (前提)")
        XCTAssertEqual(muted.width(forSegment: 0), unmuted.width(forSegment: 0))
        XCTAssertEqual(muted.width(forSegment: 0), max(plainShort.width(forSegment: 0), plainLong.width(forSegment: 0)))
    }

    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = segmentedControl(in: subview) { return found }
        }
        return nil
    }
}
