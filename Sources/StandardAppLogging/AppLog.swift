import Foundation
import OSLog

// MARK: - AppLog

/// アプリ共通のログ書き出し入口 (dual-sink)。
///
/// 1 回の呼び出しで 2 つの sink に出す:
/// - **`os.Logger` (常時)**: unified logging。リリースビルドでも OS が記録するため
///   配布後の事後診断 (`log show` / sysdiagnose) に使える。privacy ポリシーで
///   release の平文露出を防ぐ。
/// - **stderr ミラー (DEBUG のみ)**: `make dev-fg` の tee pipe (unbuffered stderr) に
///   出す開発用。レベル別 ANSI 色付き。`#if DEBUG` 限定なので release には出ない。
///   `NSLog` ではなく `fputs(stderr)` を使う (NSLog は unified log にも複製され、
///   `.private` メッセージが DEBUG で平文複製 + ANSI 混入するため。codex 設計review P1)。
///
/// 「sink ごとの整形 / privacy / 色を 1 箇所に集約し、callsite では毎回判断しない」
/// のが目的。**privacy は `category` が唯一の決定者** (per-call override を持たない =
/// secret 近傍カテゴリへ誤って public を渡す経路が構造的に存在しない)。フィールド単位で
/// 公開/秘匿を出し分けたい callsite は `os.Logger` を直接使う (`LogPrivacy` 参照)。
/// secret を含みうる文字列は **呼び出し側で sanitize 済みにして渡す**。
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
    ///   - colorize: DEBUG ミラーの色付け。既定は DEBUG=ON / release=OFF。
    ///     `make dev-fg` は tee pipe で stderr が非 TTY になり `isatty` 判定では
    ///     色が消えるため、TTY 判定ではなく明示フラグで制御する。consumer の
    ///     composition root が env と連動させたい場合に渡す (例: `NO_COLOR` が
    ///     セットされていたら false。<https://no-color.org>)。色は `tmp/debug.log`
    ///     にも tee されるため、ログを grep / CI 解析する場合は false にする。
    public init(subsystem: String, colorize: Bool = AppLog.defaultColorize) {
        self.subsystem = subsystem
        self.colorize = colorize
    }

    /// 既定の色付け方針 (DEBUG=ON / release=OFF)。
    public static var defaultColorize: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Core

    /// 1 メッセージを両 sink に出す。privacy は `category.defaultPrivacy` で決まる。
    public func log(_ level: LogLevel, _ category: any LogCategory, _ message: String) {
        emitUnifiedLog(level: level, category: category.categoryName, privacy: category.defaultPrivacy, message: message)
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
        let line = "[\(category)] \(message)"
        let out = colorize ? LogColor.apply(level: level, to: line) : line
        // dev leg は **stderr のみ** に書く。stderr は unbuffered なので `make dev-fg`
        // の tee pipe に即時に出る。NSLog を使わないのは unified log への複製を避けるため
        // (codex 設計review P1: NSLog だと .private メッセージが DEBUG で平文複製 + ANSI 混入)。
        fputs(out + "\n", stderr)
    }
    #endif
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
