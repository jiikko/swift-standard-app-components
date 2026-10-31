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

    func test_境目の位置を列の最小と最大の中に収める() {
        // NSSplitView.setPosition は列の最小・最大を通さないので、帯のドラッグはここで収める
        let controller = makeSplitController(firstBehavior: true)
        controller.splitViewItems[0].minimumThickness = 200
        controller.splitViewItems[0].maximumThickness = 600
        controller.view.frame = NSRect(x: 0, y: 0, width: 1200, height: 400)
        let split = controller.splitView

        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(350, in: split), 350)
        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(1195, in: split), 600, "最大を超える")
        XCTAssertEqual(StandardSidebarDividerGrabArea.clampedPosition(20, in: split), 200, "最小を割る")
    }
}

private extension NSViewController {
    static func empty() -> NSViewController {
        let controller = NSViewController()
        controller.view = NSView()
        return controller
    }
}
