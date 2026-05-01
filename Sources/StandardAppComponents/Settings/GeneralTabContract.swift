import SwiftUI

public struct GeneralTabContract {
    let appearance: AnyView
    let language: AnyView
    let appSections: AnyView

    public init<Appearance: View, Language: View, AppSections: View>(
        @ViewBuilder appearance: () -> Appearance,
        @ViewBuilder language: () -> Language,
        @ViewBuilder appSections: () -> AppSections = { EmptyView() }
    ) {
        self.appearance = AnyView(appearance())
        self.language = AnyView(language())
        self.appSections = AnyView(appSections())
    }
}
