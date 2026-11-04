import AppKit
import SwiftUI

/// `StandardSplitMenuButton(chevronPresentation: .popover)` の ⌄ のクリックで、⌄ の区画の上に項目のリスト (`StandardPopoverMenu`) の
/// ポップオーバーを出す。外のクリックで閉じ (`.transient`)、もう一度 ⌄ を押しても閉じる。項目を選ぶと閉じてから操作を呼ぶ
@MainActor
final class SplitMenuPopoverPresenter: NSObject, NSPopoverDelegate {
    /// 開く (`rect` は control の座標の ⌄ の区画)。テストでは差し替える
    var present: (NSPopover, NSRect, NSSegmentedControl) -> Void = { popover, rect, control in
        popover.show(relativeTo: rect, of: control, preferredEdge: control.isFlipped ? .minY : .maxY)
    }

    /// 開いているポップオーバー
    private(set) var popover: NSPopover?
    /// ポップオーバーを閉じさせたマウスの押下の番号 (`NSEvent.eventNumber`)。⌄ のクリックで閉じたとき、同じクリックで開き直さない
    /// (外のクリックで閉じる `.transient` は、閉じた後にその押下を ⌄ の区画へ届ける。枠なしの見た目は離したときに届くが、
    /// 離しの `eventNumber` は押下と同じ)
    private var dismissingClickNumber: Int?

    /// 開く。開いていれば閉じる
    func toggle(
        items: [StandardSplitMenuButton.Item],
        in control: NSSegmentedControl,
        segments: SplitMenuSegments,
        choose: @escaping (Int) -> Void
    ) {
        if let popover, popover.isShown {
            // 外のクリックで閉じ始めた後に同じ押下が届いたときもここに来る。覚えた番号は使い終えたので消す
            dismissingClickNumber = nil
            popover.performClose(nil)
            return
        }
        if let dismissingClickNumber, let event = NSApp.currentEvent,
           [.leftMouseDown, .leftMouseUp].contains(event.type), event.eventNumber == dismissingClickNumber {
            self.dismissingClickNumber = nil
            return
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        let hosting = NSHostingController(rootView: StandardPopoverMenu(items: items) { [weak popover] index in
            popover?.performClose(nil)
            choose(index)
        })
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        self.popover = popover
        present(popover, Self.menuSegmentRect(in: control, segments: segments), control)
    }

    /// 閉じる (ボタンが押せなくなった・画面から外れた)
    func close() {
        popover?.performClose(nil)
    }

    /// ⌄ の区画の範囲 (control の座標)
    static func menuSegmentRect(in control: NSSegmentedControl, segments: SplitMenuSegments) -> NSRect {
        guard let menuSegment = segments.menu else { return control.bounds }
        let frames = (control.cell as? LongPressHintSegmentedCell)?.segmentFrames(in: control.bounds, controlView: control)
            ?? segments.frames(in: control.bounds, menuWidth: control.width(forSegment: menuSegment))
        return frames.indices.contains(menuSegment) ? frames[menuSegment] : control.bounds
    }

    func popoverWillClose(_ notification: Notification) {
        if let event = NSApp.currentEvent, event.type == .leftMouseDown {
            dismissingClickNumber = event.eventNumber
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // 閉じる途中に開き直していたら、閉じたのは前のポップオーバー。今のものは見失わない
        guard (notification.object as? NSPopover) === popover else { return }
        popover = nil
    }
}
