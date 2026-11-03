import AppKit

/// `StandardSplitMenuButton` の区画の並び: 主の区画と ⌄ の区画の番号・範囲・当たり判定・メニューを開く位置。
///
/// NSSegmentedControl は番号の順に左から並べるので、⌄ を左に置く (`.leading`) ときは ⌄ が 0、主が 1 になる。
/// ボタン (クリックの振り分け)・control (当たり判定・押下)・cell (描画) はどれもこれで引き、番号を決め打たない
struct SplitMenuSegments: Equatable {
    let action: Int
    /// ⌄ の区画 (メニューが無ければ nil。区画は 1 つ)
    let menu: Int?
    let menuEdge: StandardSplitMenuButton.MenuEdge

    init(hasMenu: Bool, menuEdge: StandardSplitMenuButton.MenuEdge) {
        self.menuEdge = menuEdge
        if !hasMenu {
            action = 0
            menu = nil
        } else if menuEdge == .leading {
            action = 1
            menu = 0
        } else {
            action = 0
            menu = 1
        }
    }

    var count: Int { menu == nil ? 1 : 2 }

    /// 区画の範囲 (番号の順 = 左から)。⌄ の区画は `menuWidth`、主は残り
    func frames(in rect: NSRect, menuWidth: CGFloat) -> [NSRect] {
        guard menu != nil else { return [rect] }
        let leftWidth = menuEdge == .leading ? menuWidth : rect.width - menuWidth
        var left = rect
        left.size.width = leftWidth
        var right = rect
        right.origin.x = rect.minX + leftWidth
        right.size.width = rect.width - leftWidth
        return [left, right]
    }

    /// x 座標 (control の座標、幅 `width`) が乗っている区画。⌄ の側の端から `menuWidth` までが ⌄ の区画
    func segment(atX x: CGFloat, width: CGFloat, menuWidth: CGFloat) -> Int {
        guard let menu else { return action }
        let isOnMenu = menuEdge == .leading ? x < menuWidth : x >= width - menuWidth
        return isOnMenu ? menu : action
    }

    /// ⌄ のクリックでメニューを開く x (control の座標)。⌄ が右なら ⌄ の区画の左端の少し左、左ならボタンの左端
    func menuOriginX(width: CGFloat, menuWidth: CGFloat) -> CGFloat {
        menuEdge == .leading ? 0 : width - menuWidth - 4
    }
}
