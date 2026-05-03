import SwiftUI

struct GeneralTabContent: View {
    let contract: GeneralTabContract

    var body: some View {
        Form {
            // 各 slot は SwiftUI の Form/grouped が提供する自然な「label 左 / field 右」
            // レイアウトに任せる。consumer は次のいずれかで標準 macOS 設定 UI と揃う:
            //
            //   Picker("テーマ", selection: ...) { ... }   // label 左 / segmented 右
            //   Toggle("ログイン時に開く", isOn: ...)         // label 左 / switch 右
            //   LabeledContent("バージョン") { Text(...) }  // 任意の field
            //
            // `.labelsHidden()` を当てたり label を `EmptyView` にすると field が左寄せに
            // 崩れて非標準の見た目になるため避ける。複雑な行 (HStack で複数コントロールを
            // 並べる等) を載せる場合は consumer 側で row 全体に `.frame(maxWidth: .infinity,
            // alignment: .leading)` を当てて整えること。
            Section {
                contract.appearance
            } header: {
                Text("Appearance", bundle: .module)
            }

            Section {
                contract.language
            } header: {
                Text("Language", bundle: .module)
            }

            // appSections は consumer 自身の Section 群を含むため、ここでは row 装飾を加えない
            // (Section に直接 .frame を当てると Form の構造解析を邪魔する可能性がある)。
            contract.appSections
        }
        .formStyle(.grouped)
    }
}
