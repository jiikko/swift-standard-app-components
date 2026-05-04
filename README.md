# StandardAppComponents

Personal SPM. macOS アプリで繰り返し書かれる定型コードを 1 箇所に集約する社内 SPM。複数の社内 macOS アプリ (ThumbnailThumb / vlc-multi-video-player / DualNote 等) で共通化する。

## スクリーンショット

### 設定 (Settings) ウィンドウ

`SettingsWindow` で組み立てた General タブ (`Appearance` + `Language` セクション)。

| Light | Dark |
|---|---|
| ![Settings (Light)](docs/images/settings-general-light.png) | ![Settings (Dark)](docs/images/settings-general-dark.png) |

> NSWindow chrome (タイトルバー / 閉じるボタン / vibrancy 背景) は SwiftUI offscreen rendering の制約で再現されない。実機での見た目はもう少し macOS ネイティブ寄りになる。

### アプリ内通知 (Toast)

`ToastManager` + `ToastContainerView` 経由で画面右下に出るトースト。

| Style | Screenshot |
|---|---|
| Success | ![Toast Success](docs/images/toast-success.png) |
| Error (with message) | ![Toast Error](docs/images/toast-error.png) |
| Warning | ![Toast Warning](docs/images/toast-warning.png) |
| Info | ![Toast Info](docs/images/toast-info.png) |
| With action button | ![Toast With Action](docs/images/toast-with-action.png) |

スクショは `bin/generate-screenshots` (= `swift run ScreenshotGenerator`) で再生成可能。UI を変更した時はこのコマンドで `docs/images/*.png` を更新して同コミットに含める運用。

## ドキュメント

| 切り口 | ドキュメント | 主な API |
|---|---|---|
| 設定 (Settings) ウィンドウ | [docs/settings.md](docs/settings.md) | `SettingsWindow` / `GeneralTabContract` / `StandardAppearanceMode` / `LanguageSection` / `LaunchAtLoginToggle` / `MenuBarVisibilityToggle` / `WindowBackgroundView` / `View.autoSaveWindowFrame(name:)` |
| アプリ内通知 (Toast) | [docs/toast.md](docs/toast.md) | `Toast` / `ToastManaging` / `ToastManager` / `ToastView` / `View.standardToastContainer(_:)` |

## 最小サンプル

[`Examples/MinimalApp.swift`](Examples/MinimalApp.swift) を参照 (`SettingsWindow` + 外観切替 + 言語切替 + ローカライズ検証込み)。

## Build

```bash
swift build
swift test
bin/generate-screenshots   # README 用 PNG を再生成
```

## 運用ルール

このリポジトリ用の Claude Code 向け運用ルールは [CLAUDE.md](./CLAUDE.md) を参照。
要点: **commit したら必ず origin に push する** (consumer アプリが SPM の `branch: master` で参照しているため)。
