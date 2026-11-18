import AppKit
import SwiftUI

/// 主の操作とメニューを持つ分割ボタン (AppKit の `NSSegmentedControl` の 2 区画)。
///
/// - 主の区画 (アイコン + 名前): クリックで主の操作、押し続けるとメニュー (押したまま項目まで動かして離すと決まる)。
///   押し続けられることを示す小さな ▼ を、⌄ の側の上の角に描く
/// - ⌄ の区画: クリックでその下にメニュー。既定は右端 (`menuEdge: .trailing`)。`.leading` で左端に置く
///   (戻す・進めるのボタンを左右対称に並べるとき。区画の番号も左から ⌄・主の順になる。`SplitMenuSegments`)
/// - 右クリック (control-クリック) でも同じメニュー
///
/// `itemsPresenter:` を渡すと、⌄ のクリックと枠付きの主の区画の長押しで、標準のメニューの代わりに consumer の出すもの (ポップオーバーなど)
/// を開く (`StandardSplitMenuItemsPresenter`)。右クリックと枠なしの長押し (AppKit の `setMenu(_:forSegment:)`) は標準のメニューのまま
///
/// メニューは macOS の標準のもの (キーボード・VoiceOver が効く)。
///
/// ```swift
/// StandardSplitMenuButton("-1 Min", systemImage: "gobackward", items: [
///     .init("-30s") { seek(-30) },
///     .init("-3m") { seek(-180) }
/// ]) { seek(-60) }
/// .controlSize(.large)
/// ```
///
/// 大きさは `.controlSize(_:)`、押せるかは `.disabled(_:)` に従う。名前とメニューの文字は verbatim
/// (ローカライズが要るなら consumer が解決した文字を渡す)。
///
/// 見た目は既定で macOS 標準の描画 (macOS 26 以降は枠のない灰色の塗り。`segmentStyle` を変えても同じ)。consumer の自作の枠付きのボタンと
/// 並べるなら `border:` に `Border` を渡すと、枠・塗り・区画の間の縦線と中身 (アイコン・文字) を自分で描き、カーソルを乗せた区画と押している区画の
/// 塗りを変え (押している区画は中身を少し下げて凹んで見せる)、高さを揃える。
///
/// `items` が空なら区画 1 つの普通のボタン (メニュー・▼・⌄ なし) になる。同じ枠付きの見た目で、メニューを持たないボタンを並べるときに使う。
/// 名前が切り替わるボタン (Mute All / Unmute など) は `reservingWidthFor:` に切り替わる先を渡すと、切り替えても幅が変わらない (枠付きのときだけ)。
///
/// クリックでキーボードの入力先 (first responder) を取らない (`refusesFirstResponder`)。取ると、consumer が自前で受けている
/// 単キーのショートカットが止まる (`StandardGlassSegmentedPicker` と同じ理由)。
public struct StandardSplitMenuButton: NSViewRepresentable {
    /// メニューの 1 項目
    public struct Item {
        public let title: String
        /// 項目の先頭に出すアイコン (SF Symbols)。nil なら文字だけ
        public let systemImage: String?
        /// 項目の左に ✓ を付けるか (今の値など。標準メニューの状態 `.on`。`itemsPresenter` にもそのまま渡す)
        public let isChecked: Bool
        public let action: () -> Void

        public init(_ title: String, systemImage: String? = nil, isChecked: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.isChecked = isChecked
            self.action = action
        }
    }

    /// 主の区画を押し続けてメニューを出すまでの時間の既定 (旧 `LongPressMenuButton` と同じ)。`init(longPressDelay:)` で変える
    public static let defaultLongPressDelay: TimeInterval = 0.3

    /// ⌄ の区画を置く側
    public enum MenuEdge: Equatable, Sendable {
        case trailing
        case leading
    }

    private let title: String
    private let systemImage: String
    private let items: [Item]
    private let border: Border?
    private let widthAlternatives: [(title: String, systemImage: String)]
    private let menuEdge: MenuEdge
    private let makeItemsPresenter: (@MainActor () -> any StandardSplitMenuItemsPresenter)?
    private let longPressDelay: TimeInterval
    private let action: () -> Void

