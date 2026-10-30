@testable import StandardAppComponents
import XCTest

/// タブを閉じたときだけ、閉じたタブを並びに残して幅を縮める (`StandardTabClosing`)。
/// 閉じた以外の並びの変化 (足す・並べ替え・総入れ替え・置き換え) では縮めない
final class StandardTabClosingTests: XCTestCase {
    private let first = 1
    private let second = 2
    private let third = 3
    private let fourth = 4

    func test_タブが抜けたら閉じたと見る() {
        XCTAssertTrue(StandardTabClosing.isClose(from: [first, second, third], to: [first, third]))
        XCTAssertTrue(StandardTabClosing.isClose(from: [first, second, third], to: [second, third]))
    }

    func test_足したとき並べ替えたときは閉じたと見ない() {
        XCTAssertFalse(StandardTabClosing.isClose(from: [first, second], to: [first, second, third]))
        XCTAssertFalse(StandardTabClosing.isClose(from: [first, second, third], to: [third, first, second]))
    }

    func test_総入れ替えと置き換えは閉じたと見ない() {
        XCTAssertFalse(StandardTabClosing.isClose(from: [first], to: [second, third]))
        XCTAssertFalse(StandardTabClosing.isClose(from: [], to: [first, second]))
        XCTAssertFalse(StandardTabClosing.isClose(from: [first], to: [second]))
        XCTAssertFalse(StandardTabClosing.isClose(from: [first, second, third], to: [first, 99]))
    }

    func test_閉じられたタブを前の並びの順で返す() {
        XCTAssertEqual(StandardTabClosing.closedIDs(from: [first, second, third, fourth], to: [first, fourth]), [second, third])
        XCTAssertEqual(StandardTabClosing.closedIDs(from: [first], to: [second]), [])
    }

    func test_閉じたタブは元の位置に残す() {
        let entries = StandardTabClosing.entries(live: [first, third], closing: [second], previousOrder: [first, second, third])
        XCTAssertEqual(entries.map(\.id), [first, second, third])
        XCTAssertEqual(entries.map(\.liveIndex), [0, nil, 1])
    }

    func test_先頭のタブを閉じたら先頭に残す() {
        let entries = StandardTabClosing.entries(live: [second, third], closing: [first], previousOrder: [first, second, third])
        XCTAssertEqual(entries.map(\.id), [first, second, third])
    }

    func test_縮めている途中に隣も閉じたら両方を元の並びで残す() {
        let entries = StandardTabClosing.entries(
            live: [first, fourth], closing: [second, third], previousOrder: [first, second, third, fourth]
        )
        XCTAssertEqual(entries.map(\.id), [first, second, third, fourth])
    }

    func test_縮めている途中に並べ替えたら左隣についていく() {
        let entries = StandardTabClosing.entries(
            live: [third, fourth, first], closing: [second], previousOrder: [first, second, third, fourth]
        )
        XCTAssertEqual(entries.map(\.id), [third, fourth, first, second])
    }

    func test_縮めている途中に同じidが戻ってきたら生きているタブとして1つだけ出す() {
        // 閉じてすぐ同じ id のタブを足し直した (undo など)。縮めているタブと生きているタブが同じ id で 2 つ並ばない
        let entries = StandardTabClosing.entries(live: [first, second], closing: [second], previousOrder: [first, second])
        XCTAssertEqual(entries.map(\.id), [first, second])
        XCTAssertEqual(entries.map(\.liveIndex), [0, 1])
    }

    func test_ドラッグの前後は相手のタブの左右半分で決める() {
        XCTAssertEqual(StandardTabMovePlacement.placement(locationX: 10, tabWidth: 100), .before)
        XCTAssertEqual(StandardTabMovePlacement.placement(locationX: 60, tabWidth: 100), .after)
        XCTAssertEqual(StandardTabMovePlacement.placement(locationX: 10, tabWidth: 0), .before)
    }

    func test_ちょうど中央は後ろ_幅が負なら前() {
        // 中央 (幅の半分) は左半分の外なので後ろ
        XCTAssertEqual(StandardTabMovePlacement.placement(locationX: 50, tabWidth: 100), .after)
        XCTAssertEqual(StandardTabMovePlacement.placement(locationX: 5, tabWidth: -10), .before)
    }

    func test_縮めるタブが無ければconsumerの並びのまま() {
        // 前に描いた並びが違っても (並べ替えた直後)、縮めるタブが無ければ前の並びを見ない
        let entries = StandardTabClosing.entries(live: [first, second], closing: [], previousOrder: [second, first])
        XCTAssertEqual(entries.map(\.id), [first, second])
        XCTAssertEqual(entries.map(\.liveIndex), [0, 1])
    }
}
