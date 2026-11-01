import AppKit

// `StandardSplitMenuButton` の AppKit 側: 枠付きの見た目の描画と、カーソルを乗せた区画・押している区画の追跡

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

    /// 枠付きの見た目の左の区画の幅 (中身 + 左右の余白。メニューがあれば ▼ の分も足す)
    static func actionSegmentWidth(title: String, image: NSImage?, border: StandardSplitMenuButton.Border, hasMenu: Bool) -> CGFloat {
        let titleWidth = (title as NSString).size(withAttributes: [.font: border.font]).width
        let iconWidth = image.map { symbol($0, border: border, color: border.foreground).size.width } ?? 0
        let spacing = image != nil && !title.isEmpty ? border.iconSpacing : 0
        let hint = hasMenu ? LongPressHintSegmentedCell.triangleSize : 0
        return (border.horizontalPadding * 2 + iconWidth + spacing + titleWidth + hint).rounded(.up)
    }

    /// SF Symbols の絵を、枠付きの見た目の大きさと色にする
    static func symbol(_ image: NSImage, border: StandardSplitMenuButton.Border, color: NSColor) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: border.iconPointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return image.withSymbolConfiguration(configuration) ?? image
    }
}

/// 枠付きの見た目のとき、高さを `Border.height` に揃え、カーソルを乗せた区画と押している区画を覚えて描き直す
final class SplitMenuSegmentedControl: NSSegmentedControl {
    var border: StandardSplitMenuButton.Border? {
        didSet {
            invalidateIntrinsicContentSize()
            updateTrackingAreas()
            needsDisplay = true
        }
    }

    private(set) var hoveredSegment: Int? {
        didSet { if hoveredSegment != oldValue { needsDisplay = true } }
    }

    private(set) var pressedSegment: Int? {
        didSet { if pressedSegment != oldValue { needsDisplay = true } }
    }

