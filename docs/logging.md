# ロギング (`StandardAppLogging` product)

`StandardAppLogging` は **UI 非依存** のロギング product。**ログの入口を `AppLog` に統一**し、callsite は `Logger(subsystem:category:)` を直接生成しない。用途で 2 つのレーンを使い分ける。

| レーン | 入口 | 用途 | privacy | sink |
|---|---|---|---|---|
| **line log** | `appLog.info(.app, "msg")` 等 (`String`) | 人間が読む通常ログ | category 単位 / メッセージ全体 | `os.Logger` + DEBUG stderr ミラー |
| **structured / OSLog-native** | `appLog.osLogger(for: .network)` → `Logger` | 補間ごとの privacy / structured logging | 補間ごとに `privacy:` を明示 | `os.Logger` のみ |

```text
NG: 構造化したいときは os.Logger を直接作ってください
OK: 構造化したいときは appLog.osLogger(for: category) を使ってください
```

どちらも `StandardAppLogging` の API で、subsystem は `AppLog`、category は `LogCategory` 由来に固定される。

> このリポジトリ固有の「`print` を使わない / dev-fg pipe で消える」背景は umbrella の `.claude/rules/macos-debug-logging.md` に集約。本ドキュメントは facade 自体の設計・使い分けを扱う。

## 設計

- **入口と規約を統一する 2 レーン**: ログの入口と subsystem / category 規約は `AppLog` に統一する (callsite は `Logger(subsystem:category:)` を手打ちしない)。ただし「lib が全部を制御する」のではない — line log の整形 / privacy / stderr ミラーは `AppLog` が制御し、structured レーンは `AppLog` から category 規約付き `Logger` を払い出して、OSLog-native な補間と privacy は `os.Logger` に委譲する。
- **dual-sink (line log)**: `AppLog` の 1 呼び出しで `os.Logger` と DEBUG の stderr ミラーに書く。sink ごとの整形 / privacy / 色を 1 箇所に集約し、「callsite では毎回判断しない」のが目的。
- **薄い facade**: privacy 既定 (category 単位) や色付け方針を入口で固定する。ただし line log は補間単位の privacy を扱えない (後述) ので、その用途のために structured レーンを残す = `os.Logger` を完全には隠蔽しない。
- **UI 非依存の別 product**: UI を背負えないレイヤー (consumer の Infrastructure / Model など `StandardAppComponents` を import できない場所) からも依存できるよう、UI 主体の `StandardAppComponents` とは別 product にしている。

## `StandardAppLogging` だけで完結するのか？

「`StandardAppLogging` だけ呼べばログ書き出しが一本化する」と思いがちだが、**「完結」には 2 つの意味があり、片方は YES・片方は NO**。ここを取り違えやすい (line log だけ見れば前者なので「全部 lib で閉じる」と早合点しやすい)。

- **ログ規約 / 入口 / subsystem・category 管理としては完結する (YES)。**
  `print` / `NSLog` を使わず、`Logger(subsystem:category:)` を手打ちせず、常に `appLog` から始める。line log も structured も入口は `AppLog`。
- **Swift コード上で `os.Logger` を一切触らない、という意味では完結しない (NO)。**
  per-field privacy が要る callsite は `appLog.osLogger(for:)` が払い出した `os.Logger` に直接書き、`import OSLog` も要る。最後の書き込みだけは `os.Logger` の API に委譲する。

正確に言うと:

> ログは `StandardAppLogging` 経由で書く。ただし structured log では、`StandardAppLogging` が払い出した `os.Logger` に**最後の書き込みを委譲する**。

これは「`StandardAppLogging` を使わない例外がある」のではなく、**structured レーンが raw `os.Logger` を公式に露出している**という意味 (なぜ薄い wrapper で包めないかは後述の structured レーンの節)。

| 観点 | 完結する？ | 説明 |
|---|---|---|
| `print` / `NSLog` をログ用途に使わない | ✅ Yes | ログは `AppLog` に寄せる (背景は umbrella `macos-debug-logging.md`) |
| `Logger(subsystem:category:)` を callsite で手打ちしない | ✅ Yes | structured も `appLog.osLogger(for:)` 経由で払い出す |
| subsystem / category 規約を lib に集約する | ✅ Yes | `AppLog` + `LogCategory` 経由 |
| line log の sink / privacy / colorize を lib が制御する | ✅ Yes | `appLog.info` / `error` 側で完結 |
| per-field privacy を lib 独自 wrapper だけで完結する | ❌ No | 最後の書き込みは raw `os.Logger` の API |
| `import OSLog` なしで structured log まで書く | ❌ No | structured callsite は `import OSLog` 必須 |

要するに **「規約は一本化、コードは structured だけ os.Logger を触る」**。大多数の callsite は line log なので `AppLog` だけで閉じ、`os.Logger` が出てくるのは per-field privacy が要る少数の structured callsite に限られる。

