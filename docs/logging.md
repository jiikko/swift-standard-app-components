# ロギング (`StandardAppLogging` product)

`StandardAppLogging` は **UI 非依存** の dual-sink ロギング facade。

> このリポジトリ固有の「`print` を使わない / dev-fg pipe で消える」背景は umbrella の `.claude/rules/macos-debug-logging.md` に集約。本ドキュメントは facade 自体の設計・使い分けを扱う。

## 設計

- **dual-sink**: `AppLog` の 1 回の呼び出しで 2 つの sink (`os.Logger` と DEBUG の stderr ミラー) に書く。sink ごとの整形 / privacy / 色を 1 箇所に集約し、「callsite では毎回判断しない」のが目的。
- **facade**: privacy の既定 (category 単位) や色付けといった方針を入口で固定し、呼び出し側を薄くする。万能ではない (補間単位の privacy は扱えない。下記参照) ので `os.Logger` を完全に隠蔽はしない。
- **UI 非依存の別 product**: UI を背負えないレイヤー (consumer の Infrastructure / Model など `StandardAppComponents` を import できない場所) からも依存できるよう、UI 主体の `StandardAppComponents` とは別 product にしている。

## 最小利用

composition root で `AppLog` を 1 個作って共有し、カテゴリ集合はアプリ側の enum で定義する (lib はカテゴリを知らない)。

```swift
import StandardAppLogging

let appLog = AppLog(subsystem: "com.example.myapp")

enum MyLogCategory: String, LogCategory {
    case app
    case network
    case perf

    var categoryName: String { rawValue }
    var defaultPrivacy: LogPrivacy {
        switch self {
        case .network:      return .private   // secret 近傍
        case .app, .perf:   return .public
        }
    }
}

appLog.info(.app, "launched")
appLog.debug(.perf, "thumbnail decoded in \(elapsedMs)ms")
appLog.error(.network, "request failed: \(sanitizedError)")
```

| API | 役割 |
|---|---|
| `AppLog(subsystem:colorize:)` | 入口。値型 + immutable で `Sendable`。`subsystem` は reverse-DNS (例 `com.jiikko.obaket`)。`colorize` の既定は DEBUG=ON / release=OFF |
| `debug` / `info` / `notice` / `warning` / `error` / `fault` | レベル別の書き出し (convenience)。引数は `(category, message)` |
| `log(_:_:_:)` | 低レベル入口。引数は `(level, category, message)`。上の convenience はこれを呼ぶだけ |
| `LogCategory` (protocol) | アプリが enum で実装する契約。`categoryName` (Console.app のフィルタ名) と `defaultPrivacy` を持つ。**純値で実装**し、actor / main-actor state を読まないこと (`Sendable` を実質破るため) |
| `LogLevel` | `debug` / `info` / `notice` / `warning` / `error` / `fault` |
| `LogPrivacy` | `.public` / `.private` (メッセージ単位)。下記 privacy モデル参照 |

## Sinks

1 回の呼び出しで 2 つの sink に出す。

| Sink | 出るビルド | 用途 |
|---|---|---|
| `os.Logger` (unified logging) | DEBUG / release **常時** | 配布後の事後診断 (`log show` / `log stream` / sysdiagnose / Console.app)。`.private` は release で平文露出が畳まれる |
| stderr ミラー | **DEBUG のみ** (`#if DEBUG`) | `make dev-fg` などで foreground 起動したときの即時確認。`fputs(stderr)` で unbuffered に出すため tee pipe に即時に出る |

release ビルドでは stderr ミラーは出ない (`os.Logger` のみ)。stderr ミラーが `NSLog` ではなく `fputs(stderr)` なのは意図的で、`NSLog` だと unified log にも複製され、`.private` メッセージが DEBUG で平文複製 + ANSI 混入してしまうため (codex 設計review P1)。

## Privacy モデル

`AppLog` の privacy は **`category` が唯一の決定者で、メッセージ全体に all-or-nothing で適用**される (per-call override を持たない)。

- `.private` カテゴリ: release で **メッセージ全体** が `<private>` に畳まれる。
- `.public` カテゴリ: release でも **何も秘匿しない**。public カテゴリのメッセージに secret を補間すれば平文で残る。

これは「`.private` カテゴリへ呼び出しごとに `.public` を上書きして渡す」一方向を塞ぐだけで、**万能な安全網ではない**。`os.Logger` の `%{private}` は補間ごとの粒度だが、`OSLogMessage` のコンパイラ magic は関数境界を越えられないため、String を受け取る facade はメッセージ単位の privacy しか扱えない。

したがって:

- **secret を含みうる文字列は category に関係なく、呼び出し側で sanitize 済みにしてから渡す**。
- 補間ごとに公開 / 秘匿を出し分けたい callsite は、この facade に寄せず `os.Logger` を直接使う (下記)。

