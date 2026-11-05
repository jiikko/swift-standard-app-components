import AppKit
import SwiftUI

/// 押すと上に項目のリスト (`StandardPopoverMenu`) のポップオーバーを出すボタン。中身 (見た目) は consumer が描く。
///
/// `StandardSplitMenuButton(chevronPresentation: .popover)` の ⌄ と同じ動き: 押した時点で開き、押したまま項目まで動かして離すと選ぶ
/// (項目の外で離すと開いたまま、続けてクリックで選べる)。外のクリックで閉じ、開いている間にもう一度押しても閉じる。
/// SwiftUI の `Button` + `.popover` は離したときに開くので、押したまま選べない (2026-11-05 vlc-multi-video-player のユーザー指示)。
///
/// ```swift
/// StandardPopoverMenuButton(items: presets) { isHighlighted in
///     Text(verbatim: "1.50x ⌄").background(isHighlighted ? hoverFill : .clear)
/// }
/// ```
///
/// `label` の `isHighlighted` は、カーソルを乗せている間とリストを開いている間に true。押せるかは `.disabled(_:)` に従う
/// (押せない間は開かず、開いていれば閉じる)。キーボード・VoiceOver では開けない (クリックの区画の上に AppKit の view を重ねるため)。
/// キーボードで選ぶ経路が要る consumer は、標準のメニューを持つ別の入口を用意する
public struct StandardPopoverMenuButton<Label: View>: View {
    private let items: [StandardSplitMenuButton.Item]
    private let label: (Bool) -> Label

    @State private var isHovering = false
    @State private var isPresented = false

    public init(items: [StandardSplitMenuButton.Item], @ViewBuilder label: @escaping (_ isHighlighted: Bool) -> Label) {
        self.items = items
        self.label = label
    }

    public var body: some View {
        label(isHovering || isPresented)
            .overlay(
                PopoverMenuPressArea(
                    items: items,
                    onHover: { isHovering = $0 },
                    onPresentedChange: { isPresented = $0 }
                )
            )
    }
}

/// `StandardPopoverMenuButton` の押せる範囲 (AppKit)。押下を自分で受けてポップオーバーを開き、離すまで追う
private struct PopoverMenuPressArea: NSViewRepresentable {
    let items: [StandardSplitMenuButton.Item]
    let onHover: (Bool) -> Void
    let onPresentedChange: (Bool) -> Void

    func makeNSView(context: Context) -> PopoverMenuPressView {
        let view = PopoverMenuPressView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: PopoverMenuPressView, context: Context) {
        view.items = items
        view.onHover = onHover
        view.presenter.onShownChange = onPresentedChange
        view.isEnabled = context.environment.isEnabled
    }

    /// 画面から外れたら開いているリストを閉じる (残すと、外れたボタンの位置に浮いたままになる)
    static func dismantleNSView(_ view: PopoverMenuPressView, coordinator: ()) {
        view.presenter.close()
    }
}

/// 押下を受けてポップオーバーを開き、離すまで追う view。カーソルを乗せたかを `onHover` で返し、乗せている間は指のカーソル
final class PopoverMenuPressView: NSView {
    let presenter = SplitMenuPopoverPresenter()
    var items: [StandardSplitMenuButton.Item] = [] {
        didSet { presenter.update(items: items) }
    }
    var onHover: ((Bool) -> Void)?
    var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            // 押せなくなったら開いているリストも閉じる (残すと、押しても何も起きない項目が並ぶ)
            if !isEnabled {
                presenter.close()
                onHover?(false)
            }
            window?.invalidateCursorRects(for: self)
        }
    }

    private var hoverTrackingArea: NSTrackingArea?

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, !items.isEmpty else { return }
        presenter.toggle(items: items, relativeTo: bounds, of: self) { [weak self] index in
            self?.chooseItem(at: index)
        }
        PopoverPressTracking.track(
            in: self,
            moved: { [presenter] in presenter.dragMoved(toScreen: $0) },
            ended: { [presenter] in presenter.dragEnded(atScreen: $0) }
        )
    }

    /// 項目は選んだ時点の `items` から引く (開いた後に consumer が並べ替えても、範囲の外は選ばない)
    func chooseItem(at index: Int) {
        guard isEnabled, items.indices.contains(index) else { return }
        items[index].action()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        if isEnabled { onHover?(true) }
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }
}
