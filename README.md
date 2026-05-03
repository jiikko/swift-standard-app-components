# StandardAppComponents

Personal SPM. macOS アプリ向けの再利用可能な標準コンポーネント / モディファイア集。

## Components

### Settings

| 型 | 役割 |
|----|------|
| `SettingsWindow` | macOS Settings シーン本体。General タブ + 任意の app タブを `TabView` で構成。`width` / `heights` (per-tab) / `defaultHeight` を受け取り、タブ切り替え時に高さがアニメーション付きで遷移する。`SettingsWindow.generalTabId` で General タブの tag 定数を公開。 |
| `GeneralTabContract` | General タブの「Appearance / Language / アプリ独自セクション」スロット契約。consumer は各 slot に View を渡すだけで General タブが組み上がる。 |

### Behaviors (`View` extension / `NSViewRepresentable`)

| API | 役割 |
|-----|------|
| `View.applyAppAppearance(_ scheme: ColorScheme?)` | アプリ全体の外観 (light / dark / system) を切り替える。`.preferredColorScheme` だけでは追従しない `Settings` × `Form.formStyle(.grouped)` の罠を吸収するため、`NSApp.appearance` と全 `NSWindow.appearance` も同時更新する。 |
| `View.standardSettingsBehaviors()` | Settings シーン専用の標準挙動。現状は ESC で owning window を閉じる。隠し `Button` + `.keyboardShortcut(.cancelAction)` ベースで、TextField にフォーカスがあっても確実に発火する (`.onExitCommand` の取りこぼしを回避)。`attachedSheet` 表示中は sheet 側を優先。 |
| `View.autoSaveWindowFrame(name: String)` | hosting している `NSWindow` に `setFrameAutosaveName` を当て、ウィンドウサイズと位置を `UserDefaults` に永続化する。 |
| `WindowBackgroundView` | `NSVisualEffectView` を SwiftUI から使うラッパー。`.background(WindowBackgroundView())` で macOS 標準アプリと同じ vibrancy material を当てられる。フラットな `Color` 塗りでは Settings 等と視覚的に揃わない問題を解消。 |

## Build

```bash
swift build
swift test
```

## 運用ルール

このリポジトリ用の Claude Code 向け運用ルールは [CLAUDE.md](./CLAUDE.md) を参照。
要点: **commit したら必ず origin に push する** (consumer アプリが SPM の `branch: master` で参照しているため)。
