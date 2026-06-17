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
    private let configuration: StandardActionConfirmationConfiguration
    private let cancel: Text
    private let message: (Subject) -> Text

    init(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subject: Subject?,
        primary: StandardActionButton?,
        secondary: StandardActionButton?,
        destructive: StandardActionButton?,
        cancel: Text,
        message: @escaping (Subject) -> Text
    ) {
        _isPresented = isPresented
        self.title = title
        self.subject = subject
        configuration = StandardActionConfirmationConfiguration(
            hasSubject: subject != nil,
            primary: primary,
            secondary: secondary,
            destructive: destructive
        )
        self.cancel = cancel
        self.message = message
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible,
            actions: {
                if configuration.showsSubjectActions {
                    let buttons = configuration.actionButtons
                    ForEach(buttons.indices, id: \.self) { index in
                        let button = buttons[index]
                        Button(button.title, role: button.role) {
                            button.handler()
                        }
                    }
                }

                Button(role: .cancel) {} label: {
                    cancel
                }
            },
            message: {
                if configuration.showsMessage, let subject {
                    message(subject)
                }
            }
        )
    }
}

struct StandardActionConfirmationConfiguration {
    let hasSubject: Bool
    private let primary: StandardActionButton?
    private let secondary: StandardActionButton?
    private let destructive: StandardActionButton?

    init(
        hasSubject: Bool,
        primary: StandardActionButton?,
        secondary: StandardActionButton?,
        destructive: StandardActionButton?
    ) {
        self.hasSubject = hasSubject
        self.primary = primary
        self.secondary = secondary
        self.destructive = destructive
    }

    var showsSubjectActions: Bool {
        hasSubject
    }

    var showsMessage: Bool {
        hasSubject
    }

    var actionButtons: [StandardActionButton] {
        guard hasSubject else { return [] }
        return [primary, secondary, destructive].compactMap { $0 }
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
        message: @escaping (Subject) -> Text
    ) -> some View {
        standardActionConfirmation(
            isPresented: isPresented,
            title: title,
            subject: subject,
            primary: primary,
            secondary: secondary,
            destructive: destructive,
            cancel: Text("Cancel", bundle: .module),
            message: message
        )
    }

    /// 標準的な action confirmation dialog を、custom cancel label 付きで付与する。
    public func standardActionConfirmation<Subject>(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subject: Subject?,
        primary: StandardActionButton? = nil,
        secondary: StandardActionButton? = nil,
        destructive: StandardActionButton? = nil,
        cancel: Text,
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
