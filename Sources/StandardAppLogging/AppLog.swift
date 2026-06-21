import Foundation
import OSLog

// MARK: - AppLog

/// アプリ共通のログ書き出し入口。ログの入口は常に `AppLog` に統一し、callsite は
/// `Logger(subsystem:category:)` を直接生成しない。2 つのレーンを持つ:
///
/// - **line log** (本 struct の `info` / `error` 等、`String` を受ける): 人間が読む
///   通常ログ。privacy は `category` 単位で **メッセージ全体** に適用。下記 dual-sink。
/// - **structured / OSLog-native** (`osLogger(for:)` → `Logger`): 補間ごとの privacy
///   (`\(x, privacy: .private)`) や structured logging が要る callsite 用。`os.Logger`
///   のみ (stderr ミラーなし)。`osLogger(for:)` の doc 参照。
///
/// ## line log の dual-sink
///
/// 1 回の呼び出しで 2 つの sink に出す:
/// - **`os.Logger` (常時)**: unified logging。リリースビルドでも OS が記録するため
///   配布後の事後診断 (`log show` / sysdiagnose) に使える。`.private` カテゴリは
///   release で平文露出が畳まれる (下記 privacy の注意を参照)。
/// - **stderr ミラー (DEBUG のみ)**: `make dev-fg` の tee pipe (unbuffered stderr) に
///   出す開発用。レベル別 ANSI 色付き。`#if DEBUG` 限定なので release には出ない。
///   `NSLog` ではなく `fputs(stderr)` を使う (NSLog は unified log にも複製され、
///   `.private` メッセージが DEBUG で平文複製 + ANSI 混入するため。codex 設計review P1)。
///
/// ## line log の privacy
///
/// 「sink ごとの整形 / privacy / 色を 1 箇所に集約し、callsite では毎回判断しない」
/// のが目的。**line log の privacy は `category` が唯一の決定者** (per-call override を
/// 持たない。`LogCategory.defaultMessagePrivacy`)。ただしこれは万能な安全網ではなく、
/// **「`.private` カテゴリへ呼び出しごとに `.public` を上書きして渡す」一方向を塞ぐだけ**
/// である点に注意 (誤読しやすい):
///
/// - `.private` カテゴリは release で **メッセージ全体** が `<private>` に畳まれる
///   (os.Logger の補間ごとの出し分けは `String` では関数境界を越えられないため。
///   `LogPrivacy` 参照)。静的な文脈ごと秘匿されるので、選択的に残したい診断は
///   structured レーン (`osLogger(for:)`) を使う。
/// - `.public` カテゴリは **何も秘匿しない**。public カテゴリのメッセージに secret を
///   補間すれば release でも平文で残る。category は secret を守る安全網ではない。
///
/// したがって **secret を含みうる文字列は category に関係なく、呼び出し側で sanitize 済みに
/// してから渡す**こと。フィールド単位で公開/秘匿を出し分けたい callsite は line log に
/// 寄せず `osLogger(for:)` の structured レーンを使う。
///
/// 値型 + immutable で `Sendable`。アプリは composition root で 1 個作って共有する:
///
/// ```swift
/// let appLog = AppLog(subsystem: "com.example.myapp")
/// appLog.error(MyCategory.network, "request failed: \(sanitized)")
/// ```
///
/// > 本 product は SAC の中で **意図的に OSLog / stderr に書く唯一の場所**。
/// > 「lib は consumer 不在でログを書かない」(UI 部品の規約) と矛盾しない:
/// > UI 部品は依然ログを持たず、本 product は「アプリがログを書くための道具」。
public struct AppLog: Sendable {
    /// `Logger(subsystem:)` に渡す reverse-DNS。例: `com.jiikko.obaket`。
    public let subsystem: String

    /// DEBUG ミラーに ANSI 色を付けるか。
    private let colorize: Bool

    /// - Parameters:
    ///   - subsystem: unified logging の subsystem 識別子。
    ///   - colorize: DEBUG ミラーの色付け。既定 (`defaultColorize`) は DEBUG かつ
    ///     `NO_COLOR` / `CI` / `TERM=dumb` のいずれも無いとき ON、それ以外 OFF。
    ///     `make dev-fg` は tee pipe で stderr が非 TTY になり `isatty` 判定では
    ///     色が消えるため、TTY 判定ではなく明示フラグ + env で制御する。env と無関係に
    ///     強制したい場合に明示的に渡す。色は `tmp/debug.log` にも tee される。
    public init(subsystem: String, colorize: Bool = AppLog.defaultColorize) {
        self.subsystem = subsystem
        self.colorize = colorize
    }

    /// 既定の色付け方針。release は常に OFF。DEBUG は env で自動判定
    /// (`NO_COLOR` / `CI` / `TERM=dumb` のいずれかがあれば OFF)。
    public static var defaultColorize: Bool {
        #if DEBUG
        return colorizeDefault(environment: ProcessInfo.processInfo.environment)
        #else
        return false
        #endif
    }

    /// DEBUG の色付け既定を env から決める純粋関数 (副作用なし。テスト用に切り出し)。
    /// `NO_COLOR` (<https://no-color.org>、値の有無で判定) / `CI` / `TERM=dumb` の
    /// いずれかがあれば false。`tmp/debug.log` を CI / 非対話環境で解析する経路でも
    /// ANSI が混ざらない。`#if DEBUG` で囲まないのはテストから写像を担保するため。
    static func colorizeDefault(environment: [String: String]) -> Bool {
        if environment["NO_COLOR"] != nil { return false }
        if environment["CI"] != nil { return false }
        if environment["TERM"] == "dumb" { return false }
        return true
    }

    // MARK: - Core

