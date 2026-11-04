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
    private let items: [StandardSplitMenuButton.Item]
    private let onChoose: (Int) -> Void

    public init(items: [StandardSplitMenuButton.Item], onChoose: @escaping (Int) -> Void) {
        self.items = items
        self.onChoose = onChoose
    }

    public var body: some View {
        // ✓ とアイコンの列は、どれか 1 つでも持つときだけ取る (標準メニューと同じく、列の位置を全行で揃える)
        let showsCheck = items.contains(where: \.isChecked)
        let showsIcon = items.contains { $0.systemImage != nil }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                StandardPopoverMenuRow(item: item, showsCheck: showsCheck, showsIcon: showsIcon) {
                    onChoose(index)
                }
            }
        }
        .padding(6)
        .frame(minWidth: 140, alignment: .leading)
    }
}

private struct StandardPopoverMenuRow: View {
    let item: StandardSplitMenuButton.Item
    let showsCheck: Bool
    let showsIcon: Bool
    let choose: () -> Void

    @State private var isHovering = false

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
            .foregroundStyle(isHovering ? Color(nsColor: .selectedMenuItemTextColor) : Color(nsColor: .labelColor))
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(item.isChecked ? .isSelected : [])
    }
}
