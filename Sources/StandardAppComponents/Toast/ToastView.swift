import SwiftUI

// MARK: - Toast View

/// 個別のトースト通知を表示する pure UI View。`ToastContainerView` から
/// 呼ばれる前提だが、テスト・preview から直接使うことも可能。
public struct ToastView: View {
    private enum Layout {
        static let contentSpacing: CGFloat = 12
        static let iconFontSize: CGFloat = 18
        static let textSpacing: CGFloat = 2
        static let titleFontSize: CGFloat = 13
        static let messageFontSize: CGFloat = 12
        static let messageOpacity: Double = 0.9
        static let messageLineLimit: Int = 2
        static let spacerMinLength: CGFloat = 8
        static let actionButtonFontSize: CGFloat = 12
        static let actionButtonHorizontalPadding: CGFloat = 12
        static let actionButtonVerticalPadding: CGFloat = 6
        static let actionButtonCornerRadius: CGFloat = 4
        static let actionButtonBackgroundOpacity: Double = 0.2
        static let closeButtonFontSize: CGFloat = 12
        static let closeButtonOpacity: Double = 0.8
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 10
        static let shadowOpacity: Double = 0.2
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 4
    }

    private let toast: Toast
    private let onDismiss: () -> Void

    /// - Parameters:
    ///   - toast: 表示する Toast。
    ///   - onDismiss: 閉じるボタン or アクションボタンが押された時に呼ばれる。
    ///     呼び出し側で `manager.dismiss()` を呼ぶことを想定。
    public init(toast: Toast, onDismiss: @escaping () -> Void) {
        self.toast = toast
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: Layout.contentSpacing) {
            // アイコン
            Image(systemName: toast.style.iconName)
                .font(.system(size: Layout.iconFontSize, weight: .semibold))
                .foregroundStyle(toast.style.foregroundColor)

            // テキスト
            VStack(alignment: .leading, spacing: Layout.textSpacing) {
                Text(toast.title)
                    .font(.system(size: Layout.titleFontSize, weight: .semibold))
                    .foregroundStyle(toast.style.foregroundColor)

                if let message = toast.message {
                    Text(message)
                        .font(.system(size: Layout.messageFontSize))
                        .foregroundStyle(toast.style.foregroundColor.opacity(Layout.messageOpacity))
                        .lineLimit(Layout.messageLineLimit)
                }
            }

            Spacer(minLength: Layout.spacerMinLength)

            // アクションボタン (オプション)
            if let action = toast.action {
                Button {
                    action.handler()
                    onDismiss()
                } label: {
                    Text(action.title)
                        .font(.system(size: Layout.actionButtonFontSize, weight: .medium))
                        .foregroundStyle(toast.style.foregroundColor)
                        .padding(.horizontal, Layout.actionButtonHorizontalPadding)
                        .padding(.vertical, Layout.actionButtonVerticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.actionButtonCornerRadius)
                                .fill(Color.white.opacity(Layout.actionButtonBackgroundOpacity))
                        )
                }
                .buttonStyle(.plain)
            }

            // 閉じるボタン
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: Layout.closeButtonFontSize, weight: .semibold))
                    .foregroundStyle(toast.style.foregroundColor.opacity(Layout.closeButtonOpacity))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(toast.style.backgroundColor)
                .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, x: 0, y: Layout.shadowY)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(toast.accessibilityLabel)
        .accessibilityAddTraits(toast.action == nil ? .isStaticText : [])
    }
}
