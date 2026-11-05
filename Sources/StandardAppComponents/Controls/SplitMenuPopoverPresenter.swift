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
    /// 開いているポップオーバーの、押したまま動かしている間の状態と、項目を選んだときの操作
    private(set) var drag: StandardPopoverMenuDrag?
    private var choose: ((Int) -> Void)?
    /// 画面の座標を、開いているポップオーバーの中身の座標 (左上が原点) に直す。開いていなければ nil。テストでは差し替える
    var locateInContent: (NSPopover, NSPoint) -> CGPoint? = { popover, screenPoint in
        guard popover.isShown, let view = popover.contentViewController?.view, let window = view.window else { return nil }
        let point = view.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        return CGPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
    }
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
        let drag = StandardPopoverMenuDrag()
        let chooseAndClose: (Int) -> Void = { [weak popover] index in
            popover?.performClose(nil)
            choose(index)
        }
        let hosting = NSHostingController(rootView: StandardPopoverMenu(items: items, drag: drag, onChoose: chooseAndClose))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        self.popover = popover
        self.drag = drag
        self.choose = chooseAndClose
        present(popover, Self.menuSegmentRect(in: control, segments: segments), control)
    }

    /// 開いたボタンを押したまま動かした (`screenPoint` は画面の座標)。ポップオーバーの行の上なら、その行を塗る
    func dragMoved(toScreen screenPoint: NSPoint) {
        guard let drag else { return }
        drag.isTracking = true
        drag.highlighted = row(atScreen: screenPoint)
    }

    /// 開いたボタンを押したまま動かして離した。行の上で離したらその項目を選ぶ (閉じてから操作を呼ぶ)。
    /// 行の外で離したら開いたまま (動かさずに離したときと同じく、続けてクリックで選べる。標準のメニューも同じ)
    func dragEnded(atScreen screenPoint: NSPoint) {
        guard let drag else { return }
        let index = row(atScreen: screenPoint)
        drag.isTracking = false
        drag.highlighted = nil
        if let index {
            choose?(index)
        }
    }

    private func row(atScreen screenPoint: NSPoint) -> Int? {
        guard let popover, let drag, let point = locateInContent(popover, screenPoint) else { return nil }
        return drag.row(at: point)
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
        // 閉じ始めたら、押したまま離しても選ばない (開いている ⌄ を押して閉じた押下を離したとき、消えかけの行の上で選ばない)
        if (notification.object as? NSPopover) === popover {
            drag = nil
            choose = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // 閉じる途中に開き直していたら、閉じたのは前のポップオーバー。今のものは見失わない
        guard (notification.object as? NSPopover) === popover else { return }
        popover = nil
        drag = nil
        choose = nil
    }
}
