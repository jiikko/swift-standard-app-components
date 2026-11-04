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
        let origin = StandardSplitMenuButton.menuOrigin(in: control, segments: SplitMenuSegments(hasMenu: true, menuEdge: .trailing))
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
        XCTAssertNotNil(control.hoveredSegment)
        control.isEnabled = false
        XCTAssertNil(control.hoveredSegment, "乗せたまま押せなくなったら、乗せた見た目を消す")

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

    /// ⌄ を左に置く (戻すボタンを左右対称に並べる)。区画の番号は左から ⌄・主になり、クリックの振り分け・当たり判定・長押しのメニューが付く区画が入れ替わる
    func test_menuEdgeがleadingなら左の区画がメニューで右の区画が主の操作() throws {
        let log = Log()
        let control = try hostedControl(
            StandardSplitMenuButton("-1m", systemImage: "gobackward", items: [
                .init("-30s") { log.calls.append("-30s") }
            ], border: border, menuEdge: .leading) { log.calls.append("primary") }
        )
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var presented = 0
        coordinator.presentMenu = { _, _ in presented += 1 }
        control.frame = NSRect(x: 0, y: 0, width: 150, height: 30)

        XCTAssertEqual(control.segmentCount, 2)
        XCTAssertEqual(control.label(forSegment: 1), "-1m", "主の区画は右 (番号 1)")
        XCTAssertEqual(control.width(forSegment: 0), border.menuSegmentWidth, "⌄ の区画は左 (番号 0)")
        XCTAssertNotNil(control.menu(forSegment: 1), "長押しのメニューは主の区画に付く")
        XCTAssertNil(control.menu(forSegment: 0))
        XCTAssertEqual(control.segment(atX: 5), 0, "左端は ⌄")
        XCTAssertEqual(control.segment(atX: 140), 1, "右端は主")

        coordinator.handleClick(segment: 1, in: control)
        XCTAssertEqual(log.calls, ["primary"])
        XCTAssertEqual(presented, 0)
        coordinator.handleClick(segment: 0, in: control)
        XCTAssertEqual(presented, 1, "左の ⌄ でメニュー")
        XCTAssertEqual(log.calls, ["primary"])
    }

    func test_区画の並びはメニューを置く側とメニューの有無で決まる() {
        let trailing = SplitMenuSegments(hasMenu: true, menuEdge: .trailing)
        XCTAssertEqual([trailing.action, trailing.menu], [0, 1])
        let leading = SplitMenuSegments(hasMenu: true, menuEdge: .leading)
        XCTAssertEqual([leading.action, leading.menu], [1, 0])
        let single = SplitMenuSegments(hasMenu: false, menuEdge: .leading)
        XCTAssertEqual([single.action, single.menu], [0, nil], "メニューが無ければ区画 1 つ")

        let rect = NSRect(x: 0, y: 0, width: 100, height: 30)
        XCTAssertEqual(leading.frames(in: rect, menuWidth: 26).map(\.width), [26, 74], "⌄ を左に置くと左の区画が ⌄ の幅")
        XCTAssertEqual(trailing.frames(in: rect, menuWidth: 26).map(\.width), [74, 26])
        XCTAssertEqual(leading.menuOriginX(width: 100, menuWidth: 26), 0, "⌄ が左ならボタンの左端の下に開く")
        XCTAssertEqual(trailing.menuOriginX(width: 100, menuWidth: 26), 70)
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

    func test_枠付きの左の区画は_離せば主の操作_外で離せば取り消し_押し続ければメニュー() {
        let withMenu = SplitMenuPressTracker(hasMenu: true)
        let delay = SplitMenuPressTracker.longPressDelay
        XCTAssertEqual(withMenu.outcome(elapsed: 0.1, release: .inside, isOver: true), .primary)
        XCTAssertEqual(withMenu.outcome(elapsed: 0.1, release: .outside, isOver: false), .cancel)
        XCTAssertEqual(withMenu.outcome(elapsed: 0.1, release: .notYet, isOver: true), .pending)
        XCTAssertEqual(withMenu.outcome(elapsed: delay, release: .notYet, isOver: true), .menu)
        XCTAssertEqual(withMenu.outcome(elapsed: delay, release: .notYet, isOver: false), .pending, "外へ出している間はメニューを開かない")
        let withoutMenu = SplitMenuPressTracker(hasMenu: false)
        XCTAssertEqual(withoutMenu.outcome(elapsed: 5, release: .notYet, isOver: true), .pending, "メニューの無いボタンは押し続けても離すまで待つ")
        XCTAssertEqual(withoutMenu.outcome(elapsed: 5, release: .inside, isOver: true), .primary)
    }

    func test_枠付きのときcontrolが自分で追う操作とメニューをcoordinatorに配線する() throws {
        let log = Log()
        func view(disabled: Bool, items: [StandardSplitMenuButton.Item]) -> some View {
            StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: items, border: border) {
                log.calls.append("primary")
            }
                .disabled(disabled)
        }
        let items: [StandardSplitMenuButton.Item] = [.init("-30s") { log.calls.append("-30s") }]
        let host = NSHostingView(rootView: view(disabled: false, items: items))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)

        control.primaryAction?()
        XCTAssertEqual(log.calls, ["primary"])
        XCTAssertEqual(control.menuProvider?()?.items.map(\.title), ["-30s"])

        host.rootView = view(disabled: true, items: items)
        host.layoutSubtreeIfNeeded()
        control.primaryAction?()
        XCTAssertEqual(log.calls, ["primary"], "押せない間は主の操作を呼ばない")
        XCTAssertNil(control.menuProvider?() ?? nil, "押せない間はメニューを開かない")

        host.rootView = view(disabled: false, items: [])
        host.layoutSubtreeIfNeeded()
        XCTAssertNil(control.menuProvider?() ?? nil, "項目が無ければメニューを開かない")
    }

    func test_項目のアイコンをメニューの先頭に出し_変えたら作り直す() throws {
        func view(icon: String?) -> some View {
            StandardSplitMenuButton("Play All", systemImage: "play.fill", items: [
                .init("Pause All", systemImage: icon) {},
                .init("Sync Start") {}
            ]) {}
        }
        let host = NSHostingView(rootView: view(icon: "pause.fill"))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(segmentedControl(in: host))
        let menu = try XCTUnwrap(control.menu(forSegment: StandardSplitMenuButton.actionSegment))
        XCTAssertNotNil(menu.items[0].image)
        XCTAssertNil(menu.items[1].image, "アイコンを渡さない項目は文字だけ")

        host.rootView = view(icon: nil)
        host.layoutSubtreeIfNeeded()
        XCTAssertNil(control.menu(forSegment: StandardSplitMenuButton.actionSegment)?.items[0].image, "アイコンを外したら作り直す")
    }

    // MARK: - ⌄ のクリックでポップオーバー (`ChevronPresentation.popover`)

    private func makePopoverButton(log: Log, border: StandardSplitMenuButton.Border? = nil) throws -> NSSegmentedControl {
        let view = StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
            .init("-30s") { log.calls.append("-30s") },
            .init("-3m", isChecked: true) { log.calls.append("-3m") }
        ], border: border, chevronPresentation: .popover) { log.calls.append("primary") }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        return try XCTUnwrap(segmentedControl(in: host))
    }

    func test_popoverなら右の区画のクリックはメニューでなく右の区画の上にポップオーバーを開く() throws {
        let log = Log()
        let control = try makePopoverButton(log: log)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var menus = 0
        coordinator.presentMenu = { _, _ in menus += 1 }
        var presented: [(NSPopover, NSRect)] = []
        coordinator.popoverPresenter.present = { popover, rect, _ in presented.append((popover, rect)) }

        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)

        XCTAssertEqual(menus, 0, "標準のメニューは開かない")
        XCTAssertEqual(presented.count, 1)
        let (popover, rect) = try XCTUnwrap(presented.first)
        XCTAssertEqual(popover.behavior, .transient, "外のクリックで閉じる")
        XCTAssertTrue(popover.contentViewController is NSHostingController<StandardPopoverMenu>, "中身は項目のリスト")
        let menuWidth = control.width(forSegment: StandardSplitMenuButton.menuSegment)
        XCTAssertEqual(rect.maxX, control.bounds.maxX, accuracy: 1, "矢印は ⌄ の区画 (右端) に向ける")
        XCTAssertEqual(rect.width, menuWidth, accuracy: 1)
        XCTAssertEqual(log.calls, [], "開くだけでは何も呼ばない")

        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)
        XCTAssertEqual(log.calls, ["primary"], "左の区画は今までどおり主の操作")
    }

    func test_popoverでも長押しと右クリックは標準のメニューのまま() throws {
        let control = try makePopoverButton(log: Log())
        XCTAssertEqual(control.menu(forSegment: StandardSplitMenuButton.actionSegment)?.items.map(\.title), ["-30s", "-3m"])
        XCTAssertEqual(control.menu?.items.map(\.title), ["-30s", "-3m"])
    }

    func test_枠付きでpopoverならcontrolの右の区画の押下をポップオーバーへ_menuなら配線しない() throws {
        let log = Log()
        let control = try XCTUnwrap(makePopoverButton(log: log, border: border) as? SplitMenuSegmentedControl)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var presented = 0
        coordinator.popoverPresenter.present = { _, _, _ in presented += 1 }
        let chevronAction = try XCTUnwrap(control.chevronAction, "popover なら ⌄ の押下を coordinator へ")
        chevronAction()
        XCTAssertEqual(presented, 1)

        let menuControl = try XCTUnwrap(makeBorderedMenuButton() as? SplitMenuSegmentedControl)
        XCTAssertNil(menuControl.chevronAction, "menu なら control がメニューを開く")
    }

    private func makeBorderedMenuButton() throws -> NSSegmentedControl {
        let host = NSHostingView(rootView: StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [.init("-30s") {}], border: border) {})
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        return try XCTUnwrap(segmentedControl(in: host))
    }

    func test_前のポップオーバーの閉じた知らせで今のポップオーバーを見失わない() throws {
        let control = try makePopoverButton(log: Log())
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        let presenter = coordinator.popoverPresenter
        presenter.present = { _, _, _ in }
        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)
        let first = try XCTUnwrap(presenter.popover)
        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)
        let second = try XCTUnwrap(presenter.popover)
        XCTAssertFalse(first === second)

        presenter.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: first))
        XCTAssertTrue(presenter.popover === second, "閉じたのは前のもの")
        presenter.popoverDidClose(Notification(name: NSPopover.didCloseNotification, object: second))
        XCTAssertNil(presenter.popover)
    }

    func test_ポップオーバーの項目を選ぶとその操作を呼び_押せない間は呼ばない() throws {
        let log = Log()
        let control = try makePopoverButton(log: log)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        coordinator.chooseItem(at: 1)
        XCTAssertEqual(log.calls, ["-3m"])
        coordinator.chooseItem(at: 5)
        XCTAssertEqual(log.calls, ["-3m"], "範囲の外は何もしない")
        coordinator.isEnabled = false
        coordinator.chooseItem(at: 0)
        XCTAssertEqual(log.calls, ["-3m"], "押せない間は呼ばない")
    }

    func test_isCheckedの項目は標準のメニューで状態がon_変えたら作り直す() throws {
        func view(checked: Bool) -> some View {
            StandardSplitMenuButton("Speed", systemImage: "gauge.with.dots.needle.33percent", items: [
                .init("1.00x", isChecked: checked) {},
                .init("1.50x") {}
            ]) {}
        }
        let host = NSHostingView(rootView: view(checked: true))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(segmentedControl(in: host))
        XCTAssertEqual(control.menu?.items.map(\.state), [.on, .off])

        host.rootView = view(checked: false)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(control.menu?.items.map(\.state), [.off, .off], "✓ を外したら作り直す")
    }

    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = segmentedControl(in: subview) { return found }
        }
        return nil
    }
}
