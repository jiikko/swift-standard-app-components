@testable import StandardAppComponents
import XCTest

/// 足したタブの見分け (`StandardTabOpening`)。足した描画だけを動かし、復元・置き換え・閉じる・並べ替えでは帯を動かさない
final class StandardTabOpeningTests: XCTestCase {
    func test_足したタブだけを今の並びの順で返す() {
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [1, 2], to: [1, 2, 3]), [3])
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [1, 2], to: [1, 4, 2, 3]), [4, 3])
    }

    func test_最初の描画は足したことにしない() {
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [Int](), to: [1, 2]), [])
    }

    func test_総入れ替えと置き換えは足したことにしない() {
        // ウィンドウの復元 (1 → N で前のタブが残らない) と、数が同じ置き換え
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [1], to: [5, 6, 7]), [])
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [1, 2], to: [1, 3]), [])
    }

    func test_閉じる_並べ替えは足したことにしない() {
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [1, 2, 3], to: [1, 3]), [])
        XCTAssertEqual(StandardTabOpening.openedIDs(from: [1, 2, 3], to: [3, 1, 2]), [])
    }
}
