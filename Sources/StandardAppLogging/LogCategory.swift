import Foundation

// MARK: - Log Level

/// ログレベル。`OSLogType` への写像は `AppLog` 内で行う
/// (`notice` → `.default`、`warning`/`error` → `.error`、`fault` → `.fault`。
/// Apple の `Logger` 便宜メソッドと同じ畳み方)。
public enum LogLevel: Sendable, CaseIterable {
    case debug
    case info
    case notice
    case warning
    case error
    case fault
}

extension LogLevel {
    /// 色を使えない sink (`colorize: false` の stderr ミラー / grep / CI) で level を
    /// **文字**として読ませるための安定ラベル。case 名と一致させる
    /// (色付きの開発ビューでは level は ANSI 色で表すため、この label は使わない。
    /// `AppLog.mirrorLine` 参照)。
    var label: String {
        switch self {
        case .debug:   return "debug"
        case .info:    return "info"
        case .notice:  return "notice"
        case .warning: return "warning"
        case .error:   return "error"
        case .fault:   return "fault"
        }
    }

    /// `[label]` 形式を左詰めで揃えるための列幅 (= 最長の `[warning]` = 9)。
    /// `allCases` から導くので level が増減しても自動追従する。
    static let labelColumnWidth: Int = LogLevel.allCases
        .map { "[\($0.label)]".count }
        .max() ?? 0
}

// MARK: - Log Privacy

/// **line log** の 1 メッセージ全体に適用する privacy ポリシー (**メッセージ単位**)。
///
/// `os.Logger` の `%{private}` / `%{public}` は**補間ごとの粒度**だが、
/// `OSLogMessage` は呼び出し箇所のコンパイラ magic で**関数境界を越えられない**
/// (`OSLogMessage` を変数で受けて `Logger` へ forward すると
/// `argument must be a string interpolation` でコンパイル不可。実測 2026-06-21)。
/// そのため `String` を受け取る line log は privacy を**メッセージ単位**でしか
/// 扱えない。フィールド単位で公開/秘匿を出し分けたい callsite は:
///
/// 1. private フィールドを呼び出し側で sanitize してから line log に渡す
///    (= 「ログ毎ではなく sanitize 境界で一度だけ判断する」)、または
/// 2. structured レーン (`AppLog.osLogger(for:)`) を使い、返った `Logger` に
///    補間ごとの `privacy:` を書く。
///
/// のいずれかを選ぶ。line log の既定は `category` の `defaultMessagePrivacy`。
public enum LogPrivacy: Sendable {
    case `public`
    case `private`
}

// MARK: - Log Category

/// アプリが定義するログカテゴリ契約。
///
/// 各アプリは「サブシステム領域ごとに 1 case」を持つ enum を本 protocol に
/// 適合させて使う (= カテゴリが exhaustive になり、追加が compile で気づける)。
/// lib 側はカテゴリの**集合を知らない** (機構のみ提供) ため、provider 名など
/// アプリ固有の語彙が lib に漏れない。
///
/// ```swift
/// enum ObaketLogCategory: String, LogCategory {
///     case dropbox, webdav, app, perf // ...
///     var categoryName: String { rawValue }
///     var defaultMessagePrivacy: LogPrivacy {
///         switch self {
///         case .dropbox, .webdav: return .private   // secret 近傍
///         case .app, .perf:       return .public
///         }
///     }
/// }
/// ```
/// 実装は **純値で行う** (enum + rawValue 等)。`categoryName` / `defaultMessagePrivacy` から
/// actor / main-actor state を読まないこと (`Sendable` 契約を実質破るため。codex 設計review P3)。
public protocol LogCategory: Sendable {
    /// Console.app / `log stream` の category フィルタに出る安定名。
    var categoryName: String { get }

    /// **line log** (`AppLog.info` / `error` 等の `String` API) のメッセージ全体に
    /// 適用する既定 privacy。structured レーン (`AppLog.osLogger(for:)`) では補間ごとに
    /// `privacy:` を明示するため、この値は参照しない。
    /// secret 近傍の領域は `.private` を返すこと。
    /// 注意: `.public` を返すカテゴリは release で **何も秘匿しない**。category は
    /// secret を守る安全網ではないので、secret を含みうる文字列は category に
    /// 関係なく callsite で sanitize 済みにして渡す (`AppLog` の doc 参照)。
    var defaultMessagePrivacy: LogPrivacy { get }
}
