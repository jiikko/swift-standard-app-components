import AppKit

// `StandardSplitMenuButton` の枠付きの見た目の、AppKit の view に依らない決まり: 塗り・枠の色・主の区画の幅・押下の判定

/// 枠付きの見た目の状態から塗りを決める (`border` を渡したときだけ使う)
enum SplitMenuButtonLook {
    /// 区画の塗り。押している区画 > カーソルを乗せた区画 > 地の塗り (nil。区画ごとには塗らない)
    static func segmentFill(_ segment: Int, hovered: Int?, pressed: Int?, border: StandardSplitMenuButton.Border) -> NSColor? {
        if pressed == segment { return border.pressedFill }
        if pressed == nil, hovered == segment { return border.hoveredFill }
        return nil
    }

    /// 枠の色。カーソルが乗っている・押している間は濃くする
    static func stroke(hovered: Int?, pressed: Int?, border: StandardSplitMenuButton.Border) -> NSColor {
        hovered != nil || pressed != nil ? border.hoveredStroke : border.stroke
    }

    /// 枠付きの見た目の主の区画の幅 (中身 + 左右の余白。メニューがあれば ▼ の分も足す)
    static func actionSegmentWidth(title: String, image: NSImage?, border: StandardSplitMenuButton.Border, hasMenu: Bool) -> CGFloat {
        let titleWidth = (title as NSString).size(withAttributes: [.font: border.font]).width
        let iconWidth = image.map { symbol($0, border: border, color: border.foreground).size.width } ?? 0
        let spacing = image != nil && !title.isEmpty ? border.iconSpacing : 0
        let hint = hasMenu ? LongPressHintSegmentedCell.triangleSize : 0
        return (border.horizontalPadding * 2 + iconWidth + spacing + titleWidth + hint).rounded(.up)
    }

    /// SF Symbols の絵を、枠付きの見た目の大きさと色にする。1 色で塗り、絵の抜き (ゴミ箱の × など) は抜いたまま残す
    /// (`paletteColors` に 1 色だけ渡すと、抜きの層まで同じ色で塗られて見えなくなる)
    static func symbol(_ image: NSImage, border: StandardSplitMenuButton.Border, color: NSColor) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: border.iconPointSize, weight: .regular)
        let sized = image.withSymbolConfiguration(configuration) ?? image
        return NSImage(size: sized.size, flipped: false) { rect in
            sized.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}

/// 枠付きの見た目のときの主の区画の押下の判定。押してから離すまで・押し続けるまでの出来事から、主の操作・メニュー・取り消しを決める
struct SplitMenuPressTracker {
    enum Outcome: Equatable {
        /// まだ決まらない (押し続けている)
        case pending
        /// 主の操作 (離した位置がボタンの上)
        case primary
        /// 長押しのメニューを開く
        case menu
        /// 何もしない (外で離した)
        case cancel
    }

    /// 離したかどうかと、離した位置
    enum Release: Equatable {
        case notYet
        case inside
        case outside
    }

    let hasMenu: Bool
    /// 押し続けてメニューを出すまでの時間
    let longPressDelay: TimeInterval

    /// 押してから `elapsed` 秒たった時点で、離したかどうかと離した位置、今カーソルが主の区画の上にあるか (`isOver`) から決める。
    /// 押したまま外へ出している間はメニューを開かない (標準のボタンと同じく、外へ出して離せば取り消せる)
    func outcome(elapsed: TimeInterval, release: Release, isOver: Bool) -> Outcome {
        switch release {
        case .inside:
            .primary
        case .outside:
            .cancel
        case .notYet:
            hasMenu && isOver && elapsed >= longPressDelay ? .menu : .pending
        }
    }
}