## Level → OSLogType の写像

`os.Logger` には `notice`/`warning` という level がないため、Apple の `Logger` 便宜メソッドと同じ畳み方をする。

| `LogLevel` | `OSLogType` |
|---|---|
| `debug` | `.debug` |
| `info` | `.info` |
| `notice` | `.default` |
| `warning` | `.error` |
| `error` | `.error` |
| `fault` | `.fault` |

注意: **`warning` は unified logging 上では `.error` として出る**。Console.app / `log show` で `warning` が「エラー」レベルに見えるのはこのため (驚きやすいポイント)。`warning` と `error` を区別したいのは DEBUG の stderr ミラー側 (色 / level ラベルで区別) で、unified log 側では同じ重大度に畳まれる。

## DEBUG stderr ミラーの出力フォーマット

本文は常に `[category] message`。level の見せ方は `colorize` で 2 通りに分かれる。

### `colorize: true` (DEBUG の既定 / 開発ビュー)

本文をレベル別 ANSI 色で包む。level は **色** で表す (本文に level テキストは足さない)。

```text
[app] launched (build 142)          # debug   … gray
[perf] thumbnail decoded in 12ms    # info    … 既定色
[app] window restored               # notice  … cyan
[network] retrying (attempt 2/3)    # warning … yellow
[network] request failed: timeout   # error   … red
[app] unexpected nil state          # fault   … red
```

| レベル | 色 |
|---|---|
| `debug` | gray (bright black) |
| `info` | 既定色 (色なし) |
| `notice` | cyan |
| `warning` | yellow |
| `error` / `fault` | red |

### `colorize: false` (grep / CI / `tmp/debug.log`)

ANSI 色を載せられない sink では色で level を表せないため、代わりに `[level]` を **文字** で前置する。`[warning]` 幅に左詰め整列するので category 列が揃う。

```text
[debug]   [app] launched (build 142)
[info]    [perf] thumbnail decoded in 12ms
[notice]  [app] window restored
[warning] [network] retrying (attempt 2/3)
[error]   [network] request failed: timeout
[fault]   [app] unexpected nil state
```

これにより、色を消したログ (= grep / CI で解析する対象) でも level が文字で残る。

### `colorize` の制御

```swift
let appLog = AppLog(subsystem: "com.example.myapp", colorize: false)
```

- 既定は DEBUG=ON / release=OFF。`make dev-fg` は tee pipe で stderr が非 TTY になり `isatty` 判定では色が消えるため、TTY 判定ではなく明示フラグで制御している。
- 色は `tmp/debug.log` にも tee されるため、ログを grep / CI 解析するなら `colorize: false` にする (上記の通り level が文字で出る)。
- consumer の composition root が `NO_COLOR` (<https://no-color.org>) などの env と連動させたい場合は、その値を見て `colorize` に渡す。

## `AppLog` を使うとき / `os.Logger` を直接使うとき

`AppLog` は便利だが `os.Logger` の完全な代替ではない。

### `AppLog` を使う

- 通常の app lifecycle ログ
- network / sync / perf など人間向けの診断ログ
- DEBUG で foreground 実行したときに stderr でも見たいログ
- privacy を「カテゴリ単位 + sanitize 境界で一度だけ」判断したいとき

### `os.Logger` を直接使う

- 補間ごとに public / private を出し分けたい (`AppLog` はメッセージ単位の privacy しか扱えない)
- public な診断情報と private な値を **同じ message** に混ぜたい
- `OSLog` の static interpolation / structured logging (型付きフォーマット) を活かしたい

```swift
import OSLog

let logger = Logger(subsystem: "com.example.myapp", category: "auth")
logger.info("user=\(userID, privacy: .private) status=\(status, privacy: .public)")
```

## 採用方針

- composition root で `AppLog` を **1 個** 作り、DI で配る (`.shared` singleton を新設しない)。
- カテゴリは「サブシステム領域ごとに 1 case」を持つ enum を `LogCategory` に適合させる (exhaustive になり、追加が compile で気づける)。
- `categoryName` / `defaultPrivacy` は純値で返す (actor / main-actor state を読まない)。
- secret を含みうる値は category に関係なく callsite で sanitize してから渡す。

## 関連

- 実装と doc コメント (privacy / sink の一次情報): [`Sources/StandardAppLogging/`](../Sources/StandardAppLogging/) (`AppLog.swift` / `LogCategory.swift` / `LogColor.swift`)
- 最小サンプル: [`Examples/LoggingExample.swift`](../Examples/LoggingExample.swift)
- このリポジトリ群での「`print` 禁止 / dev-fg pipe の落とし穴」: umbrella `.claude/rules/macos-debug-logging.md`
- 公開 API の責務境界 (UI product 側): [`docs/api-boundaries.md`](api-boundaries.md)