## 最小利用

composition root で `AppLog` を 1 個作って共有し、カテゴリ集合はアプリ側の enum で定義する (lib はカテゴリを知らない)。

```swift
import StandardAppLogging
import OSLog   // structured レーン (osLogger) の privacy: 補間に必要

let appLog = AppLog(subsystem: "com.example.myapp")

enum MyLogCategory: String, LogCategory {
    case app
    case network
    case perf

    var categoryName: String { rawValue }

    // line log のメッセージ全体に効く既定 privacy。structured レーンでは参照されない。
    var defaultMessagePrivacy: LogPrivacy {
        switch self {
        case .network:      return .private   // secret 近傍
        case .app, .perf:   return .public
        }
    }
}

// line log
appLog.info(.app, "launched")
appLog.debug(.perf, "thumbnail decoded in \(elapsedMs)ms")
appLog.error(.network, "request failed: \(sanitizedError)")

// structured / OSLog-native
appLog.osLogger(for: .network).error(
    "request failed status=\(status, privacy: .public) token=\(token, privacy: .private)"
)
```

| API | 役割 |
|---|---|
| `AppLog(subsystem:colorize:)` | 入口。値型 + immutable で `Sendable`。`subsystem` は reverse-DNS (例 `com.jiikko.obaket`)。`colorize` の既定は下記 |
| `debug` / `info` / `notice` / `warning` / `error` / `fault` | **line log**。レベル別の書き出し (convenience)。引数は `(category, message)` |
| `log(_:_:_:)` | line log の低レベル入口。引数は `(level, category, message)`。上の convenience はこれを呼ぶだけ |
| `osLogger(for:)` | **structured レーン**。category 規約付きの raw `os.Logger` を返す |
| `LogCategory` (protocol) | アプリが enum で実装する契約。`categoryName` (Console.app のフィルタ名) と `defaultMessagePrivacy` を持つ。**純値で実装**し、actor / main-actor state を読まないこと (`Sendable` を実質破るため) |
| `LogLevel` | `debug` / `info` / `notice` / `warning` / `error` / `fault` |
| `LogPrivacy` | `.public` / `.private`。line log の **メッセージ単位** privacy。下記 privacy モデル参照 |

## line log の Sinks

line log は 1 回の呼び出しで 2 つの sink に出る。

| Sink | 出るビルド | 用途 |
|---|---|---|
| `os.Logger` (unified logging) | DEBUG / release **常時** | 配布後の事後診断 (`log show` / `log stream` / sysdiagnose / Console.app)。`.private` は release で平文露出が畳まれる |
| stderr ミラー | **DEBUG のみ** (`#if DEBUG`) | `make dev-fg` などで foreground 起動したときの即時確認。`fputs(stderr)` で unbuffered に出すため tee pipe に即時に出る |

release ビルドでは stderr ミラーは出ない (`os.Logger` のみ)。stderr ミラーが `NSLog` ではなく `fputs(stderr)` なのは意図的で、`NSLog` だと unified log にも複製され、`.private` メッセージが DEBUG で平文複製 + ANSI 混入してしまうため (codex 設計review P1)。

**structured レーンは stderr ミラーしない** (`os.Logger` のみ)。`OSLogMessage` の field 単位 privacy を stderr 側で平文再構成すると `.private` を漏らすため。stderr でも見たい要約は、sanitize 済みの line log を別途出す。

## line log の Privacy モデル

line log の privacy は **`category` (`defaultMessagePrivacy`) が唯一の決定者で、メッセージ全体に all-or-nothing で適用**される (per-call override を持たない)。

- `.private` カテゴリ: release で **メッセージ全体** が `<private>` に畳まれる。
- `.public` カテゴリ: release でも **何も秘匿しない**。public カテゴリのメッセージに secret を補間すれば平文で残る。

これは「`.private` カテゴリへ呼び出しごとに `.public` を上書きして渡す」一方向を塞ぐだけで、**万能な安全網ではない**。`os.Logger` の `%{private}` は補間ごとの粒度だが、`OSLogMessage` のコンパイラ magic は関数境界を越えられない (`String` を受け取る line log は補間構造を復元できない)。

したがって:

- **secret を含みうる文字列は category に関係なく、呼び出し側で sanitize 済みにしてから渡す**。
- 補間ごとに公開 / 秘匿を出し分けたい callsite は line log に寄せず、**structured レーン** (`appLog.osLogger(for:)`) を使う (下記)。

## structured / OSLog-native レーン

補間ごとの privacy や OSLog native な structured logging が要る callsite は `appLog.osLogger(for: category)` で **category 規約付きの `os.Logger`** を得て、返った Logger に**直接**書く。

```swift
import OSLog   // privacy: 補間が OSLogPrivacy を参照するため、この callsite では必須

appLog.osLogger(for: .network).error(
    "request failed status=\(status, privacy: .public) token=\(token, privacy: .private)"
)
```

