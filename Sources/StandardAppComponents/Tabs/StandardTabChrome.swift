import AppKit
import SwiftUI

/// タブ 1 枚の見た目 (中身・×・塗り・区切り線)。押す・ドラッグ・hover の受け方は `StandardTabStrip` が外側に付ける
struct StandardTabChrome<Content: View>: View {
    let content: Content
    let isActive: Bool
    let isHovered: Bool
    let isDragging: Bool
    /// どれかのタブをドラッグ中 (× を隠して押せなくする。ドラッグしているタブが閉じて消える形を作らない)
    let isAnyDragging: Bool
    let showsClose: Bool
    let separatorAfter: Bool
    let selectedFill: Color
    let configuration: StandardTabStripConfiguration
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: StandardTabStripConfiguration.contentSpacing) {
            content
            closeButton
                // hover の時だけ見せる。場所は常に確保して、出し入れで題名が動かないようにする
                .opacity(showsClose && isHovered && !isAnyDragging ? 1 : 0)
                .disabled(!showsClose || isAnyDragging)
        }
        // ドラッグ中のタブは中身だけを薄くする (塗りまで薄くすると、本体との境の線が透けてつながりが切れる)
        .opacity(isDragging ? 0.45 : 1)
        .padding(.horizontal, StandardTabStripConfiguration.horizontalPadding)
        .frame(minWidth: configuration.tabWidth.lowerBound, maxWidth: configuration.tabWidth.upperBound)
        .frame(height: configuration.tabHeight)
        .background {
            if isActive {
                StandardTabShape().fill(selectedFill)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.06))
                    .padding(.vertical, 3)
            }
        }
        // 隣り合う選んでいないタブの間にだけ細い区切り線 (選んでいるタブの塗りと地続きに見せるため、その左右には引かない)
        .overlay(alignment: .trailing) {
            if separatorAfter {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
                    .padding(.vertical, 8)
            }
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.secondary)
                .frame(width: StandardTabStripConfiguration.closeBoxSize, height: StandardTabStripConfiguration.closeBoxSize)
                .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 3))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(configuration.closeHelp ?? StandardTabStripConfiguration.defaultCloseHelp)
        .accessibilityLabel(Text("Close Tab", bundle: .module))
    }
}

/// 閉じて縮めている途中のタブ。押せない。中身は元の幅のまま左に寄せ、右端から切り取って隠す
/// (中身ごと縮めると題名が詰め直されて「…」が動いて見える)
struct StandardClosingTabChrome<Content: View>: View {
    let content: Content
    let width: CGFloat
    let isCollapsed: Bool
    let configuration: StandardTabStripConfiguration

    var body: some View {
        HStack(spacing: StandardTabStripConfiguration.contentSpacing) {
            content
            // 生きているタブの × の場所と同じ幅を空け、題名の位置を閉じる前と揃える
            Color.clear
                .frame(width: StandardTabStripConfiguration.closeBoxSize, height: StandardTabStripConfiguration.closeBoxSize)
        }
        .padding(.horizontal, StandardTabStripConfiguration.horizontalPadding)
        .frame(width: width, height: configuration.tabHeight)
        .frame(width: isCollapsed ? 0 : width, alignment: .leading)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
