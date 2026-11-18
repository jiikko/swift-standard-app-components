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
        let delay = StandardSplitMenuButton.defaultLongPressDelay
        let withMenu = SplitMenuPressTracker(hasMenu: true, longPressDelay: delay)
        XCTAssertEqual(withMenu.outcome(elapsed: 0.1, release: .inside, isOver: true), .primary)
        XCTAssertEqual(withMenu.outcome(elapsed: 0.1, release: .outside, isOver: false), .cancel)
        XCTAssertEqual(withMenu.outcome(elapsed: 0.1, release: .notYet, isOver: true), .pending)
        XCTAssertEqual(withMenu.outcome(elapsed: delay, release: .notYet, isOver: true), .menu)
        XCTAssertEqual(withMenu.outcome(elapsed: delay, release: .notYet, isOver: false), .pending, "外へ出している間はメニューを開かない")
        let short = SplitMenuPressTracker(hasMenu: true, longPressDelay: 0.1)
        XCTAssertEqual(short.outcome(elapsed: 0.1, release: .notYet, isOver: true), .menu, "渡した時間で長押しになる")
        XCTAssertEqual(short.outcome(elapsed: 0.09, release: .notYet, isOver: true), .pending)
        let withoutMenu = SplitMenuPressTracker(hasMenu: false, longPressDelay: delay)
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

    // MARK: - ⌄ のクリックと長押しで consumer が出すもの (`itemsPresenter`)

    /// 分割ボタンが presenter に何を頼んだかを記録する。順序を見るために、主の操作の直前の知らせは `log` にも書く
    @MainActor
    private final class SpyItemsPresenter: StandardSplitMenuItemsPresenter {
        let log: Log
        var toggles: [NSRect] = []
        var closes = 0
        var updatedItems: [String] = []
        var choose: ((Int) -> Void)?
        var moved: [NSPoint] = []
        var ended: [NSPoint] = []

        init(log: Log) {
            self.log = log
        }

        func toggle(items: [StandardSplitMenuButton.Item], relativeTo anchor: NSRect, of view: NSView, choose: @escaping (Int) -> Void) {
            toggles.append(anchor)
            self.choose = choose
        }

        func update(items: [StandardSplitMenuButton.Item]) {
            updatedItems = items.map(\.title)
        }

        func pressMoved(toScreen point: NSPoint) {
            moved.append(point)
        }

        func pressEnded(atScreen point: NSPoint) {
            ended.append(point)
        }

        func willPerformPrimaryAction() {
            log.calls.append("willPerformPrimaryAction")
        }

        func close() {
            closes += 1
        }
    }

    private func presenterButton(
        log: Log, presenter: SpyItemsPresenter, border: StandardSplitMenuButton.Border? = nil, longPressDelay: TimeInterval = 0.3
    ) -> some View {
        StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
            .init("-30s") { log.calls.append("-30s") },
            .init("-3m", isChecked: true) { log.calls.append("-3m") }
        ], border: border, itemsPresenter: { presenter }, longPressDelay: longPressDelay) { log.calls.append("primary") }
    }

    private func makePresenterButton(log: Log, presenter: SpyItemsPresenter, border: StandardSplitMenuButton.Border? = nil) throws
        -> NSSegmentedControl {
        let host = NSHostingView(rootView: presenterButton(log: log, presenter: presenter, border: border))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        return try XCTUnwrap(segmentedControl(in: host))
    }

    func test_itemsPresenterなら右の区画のクリックはメニューでなく右の区画の範囲でpresenterに出させ_選んだ項目を呼ぶ() throws {
        let log = Log()
        let presenter = SpyItemsPresenter(log: log)
        let control = try makePresenterButton(log: log, presenter: presenter)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        var menus = 0
        coordinator.presentMenu = { _, _ in menus += 1 }

        coordinator.handleClick(segment: StandardSplitMenuButton.menuSegment, in: control)

        XCTAssertEqual(menus, 0, "標準のメニューは開かない")
        let anchor = try XCTUnwrap(presenter.toggles.first)
        XCTAssertEqual(presenter.toggles.count, 1)
        XCTAssertEqual(anchor.maxX, control.bounds.maxX, accuracy: 1, "⌄ の区画 (右端) に出させる")
        XCTAssertEqual(anchor.width, control.width(forSegment: StandardSplitMenuButton.menuSegment), accuracy: 1)
        XCTAssertEqual(log.calls, [], "開くだけでは何も呼ばない")

        try XCTUnwrap(presenter.choose)(1)
        XCTAssertEqual(log.calls, ["-3m"], "選んだ番号の項目を呼ぶ")
    }

    /// 主の操作の直前に presenter へ知らせる (開いているリストを閉じさせるため。2026-11-18 vlc-multi-video-player のユーザー指示:
    /// 長押しで開いた後に -1m / +1m を 1 回押したら閉じる)
    func test_主の区画のクリックは主の操作の直前にpresenterへ知らせる() throws {
        let log = Log()
        let presenter = SpyItemsPresenter(log: log)
        let control = try makePresenterButton(log: log, presenter: presenter)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)

        coordinator.handleClick(segment: StandardSplitMenuButton.actionSegment, in: control)

        XCTAssertEqual(log.calls, ["willPerformPrimaryAction", "primary"])
        XCTAssertEqual(presenter.toggles.count, 0, "主の区画は出させない")
    }

    func test_枠なしのitemsPresenterでは長押しと右クリックは標準のメニューのまま() throws {
        let control = try makePresenterButton(log: Log(), presenter: SpyItemsPresenter(log: Log()))
        XCTAssertEqual(control.menu(forSegment: StandardSplitMenuButton.actionSegment)?.items.map(\.title), ["-30s", "-3m"])
        XCTAssertEqual(control.menu?.items.map(\.title), ["-30s", "-3m"])
    }

    func test_枠付きでitemsPresenterなら右の区画の押下と主の区画の長押しをpresenterへ_無ければ配線しない() throws {
        let log = Log()
        let presenter = SpyItemsPresenter(log: log)
        let control = try XCTUnwrap(makePresenterButton(log: log, presenter: presenter, border: border) as? SplitMenuSegmentedControl)
        var menus = 0
        try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator).presentMenu = { _, _ in menus += 1 }

        try XCTUnwrap(control.chevronAction, "⌄ の押下を presenter へ")()
        try XCTUnwrap(control.longPressAction, "長押しも presenter へ")()

        XCTAssertEqual(menus, 0, "標準のメニューは開かない")
        XCTAssertEqual(presenter.toggles.count, 2)
        XCTAssertEqual(try XCTUnwrap(presenter.toggles.last).maxX, control.bounds.maxX, accuracy: 1, "長押しも ⌄ の区画に出させる")
        XCTAssertEqual(log.calls, [], "開くだけでは主の操作を呼ばない")
        XCTAssertNotNil(control.itemsPressMoved)
        XCTAssertNotNil(control.itemsPressEnded)

        let host = NSHostingView(rootView: StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [.init("-30s") {}], border: border) {})
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let menuControl = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        XCTAssertNil(menuControl.chevronAction, "presenter が無ければ control がメニューを開く")
        XCTAssertNil(menuControl.longPressAction)
        XCTAssertNil(menuControl.itemsPressMoved)
        XCTAssertNil(menuControl.itemsPressEnded)
    }

    func test_presenterは1度だけ作り_項目の変化を知らせ_押せなくなったら閉じ_外したら閉じて捨てる() throws {
        let log = Log()
        let presenter = SpyItemsPresenter(log: log)
        var made = 0
        let makePresenter: @MainActor () -> any StandardSplitMenuItemsPresenter = {
            made += 1
            return presenter
        }
        func view(items: [String], disabled: Bool = false, withPresenter: Bool = true) -> some View {
            let menuItems: [StandardSplitMenuButton.Item] = items.map { title in StandardSplitMenuButton.Item(title) {} }
            return StandardSplitMenuButton(
                "-1 Min", systemImage: "gobackward", items: menuItems, itemsPresenter: withPresenter ? makePresenter : nil
            ) {}
                .disabled(disabled)
        }
        let host = NSHostingView(rootView: AnyView(view(items: ["-30s"])))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(segmentedControl(in: host))
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)

        host.rootView = AnyView(view(items: ["-30s", "-3m"]))
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(made, 1, "描き直しでは作り直さない (開いている状態を失う)")
        XCTAssertEqual(presenter.updatedItems, ["-30s", "-3m"])
        XCTAssertEqual(presenter.closes, 0)

        host.rootView = AnyView(view(items: ["-30s", "-3m"], disabled: true))
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(presenter.closes, 0, "押せなくなったら閉じる")

        let closesBeforeRemoval = presenter.closes
        host.rootView = AnyView(view(items: ["-30s", "-3m"], withPresenter: false))
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(presenter.closes, closesBeforeRemoval + 1, "外したら閉じる")
        XCTAssertNil(coordinator.itemsPresenter)
    }

    func test_画面から外れたら開いているものを閉じる() throws {
        let presenter = SpyItemsPresenter(log: Log())
        let control = try makePresenterButton(log: Log(), presenter: presenter)
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        StandardSplitMenuButton.dismantleNSView(control, coordinator: coordinator)
        XCTAssertEqual(presenter.closes, 1)
    }

    func test_項目を選ぶとその操作を呼び_押せない間は呼ばない() throws {
        let log = Log()
        let control = try makePresenterButton(log: log, presenter: SpyItemsPresenter(log: log))
        let coordinator = try XCTUnwrap(control.target as? StandardSplitMenuButton.Coordinator)
        coordinator.chooseItem(at: 1)
        XCTAssertEqual(log.calls, ["-3m"])
        coordinator.chooseItem(at: 5)
        XCTAssertEqual(log.calls, ["-3m"], "範囲の外は何もしない")
        coordinator.isEnabled = false
        coordinator.chooseItem(at: 0)
        XCTAssertEqual(log.calls, ["-3m"], "押せない間は呼ばない")
    }

    /// ⌄ を押して出させた押下を、control が離すまで追い、動かしたイベントと離したイベントの位置を presenter へ渡す (イベントはウィンドウに先に積む)
    func test_右の区画を押したまま動かして離すと_controlが離すまで追ってpresenterへ位置を渡す() throws {
        let log = Log()
        let presenter = SpyItemsPresenter(log: log)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        retainedWindows.append(window)
        let host = NSHostingView(rootView: presenterButton(log: log, presenter: presenter, border: border))
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let control = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        let inWindow = control.convert(NSPoint(x: control.bounds.maxX - 4, y: control.bounds.midY), to: nil)
        window.postEvent(try mouseEvent(.leftMouseDragged, at: inWindow, in: window), atStart: false)
        window.postEvent(try mouseEvent(.leftMouseUp, at: inWindow, in: window), atStart: false)

        control.mouseDown(with: try mouseEvent(.leftMouseDown, at: inWindow, in: window))

        XCTAssertEqual(presenter.toggles.count, 1, "押した時点で出させる")
        XCTAssertEqual(presenter.moved.count, 1, "動かしたイベントを渡す")
        XCTAssertEqual(presenter.ended.count, 1, "離したイベントを渡す")
        XCTAssertEqual(log.calls, [])
    }

    func test_長押しの時間は渡した値をcontrolへ渡す() throws {
        let host = NSHostingView(rootView: StandardSplitMenuButton(
            "-1m", systemImage: "gobackward", items: [.init("-30s") {}], border: border, longPressDelay: 0.1
        ) {})
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 60)
        host.layoutSubtreeIfNeeded()
        retained.append(host)
        let control = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        XCTAssertEqual(control.longPressDelay, 0.1)
    }

    /// 枠付きの主の区画を押し、0.2 秒後に離す。渡した長押しの時間 (0.1 秒) で判定し、離す前に presenter に出させる
    /// (既定の 0.3 秒のままなら、離した時点で主の操作になる)。離すイベントは追跡のループの中で流す
    func test_主の区画は_渡した長押しの時間で判定する() throws {
        let log = Log()
        let presenter = SpyItemsPresenter(log: log)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        retainedWindows.append(window)
        let host = NSHostingView(rootView: presenterButton(log: log, presenter: presenter, border: border, longPressDelay: 0.1))
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let control = try XCTUnwrap(segmentedControl(in: host) as? SplitMenuSegmentedControl)
        let inWindow = control.convert(NSPoint(x: 10, y: control.bounds.midY), to: nil)
        let release = try mouseEvent(.leftMouseUp, at: inWindow, in: window)
        let timer = Timer(timeInterval: 0.2, repeats: false) { _ in
            MainActor.assumeIsolated { window.postEvent(release, atStart: false) }
        }
        RunLoop.current.add(timer, forMode: .eventTracking)

        control.mouseDown(with: try mouseEvent(.leftMouseDown, at: inWindow, in: window))

        XCTAssertEqual(presenter.toggles.count, 1, "0.1 秒で長押しになり、presenter に出させる")
        XCTAssertEqual(presenter.ended.count, 1, "長押しで出させた押下も離すまで追い、離した位置を渡す (押したまま項目まで動かして選べる)")
        XCTAssertEqual(log.calls, [], "主の操作は呼ばない")
    }

    private var retainedWindows: [NSWindow] = []

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
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
