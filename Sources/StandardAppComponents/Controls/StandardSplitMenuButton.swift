import AppKit
import SwiftUI

/// 主の操作とメニューを持つ分割ボタン (AppKit の `NSSegmentedControl` の 2 区画)。
///
/// - 左の区画 (アイコン + 名前): クリックで主の操作、押し続けるとメニュー (押したまま項目まで動かして離すと決まる)。
///   押し続けられることを示す小さな ▼ を右上に描く
/// - 右の区画 (⌄): クリックでその下にメニュー
/// - 右クリック (control-クリック) でも同じメニュー
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
        public let action: () -> Void

        public init(_ title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }
    }

    /// 枠付きの見た目 (`border:` に渡す)。色は consumer の他のボタンと同じものを渡す
    public struct Border: Equatable {
        public var fill: NSColor
        public var hoveredFill: NSColor
        public var pressedFill: NSColor
        public var stroke: NSColor
        public var hoveredStroke: NSColor
        public var divider: NSColor
        public var cornerRadius: CGFloat
        /// 高さ (標準の描画の高さは `controlSize` で決まり、他のボタンと揃わないことがある)
        public var height: CGFloat
        /// 押せない間の不透明度
        public var disabledOpacity: CGFloat
        /// アイコン・文字・⌄ の色
        public var foreground: NSColor
        public var font: NSFont
        public var iconPointSize: CGFloat
        public var iconSpacing: CGFloat
        /// 左の区画の中身の左右の余白
        public var horizontalPadding: CGFloat
        /// 右の区画 (⌄) の幅
        public var menuSegmentWidth: CGFloat

        public init(
            fill: NSColor,
            hoveredFill: NSColor,
            pressedFill: NSColor,
            stroke: NSColor,
            hoveredStroke: NSColor,
            divider: NSColor,
            foreground: NSColor = .secondaryLabelColor,
            font: NSFont = .systemFont(ofSize: 13),
            iconPointSize: CGFloat = 14,
            iconSpacing: CGFloat = 8,
            horizontalPadding: CGFloat = 16,
            menuSegmentWidth: CGFloat = 28,
            cornerRadius: CGFloat = 6,
            height: CGFloat = 30,
            disabledOpacity: CGFloat = 0.4
        ) {
            self.fill = fill
            self.hoveredFill = hoveredFill
            self.pressedFill = pressedFill
            self.stroke = stroke
            self.hoveredStroke = hoveredStroke
            self.divider = divider
            self.foreground = foreground
            self.font = font
            self.iconPointSize = iconPointSize
            self.iconSpacing = iconSpacing
            self.horizontalPadding = horizontalPadding
            self.menuSegmentWidth = menuSegmentWidth
            self.cornerRadius = cornerRadius
            self.height = height
            self.disabledOpacity = disabledOpacity
        }
    }

    private let title: String
    private let systemImage: String
    private let items: [Item]
    private let border: Border?
    private let widthAlternatives: [(title: String, systemImage: String)]
    private let action: () -> Void

    /// - Parameters:
    ///   - title: 左の区画の名前
    ///   - systemImage: 左の区画のアイコン (SF Symbols)
    ///   - items: メニューの項目 (左の長押し・右の ⌄・右クリックで同じものを出す)
    ///   - border: 枠付きの見た目。nil なら macOS 標準の描画
    ///   - widthAlternatives: 切り替わる先の名前とアイコン。左の区画の幅をこれらと今の中身のいちばん広いものに揃える (枠付きのときだけ)
    ///   - action: 左の区画のクリックで呼ぶ主の操作
    public init(
        _ title: String,
        systemImage: String,
        items: [Item],
        border: Border? = nil,
        reservingWidthFor widthAlternatives: [(title: String, systemImage: String)] = [],
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.items = items
        self.border = border
        self.widthAlternatives = widthAlternatives
        self.action = action
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
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
        let hasMenu = !items.isEmpty
        control.segmentCount = hasMenu ? 2 : 1
        control.setLabel(title, forSegment: Self.actionSegment)
        control.setImage(NSImage(systemSymbolName: systemImage, accessibilityDescription: nil), forSegment: Self.actionSegment)
        if hasMenu {
            control.setImage(
                NSImage(systemSymbolName: "chevron.down", accessibilityDescription: Self.moreOptionsLabel),
                forSegment: Self.menuSegment
            )
            control.setToolTip(Self.moreOptionsLabel, forSegment: Self.menuSegment)
        }
        control.controlSize = Self.nsControlSize(context.environment.controlSize)
        control.isEnabled = context.environment.isEnabled
        if let control = control as? SplitMenuSegmentedControl, control.border != border {
            control.border = border
        }
        if let border {
            control.setWidth(actionSegmentWidth(border: border, hasMenu: hasMenu), forSegment: Self.actionSegment)
            if hasMenu { control.setWidth(border.menuSegmentWidth, forSegment: Self.menuSegment) }
        } else {
            control.setWidth(0, forSegment: Self.actionSegment)
            if hasMenu { control.setWidth(Self.menuSegmentWidth(control.controlSize), forSegment: Self.menuSegment) }
        }
        control.invalidateIntrinsicContentSize()
        // 左: 操作とメニューの両方を持つ区画は、クリックで操作、押し続けるとメニュー (AppKit の `setMenu(_:forSegment:)`)。
        // 右: 区画にメニューを付けると、control に操作があるので長押しでしか開かない。クリックを受けて自分でメニューを開く
        control.setMenu(hasMenu ? coordinator.makeMenu() : nil, forSegment: Self.actionSegment)
        control.setShowsMenuIndicator(false, forSegment: Self.actionSegment)
        // 右クリックのメニューは control が押せるかを見ずに開くので、押せない間は付けない (項目も `validateMenuItem` で無効にする)
        control.menu = hasMenu && coordinator.isEnabled ? coordinator.makeMenu() : nil
    }

    /// 枠付きのときの左の区画の幅。今の中身と `widthAlternatives` のいちばん広いもの (切り替えても幅が変わらない)
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

    static let actionSegment = 0
    static let menuSegment = 1

    static var moreOptionsLabel: String {
        String(localized: "More Options", bundle: .module)
    }

    /// 右の区画 (⌄) の幅
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

    /// 右の区画のクリックでメニューを開く位置 (control の座標)。右の区画の左端の下
    static func menuOrigin(in control: NSSegmentedControl) -> NSPoint {
        let x = control.bounds.width - control.width(forSegment: menuSegment) - 4
        let y = control.isFlipped ? control.bounds.maxY + 4 : -4
        return NSPoint(x: x, y: y)
    }

    @MainActor
    public final class Coordinator: NSObject, NSMenuItemValidation {
        var action: () -> Void = {}
        var items: [Item] = []
        /// `.disabled` の間は操作もメニューの項目も呼ばない (メニューを開く経路は右クリック・VoiceOver など control の外にもある)
        var isEnabled = true
        /// 右の区画のクリックでメニューを開く。テストでは差し替える (`popUp` はメニューを閉じるまで戻らない)
        var presentMenu: (NSMenu, NSSegmentedControl) -> Void = { menu, control in
            menu.popUp(positioning: nil, at: StandardSplitMenuButton.menuOrigin(in: control), in: control)
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()
            for (index, item) in items.enumerated() {
                let menuItem = NSMenuItem(title: item.title, action: #selector(menuItemChosen(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.tag = index
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
            switch segment {
            case StandardSplitMenuButton.actionSegment:
                action()
            case StandardSplitMenuButton.menuSegment where !items.isEmpty:
                presentMenu(makeMenu(), control)
            default:
                break
            }
        }

        public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            isEnabled
        }

        @objc func menuItemChosen(_ sender: NSMenuItem) {
            guard isEnabled, items.indices.contains(sender.tag) else { return }
            items[sender.tag].action()
        }
    }
}
