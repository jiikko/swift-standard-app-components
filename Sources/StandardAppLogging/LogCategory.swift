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

// MARK: - Log Privacy

/// 1 ログメッセージ全体に適用する privacy ポリシー (**メッセージ単位**)。
///
/// `os.Logger` の `%{private}` / `%{public}` は**補間ごとの粒度**だが、
/// `OSLogMessage` は呼び出し箇所のコンパイラ magic で**関数境界を越えられない**。
/// そのため文字列を受け取る本 facade は privacy を**メッセージ単位**でしか
/// 扱えない。フィールド単位で公開/秘匿を出し分けたい callsite は:
///
/// 1. private フィールドを呼び出し側で sanitize してから本 facade に渡す
///    (= 「ログ毎ではなく sanitize 境界で一度だけ判断する」)、または
/// 2. その callsite だけ `os.Logger` を直接使う (本 facade に寄せない)。
///
/// のいずれかを選ぶ。本 facade の既定は `category` の `defaultPrivacy`。
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
///     var defaultPrivacy: LogPrivacy {
///         switch self {
///         case .dropbox, .webdav: return .private   // secret 近傍
///         case .app, .perf:       return .public
///         }
///     }
/// }
/// ```
/// 実装は **純値で行う** (enum + rawValue 等)。`categoryName` / `defaultPrivacy` から
/// actor / main-actor state を読まないこと (`Sendable` 契約を実質破るため。codex 設計review P3)。
public protocol LogCategory: Sendable {
    /// Console.app / `log stream` の category フィルタに出る安定名。
    var categoryName: String { get }

    /// callsite が privacy を明示しなかったときの既定 (メッセージ単位)。
    /// secret 近傍の領域は `.private` を返すこと。
    var defaultPrivacy: LogPrivacy { get }
}
