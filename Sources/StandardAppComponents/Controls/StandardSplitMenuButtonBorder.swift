import AppKit

// `StandardSplitMenuButton` の型の本体の長さ (lint の上限) を超えないよう、見た目の設定の型を別のファイルに置く

extension StandardSplitMenuButton {
    /// 枠付きの見た目 (`border:` に渡す)。色は consumer の他のボタンと同じものを渡す
    public struct Border: Equatable {
        public var fill: NSColor
        public var hoveredFill: NSColor
        public var pressedFill: NSColor
        public var stroke: NSColor
        public var hoveredStroke: NSColor
        public var divider: NSColor
        public var cornerRadius: CGFloat
        /// 高さ (標準の描画の高さは `controlSize` で決まり、他のボタンと揃わないことがある)
        public var height: CGFloat
        /// 押せない間の不透明度
        public var disabledOpacity: CGFloat
        /// アイコン・文字・⌄ の色
        public var foreground: NSColor
        public var font: NSFont
        public var iconPointSize: CGFloat
        public var iconSpacing: CGFloat
        /// 左の区画の中身の左右の余白
        public var horizontalPadding: CGFloat
        /// 右の区画 (⌄) の幅
        public var menuSegmentWidth: CGFloat

        public init(
            fill: NSColor,
            hoveredFill: NSColor,
            pressedFill: NSColor,
            stroke: NSColor,
            hoveredStroke: NSColor,
            divider: NSColor,
            foreground: NSColor = .secondaryLabelColor,
            font: NSFont = .systemFont(ofSize: 13),
            iconPointSize: CGFloat = 14,
            iconSpacing: CGFloat = 8,
            horizontalPadding: CGFloat = 16,
            menuSegmentWidth: CGFloat = 28,
            cornerRadius: CGFloat = 6,
            height: CGFloat = 30,
            disabledOpacity: CGFloat = 0.4
        ) {
            self.fill = fill
            self.hoveredFill = hoveredFill
            self.pressedFill = pressedFill
            self.stroke = stroke
            self.hoveredStroke = hoveredStroke
            self.divider = divider
            self.foreground = foreground
            self.font = font
            self.iconPointSize = iconPointSize
            self.iconSpacing = iconSpacing
            self.horizontalPadding = horizontalPadding
            self.menuSegmentWidth = menuSegmentWidth
            self.cornerRadius = cornerRadius
            self.height = height
            self.disabledOpacity = disabledOpacity
        }
    }
}
