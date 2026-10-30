import SwiftUI

/// タブの状態 (`label` / `tabOverlay` / `canClose` に渡す)
public struct StandardTabState: Equatable, Sendable {
    public let isActive: Bool
    public let isHovered: Bool
    public let isDragging: Bool
    /// 閉じて縮めている途中 (この item は consumer の一覧にもう無い)
    public let isClosing: Bool
}

/// `StandardTabStrip` の寸法・動き・文言
public struct StandardTabStripConfiguration: Sendable {
    /// 閉じたときの動き
    public enum CloseAnimation: Sendable {
        /// 閉じたタブを並びに残したまま幅を 0 まで縮め、右のタブをその端について詰めさせる (Chrome と同じ)
        case collapse
        /// すぐ並びから外す
        case none
    }

    /// + の置き方
    public enum AddButtonPlacement: Sendable {
        /// タブの直後 (溢れたらタブと一緒にスクロールする)
        case inline
        /// 収まる間はタブの直後、溢れたらスクロールの外の右端 (タブが多くても + が見える)
        case pinnedWhenOverflowing
    }

    public var tabWidth: ClosedRange<CGFloat>
    public var tabHeight: CGFloat
    public var closeAnimation: CloseAnimation
    public var collapseAnimation: Animation
    public var addButtonPlacement: AddButtonPlacement
    /// × の help。nil なら lib の「Close Tab」
    public var closeHelp: String?
    /// + の help。nil なら lib の「New Tab」
    public var addHelp: String?

    public init(
        tabWidth: ClosedRange<CGFloat> = 72...170,
        tabHeight: CGFloat = 30,
        closeAnimation: CloseAnimation = .collapse,
        collapseAnimation: Animation = .easeInOut(duration: 0.2),
        addButtonPlacement: AddButtonPlacement = .inline,
        closeHelp: String? = nil,
        addHelp: String? = nil
    ) {
        self.tabWidth = tabWidth
        self.tabHeight = tabHeight
        self.closeAnimation = closeAnimation
        self.collapseAnimation = collapseAnimation
        self.addButtonPlacement = addButtonPlacement
        self.closeHelp = closeHelp
        self.addHelp = addHelp
    }

    /// タブの右端から × の外側までの幅。`tabOverlay` で × を避けるときに右をこれだけ空ける
    public static var closeButtonReservedWidth: CGFloat { horizontalPadding + closeBoxSize }

    static let horizontalPadding: CGFloat = 10
    static let closeBoxSize: CGFloat = 14
    static let contentSpacing: CGFloat = 6
    static let dragPayload = "standard-tab-strip"

    static var defaultCloseHelp: String {
        String(localized: "Close Tab", bundle: .module)
    }

    static var defaultAddHelp: String {
        String(localized: "New Tab", bundle: .module)
    }
}

/// 選んでいるタブの形 (Chrome のタブ)。上の角を丸め、下端の両脇を外へ反らせて本体へつなぐ。
/// 反りは `rect` の外へ `flare` だけはみ出す (並びの両端では `StandardTabStrip` の横の余白がそれを受ける)
public struct StandardTabShape: Shape {
    public static let defaultFlare: CGFloat = 6

    public var cornerRadius: CGFloat
    public var flare: CGFloat

    public init(cornerRadius: CGFloat = 8, flare: CGFloat = StandardTabShape.defaultFlare) {
        self.cornerRadius = cornerRadius
        self.flare = flare
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - flare, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - flare), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - flare))
        path.addQuadCurve(to: CGPoint(x: rect.maxX + flare, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// `isEnabled` のときだけ drag source にする (名前の入力中などで止める)
struct TabDragSource: ViewModifier {
    let isEnabled: Bool
    let provider: () -> NSItemProvider

    func body(content: Content) -> some View {
        if isEnabled {
            content.onDrag(provider)
        } else {
            content
        }
    }
}