    private var hoverTrackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        if let border { size.height = border.height }
        return size
    }

    /// x 座標 (control の座標) が乗っている区画。区画が 2 つで右の区画の幅より右なら ⌄ の区画
    func segment(atX x: CGFloat) -> Int {
        guard segmentCount > StandardSplitMenuButton.menuSegment else { return StandardSplitMenuButton.actionSegment }
        return x >= bounds.width - width(forSegment: StandardSplitMenuButton.menuSegment)
            ? StandardSplitMenuButton.menuSegment
            : StandardSplitMenuButton.actionSegment
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        hoverTrackingArea = nil
        guard border != nil else {
            hoveredSegment = nil
            return
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHover(locationInWindow: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHover(locationInWindow: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hoveredSegment = nil
    }

    override func mouseDown(with event: NSEvent) {
        guard border != nil, isEnabled else {
            super.mouseDown(with: event)
            return
        }
        pressedSegment = segment(atX: convert(event.locationInWindow, from: nil).x)
        display()
        // 押している間の追跡 (長押しのメニュー・⌄ のメニューを含む) は離すまでここで戻らない
        super.mouseDown(with: event)
        pressedSegment = nil
        // メニューを閉じた後はカーソルが外へ出ていても mouseExited が届かないことがあるので、今の位置から取り直す
        if let window {
            updateHover(locationInWindow: window.mouseLocationOutsideOfEventStream)
        }
    }

    func updateHover(locationInWindow: NSPoint) {
        guard border != nil, isEnabled else {
            hoveredSegment = nil
            return
        }
        let point = convert(locationInWindow, from: nil)
        hoveredSegment = bounds.contains(point) ? segment(atX: point.x) : nil
    }
}

/// 左の区画の右上に小さな ▼ を描き、押し続けるとメニューが出ることを示す (大きさと位置は 2026-11-01 のユーザー指定)。
/// 枠付きの見た目のときは、標準の灰色の塗りの代わりに枠・塗り・区画の間の縦線を描き、中身 (アイコン・文字) も `Border` の色で描く
final class LongPressHintSegmentedCell: NSSegmentedCell {
    static let triangleSize: CGFloat = 6.5
    static let trailingInset: CGFloat = 3
    static let topInset: CGFloat = 5
    /// 押している区画の中身を下げる量 (凹んで見せる)
    static let pressedContentOffset: CGFloat = 1

    private var hasMenu: Bool { segmentCount > StandardSplitMenuButton.menuSegment }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard let control = controlView as? SplitMenuSegmentedControl, let border = control.border else {
            super.draw(withFrame: cellFrame, in: controlView)
            return
        }
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        if !control.isEnabled {
            context?.setAlpha(border.disabledOpacity)
            context?.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        let rect = cellFrame.insetBy(dx: 0.5, dy: 0.5)
        let shape = NSBezierPath(roundedRect: rect, xRadius: border.cornerRadius, yRadius: border.cornerRadius)
        border.fill.setFill()
        shape.fill()
        let frames = segmentFrames(in: cellFrame)
        for (segment, frame) in frames.enumerated() {
            guard let fill = SplitMenuButtonLook.segmentFill(
                segment, hovered: control.hoveredSegment, pressed: control.pressedSegment, border: border
            ) else { continue }
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            fill.setFill()
            frame.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        SplitMenuButtonLook.stroke(hovered: control.hoveredSegment, pressed: control.pressedSegment, border: border).setStroke()
        shape.lineWidth = 1
        shape.stroke()
        if hasMenu {
            let dividerX = frames[StandardSplitMenuButton.menuSegment].minX.rounded() + 0.5
            let divider = NSBezierPath()
            let dividerHalf = min(9, cellFrame.height / 2 - 6)
            divider.move(to: NSPoint(x: dividerX, y: cellFrame.midY - dividerHalf))
            divider.line(to: NSPoint(x: dividerX, y: cellFrame.midY + dividerHalf))
            divider.lineWidth = 1
            border.divider.setStroke()
            divider.stroke()
        }
        drawInterior(withFrame: cellFrame, in: controlView)
        if !control.isEnabled {
            context?.endTransparencyLayer()
        }
        context?.restoreGState()
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard let control = controlView as? SplitMenuSegmentedControl, let border = control.border else {
            super.drawInterior(withFrame: cellFrame, in: controlView)
            return
        }
        // 標準の灰色の塗りを描かず、中身を `Border` の色で描く。押している区画は中身を少し下げ、凹んで見せる
        for (segment, frame) in segmentFrames(in: cellFrame).enumerated() {
            let offset = segment == control.pressedSegment ? Self.pressedContentOffset : 0
            let content = frame.offsetBy(dx: 0, dy: controlView.isFlipped ? offset : -offset)
            drawBorderedContent(segment, in: content, border: border, flipped: controlView.isFlipped)
        }
    }

    /// 区画の範囲。区画が 2 つなら右の区画は固定の幅、左は残り (`SplitMenuSegmentedControl.segment(atX:)` と同じ分け方)
    func segmentFrames(in cellFrame: NSRect) -> [NSRect] {
        guard hasMenu else { return [cellFrame] }
        let menuWidth = width(forSegment: StandardSplitMenuButton.menuSegment)
        var left = cellFrame
        left.size.width -= menuWidth
        var right = cellFrame
        right.origin.x = cellFrame.maxX - menuWidth
        right.size.width = menuWidth
        return [left, right]
    }

    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        super.drawSegment(segment, inFrame: frame, with: controlView)
        if segment == StandardSplitMenuButton.actionSegment, hasMenu {
            drawLongPressHint(in: frame, flipped: controlView.isFlipped, color: isEnabled ? .secondaryLabelColor : .tertiaryLabelColor)
        }
    }

    /// 枠付きの見た目の中身: アイコンと名前を横に並べて真ん中に置く (`SplitMenuButtonLook.actionSegmentWidth` と同じ並べ方)
    private func drawBorderedContent(_ segment: Int, in frame: NSRect, border: StandardSplitMenuButton.Border, flipped: Bool) {
        let title = label(forSegment: segment) ?? ""
        let icon = image(forSegment: segment).map { SplitMenuButtonLook.symbol($0, border: border, color: border.foreground) }
        let attributes: [NSAttributedString.Key: Any] = [.font: border.font, .foregroundColor: border.foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        let spacing = icon != nil && !title.isEmpty ? border.iconSpacing : 0
        let contentWidth = (icon?.size.width ?? 0) + spacing + titleSize.width
        let hint = segment == StandardSplitMenuButton.actionSegment && hasMenu ? Self.triangleSize : 0
        var x = frame.minX + ((frame.width - hint) - contentWidth) / 2
        if let icon {
            icon.draw(
                in: NSRect(x: x, y: frame.midY - icon.size.height / 2, width: icon.size.width, height: icon.size.height),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil
            )
            x += icon.size.width + spacing
        }
        if !title.isEmpty {
            (title as NSString).draw(at: NSPoint(x: x, y: frame.midY - titleSize.height / 2), withAttributes: attributes)
        }
        if hint > 0 {
            drawLongPressHint(in: frame, flipped: flipped, color: border.foreground.withAlphaComponent(0.6))
        }
    }

    private func drawLongPressHint(in frame: NSRect, flipped: Bool, color: NSColor) {
        let size = Self.triangleSize
        let right = frame.maxX - Self.trailingInset
        let top = flipped ? frame.minY + Self.topInset : frame.maxY - Self.topInset
        let bottom = flipped ? top + size * 0.8 : top - size * 0.8
        let path = NSBezierPath()
        path.move(to: NSPoint(x: right - size, y: top))
        path.line(to: NSPoint(x: right, y: top))
        path.line(to: NSPoint(x: right - size / 2, y: bottom))
        path.close()
        color.setFill()
        path.fill()
    }
}
