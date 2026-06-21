# StandardAppComponents

SwiftUI **macOS アプリ専用** の Personal SPM。複数の macOS アプリで繰り返し出てくる薄い定型処理を、UI 部品 product とロギング product の 2 つに分けて提供する。

## このパッケージの位置づけ

- 複数 macOS アプリで同じ形になる薄い定型処理 (Settings ウィンドウ枠 / 表示言語切替 / ログイン時起動 / メニューバー表示 / ウィンドウ挙動 / 外観適用 / Toast / 確認ダイアログ / ブロッキング進捗 / ロギング) を集約する
- **汎用デザインシステムではない** (デザイントークン / 共通ボタン / 空状態などの広い UI kit は提供しない)
- アプリ固有の状態管理・永続化・文言・メニュー構成・ウィンドウルーティング・業務ロジックは consumer アプリ側に残す

## Products

| Product | import | 性質 | 用途 |
|---|---|---|---|
| `StandardAppComponents` | `import StandardAppComponents` | SwiftUI / AppKit 依存 (macOS) | Settings / Toast / 確認ダイアログ / ウィンドウ挙動などの UI 定型処理 |
| `StandardAppLogging` | `import StandardAppLogging` | **UI 非依存** | dual-sink ロギング facade (`os.Logger` 常時 + DEBUG のみ stderr ミラー)。UI を背負えない Infrastructure 等のレイヤーからも依存できるよう別 product にしている |

## 対象

| 対象 | 対象外 |
|---|---|
| Swift / SwiftUI macOS アプリ | iOS / watchOS アプリ |
| 複数 macOS アプリで同じ形になる AppKit / SwiftUI の薄い wrapper | クロスプラットフォーム抽象 |
| Settings ウィンドウの規約と共通挙動 | アプリ固有 Settings タブ / 設定値永続化 |
| 共通ラベルを持つ小さな UI 部品 | メニューバー常駐 agent / status item lifecycle |
| Toast の queue / 表示 / manager protocol | アプリ固有の通知文言 / エラー分類 |
| Blocking decision / progress の薄い SwiftUI wrapper | 業務ロジック、処理状態、cancel 実装 |

- swift-tools-version: **5.9**
- platform: **macOS 14+** (`Package.swift` の `platforms: [.macOS(.v14)]` は意図的に固定。`NSWindow` / `NSApp` / `NSVisualEffectView` / `SMAppService.mainApp` など AppKit / ServiceManagement 前提の API を含む)

## インストール

このパッケージは **git URL で参照する** (ローカルパス参照は CI / 他環境ビルドを壊し、バージョン固定も効かなくなるため禁止)。

### XcodeGen (`project.yml`) — 各 consumer app の標準

```yaml
packages:
  StandardAppComponents:
    url: git@github.com:jiikko/swift-standard-app-components.git
    branch: master            # or: version: 0.1.0

targets:
  MyApp:
    dependencies:
      - package: StandardAppComponents
        product: StandardAppComponents   # UI 部品
      - package: StandardAppComponents
        product: StandardAppLogging      # ロギング (UI 非依存層から使うなら)
```

### SwiftPM (`Package.swift`)

```swift
dependencies: [
    .package(url: "git@github.com:jiikko/swift-standard-app-components.git", branch: "master")
    // or: .package(url: "...", from: "0.1.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "StandardAppComponents", package: "swift-standard-app-components"),
            .product(name: "StandardAppLogging", package: "swift-standard-app-components"),
        ]
    )
]
```

UI を持たない層 (Infrastructure / Model) は `StandardAppLogging` だけを依存に足せる。

## クイックスタート

### UI 部品 (`StandardAppComponents`)

最小の App / Settings / Toast の骨格は Examples を参照 (コピペ元):

- [Examples/MinimalApp.swift](Examples/MinimalApp.swift) — `SettingsWindow` + 外観 / 言語切替 + ローカライズ検証
- [Examples/ToastExample.swift](Examples/ToastExample.swift) — `ToastManager` + `.standardToastContainer(_:)` + `ToastManaging` 注入

### ロギング (`StandardAppLogging`)

```swift
import StandardAppLogging

let appLog = AppLog(subsystem: "com.example.myapp")

enum MyLogCategory: String, LogCategory {
    case app, network
    var categoryName: String { rawValue }
    var defaultPrivacy: LogPrivacy {
        switch self {
        case .network: return .private   // secret 近傍
        case .app:     return .public
        }
    }
}

appLog.info(.app, "launched")
appLog.error(.network, "request failed: \(sanitized)")
```

サンプル全体は [Examples/LoggingExample.swift](Examples/LoggingExample.swift)、詳細は [docs/logging.md](docs/logging.md)。

## StandardAppLogging

UI 非依存の dual-sink ロギング product。`AppLog` の 1 回の呼び出しで 2 つの sink に書き、整形 / privacy / 色を 1 箇所に集約する (callsite では毎回判断しない)。

