# StandardAppComponents

Personal SPM。**macOS アプリ専用** で、繰り返し書かれる定型コード (Settings ウィンドウ枠 / Toast / 外観切替 / `SMAppService` ラッパー等) を 1 箇所に集約する社内 SPM。

## 対象 / 対象外

- ✓ **対象**: macOS アプリ (`apps/ThumbnailThumb` / `apps/vlc-multi-video-player` / `apps/DualNoteApp` 等の Swift / SwiftUI macOS app)
- ✗ **対象外**: iOS / watchOS アプリ
  - `apps/baby-note` (iOS 18+) は本 lib の利用想定なし。AppKit (`NSApp` / `NSWindow` / `SMAppService.mainApp` / `NSVisualEffectView` 等) に依存する API が多く、iOS 化のための platform conditional / 抽象化を入れるよりも、各 iOS app で必要な部分だけ自前実装するほうが筋が良い

`Package.swift` の `platforms: [.macOS(.v14)]` は意図的に macOS only に固定している。iOS 対応の要望が出てきた場合は別 SPM (例: `swift-standard-ios-components`) を切るか、API audit してから判断する。

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
