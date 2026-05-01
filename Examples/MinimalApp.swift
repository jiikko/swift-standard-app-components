// 最小サンプル: SettingsWindow を採用したアプリの骨格。
// このファイルはビルド対象には入っていない（参照用）。
//
// 各アプリの SPM 依存に
//   .package(url: "git@github.com:jiikko/swift-standard-app-components.git", branch: "master")
// を追加し、target dependencies に "StandardAppComponents" を含めて使う。

import SwiftUI
import StandardAppComponents

@main
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsWindow(
                general: GeneralTabContract(
                    appearance: { AppearanceSection() },
                    language:   { LanguageSection() }
                    // appSections は省略可（任意）
                )
            )
        }
    }
}

private struct ContentView: View {
    var body: some View {
        Text("Hello")
            .frame(minWidth: 320, minHeight: 200)
    }
}

// 各アプリが実装する外観セクション
private struct AppearanceSection: View {
    @State private var mode: Int = 0
    var body: some View {
        Picker("Mode", selection: $mode) {
            Text("System").tag(0)
            Text("Light").tag(1)
            Text("Dark").tag(2)
        }
        .pickerStyle(.segmented)
    }
}

// 各アプリが実装する言語セクション
private struct LanguageSection: View {
    @State private var language: String = "ja"
    var body: some View {
        Picker("Language", selection: $language) {
            Text("日本語").tag("ja")
            Text("English").tag("en")
        }
    }
}

// 渡し忘れた場合のコンパイルエラー例（コメントアウトを外すとコンパイルエラー）:
//
// SettingsWindow(
//     general: GeneralTabContract(
//         appearance: { AppearanceSection() }
//         // language を渡し忘れる -> Missing argument for parameter 'language' in call
//     )
// )