- subsystem は `appLog`、category は `LogCategory` 由来なので、`Logger(subsystem:category:)` を手打ちするより subsystem / category 規約が保たれる (入口は依然 `appLog`)。
- **`import OSLog` が必要**: 返り値は `os.Logger` で、`privacy:` 補間は `OSLogPrivacy` を参照する。`StandardAppLogging` は OSLog を re-export しないため、structured を使う callsite は自分で `import OSLog` する。
- `os.Logger` のみに出る (DEBUG stderr ミラーなし。上記 Sinks 参照)。
- `defaultMessagePrivacy` は **参照されない**。privacy は補間ごとの `privacy:` で決める。
- raw `Logger` を返すため、lib の API 統制 (level 集合 / privacy 既定) は効かない。これは下記の制約上やむを得ない。

### なぜ `appLog.structured(.x).error("...")` のような薄い wrapper にしないのか

`os.Logger` のログメソッドは引数を **呼び出し箇所の string interpolation literal** に限定する。`OSLogMessage` を変数で受けて `Logger` へ forward しようとすると、コンパイラが弾く:

```text
error: argument must be a string interpolation
```

(実測 2026-06-21。`LogPrivacy` の「`OSLogMessage` は関数境界を越えられない」制約の一形態。) つまり現行の Swift / OSLog API では、補間ごとの privacy を保ったまま `Logger` 呼び出しを薄く wrap できない。そのため structured レーンは「category 規約付きの raw `Logger` を返す」形を取る。`StructuredAppLog.error(_ message: OSLogMessage)` のような薄い型を再導入しないこと (API が変われば再検討の余地はある)。

> release での redaction (`.private` の `<private>` 化) は静的解析では担保しきれない。配布前に `log show` で実機確認すること。

## Level → OSLogType の写像 (line log)

line log の `LogLevel` → `OSLogType` 写像。`os.Logger` には `notice`/`warning` という level がないため、Apple の `Logger` 便宜メソッドと同じ畳み方をする。structured レーンは `LogLevel` を経由せず、callsite が `os.Logger` の便宜メソッド (`.error()` / `.notice()` 等) を直接選ぶ (`.warning()` は存在しないので warning 相当は `.error()`)。

| `LogLevel` | `OSLogType` |
|---|---|
| `debug` | `.debug` |
| `info` | `.info` |
| `notice` | `.default` |
| `warning` | `.error` |
| `error` | `.error` |
| `fault` | `.fault` |

注意: **`warning` は unified logging 上では `.error` として出る**。Console.app / `log show` で `warning` が「エラー」レベルに見えるのはこのため (驚きやすいポイント)。`warning` と `error` を区別したいのは DEBUG の stderr ミラー側 (色 / level ラベルで区別) で、unified log 側では同じ重大度に畳まれる。

## DEBUG stderr ミラーの出力フォーマット (line log)

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

- 既定 (`defaultColorize`): release は常に OFF。DEBUG は env で自動判定し、**`NO_COLOR` / `CI` / `TERM=dumb` のいずれかがあれば OFF**、無ければ ON。`make dev-fg` は tee pipe で stderr が非 TTY になり `isatty` 判定では色が消えるため、TTY 判定ではなく env + 明示フラグで制御する。
- env と無関係に強制したいとき (常に色を消す / 付ける) だけ `colorize:` を明示する。
- 色は `tmp/debug.log` にも tee されるため、自動判定が効かない経路で grep / CI 解析するなら `colorize: false` を明示する (level が文字で出る)。

## 採用方針

- composition root で `AppLog` を **1 個** 作り、DI で配る (`.shared` singleton を新設しない)。
- カテゴリは「サブシステム領域ごとに 1 case」を持つ enum を `LogCategory` に適合させる (exhaustive になり、追加が compile で気づける)。
- `categoryName` / `defaultMessagePrivacy` は純値で返す (actor / main-actor state を読まない)。
- secret を含みうる値は category に関係なく callsite で sanitize してから渡す (line log / structured どちらでも)。
- 構造化が要る callsite は `Logger(subsystem:category:)` を新設せず `appLog.osLogger(for:)` を使う。

## 関連

- 実装と doc コメント (privacy / sink / wrapper 不可の一次情報): [`Sources/StandardAppLogging/`](../Sources/StandardAppLogging/) (`AppLog.swift` / `LogCategory.swift` / `LogColor.swift`)
- 最小サンプル: [`Examples/LoggingExample.swift`](../Examples/LoggingExample.swift)
- このリポジトリ群での「`print` 禁止 / dev-fg pipe の落とし穴」: umbrella `.claude/rules/macos-debug-logging.md`
- 公開 API の責務境界 (UI product 側): [`docs/api-boundaries.md`](api-boundaries.md)
