import AppKit
import SwiftUI

/// `NavigationSplitView` のサイドバーと右の列の境目を、つかめる範囲を広げるための透明な帯。
///
/// 標準の境目 (`NSSplitView` の thin の線) は左右に約 2pt ずつしかつかめない (2026-10-31 に vlc-multi-video-player で
/// ドラッグして測った)。consumer はこの view を境目の上に重ねて置く (位置と幅は consumer が決める。サイドバーを閉じている間は置かない)。
/// 帯の上ではカーソルが左右の矢印になり、ドラッグすると分割の位置を動かす。幅の最小・最大は分割 (`NSSplitViewController` の
/// 列の min / max) がそのまま守る。
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

    /// `window` の中で、最初の列がサイドバーの `NSSplitView` (`NavigationSplitView` が作る分割) を探す。無ければ nil
    @MainActor
    static func sidebarSplitView(in window: NSWindow) -> NSSplitView? {
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

    final class GrabView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
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
                split.setPosition(startPosition + next.locationInWindow.x - startX, ofDividerAt: 0)
                if next.type == .leftMouseUp { break }
            }
        }
    }
}
