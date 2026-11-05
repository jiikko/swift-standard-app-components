import AppKit

// `StandardSplitMenuButton` の AppKit 側: 枠付きの見た目の描画と、カーソルを乗せた区画・押している区画の追跡

/// 枠付きの見た目のとき、高さを `Border.height` に揃え、カーソルを乗せた区画と押している区画を覚えて描き直す
final class SplitMenuSegmentedControl: NSSegmentedControl {
    var border: StandardSplitMenuButton.Border? {
        didSet {
            invalidateIntrinsicContentSize()
            updateTrackingAreas()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    /// ⌄ の区画を置く側 (`StandardSplitMenuButton.MenuEdge`)。区画の番号はここから決まる (`segments`)
    var menuEdge: StandardSplitMenuButton.MenuEdge = .trailing {
        didSet { needsDisplay = true }
    }

    /// 今の区画の並び (主と ⌄)
    var segments: SplitMenuSegments {
        SplitMenuSegments(hasMenu: segmentCount > 1, menuEdge: menuEdge)
    }

    private(set) var hoveredSegment: Int? {
        didSet { if hoveredSegment != oldValue { needsDisplay = true } }
    }

    private(set) var pressedSegment: Int? {
        didSet { if pressedSegment != oldValue { needsDisplay = true } }
    }

    private var hoverTrackingArea: NSTrackingArea?

    /// 枠付きの見た目のときの押下の扱い。AppKit の区画の追跡は元の高さの中でしか押下を拾わず、`Border.height` に広げた上下の縁が
    /// 押せなかった (2026-11-01 に probe で確かめた。`cellSize` を上書きしても変わらない) ので、枠付きのときは自分で追跡する
    var primaryAction: (() -> Void)?
    /// 開くメニュー (無ければメニューを持たないボタン)
    var menuProvider: (() -> NSMenu?)?
    /// ⌄ の区画の押下でメニューの代わりに呼ぶもの (`ChevronPresentation.popover`)。nil ならメニューを開く
    var chevronAction: (() -> Void)?
    /// 主の区画の長押しでメニューの代わりに呼ぶもの (`ChevronPresentation.popover`)。nil ならメニューを開く
    var longPressAction: (() -> Void)?
    /// メニューを `point` (control の座標) に開く。テストでは差し替える (`popUp` はメニューを閉じるまで戻らない)
    var presentMenuAt: (NSMenu, NSPoint, SplitMenuSegmentedControl) -> Void = { menu, point, control in
        menu.popUp(positioning: nil, at: point, in: control)
    }

    /// 自分で追う押下 (クリック・長押し・⌄) を coordinator へつなぐ (枠付きのときに使う)。押せるかと項目の扱いは coordinator と同じ
    func connect(to coordinator: StandardSplitMenuButton.Coordinator, chevronPresentation: StandardSplitMenuButton.ChevronPresentation) {
        primaryAction = { [weak coordinator, weak self] in
            guard let coordinator, let self else { return }
            coordinator.handleClick(segment: coordinator.segments.action, in: self)
        }
        menuProvider = { [weak coordinator] in
            guard let coordinator, coordinator.isEnabled, !coordinator.items.isEmpty else { return nil }
            return coordinator.makeMenu()
        }
        // ⌄ の押下: ポップオーバーなら coordinator が出す (nil なら自分でメニューを開く)
        chevronAction = chevronPresentation == .popover ? { [weak coordinator, weak self] in
            guard let coordinator, let self, let menuSegment = coordinator.segments.menu else { return }
            coordinator.handleClick(segment: menuSegment, in: self)
        } : nil
        // 主の区画の長押し: ポップオーバーなら ⌄ のクリックと同じものを出す (nil なら自分でメニューを開く)
        longPressAction = chevronPresentation == .popover ? { [weak coordinator, weak self] in
            guard let coordinator, let self else { return }
            coordinator.presentItemsPopover(in: self)
        } : nil
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        if let border { size.height = border.height }
        return size
    }

    override var isEnabled: Bool {
        didSet {
            // 押せなくなった (押した直後に押せなくなるボタンなど) ら、カーソルを乗せた見た目を残さない
            if !isEnabled { hoveredSegment = nil }
            window?.invalidateCursorRects(for: self)
        }
    }

    /// 枠付きで押せる間は指のカーソル (自作のボタンと同じ)
    override func resetCursorRects() {
        super.resetCursorRects()
        if border != nil, isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // 右クリックのメニューは閉じるまで戻らない。閉じた後は mouseExited が届かないことがあるので、今の位置から取り直す
        super.rightMouseDown(with: event)
        if let window {
            updateHover(locationInWindow: window.mouseLocationOutsideOfEventStream)
        }
    }

    /// x 座標 (control の座標) が乗っている区画 (`SplitMenuSegments.segment(atX:width:menuWidth:)`)
    func segment(atX x: CGFloat) -> Int {
        let segments = segments
        let menuWidth = segments.menu.map { width(forSegment: $0) } ?? 0
        return segments.segment(atX: x, width: bounds.width, menuWidth: menuWidth)
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
        guard border != nil else {
            super.mouseDown(with: event)
            return
        }
        guard isEnabled else { return }
        let segment = segment(atX: convert(event.locationInWindow, from: nil).x)
        pressedSegment = segment
        display()
        if segment == segments.menu {
            // ⌄: 押した時点でメニューを開く (標準のプルダウンと同じ。押したまま項目まで動かして離しても決まる)。ポップオーバーなら coordinator が出す
            if let chevronAction {
                chevronAction()
            } else {
                openMenu(below: segment)
            }
        } else {
            trackActionSegment()
        }
        pressedSegment = nil
        // メニューを閉じた後はカーソルが外へ出ていても mouseExited が届かないことがあるので、今の位置から取り直す
        if let window {
            updateHover(locationInWindow: window.mouseLocationOutsideOfEventStream)
        }
    }

    /// 主の区画を押してから離すまでを追う。離したら主の操作 (外なら取り消し)、押し続けたらメニュー
    private func trackActionSegment() {
        let actionSegment = segments.action
        let tracker = SplitMenuPressTracker(hasMenu: menuProvider?() != nil)
        let start = Date()
        var isOver = true
        while let window {
            let remaining = tracker.hasMenu ? SplitMenuPressTracker.longPressDelay - Date().timeIntervalSince(start) : .infinity
            let next = window.nextEvent(
                matching: [.leftMouseUp, .leftMouseDragged],
                until: remaining.isFinite ? Date(timeIntervalSinceNow: max(remaining, 0)) : .distantFuture,
                inMode: .eventTracking,
                dequeue: true
            )
            var release = SplitMenuPressTracker.Release.notYet
            if let next {
                // 主の区画の上か (⌄ の区画の上で離しても主の操作にしない)
                let point = convert(next.locationInWindow, from: nil)
                isOver = bounds.contains(point) && segment(atX: point.x) == actionSegment
                if next.type == .leftMouseUp {
                    release = isOver ? .inside : .outside
                } else {
                    // 押したまま外へ出たら凹みを戻し、戻ったら凹ませる (変わったときだけ描き直す)
                    let pressed = isOver ? actionSegment : nil
                    if pressedSegment != pressed {
                        pressedSegment = pressed
                        display()
                    }
                }
            }
            switch tracker.outcome(elapsed: Date().timeIntervalSince(start), release: release, isOver: isOver) {
            case .pending:
                continue
            case .primary:
                primaryAction?()
            case .menu:
                if let longPressAction {
                    longPressAction()
                } else {
                    openMenu(below: actionSegment)
                }
            case .cancel:
                break
            }
            return
        }
    }

    /// `segment` の区画の左下にメニューを開く
    private func openMenu(below segment: Int) {
        guard let menu = menuProvider?() else { return }
        let frames = (cell as? LongPressHintSegmentedCell)?.segmentFrames(in: bounds, controlView: self) ?? [bounds]
        let frame = frames.indices.contains(segment) ? frames[segment] : bounds
        presentMenuAt(menu, NSPoint(x: frame.minX, y: isFlipped ? bounds.maxY + 4 : -4), self)
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

/// 主の区画の ⌄ の側の上の角 (⌄ が右なら右上、左なら左上) に小さな ▼ を描き、押し続けるとメニューが出ることを示す
/// (大きさと位置は 2026-11-01 のユーザー指定。左右は 2026-11-03 に、戻すボタンを左右対称に置くため ⌄ の側へ寄せた)。
/// 枠付きの見た目のときは、標準の灰色の塗りの代わりに枠・塗り・区画の間の縦線を描き、中身 (アイコン・文字) も `Border` の色で描く
final class LongPressHintSegmentedCell: NSSegmentedCell {
    static let triangleSize: CGFloat = 6.5
    static let trailingInset: CGFloat = 3
    static let topInset: CGFloat = 5
    /// 押している区画の中身を下げる量 (凹んで見せる)
    static let pressedContentOffset: CGFloat = 1

    private var hasMenu: Bool { segmentCount > 1 }

    private func menuEdge(of controlView: NSView?) -> StandardSplitMenuButton.MenuEdge {
        (controlView as? SplitMenuSegmentedControl)?.menuEdge ?? .trailing
    }

    private func segments(of controlView: NSView?) -> SplitMenuSegments {
        SplitMenuSegments(hasMenu: hasMenu, menuEdge: menuEdge(of: controlView))
    }

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
        let frames = segmentFrames(in: cellFrame, controlView: controlView)
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
            // 区画の間の線は右の区画 (番号 1) の左端
            let dividerX = frames[1].minX.rounded() + 0.5
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
        for (segment, frame) in segmentFrames(in: cellFrame, controlView: controlView).enumerated() {
            let offset = segment == control.pressedSegment ? Self.pressedContentOffset : 0
            let content = frame.offsetBy(dx: 0, dy: controlView.isFlipped ? offset : -offset)
            drawBorderedContent(segment, in: content, border: border, controlView: controlView)
        }
    }

    /// 区画の範囲 (番号の順 = 左から。`SplitMenuSegments.frames(in:menuWidth:)`)
    func segmentFrames(in cellFrame: NSRect, controlView: NSView?) -> [NSRect] {
        let segments = segments(of: controlView)
        return segments.frames(in: cellFrame, menuWidth: segments.menu.map { width(forSegment: $0) } ?? 0)
    }

    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        super.drawSegment(segment, inFrame: frame, with: controlView)
        if hasMenu, segment == segments(of: controlView).action {
            drawLongPressHint(
                in: frame, flipped: controlView.isFlipped, menuEdge: menuEdge(of: controlView),
                color: isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
            )
        }
    }

    /// 枠付きの見た目の中身: アイコンと名前を横に並べて真ん中に置く (`SplitMenuButtonLook.actionSegmentWidth` と同じ並べ方)
    private func drawBorderedContent(_ segment: Int, in frame: NSRect, border: StandardSplitMenuButton.Border, controlView: NSView) {
        let menuEdge = menuEdge(of: controlView)
        let title = label(forSegment: segment) ?? ""
        let icon = image(forSegment: segment).map { SplitMenuButtonLook.symbol($0, border: border, color: border.foreground) }
        let attributes: [NSAttributedString.Key: Any] = [.font: border.font, .foregroundColor: border.foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        let spacing = icon != nil && !title.isEmpty ? border.iconSpacing : 0
        let contentWidth = (icon?.size.width ?? 0) + spacing + titleSize.width
        let hint = hasMenu && segment == segments(of: controlView).action ? Self.triangleSize : 0
        // ▼ の分を ⌄ の側に取り、残りの真ん中に中身を置く
        var x = frame.minX + (menuEdge == .leading ? hint : 0) + ((frame.width - hint) - contentWidth) / 2
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
            drawLongPressHint(
                in: frame, flipped: controlView.isFlipped, menuEdge: menuEdge,
                color: border.foreground.withAlphaComponent(0.6)
            )
        }
    }

    private func drawLongPressHint(in frame: NSRect, flipped: Bool, menuEdge: StandardSplitMenuButton.MenuEdge, color: NSColor) {
        let size = Self.triangleSize
        // ⌄ の側の角に寄せる (⌄ が左なら左上)。`right` は ▼ の右端
        let right = menuEdge == .leading ? frame.minX + Self.trailingInset + size : frame.maxX - Self.trailingInset
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
