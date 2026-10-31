import AppKit
@testable import StandardAppComponents
import XCTest

/// サイドバーの境目をつかむ帯が、使う分割を見つけられるか。
@MainActor
final class StandardSidebarDividerGrabAreaTests: XCTestCase {
    private func makeWindow(contentView: NSView) -> NSWindow {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled],
                              backing: .buffered, defer: true)
        window.contentView = contentView
        return window
    }

    private func makeSplitController(firstBehavior sidebar: Bool) -> NSSplitViewController {
        let controller = NSSplitViewController()
        let first = sidebar
            ? NSSplitViewItem(sidebarWithViewController: NSViewController.empty())
            : NSSplitViewItem(viewController: NSViewController.empty())
        controller.addSplitViewItem(first)
        controller.addSplitViewItem(NSSplitViewItem(viewController: NSViewController.empty()))
        return controller
    }

    func test_サイドバーを持つ分割を入れ子の中から見つける() {
        let controller = makeSplitController(firstBehavior: true)
        let container = NSView()
        container.addSubview(controller.view)
        let window = makeWindow(contentView: container)

        XCTAssertIdentical(StandardSidebarDividerGrabArea.sidebarSplitView(in: window), controller.splitView)
    }

    func test_サイドバーの無い分割は使わない() {
        // 最初の列がサイドバーでない分割 (中の左右の分割など) の位置を動かさない
        let other = makeSplitController(firstBehavior: false)
        let sidebarSplit = makeSplitController(firstBehavior: true)
        let container = NSView()
        container.addSubview(other.view)
        container.addSubview(sidebarSplit.view)
        let window = makeWindow(contentView: container)

        XCTAssertIdentical(StandardSidebarDividerGrabArea.sidebarSplitView(in: window), sidebarSplit.splitView)
        let onlyOther = NSView()
        onlyOther.addSubview(makeSplitController(firstBehavior: false).view)
        XCTAssertNil(StandardSidebarDividerGrabArea.sidebarSplitView(in: makeWindow(contentView: onlyOther)))
    }

    func test_境目の位置を渡した幅の範囲と列の上下限の中に収める() {
        // NSSplitView.setPosition は列の最小・最大を通さず、NavigationSplitView の min / max は分割の側に無いので、帯が収める
        let controller = makeSplitController(firstBehavior: true)
        controller.view.frame = NSRect(x: 0, y: 0, width: 1200, height: 400)
        let split = controller.splitView

        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(350, in: split, widthRange: 200...600), 350)
        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(1195, in: split, widthRange: 200...600), 600, "最大を超える")
        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(20, in: split, widthRange: 200...600), 200, "最小を割る")
        // 分割の側の上下限が狭ければ、そちらも守る
        controller.splitViewItems[0].maximumThickness = 500
        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(550, in: split, widthRange: 200...600), 500)
    }

    func test_分割が無いウィンドウでは帯がイベントを受けない() {
        // 分割を見つけられない (OS の版で作りが違う) とき、カーソルだけ変えてクリックを奪う帯にしない
        let grab = StandardSidebarDividerGrabArea.GrabView(frame: NSRect(x: 0, y: 0, width: 11, height: 100))
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        container.addSubview(grab)
        _ = makeWindow(contentView: container)
        XCTAssertNil(grab.hitTest(NSPoint(x: 5, y: 50)), "分割が無いのに帯がイベントを受ける")

        // サイドバーの分割がある同じ形のウィンドウでは受ける (この検査が空振りしていないことの確かめ)
        let controller = makeSplitController(firstBehavior: true)
        let withSplit = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        withSplit.addSubview(controller.view)
        let grabWithSplit = StandardSidebarDividerGrabArea.GrabView(frame: NSRect(x: 0, y: 0, width: 11, height: 100))
        withSplit.addSubview(grabWithSplit)
        _ = makeWindow(contentView: withSplit)
        XCTAssertIdentical(grabWithSplit.hitTest(NSPoint(x: 5, y: 50)), grabWithSplit)
    }
}

private extension NSViewController {
    static func empty() -> NSViewController {
        let controller = NSViewController()
        controller.view = NSView()
        return controller
    }
}
