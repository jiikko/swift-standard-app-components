import SwiftUI

/// `View.standardActionConfirmation(...)` に渡す confirmation dialog button。
///
/// `role` は SwiftUI の `ButtonRole` をそのまま公開する。破壊的操作は
/// `.destructive`、明示 cancel は `.cancel` を渡す。
public struct StandardActionButton {
    /// ボタンに表示する localized title。
    public let title: LocalizedStringResource
    /// SwiftUI `Button` に渡す role。通常ボタンなら `nil`。
    public let role: ButtonRole?
    /// タップ時に呼ぶ UI action。
    public let handler: @MainActor @Sendable () -> Void

    /// - Parameters:
    ///   - title: ボタンに表示する localized title。
    ///   - role: SwiftUI `ButtonRole`。通常ボタンなら `nil`。
    ///   - handler: タップ時に呼ぶ UI action。
    public init(
        _ title: LocalizedStringResource,
        role: ButtonRole? = nil,
        handler: @MainActor @Sendable @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.handler = handler
    }
}

private struct StandardActionConfirmation<Subject>: ViewModifier {
    @Binding private var isPresented: Bool
    private let title: LocalizedStringResource
    private let subject: Subject?
    private let primary: StandardActionButton?
    private let secondary: StandardActionButton?
    private let destructive: StandardActionButton?
    private let cancel: LocalizedStringResource
    private let message: (Subject) -> Text

    init(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subject: Subject?,
        primary: StandardActionButton?,
        secondary: StandardActionButton?,
        destructive: StandardActionButton?,
        cancel: LocalizedStringResource,
        message: @escaping (Subject) -> Text
    ) {
        _isPresented = isPresented
        self.title = title
        self.subject = subject
        self.primary = primary
        self.secondary = secondary
        self.destructive = destructive
        self.cancel = cancel
        self.message = message
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible,
            actions: {
                if subject != nil {
                    confirmationButton(primary)
                    confirmationButton(secondary)
                    confirmationButton(destructive)
                }

                Button(cancel, role: .cancel) {}
            },
            message: {
                if let subject {
                    message(subject)
                }
            }
        )
    }

    @ViewBuilder
    private func confirmationButton(_ button: StandardActionButton?) -> some View {
        if let button {
            Button(button.title, role: button.role) {
                button.handler()
            }
        }
    }
}

extension View {
    /// 標準的な action confirmation dialog を付与する。
    ///
    /// `subject` は表示時点の対象 entity を固定するための値。`subject == nil` の間は
    /// action button と message を出さず、cancel のみ表示する。実用上は
    /// `subject` を設定してから `isPresented = true` にする。
    public func standardActionConfirmation<Subject>(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subject: Subject?,
        primary: StandardActionButton? = nil,
        secondary: StandardActionButton? = nil,
        destructive: StandardActionButton? = nil,
        cancel: LocalizedStringResource = "Cancel",
        message: @escaping (Subject) -> Text
    ) -> some View {
        modifier(
            StandardActionConfirmation(
                isPresented: isPresented,
                title: title,
                subject: subject,
                primary: primary,
                secondary: secondary,
                destructive: destructive,
                cancel: cancel,
                message: message
            )
        )
    }
}
