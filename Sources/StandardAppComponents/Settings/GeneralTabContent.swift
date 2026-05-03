import SwiftUI

struct GeneralTabContent: View {
    let contract: GeneralTabContract

    var body: some View {
        Form {
            Section {
                // Form.formStyle(.grouped) の row はデフォルトでコンテンツを中央寄せする
                // 挙動があり、consumer が毎回 .frame(maxWidth: .infinity, alignment: .leading) を
                // 書かないと崩れて見える。Form を採用しているのは lib 側の選択なので、
                // 落とし穴の吸収も lib の責務として slot 流し込み時に leading 揃えを自動で当てる。
                // alignment を変えたい slot は consumer 側で .frame(alignment:) を再指定すれば override 可能。
                contract.appearance
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text("Appearance", bundle: .module)
            }

            Section {
                contract.language
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text("Language", bundle: .module)
            }

            // appSections は consumer 自身の Section 群を含むため leading frame は当てない
            // (Section に直接 .frame を当てると Form の構造解析を邪魔する可能性がある)。
            contract.appSections
        }
        .formStyle(.grouped)
    }
}