| Sink | 出るビルド | 用途 |
|---|---|---|
| `os.Logger` | DEBUG / release **常時** | 配布後の事後診断 (`log show` / sysdiagnose / Console.app) |
| stderr ミラー | **DEBUG のみ** | `make dev-fg` など foreground 起動時の即時確認 (色付き / `tmp/debug.log` に tee。`fputs(stderr)` で unbuffered) |

導入時に知っておくべき要点 (詳細は [docs/logging.md](docs/logging.md)):

- **privacy は category 単位の all-or-nothing**。`.private` は release でメッセージ全体が `<private>` に畳まれ、`.public` は何も秘匿しない。category は安全網ではないので、**secret を含みうる値は category に関係なく callsite で sanitize してから渡す**。
- **`warning` は unified logging 上では `.error` に畳まれる** (Console.app で warning がエラー扱いに見えるのはこのため)。
- release ビルドでは stderr ミラーは出ない (`os.Logger` のみ)。
- 次のときは facade ではなく `os.Logger` を直接使う (詳細は [docs/logging.md](docs/logging.md) の「`AppLog` を使うとき / `os.Logger` を直接使うとき」): ① 補間ごとに public / private を分けたい ② public な診断値と private な値を同じ message に混ぜたい ③ `OSLog` の structured logging / 型付き静的フォーマットを活かしたい。

### DEBUG stderr ミラーの出力

本文は常に `[category] message`。level の見せ方が `colorize` で変わる:

```text
# colorize: true (DEBUG 既定)         # colorize: false (grep / CI / tmp/debug.log)
[network] request failed: timeout     [error]   [network] request failed: timeout
[perf] decoded in 12ms                [info]    [perf] decoded in 12ms
```

- `colorize: true`: level を **ANSI 色** で表す (debug=gray / info=既定色 / notice=cyan / warning=yellow / error・fault=red)。本文に level テキストは足さない。
- `colorize: false`: 色を載せられないので `[level]` を **文字** で前置 (`[warning]` 幅に整列)。色を消したログでも level が残るので grep / CI 解析に向く。

既定は DEBUG=ON / release=OFF。`AppLog(subsystem: "...", colorize: false)` で明示制御 (`NO_COLOR` 連動などは consumer 側)。

## API 一覧

`StandardAppComponents` の代表 API。「lib が提供するもの / consumer が実装するもの」の詳細は [docs/api-boundaries.md](docs/api-boundaries.md)。

| 領域 | 代表 API |
|---|---|
| Settings ウィンドウ枠 | `SettingsWindow`, `GeneralTabContract`, `SettingsWindowConstants`, `View.standardSettingsBehaviors()` |
| General タブ部品 | `LanguageSection` / `LanguageOption`, `LaunchAtLoginToggle` / `LaunchAtLoginService`, `MenuBarVisibilityToggle` |
| ショートカット設定 | `ShortcutSettingsTab`, `StandardShortcutGroup`, `StandardShortcutItem` |
| Toast | `Toast`, `ToastText`, `ToastManaging` / `ToastManager`, `ToastView`, `View.standardToastContainer(_:)` |
| 確認 / 進捗 | `StandardActionButton`, `View.standardActionConfirmation(...)`, `View.standardBlockingProgressOverlay(...)` |
| ウィンドウ / 外観 | `WindowBackgroundView`, `View.autoSaveWindowFrame(name:)`, `StandardAppearanceMode`, `View.applyAppAppearance(_:)` |
| view-local helper | `DoubleClickDetector` (即時 single + ダブルクリック起動を両立。位置 / id の 2 モード) |
| ローカライズ検証 | `StandardAppComponentsLocalization.validateRequiredKeys()` |
| ロギング (別 product) | `AppLog`, `LogCategory`, `LogLevel`, `LogPrivacy` |

## ドキュメント

| 目的 | ドキュメント |
|---|---|
| 公開 API ごとの「lib が提供するもの / consumer が実装するもの」 | [docs/api-boundaries.md](docs/api-boundaries.md) |
| Settings ウィンドウと General タブ部品の詳細 | [docs/settings.md](docs/settings.md) |
| Toast のモデル / manager / 表示コンテナの詳細 | [docs/toast.md](docs/toast.md) |
| 確認ダイアログ / ブロッキング進捗オーバーレイ | [docs/feedback.md](docs/feedback.md) |
| ロギング (`AppLog` / `LogCategory` / `LogPrivacy`)・privacy の制約 | [docs/logging.md](docs/logging.md) |
| コピペ元の最小サンプル | [Examples/README.md](Examples/README.md) |

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

## 開発

```bash
swift build              # SwiftLint plugin が build 時に走る
swift test
bin/generate-screenshots # docs/images/*.png を再生成 (UI 変更時は同コミットで)
```

このリポジトリ固有の作業ルール (commit 後の `origin/master` push 必須など) は [CLAUDE.md](CLAUDE.md) を参照。
