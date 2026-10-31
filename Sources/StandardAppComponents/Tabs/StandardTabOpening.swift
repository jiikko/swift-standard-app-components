import Foundation

/// 足したタブの見分け (`StandardTabStrip` の中で使う。`StandardTabClosing` と対の純粋な判断なので単体で検査する)。
///
/// 足したタブだけを動かして出す。総入れ替え (ウィンドウの復元・1 → N) や置き換えまで動かすと、帯全体が一斉に出てくる。
enum StandardTabOpening {
    /// 前に描いた並びから、タブが足された (いくつか増え、前に在ったタブは全部残っている) か。残りの順番は見ない。
    /// 閉じた・並べ替えた・総入れ替え・置き換えは足したことにしない。前に何も描いていない (最初の描画) も足したことにしない
    static func isOpen<ID: Hashable>(from previous: [ID], to current: [ID]) -> Bool {
        guard !previous.isEmpty, current.count > previous.count else { return false }
        let currentIDs = Set(current)
        return previous.allSatisfy { currentIDs.contains($0) }
    }

    /// 足されたタブ (今の並びの順)。足したのでなければ空
    static func openedIDs<ID: Hashable>(from previous: [ID], to current: [ID]) -> [ID] {
        guard isOpen(from: previous, to: current) else { return [] }
        let previousIDs = Set(previous)
        return current.filter { !previousIDs.contains($0) }
    }
}
