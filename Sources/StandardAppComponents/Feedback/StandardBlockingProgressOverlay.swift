import SwiftUI

private struct StandardBlockingProgressOverlay: ViewModifier {
    @Binding private var isPresented: Bool
    private let title: LocalizedStringResource
    private let subtitle: LocalizedStringResource?
    private let onCancel: (@MainActor @Sendable () -> Void)?

    init(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource?,
        onCancel: (@MainActor @Sendable () -> Void)?
    ) {
        _isPresented = isPresented
        self.title = title
        self.subtitle = subtitle
        self.onCancel = onCancel
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented)

            if isPresented {
                overlay
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isPresented)
    }

    private var overlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if let onCancel {
                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 28)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(radius: 18, y: 8)
            .accessibilityElement(children: .combine)
        }
        .allowsHitTesting(true)
    }
}

extension View {
    /// 処理中に背面操作を止める標準 progress overlay を付与する。
    ///
    /// 長時間処理・同期・import など、consumer 側で「背面操作を止める」判断が済んだ
    /// 場合だけ使う。単なる軽い完了通知や復旧可能なエラーには Toast を使う。
    public func standardBlockingProgressOverlay(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        onCancel: (@MainActor @Sendable () -> Void)? = nil
    ) -> some View {
        modifier(
            StandardBlockingProgressOverlay(
                isPresented: isPresented,
                title: title,
                subtitle: subtitle,
                onCancel: onCancel
            )
        )
    }
}
