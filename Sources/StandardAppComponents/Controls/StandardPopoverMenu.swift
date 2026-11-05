import AppKit
import SwiftUI

/// ポップオーバーに出す項目のリスト。macOS の標準メニューと同じ並び (✓・アイコン・名前) で、カーソルを乗せた行を選択の色で塗る。
///
/// `StandardSplitMenuButton(chevronPresentation: .popover)` が ⌄ のクリックで出す中身。consumer が自前の `.popover` に入れて、
/// 分割ボタン以外の場所 (自作の区画など) の見た目を揃えるのにも使う。項目を選ぶと `onChoose` に番号を渡す
/// (ポップオーバーを閉じるのは呼んだ側。閉じてから項目の操作を呼ぶ)。
///
/// 標準メニューと違い、開いた直後に ↑↓・Return では選べない (フルキーボードアクセスを切っていると、マウスで選ぶ)。
/// キーボードで選びたい consumer は `.menu` (標準メニュー) のままにする
public struct StandardPopoverMenu: View {
    /// 行の位置を測る座標 (この View の左上が原点。ポップオーバーの中身の左上と同じ)
    static let coordinateSpaceName = "StandardPopoverMenu"

    private let items: [StandardSplitMenuButton.Item]
    private let onChoose: (Int) -> Void
    @ObservedObject private var drag: StandardPopoverMenuDrag

    public init(items: [StandardSplitMenuButton.Item], onChoose: @escaping (Int) -> Void) {
        self.init(items: items, drag: StandardPopoverMenuDrag(), onChoose: onChoose)
    }

    /// `drag` は、開いたボタンを押したまま動かしている間の塗りと行の位置 (`SplitMenuPopoverPresenter` が持つ)
    init(items: [StandardSplitMenuButton.Item], drag: StandardPopoverMenuDrag, onChoose: @escaping (Int) -> Void) {
        self.items = items
        self.drag = drag
        self.onChoose = onChoose
    }

    public var body: some View {
        // ✓ とアイコンの列は、どれか 1 つでも持つときだけ取る (標準メニューと同じく、列の位置を全行で揃える)
        let showsCheck = items.contains(where: \.isChecked)
        let showsIcon = items.contains { $0.systemImage != nil }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                StandardPopoverMenuRow(
                    item: item, showsCheck: showsCheck, showsIcon: showsIcon,
                    isDragTracking: drag.isTracking, isDragHighlighted: drag.highlighted == index
                ) {
                    onChoose(index)
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.coordinateSpaceName)) } action: { frame in
                    drag.rowFrames[index] = frame
                }
            }
        }
        .padding(6)
        .frame(minWidth: 140, alignment: .leading)
        .coordinateSpace(.named(Self.coordinateSpaceName))
    }
}

/// ポップオーバーを開いたボタンを押したまま動かしている間の状態。押している間のマウスはボタンのウィンドウに届き、行の `onHover` は
/// 動かないので、ボタンの側 (`SplitMenuSegmentedControl`) がカーソルの位置を渡し、ここで塗る行を決める
@MainActor
final class StandardPopoverMenuDrag: ObservableObject {
    /// 押したまま動かしている間。この間は `onHover` の代わりに `highlighted` で塗る
    @Published var isTracking = false
    /// カーソルの下の行
    @Published var highlighted: Int?
    /// 行の範囲 (`StandardPopoverMenu.coordinateSpaceName` の座標)。描くたびに測り直す
    var rowFrames: [Int: CGRect] = [:]

    /// `point` (`StandardPopoverMenu.coordinateSpaceName` の座標) が乗っている行
    func row(at point: CGPoint) -> Int? {
        rowFrames.first { $0.value.contains(point) }?.key
    }
}

private struct StandardPopoverMenuRow: View {
    let item: StandardSplitMenuButton.Item
    let showsCheck: Bool
    let showsIcon: Bool
    /// 押したまま動かしている間は、カーソルを乗せたか (`onHover` は動かない) の代わりに `isDragHighlighted` で塗る
    let isDragTracking: Bool
    let isDragHighlighted: Bool
    let choose: () -> Void

    @State private var isHovering = false

    private var isHighlighted: Bool { isDragTracking ? isDragHighlighted : isHovering }

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 6) {
                if showsCheck {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(item.isChecked ? 1 : 0)
                        .frame(width: 12)
                }
                if showsIcon {
                    Group {
                        if let systemImage = item.systemImage {
                            Image(systemName: systemImage)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 16)
                }
                Text(verbatim: item.title)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isHighlighted ? Color(nsColor: .selectedMenuItemTextColor) : Color(nsColor: .labelColor))
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHighlighted ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(item.isChecked ? .isSelected : [])
    }
}
