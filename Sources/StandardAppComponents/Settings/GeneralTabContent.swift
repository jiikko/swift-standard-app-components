import SwiftUI

struct GeneralTabContent: View {
    let contract: GeneralTabContract

    var body: some View {
        Form {
            Section {
                contract.appearance
            } header: {
                Text("Appearance")
            }

            Section {
                contract.language
            } header: {
                Text("Language")
            }

            contract.appSections
        }
        .formStyle(.grouped)
    }
}