    /// 1 メッセージを両 sink に出す (line log)。privacy は `category.defaultMessagePrivacy` で決まる。
    public func log(_ level: LogLevel, _ category: any LogCategory, _ message: String) {
        emitUnifiedLog(level: level, category: category.categoryName, privacy: category.defaultMessagePrivacy, message: message)
        #if DEBUG
        emitDebugMirror(level: level, category: category.categoryName, message: message)
        #endif
    }

    // MARK: - Convenience

    public func debug(_ category: any LogCategory, _ message: String) { log(.debug, category, message) }
    public func info(_ category: any LogCategory, _ message: String) { log(.info, category, message) }
    public func notice(_ category: any LogCategory, _ message: String) { log(.notice, category, message) }
    public func warning(_ category: any LogCategory, _ message: String) { log(.warning, category, message) }
    public func error(_ category: any LogCategory, _ message: String) { log(.error, category, message) }
    public func fault(_ category: any LogCategory, _ message: String) { log(.fault, category, message) }

    // MARK: - Sinks

    private func emitUnifiedLog(level: LogLevel, category: String, privacy: LogPrivacy, message: String) {
        let logger = Logger(subsystem: subsystem, category: category)
        // `os.Logger` の補間 `privacy:` は**コンパイル時リテラル必須** (runtime 変数は
        // "argument must be a static method or property of 'OSLogPrivacy'" になる)。
        // そのため privacy をリテラルで分岐する。
        switch privacy {
        case .public:
            logger.log(level: level.osLogType, "\(message, privacy: .public)")
        case .private:
            logger.log(level: level.osLogType, "\(message, privacy: .private)")
        }
    }

    #if DEBUG
    private func emitDebugMirror(level: LogLevel, category: String, message: String) {
        // dev leg は **stderr のみ** に書く。stderr は unbuffered なので `make dev-fg`
        // の tee pipe に即時に出る。NSLog を使わないのは unified log への複製を避けるため
        // (codex 設計review P1: NSLog だと .private メッセージが DEBUG で平文複製 + ANSI 混入)。
        let out = AppLog.mirrorLine(level: level, category: category, message: message, colorize: colorize)
        fputs(out + "\n", stderr)
    }
    #endif

    /// DEBUG stderr ミラーの 1 行を組み立てる純粋関数 (副作用なし / 改行なし)。
    ///
    /// 本文は常に `[category] message`。level の見せ方を `colorize` で 2 通りに分ける:
    /// - `colorize: true` (DEBUG の既定 / 開発ビュー): 本文をレベル別 ANSI 色で包む
    ///   (info 等 `LogColor.ansiCode` が nil のレベルは色を付けない)。level は **色** で表す。
    /// - `colorize: false` (grep / CI / `tmp/debug.log`): ANSI を載せられないので level が
    ///   消える。代わりに `[level]` を**文字**で前置し、`labelColumnWidth` で左詰め整列して
    ///   category 列を揃える (例: `[error]   [network] timeout`)。
    ///
    /// `emitDebugMirror` の整形ロジックをここに切り出すのは、stderr 副作用と分離して
    /// **整形結果そのもの** (bracket 形式 + 色付け / level 前置) を unit-test で固定するため。
    /// `#if DEBUG` で囲まないのはテスト (debug build) から写像を担保できるようにするため。
    static func mirrorLine(level: LogLevel, category: String, message: String, colorize: Bool) -> String {
        let body = "[\(category)] \(message)"
        guard !colorize else {
            return LogColor.apply(level: level, to: body)
        }
        let levelTag = "[\(level.label)]".padding(toLength: LogLevel.labelColumnWidth, withPad: " ", startingAt: 0)
        return "\(levelTag) \(body)"
    }
}

// MARK: - LogLevel -> OSLogType

extension LogLevel {
    /// Apple の `Logger` 便宜メソッドと同じ畳み方:
    /// `notice` → `.default`、`warning`/`error` → `.error`、`fault` → `.fault`。
    var osLogType: OSLogType {
        switch self {
        case .debug:   return .debug
        case .info:    return .info
        case .notice:  return .default
        case .warning: return .error
        case .error:   return .error
        case .fault:   return .fault
        }
    }
}

// MARK: - Structured / OSLog-native lane

public extension AppLog {
    /// structured / OSLog-native レーン。category 規約付きの raw `os.Logger` を返す。
    /// 補間ごとの privacy (`\(x, privacy: .private)`) や OSLog の structured logging が
    /// 要る callsite はこれを使い、返った logger に**直接**書く:
    ///
    /// ```swift
    /// appLog.osLogger(for: .network).error(
    ///     "request failed status=\(status, privacy: .public) token=\(token, privacy: .private)"
    /// )
    /// ```
    ///
    /// subsystem は `self`、category は引数の `LogCategory` 由来なので、callsite が
    /// `Logger(subsystem:category:)` を手打ちするより subsystem / category 規約が保たれる。
    ///
    /// ## なぜ `structured(_:).error(_ message:)` のような薄い wrapper にしないか
    /// `os.Logger` のログメソッドは引数を **呼び出し箇所の string interpolation literal**
    /// に限定する。`OSLogMessage` を変数で受けて forward すると
    /// `error: argument must be a string interpolation` でコンパイルできない (実測
    /// 2026-06-21。`LogPrivacy` の「関数境界を越えられない」制約の一形態)。よって
    /// 補間ごとの privacy を保ったまま `Logger` 呼び出しを wrap するのは原理的に不可能で、
    /// 「raw `Logger` を返す」しか選択肢がない。raw を返すため lib の API 統制 (level 集合 /
    /// privacy 既定) は効かない点に注意。stderr ミラーも行わない (field 単位 privacy を
    /// 平文再構成しないため。stderr でも見たい要約は line log を別途出す)。
    func osLogger(for category: any LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.categoryName)
    }
}
