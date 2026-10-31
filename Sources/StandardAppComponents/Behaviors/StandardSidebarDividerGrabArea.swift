import AppKit
import SwiftUI

/// `NavigationSplitView` のサイドバーと右の列の境目を、つかめる範囲を広げるための透明な帯。
///
/// 標準の境目 (`NSSplitView` の thin の線) は左右に約 2pt ずつしかつかめない (2026-10-31 に vlc-multi-video-player で
/// ドラッグして測った)。consumer はこの view を境目の上に重ねて置く (位置と幅は consumer が決める。サイドバーを閉じている間は置かない)。
/// 帯の上ではカーソルが左右の矢印になり、ドラッグすると分割の位置を動かす。幅は consumer が渡す範囲 (`widthRange`) に収める
/// (`clampedPosition`)。`navigationSplitViewColumnWidth(min:ideal:max:)` に渡したのと同じ範囲を渡す。
/// 🚨 `NSSplitView.setPosition` は列の最小・最大を通さない。`NavigationSplitView` の列の min / max は SwiftUI の中で効いていて、
/// 分割の側 (`NSSplitViewItem` の太さの上下限・delegate の制約) には入っていない (2026-10-31 に vlc で測った: 列の min 200 に対して
/// item の minimumThickness は 140、maximumThickness は未設定、delegate は制約を実装していない。範囲を渡す前は 600pt の最大を超えて 1195pt まで広がった)。
/// 標準の境目のドラッグと違い、最小より左へ引いても列を畳まない。分割が見つからない (OS の版で作りが違う) ときは、
/// 帯はイベントを受けず、カーソルも変えない (下の view へ通す)。
///
/// 分割は、帯のウィンドウの中から「サイドバーの列を持つ `NSSplitView`」を探して使う (`sidebarSplitView(in:)`)。
/// SwiftUI からは境目のつかめる範囲 (`NSSplitViewDelegate` の effective rect) を変えられないので、上に重ねる形にしている。
///
/// ```swift
/// .overlay(alignment: .topLeading) {
///     StandardSidebarDividerGrabArea(widthRange: 200...600)
///         .frame(width: 11)
///         .offset(x: sidebarMaxX - 3)   // 境目の左 3pt〜右 8pt
/// }
/// ```
public struct StandardSidebarDividerGrabArea: NSViewRepresentable {
    private let widthRange: ClosedRange<CGFloat>

    /// - Parameter widthRange: サイドバーの幅の範囲 (`navigationSplitViewColumnWidth` の min...max と同じ値)
    public init(widthRange: ClosedRange<CGFloat>) {
        self.widthRange = widthRange
    }

    public func makeNSView(context: Context) -> NSView {
        let view = GrabView()
        view.widthRange = widthRange
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? GrabView)?.widthRange = widthRange
    }

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

    /// サイドバーの幅を `widthRange` と分割の側の上下限 (あれば) に収めた境目の位置 (サイドバーは左の列)
    @MainActor
    static func clampedPosition(_ proposed: CGFloat, in split: NSSplitView, widthRange: ClosedRange<CGFloat>) -> CGFloat {
        var lower = widthRange.lowerBound
        var upper = min(widthRange.upperBound, split.bounds.width)
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
        var widthRange: ClosedRange<CGFloat> = 0...CGFloat.greatestFiniteMagnitude

        override var mouseDownCanMoveWindow: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// 使える分割が無ければイベントを受けない (カーソルだけ変わってクリックを奪う、死んだ帯にしない)
        private var hasSidebarSplit: Bool {
            window.flatMap(StandardSidebarDividerGrabArea.sidebarSplitView(in:)) != nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // 帯の外の点では分割を探さない (探すのはウィンドウの view をなめるので、帯に当たったときだけにする)
            guard let hit = super.hitTest(point) else { return nil }
            return hasSidebarSplit ? hit : nil
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
                split.setPosition(
                    StandardSidebarDividerGrabArea.clampedPosition(proposed, in: split, widthRange: widthRange),
                    ofDividerAt: 0
                )
                if next.type == .leftMouseUp { break }
            }
        }
    }
}
