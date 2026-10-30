import Foundation

/// 閉じたタブを並びに残して幅を 0 まで縮めるための見分けと並べ方 (`StandardTabStrip` の中で使う。純粋な判断なので単体で検査する)。
///
/// SwiftUI の消えるときの transition では、消えるタブはすぐ並びから外れ、右のタブがその上に重なって縮む様子が見えない (Chrome と違う)。
/// そこで閉じたタブを「縮めている途中のタブ」として並びに残し、幅を 0 まで縮めてから外す。
enum StandardTabClosing {
    /// 前に描いた並びから、タブが閉じられた (いくつか抜け、残ったのは前に在ったタブだけ) か。残りの順番は見ない。
    /// 足した・並べ替えた・総入れ替え (1 → N の復元)・置き換え (数が同じ) は閉じたことにしない。
    /// 前提: consumer は 1 回の閉じる操作 (× の確認・⌘W・メニュー) で一覧を 1 回で書き換える。途中の並び (抜いてから足す等) を
    /// 挟むと、閉じたことと置き換えを見分けられない
    static func isClose<ID: Hashable>(from previous: [ID], to current: [ID]) -> Bool {
        guard current.count < previous.count else { return false }
        let previousIDs = Set(previous)
        return current.allSatisfy { previousIDs.contains($0) }
    }

    /// 閉じられたタブ (前の並びの順)。閉じたのでなければ空
    static func closedIDs<ID: Hashable>(from previous: [ID], to current: [ID]) -> [ID] {
        guard isClose(from: previous, to: current) else { return [] }
        let currentIDs = Set(current)
        return previous.filter { !currentIDs.contains($0) }
    }

    /// 並びの 1 つ。`liveIndex` は consumer のタブ一覧での位置で、nil なら縮めている途中の閉じたタブ
    struct Entry<ID: Hashable>: Identifiable, Equatable {
        let id: ID
        let liveIndex: Int?
    }

    /// 描く並び。consumer のタブの順 (`live`) を正として、縮めている途中のタブ (`closing`) を、前に描いた並び (`previousOrder`) で
    /// その左にあったタブの右隣に差し込む (左に何も残っていなければ先頭)。続けて閉じたタブも、左から順に差し込むので元の並びに戻る。
    /// 前に描いた並びに無いもの (描いたことが無い) と、consumer の一覧に戻ってきたもの (同じ id を足し直した) は差し込まない
    static func entries<ID: Hashable>(live: [ID], closing: Set<ID>, previousOrder: [ID]) -> [Entry<ID>] {
        var result = live.enumerated().map { Entry(id: $0.element, liveIndex: $0.offset) }
        let liveIDs = Set(live)
        for (position, id) in previousOrder.enumerated() where closing.contains(id) && !liveIDs.contains(id) {
            let placed = Set(result.map(\.id))
            let leftNeighbor = previousOrder[..<position].last { placed.contains($0) }
            let insertAt = leftNeighbor.flatMap { neighbor in result.firstIndex { $0.id == neighbor } }.map { $0 + 1 } ?? 0
            result.insert(Entry(id: id, liveIndex: nil), at: insertAt)
        }
        return result
    }
}

/// ドラッグで並べ替えるときの「相手のタブの前か後ろか」
public enum StandardTabMovePlacement: Sendable, Equatable {
    case before
    case after

    /// 相手のタブの左半分なら前、右半分なら後ろ。幅が 0 以下なら前
    static func placement(locationX: CGFloat, tabWidth: CGFloat) -> Self {
        guard tabWidth > 0 else { return .before }
        return locationX < tabWidth / 2 ? .before : .after
    }
}
