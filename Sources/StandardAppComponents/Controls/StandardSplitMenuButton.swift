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

    private let title: String
    private let systemImage: String
    private let items: [Item]
    private let action: () -> Void

    /// - Parameters:
    ///   - title: 左の区画の名前
    ///   - systemImage: 左の区画のアイコン (SF Symbols)
    ///   - items: メニューの項目 (左の長押し・右の ⌄・右クリックで同じものを出す)
    ///   - action: 左の区画のクリックで呼ぶ主の操作
    public init(_ title: String, systemImage: String, items: [Item], action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.items = items
        self.action = action
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.cell = LongPressHintSegmentedCell()
        control.segmentCount = 2
        control.trackingMode = .momentary
        control.refusesFirstResponder = true
        control.target = context.coordinator
        control.action = #selector(Coordinator.segmentClicked(_:))
        control.setImage(
            NSImage(systemSymbolName: "chevron.down", accessibilityDescription: Self.moreOptionsLabel),
            forSegment: Self.menuSegment
        )
        control.setToolTip(Self.moreOptionsLabel, forSegment: Self.menuSegment)
        updateNSView(control, context: context)
        return control
    }

    public func updateNSView(_ control: NSSegmentedControl, context: Context) {
        let coordinator = context.coordinator
        coordinator.action = action
        coordinator.items = items
        control.setLabel(title, forSegment: Self.actionSegment)
        control.setImage(NSImage(systemSymbolName: systemImage, accessibilityDescription: nil), forSegment: Self.actionSegment)
        control.controlSize = Self.nsControlSize(context.environment.controlSize)
        control.setWidth(Self.menuSegmentWidth(control.controlSize), forSegment: Self.menuSegment)
        control.isEnabled = context.environment.isEnabled
        // 左: 操作とメニューの両方を持つ区画は、クリックで操作、押し続けるとメニュー (AppKit の `setMenu(_:forSegment:)`)。
        // 右: 区画にメニューを付けると、control に操作があるので長押しでしか開かない。クリックを受けて自分でメニューを開く
        control.setMenu(coordinator.makeMenu(), forSegment: Self.actionSegment)
        control.setShowsMenuIndicator(false, forSegment: Self.actionSegment)
        control.menu = coordinator.makeMenu()
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
    public final class Coordinator: NSObject {
        var action: () -> Void = {}
        var items: [Item] = []
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
            switch segment {
            case StandardSplitMenuButton.actionSegment:
                action()
            case StandardSplitMenuButton.menuSegment:
                presentMenu(makeMenu(), control)
            default:
                break
            }
        }

        @objc func menuItemChosen(_ sender: NSMenuItem) {
            guard items.indices.contains(sender.tag) else { return }
            items[sender.tag].action()
        }
    }
}

/// 左の区画の右上に小さな ▼ を描き、押し続けるとメニューが出ることを示す (大きさと位置は 2026-11-01 のユーザー指定)
final class LongPressHintSegmentedCell: NSSegmentedCell {
    static let triangleSize: CGFloat = 6.5
    static let trailingInset: CGFloat = 3
    static let topInset: CGFloat = 5

    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        super.drawSegment(segment, inFrame: frame, with: controlView)
        guard segment == StandardSplitMenuButton.actionSegment else { return }
        let size = Self.triangleSize
        let right = frame.maxX - Self.trailingInset
        let top = controlView.isFlipped ? frame.minY + Self.topInset : frame.maxY - Self.topInset
        let bottom = controlView.isFlipped ? top + size * 0.8 : top - size * 0.8
        let path = NSBezierPath()
        path.move(to: NSPoint(x: right - size, y: top))
        path.line(to: NSPoint(x: right, y: top))
        path.line(to: NSPoint(x: right - size / 2, y: bottom))
        path.close()
        (isEnabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor).setFill()
        path.fill()
    }
}
