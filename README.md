# StandardAppComponents

Personal SPM. macOS アプリで繰り返し書かれる定型コードを 1 箇所に集約する社内 SPM。複数の社内 macOS アプリ (ThumbnailThumb / vlc-multi-video-player / DualNote 等) で共通化する。

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
```

## 運用ルール

このリポジトリ用の Claude Code 向け運用ルールは [CLAUDE.md](./CLAUDE.md) を参照。
要点: **commit したら必ず origin に push する** (consumer アプリが SPM の `branch: master` で参照しているため)。
