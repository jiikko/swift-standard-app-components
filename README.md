# StandardAppComponents

SwiftUI **macOS アプリ専用** の Personal SPM。

Settings ウィンドウ枠、表示言語切替、ログイン時起動トグル、メニューバー表示トグル、ウィンドウ挙動、外観適用、Toast、確認ダイアログ、ブロッキング進捗オーバーレイなど、複数アプリで繰り返し出てくる薄い macOS 定型処理を集約する。

このパッケージは汎用デザインシステムではない。アプリ固有の状態管理、永続化、文言、メニュー構成、ウィンドウルーティング、業務ロジックは consumer アプリ側に残す。

このパッケージは 2 つの product を提供する:

| product | 性質 | 用途 |
|---|---|---|
| `StandardAppComponents` | SwiftUI / AppKit 依存 (macOS) | 上記の UI 定型処理 |
| `StandardAppLogging` | **UI 非依存** | dual-sink ロギング facade (os.Logger 常時 + DEBUG のみ stderr ミラー)。UI を背負えない Infrastructure 等のレイヤーからも依存できるよう別 product にしている |

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
| ロギング facade (`AppLog` / `LogCategory` / `LogPrivacy`) の詳細・privacy の制約 | `Sources/StandardAppLogging/` の各 doc コメント (一次情報) |
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
| ダブルクリック検出 | `DoubleClickDetector` (即時 single + ダブルクリック起動を両立。位置モード `checkDoubleClick(at:)` / id モード `checkDoubleClick(id:)` の 2 モード。1 instance = 1 モード。詳細は [docs/api-boundaries.md](docs/api-boundaries.md)) |

### アプリ全体 helper

UI 部品というより、app root や window に付与する helper。

| 分類 | API |
|---|---|
| 外観 | `StandardAppearanceMode`, `View.applyAppAppearance(_:)` |
| Window frame | `View.autoSaveWindowFrame(name:)` |
| ローカライズ検証 | `StandardAppComponentsLocalization.validateRequiredKeys()` |

## ロギング (`StandardAppLogging` product)

UI 非依存の dual-sink ロギング facade。1 回の呼び出しで os.Logger (常時) と DEBUG のみの stderr ミラー (色付き / `make dev-fg` の tee pipe に即時に出る) の両方に書く。

| 分類 | API |
|---|---|
| 入口 (値型 Sendable) | `AppLog(subsystem:)` / `log`・`debug`・`info`・`notice`・`warning`・`error`・`fault(_ category:_ message:)` |
| カテゴリ契約 (アプリが enum で実装) | `LogCategory` (`categoryName` / `defaultPrivacy`) |
| レベル / privacy | `LogLevel`, `LogPrivacy` |

```swift
let appLog = AppLog(subsystem: "com.example.myapp")
appLog.error(MyLogCategory.network, "request failed: \(sanitized)")

enum MyLogCategory: String, LogCategory {
    case network, app
    var categoryName: String { rawValue }
    var defaultPrivacy: LogPrivacy {
        switch self {
        case .network: return .private   // secret 近傍
        case .app:     return .public
        }
    }
}
```

### 出力例 (DEBUG の stderr ミラー)

`make dev-fg` の tee pipe に出る開発用ミラーは `[category] message` 形式で、レベル別に ANSI 色が付く（os.Logger 側には色を付けない）。

```text
[app]     launched (build 142)            # debug   … gray
[perf]    thumbnail decoded in 12ms       # info    … 既定色
[app]     window restored                 # notice  … cyan
[network] retrying (attempt 2/3)          # warning … yellow
[network] request failed: timeout         # error   … red
[app]     unexpected nil state            # fault   … red
```

| レベル | 色 |
|---|---|
| `debug` | gray (bright black) |
| `info` | 既定色 (色なし) |
| `notice` | cyan |
| `warning` | yellow |
| `error` / `fault` | red |

色を消したい場合（`tmp/debug.log` を grep / CI 解析する等）は `AppLog(subsystem:colorize: false)`。release ビルドでは stderr ミラー自体が出ない（os.Logger のみ）。

privacy は **category 単位の all-or-nothing**。`.private` は release でメッセージ全体が `<private>` に畳まれ、`.public` は何も秘匿しない。category は secret の安全網ではないので、**secret を含みうる文字列は category に関係なく callsite で sanitize 済みにして渡す**。補間ごとに privacy を出し分けたい callsite は `os.Logger` を直接使う。詳細は `Sources/StandardAppLogging/AppLog.swift` の doc を参照。

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
