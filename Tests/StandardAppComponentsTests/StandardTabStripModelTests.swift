@testable import StandardAppComponents
import SwiftUI
import XCTest

/// `StandardTabStripModel` の判断のうち、描かずに確かめられるもの (選んだタブを送るか・タブが外れた知らせ)
@MainActor
final class StandardTabStripModelTests: XCTestCase {
    private struct Tab: Identifiable {
        let id: Int
    }

    // MARK: - 選んだタブを送るか

    func test_全部見えているタブには送らない() {
        let model = StandardTabStripModel<Tab>()
        model.viewportWidth = 300
        model.recordVisibleSpan(minX: 10, maxX: 90, for: 1)
        XCTAssertFalse(model.needsScroll(to: 1))
    }

    func test_端が切れているタブ_隠れているタブには送る() {
        let model = StandardTabStripModel<Tab>()
        model.viewportWidth = 300
        model.recordVisibleSpan(minX: -20, maxX: 60, for: 1)
        model.recordVisibleSpan(minX: 250, maxX: 330, for: 2)
        model.recordVisibleSpan(minX: 400, maxX: 480, for: 3)
        XCTAssertTrue(model.needsScroll(to: 1))
        XCTAssertTrue(model.needsScroll(to: 2))
        XCTAssertTrue(model.needsScroll(to: 3))
    }

    func test_まだ測っていないタブ_見えている所の幅が分からないときは送る() {
        let model = StandardTabStripModel<Tab>()
        XCTAssertTrue(model.needsScroll(to: 1))
        model.recordVisibleSpan(minX: 10, maxX: 90, for: 1)
        XCTAssertTrue(model.needsScroll(to: 1))
    }

    // MARK: - タブが外れた知らせ

    func test_縮めずに外れたタブはすぐ知らせる() {
        let model = StandardTabStripModel<Tab>()
        var removed: [Int] = []
        model.start(with: [Tab(id: 1), Tab(id: 2)])
        // 置き換え (知らないタブが混ざるので閉じたと見ない) は縮めないので、外れた 2 つをすぐ知らせる
        model.itemsDidChange(
            [Tab(id: 3)], displayed: [1, 2], collapses: true, fallbackWidth: 72, animation: .default,
            onTabRemoved: { removed.append($0) }
        )
        XCTAssertEqual(removed, [1, 2])
    }

    func test_縮めない設定で閉じたタブはすぐ知らせる() {
        let model = StandardTabStripModel<Tab>()
        var removed: [Int] = []
        model.start(with: [Tab(id: 1), Tab(id: 2)])
        model.itemsDidChange(
            [Tab(id: 1)], displayed: [1, 2], collapses: false, fallbackWidth: 72, animation: .default,
            onTabRemoved: { removed.append($0) }
        )
        XCTAssertEqual(removed, [2])
    }

    func test_縮めるタブは縮めきるまで知らせない() {
        let model = StandardTabStripModel<Tab>()
        var removed: [Int] = []
        model.start(with: [Tab(id: 1), Tab(id: 2)])
        model.itemsDidChange(
            [Tab(id: 1)], displayed: [1, 2], collapses: true, fallbackWidth: 72, animation: .default,
            onTabRemoved: { removed.append($0) }
        )
        XCTAssertEqual(removed, [])
        XCTAssertNotNil(model.closingTabs[2])
    }
}
