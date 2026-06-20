# StandardAppComponents

SwiftUI **macOS アプリ専用** の Personal SPM。

Settings ウィンドウ枠、表示言語切替、ログイン時起動トグル、メニューバー表示トグル、ウィンドウ挙動、外観適用、Toast、確認ダイアログ、ブロッキング進捗オーバーレイなど、複数アプリで繰り返し出てくる薄い macOS 定型処理を集約する。

このパッケージは汎用デザインシステムではない。アプリ固有の状態管理、永続化、文言、メニュー構成、ウィンドウルーティング、業務ロジックは consumer アプリ側に残す。

## 対象

| 対象 | 対象外 |
|---|---|
| Swift / SwiftUI macOS アプリ | iOS / watchOS アプリ |
| 複数 macOS アプリで同じ形になる AppKit / SwiftUI の薄い wrapper | クロスプラットフォーム抽象 |
| Settings ウィンドウの規約と共通挙動 | アプリ固有 Settings タブ / 設定値永続化 |
| 共通ラベルを持つ小さな UI 部品 | メニューバー常駐 agent / status item lifecycle |
| Toast の queue / 表示 / manager protocol | アプリ固有の通知文言 / エラー分類 |
| Blocking decision / progress の薄い SwiftUI wrapper | 業務ロジック、処理状態、cancel 実装 |

`Package.swift` の `platforms: [.macOS(.v14)]` は意図的に固定している。`NSWindow`, `NSApp`, `NSVisualEffectView`, `SMAppService.mainApp` など AppKit / ServiceManagement 前提の API を含む。

## ドキュメント

| 目的 | ドキュメント |
|---|---|
| 公開 API ごとの「lib が提供するもの / consumer が実装するもの」を確認する | [docs/api-boundaries.md](docs/api-boundaries.md) |
| Settings ウィンドウと General タブ部品の詳細 | [docs/settings.md](docs/settings.md) |
| Toast のモデル / manager / 表示コンテナの詳細 | [docs/toast.md](docs/toast.md) |
| 確認ダイアログ / ブロッキング進捗オーバーレイの使い方 | [docs/feedback.md](docs/feedback.md) |
| コピペ元の最小サンプル | [Examples/README.md](Examples/README.md) |

## 代表 API

### Settings ウィンドウ

Settings シーン全体の枠と、Settings タブ内に差し込む content 部品。

| 分類 | API |
|---|---|
| ウィンドウ枠 | `SettingsWindow`, `GeneralTabContract`, `SettingsWindowConstants`, `NotImplementedSlot` |
| General タブ content | `LanguageSection`, `LanguageOption`, `LaunchAtLoginToggle`, `LaunchAtLoginService`, `MenuBarVisibilityToggle` |
| アプリ固有タブ content | `ShortcutSettingsTab`, `StandardShortcutGroup`, `StandardShortcutItem` |
| Settings 専用挙動 | `View.standardSettingsBehaviors()` |

### 独立 UI コンポーネント / view-local helper

Settings 以外の root view / 任意 view に置く UI component と、view 内の interaction で使う薄い helper。

| 分類 | API |
|---|---|
| Toast | `Toast`, `ToastText`, `ToastAction`, `ToastManaging`, `ToastManager`, `ToastView`, `ToastContainerView`, `View.standardToastContainer(_:)` |
| Blocking decision / progress | `StandardActionButton`, `View.standardActionConfirmation(...)`, `View.standardBlockingProgressOverlay(...)` |
| Window background | `WindowBackgroundView` |
| ダブルクリック検出 | `DoubleClickDetector` (即時 single + ダブルクリック起動を両立。row / cell ごとに `@State` で別 instance を持つ。詳細は [docs/api-boundaries.md](docs/api-boundaries.md)) |

### アプリ全体 helper

UI 部品というより、app root や window に付与する helper。

| 分類 | API |
|---|---|
| 外観 | `StandardAppearanceMode`, `View.applyAppAppearance(_:)` |
| Window frame | `View.autoSaveWindowFrame(name:)` |
| ローカライズ検証 | `StandardAppComponentsLocalization.validateRequiredKeys()` |

## 明示的に提供しないもの

- `AboutContract` / 独自 About ウィンドウ
- `MenuBarAgent` / `MenuBarContract`
- Sparkle setup helper
- Global shortcut registrar
- Notification permission flow
- アプリ設定値の永続化層
- デザイントークン / 共通ボタン / 空状態などの広い UI kit

理由と境界は [docs/api-boundaries.md](docs/api-boundaries.md) にまとめている。

## スクリーンショット

### Settings ウィンドウ

| Light | Dark |
|---|---|
| ![Settings (Light)](docs/images/settings-general-light.png) | ![Settings (Dark)](docs/images/settings-general-dark.png) |

SwiftUI の offscreen screenshot generator では NSWindow chrome は完全には再現されない。実アプリではより macOS ネイティブな見た目になる。

### ショートカット設定

![Shortcut Settings](docs/images/settings-shortcuts.png)

### Toast

| Style | Screenshot |
|---|---|
| Success | ![Toast Success](docs/images/toast-success.png) |
| Error | ![Toast Error](docs/images/toast-error.png) |
| Warning | ![Toast Warning](docs/images/toast-warning.png) |
| Info | ![Toast Info](docs/images/toast-info.png) |
| With action | ![Toast With Action](docs/images/toast-with-action.png) |

スクショ再生成:

```bash
bin/generate-screenshots
```

## ビルド

```bash
swift build
swift test
bin/generate-screenshots
```

## 運用

このリポジトリ固有の作業ルールは [CLAUDE.md](CLAUDE.md) を参照。

重要: この package で commit したら `origin/master` へ push する。consumer アプリは現状 `branch: master` で参照しているため、ローカル commit のままだと取り込めない。