    /// - Parameters:
    ///   - title: 左の区画の名前
    ///   - systemImage: 左の区画のアイコン (SF Symbols)
    ///   - items: メニューの項目 (左の長押し・右の ⌄・右クリックで同じものを出す)
    ///   - border: 枠付きの見た目。nil なら macOS 標準の描画
    ///   - widthAlternatives: 切り替わる先の名前とアイコン。主の区画の幅をこれらと今の中身のいちばん広いものに揃える (枠付きのときだけ)
    ///   - menuEdge: ⌄ の区画を置く側 (既定は右)
    ///   - itemsPresenter: ⌄ のクリックと枠付きの主の区画の長押しで、標準のメニューの代わりに項目を出すものを作る。ボタンが画面に出たときに
    ///     1 度だけ呼ぶ (開いている状態をボタンが持ち続ける)。nil なら標準のメニュー
    ///   - longPressDelay: 主の区画を押し続けてメニューを出すまでの秒数 (枠付きのときだけ。枠なしは AppKit が決める)。
    ///     短くするほど、普通のクリックの押している間 (100ms 前後) が長押しに数えられやすくなる
    ///   - action: 主の区画のクリックで呼ぶ主の操作
    public init(
        _ title: String,
        systemImage: String,
        items: [Item],
        border: Border? = nil,
        reservingWidthFor widthAlternatives: [(title: String, systemImage: String)] = [],
        menuEdge: MenuEdge = .trailing,
        itemsPresenter makeItemsPresenter: (@MainActor () -> any StandardSplitMenuItemsPresenter)? = nil,
        longPressDelay: TimeInterval = StandardSplitMenuButton.defaultLongPressDelay,
        action: @escaping () -> Void
    ) {
        self.longPressDelay = longPressDelay
        self.title = title
        self.systemImage = systemImage
        self.items = items
        self.border = border
        self.widthAlternatives = widthAlternatives
        self.menuEdge = menuEdge
        self.makeItemsPresenter = makeItemsPresenter
        self.action = action
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 画面から外れたら (タブの切り替えなど) 開いているものを閉じる。残すと、外れたボタンの位置に浮いたままになる
    public static func dismantleNSView(_ control: NSSegmentedControl, coordinator: Coordinator) {
        coordinator.itemsPresenter?.close()
    }

    public func makeNSView(context: Context) -> NSSegmentedControl {
        let control = SplitMenuSegmentedControl()
        control.cell = LongPressHintSegmentedCell()
        control.trackingMode = .momentary
        control.refusesFirstResponder = true
        control.target = context.coordinator
        control.action = #selector(Coordinator.segmentClicked(_:))
        updateNSView(control, context: context)
        return control
    }

    public func updateNSView(_ control: NSSegmentedControl, context: Context) {
        let coordinator = context.coordinator
        coordinator.action = action
        coordinator.items = items
        coordinator.isEnabled = context.environment.isEnabled
        updateItemsPresenter(of: coordinator)
        let hasMenu = !items.isEmpty
        let segments = SplitMenuSegments(hasMenu: hasMenu, menuEdge: menuEdge)
        coordinator.segments = segments
        if let control = control as? SplitMenuSegmentedControl, control.menuEdge != menuEdge {
            control.menuEdge = menuEdge
        }
        setContents(of: control, segments: segments)
        control.controlSize = Self.nsControlSize(context.environment.controlSize)
        control.isEnabled = context.environment.isEnabled
        if let control = control as? SplitMenuSegmentedControl {
            if control.border != border { control.border = border }
            control.longPressDelay = longPressDelay
            control.connect(to: coordinator)
        }
        applyWidths(to: control, segments: segments)
        let menuKey = Coordinator.MenuKey(
            titles: items.map(\.title),
            systemImages: items.map(\.systemImage),
            checked: items.map(\.isChecked),
            isEnabled: coordinator.isEnabled
        )
        if coordinator.builtMenuKey != menuKey {
            coordinator.builtMenuKey = menuKey
            // 左: 操作とメニューの両方を持つ区画は、クリックで操作、押し続けるとメニュー (AppKit の `setMenu(_:forSegment:)`)。
            // 右: 区画にメニューを付けると、control に操作があるので長押しでしか開かない。クリックを受けて自分でメニューを開く
            for segment in 0 ..< control.segmentCount {
                control.setMenu(segment == segments.action && hasMenu ? coordinator.makeMenu() : nil, forSegment: segment)
                control.setShowsMenuIndicator(false, forSegment: segment)
            }
            // 右クリックのメニューは control が押せるかを見ずに開くので、押せない間は付けない (項目も `validateMenuItem` で無効にする)
            control.menu = hasMenu && coordinator.isEnabled ? coordinator.makeMenu() : nil
        }
    }

    /// `itemsPresenter` を初めて渡されたときに作り、外されたら閉じて捨てる。開いている間に項目が変わったら知らせ、
    /// 押せなくなったら閉じる (残すと、押しても何も起きない項目が並ぶ)
    private func updateItemsPresenter(of coordinator: Coordinator) {
        if let makeItemsPresenter {
            if coordinator.itemsPresenter == nil { coordinator.itemsPresenter = makeItemsPresenter() }
        } else if let presenter = coordinator.itemsPresenter {
            presenter.close()
            coordinator.itemsPresenter = nil
        }
        coordinator.itemsPresenter?.update(items: items)
        if !coordinator.isEnabled { coordinator.itemsPresenter?.close() }
    }

    /// 区画の数と中身 (主の区画の名前とアイコン、⌄ の区画の ⌄ と説明)。⌄ を置く側が変わっても前の中身を残さない
    private func setContents(of control: NSSegmentedControl, segments: SplitMenuSegments) {
        control.segmentCount = segments.count
        control.setLabel(title, forSegment: segments.action)
        control.setImage(NSImage(systemSymbolName: systemImage, accessibilityDescription: nil), forSegment: segments.action)
        control.setToolTip(nil, forSegment: segments.action)
        if let menuSegment = segments.menu {
            control.setLabel("", forSegment: menuSegment)
            control.setImage(
                NSImage(systemSymbolName: "chevron.down", accessibilityDescription: Self.moreOptionsLabel),
                forSegment: menuSegment
            )
            control.setToolTip(Self.moreOptionsLabel, forSegment: menuSegment)
        }
    }

    /// 区画の幅。中身が変わったときだけ当て直す (consumer の view は関係の無い状態の変化でも何度も更新される)
    private func applyWidths(to control: NSSegmentedControl, segments: SplitMenuSegments) {
        var widths = [CGFloat](repeating: 0, count: segments.count)
        if let border {
            widths[segments.action] = actionSegmentWidth(border: border, hasMenu: segments.menu != nil)
            if let menuSegment = segments.menu { widths[menuSegment] = border.menuSegmentWidth }
        } else if let menuSegment = segments.menu {
            widths[menuSegment] = Self.menuSegmentWidth(control.controlSize)
        }
        // 枠なしは名前とアイコンから AppKit が幅を決める (幅は 0 のまま) ので、名前が変わったときに大きさを取り直させるため毎回 invalidate する
        if border == nil || widths.indices.map({ control.width(forSegment: $0) }) != widths {
            for (segment, width) in widths.enumerated() {
                control.setWidth(width, forSegment: segment)
            }
            control.invalidateIntrinsicContentSize()
        }
    }

    /// 枠付きのときの主の区画の幅。今の中身と `widthAlternatives` のいちばん広いもの (切り替えても幅が変わらない)
    private func actionSegmentWidth(border: Border, hasMenu: Bool) -> CGFloat {
        let contents = [(title: title, systemImage: systemImage)] + widthAlternatives
        return contents.map { content in
            SplitMenuButtonLook.actionSegmentWidth(
                title: content.title,
                image: NSImage(systemSymbolName: content.systemImage, accessibilityDescription: nil),
                border: border,
                hasMenu: hasMenu
            )
        }.max() ?? 0
    }

    /// ⌄ が右 (既定) のときの区画の番号。⌄ を左に置くときは `SplitMenuSegments` で引く
    static let actionSegment = 0
    static let menuSegment = 1

    static var moreOptionsLabel: String {
        String(localized: "More Options", bundle: .module)
    }

    /// ⌄ の区画の幅
    static func menuSegmentWidth(_ size: NSControl.ControlSize) -> CGFloat {
        switch size {
        case .mini: 16
        case .small: 18
        case .large: 26
        case .extraLarge: 30
        default: 22
        }
    }

    static func nsControlSize(_ size: ControlSize) -> NSControl.ControlSize {
        switch size {
        case .mini: .mini
        case .small: .small
        case .large: .large
        case .extraLarge:
            // AppKit の extraLarge は macOS 26 から。それより前は large にする
            if #available(macOS 26.0, *) { .extraLarge } else { .large }
        default: .regular
        }
    }

    /// ⌄ の区画のクリックでメニューを開く位置 (control の座標)。x は `SplitMenuSegments.menuOriginX`
    static func menuOrigin(in control: NSSegmentedControl, segments: SplitMenuSegments) -> NSPoint {
        let menuWidth = segments.menu.map { control.width(forSegment: $0) } ?? 0
        let x = segments.menuOriginX(width: control.bounds.width, menuWidth: menuWidth)
        let y = control.isFlipped ? control.bounds.maxY + 4 : -4
        return NSPoint(x: x, y: y)
    }

    /// ⌄ の区画の範囲 (control の座標)。⌄ が無ければ control 全体
    static func menuSegmentRect(in control: NSSegmentedControl, segments: SplitMenuSegments) -> NSRect {
        guard let menuSegment = segments.menu else { return control.bounds }
        let frames = (control.cell as? LongPressHintSegmentedCell)?.segmentFrames(in: control.bounds, controlView: control)
            ?? segments.frames(in: control.bounds, menuWidth: control.width(forSegment: menuSegment))
        return frames.indices.contains(menuSegment) ? frames[menuSegment] : control.bounds
    }

    @MainActor
    public final class Coordinator: NSObject, NSMenuItemValidation {
        var action: () -> Void = {}
        var items: [Item] = []
        /// ⌄ のクリックと枠付きの長押しで、標準のメニューの代わりに項目を出すもの (`init(itemsPresenter:)`)。nil なら標準のメニュー
        var itemsPresenter: (any StandardSplitMenuItemsPresenter)?
        /// `.disabled` の間は操作もメニューの項目も呼ばない (メニューを開く経路は右クリック・VoiceOver など control の外にもある)
        var isEnabled = true
        /// 今付けているメニューの中身 (項目の名前と押せるか)。同じなら作り直さない (項目の操作は `items` を tag で引くので、名前が同じなら古いメニューのままでよい)
        struct MenuKey: Equatable {
            let titles: [String]
            let systemImages: [String?]
            let checked: [Bool]
            let isEnabled: Bool
        }

        var builtMenuKey: MenuKey?
        /// 区画の番号 (⌄ を置く側で変わる)
        var segments = SplitMenuSegments(hasMenu: true, menuEdge: .trailing)
        /// ⌄ の区画のクリックでメニューを開く。テストでは差し替える (`popUp` はメニューを閉じるまで戻らない)
        var presentMenu: (NSMenu, NSSegmentedControl) -> Void = { menu, control in
            let segments = (control as? SplitMenuSegmentedControl)?.segments ?? SplitMenuSegments(hasMenu: true, menuEdge: .trailing)
            menu.popUp(positioning: nil, at: StandardSplitMenuButton.menuOrigin(in: control, segments: segments), in: control)
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()
            for (index, item) in items.enumerated() {
                let menuItem = NSMenuItem(title: item.title, action: #selector(menuItemChosen(_:)), keyEquivalent: "")
                menuItem.image = item.systemImage.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
                menuItem.target = self
                menuItem.tag = index
                menuItem.state = item.isChecked ? .on : .off
                menu.addItem(menuItem)
            }
            return menu
        }

        @objc func segmentClicked(_ sender: NSSegmentedControl) {
            handleClick(segment: sender.selectedSegment, in: sender)
        }

        /// 押された区画に応じて主の操作を呼ぶか、メニューを開く (momentary の control は押していないと -1 を返す。そのときは何もしない)
        func handleClick(segment: Int, in control: NSSegmentedControl) {
            guard isEnabled else { return }
            if segment == segments.action {
                itemsPresenter?.willPerformPrimaryAction()
                action()
            } else if segment == segments.menu, !items.isEmpty {
                if itemsPresenter != nil {
                    presentItems(in: control)
                } else {
                    presentMenu(makeMenu(), control)
                }
            }
        }

        /// `itemsPresenter` に ⌄ の区画の上へ項目を出させる (開いていれば閉じる)。⌄ のクリックと、枠付きの主の区画の長押しが使う
        func presentItems(in control: NSSegmentedControl) {
            guard isEnabled, !items.isEmpty, let itemsPresenter else { return }
            let anchor = StandardSplitMenuButton.menuSegmentRect(in: control, segments: segments)
            itemsPresenter.toggle(items: items, relativeTo: anchor, of: control) { [weak self] index in
                self?.chooseItem(at: index)
            }
        }

        func chooseItem(at index: Int) {
            guard isEnabled, items.indices.contains(index) else { return }
            items[index].action()
        }

        public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            isEnabled
        }

        @objc func menuItemChosen(_ sender: NSMenuItem) {
            chooseItem(at: sender.tag)
        }
    }
}
