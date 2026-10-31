import AppKit
import SwiftUI

/// `NavigationSplitView` のサイドバーと右の列の境目を、つかめる範囲を広げるための透明な帯。
///
/// 標準の境目 (`NSSplitView` の thin の線) は左右に約 2pt ずつしかつかめない (2026-10-31 に vlc-multi-video-player で
/// ドラッグして測った)。consumer はこの view を境目の上に重ねて置く (位置と幅は consumer が決める。サイドバーを閉じている間は置かない)。
/// 帯の上ではカーソルが左右の矢印になり、ドラッグすると分割の位置を動かす。幅はサイドバーの列の最小・最大
/// (`NSSplitViewItem` の太さの上下限と、分割の delegate の制約) の中に収める (`clampedPosition`)。
/// 🚨 `NSSplitView.setPosition` は列の最小・最大を通さない (2026-10-31 に vlc で、最大 600pt の列が 1195pt まで広がった)。
/// 標準の境目のドラッグと違い、最小より左へ引いても列を畳まない。分割が見つからない (OS の版で作りが違う) ときは、
/// 帯はイベントを受けず、カーソルも変えない (下の view へ通す)。
///
/// 分割は、帯のウィンドウの中から「サイドバーの列を持つ `NSSplitView`」を探して使う (`sidebarSplitView(in:)`)。
/// SwiftUI からは境目のつかめる範囲 (`NSSplitViewDelegate` の effective rect) を変えられないので、上に重ねる形にしている。
///
/// ```swift
/// .overlay(alignment: .topLeading) {
///     StandardSidebarDividerGrabArea()
///         .frame(width: 11)
///         .offset(x: sidebarMaxX - 3)   // 境目の左 3pt〜右 8pt
/// }
/// ```
public struct StandardSidebarDividerGrabArea: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        GrabView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}

    /// `window` の中で、最初の列がサイドバーの `NSSplitView` (`NavigationSplitView` が作る分割) を探す。無ければ nil。
    /// サイドバーの今の幅は `arrangedSubviews.first` の幅 (consumer の検査・計測の道具からも使う)
    @MainActor
    public static func sidebarSplitView(in window: NSWindow) -> NSSplitView? {
        guard let root = window.contentView else { return nil }
        var queue: [NSView] = [root]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let split = view as? NSSplitView, split.isVertical,
               let controller = split.delegate as? NSSplitViewController,
               controller.splitViewItems.first?.behavior == .sidebar {
                return split
            }
            queue.append(contentsOf: view.subviews)
        }
        return nil
    }

    /// サイドバーの列の幅を、列の最小・最大の中に収めた境目の位置 (サイドバーは左の列)
    @MainActor
    static func clampedPosition(_ proposed: CGFloat, in split: NSSplitView) -> CGFloat {
        var lower: CGFloat = 0
        var upper = split.bounds.width
        if let item = (split.delegate as? NSSplitViewController)?.splitViewItems.first {
            if item.minimumThickness > 0 { lower = max(lower, item.minimumThickness) }
            if item.maximumThickness > 0 { upper = min(upper, item.maximumThickness) }
        }
        if let delegate = split.delegate {
            lower = max(lower, delegate.splitView?(split, constrainMinCoordinate: lower, ofSubviewAt: 0) ?? lower)
            upper = min(upper, delegate.splitView?(split, constrainMaxCoordinate: upper, ofSubviewAt: 0) ?? upper)
        }
        return min(max(proposed, lower), max(lower, upper))
    }

    final class GrabView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// 使える分割が無ければイベントを受けない (カーソルだけ変わってクリックを奪う、死んだ帯にしない)
        private var hasSidebarSplit: Bool {
            window.flatMap(StandardSidebarDividerGrabArea.sidebarSplitView(in:)) != nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            hasSidebarSplit ? super.hitTest(point) : nil
        }

        override func resetCursorRects() {
            guard hasSidebarSplit else { return }
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func mouseDown(with event: NSEvent) {
            guard let window,
                  let split = StandardSidebarDividerGrabArea.sidebarSplitView(in: window),
                  let sidebar = split.arrangedSubviews.first, !sidebar.isHidden else {
                super.mouseDown(with: event)
                return
            }
            // 押した所と境目のずれを保ったまま動かす (帯のどこをつかんでも、境目が指に付いてくる)
            let startX = event.locationInWindow.x
            let startPosition = sidebar.frame.maxX
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
                let proposed = startPosition + next.locationInWindow.x - startX
                split.setPosition(StandardSidebarDividerGrabArea.clampedPosition(proposed, in: split), ofDividerAt: 0)
                if next.type == .leftMouseUp { break }
            }
        }
    }
}
