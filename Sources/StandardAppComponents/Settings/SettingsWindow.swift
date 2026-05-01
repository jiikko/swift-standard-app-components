import SwiftUI

public struct SettingsWindow<AppTabs: View>: View {
    private let general: GeneralTabContract
    private let appTabs: () -> AppTabs

    public init(
        general: GeneralTabContract,
        @ViewBuilder appTabs: @escaping () -> AppTabs = { EmptyView() }
    ) {
        self.general = general
        self.appTabs = appTabs
    }

    public var body: some View {
        TabView {
            GeneralTabContent(contract: general)
                .tabItem { Label("General", systemImage: "gearshape") }

            appTabs()
        }
    }
}
