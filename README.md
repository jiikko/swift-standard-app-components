# StandardAppComponents

jiikko の macOS アプリ群が共通で使う **UI 規約** と **共通振る舞い** を提供する Swift Package。

## 目的

各アプリで「設定ウィンドウの構造」「ESC で閉じる等の標準キー操作」「メニューバー常駐 / Login Item 等のシステム統合」がバラバラになるのを防ぐ。

- **必須規約**（外観・言語セクション、`TabView` ベース、ESC で閉じる等）は型と modifier で強制
- **opt-in 機能の足場**（メニューバー、Login Item、About 等）は採用アプリだけが組み込む
- 未実装スロットはコンパイル時 / DEBUG 時 `assertionFailure` / Release 時の警告ビューで実装者が気付ける

## モジュール構成（予定）

| サブディレクトリ | 内容 |
|------------------|------|
| `Settings/` | `SettingsWindow` / `GeneralTabContract` |
| `MenuBar/` | `MenuBarAgent` / `MenuBarContract` / `MenuBarVisibilitySection` |
| `Lifecycle/` | `LaunchAtLoginContract` / `AboutContract` |
| `Behaviors/` | `standardSettingsBehaviors` / `autoSaveWindowFrame` 等 |
| `Internal/` | `NotImplementedSlot` 等 |

## 利用方法（予定）

```swift
// アプリの Package.swift
.package(url: "https://github.com/jiikko/swift-standard-app-components.git", from: "0.1.0")

// アプリのコード
import StandardAppComponents

@main
struct MyApp: App {
    var body: some Scene {
        Settings {
            SettingsWindow {
                GeneralTabContract(
                    appearance: { AppearanceSection() },
                    language:   { LanguageSection() }
                )
            } appTabs: {
                AppTab("詳細") { AdvancedTab() }
            }
        }
    }
}
```

## 開発

```bash
swift build
swift test
```

## ステータス

最小スケルトン。設計は [my-products/issues/002-feat-ui-catalog.md](https://github.com/jiikko/my-products) を参照。

## 対象アプリ

Swift 系 macOS アプリ（DualNoteApp / ThumbnailThumb / SnapTrim / fdup-macos / vlc-multi-video-player / baby-note）。Electron 系は対象外。
