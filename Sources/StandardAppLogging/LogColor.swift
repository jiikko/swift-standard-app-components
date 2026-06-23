import Foundation

// MARK: - ANSI Color

/// dev leg (stderr / `make dev-fg` の tee pipe) 向けの ANSI 色付け。
///
/// **os.Logger 側には適用しない** (`os.Logger` は ANSI を解さず Console.app に
/// 生の escape コードが見えるだけ)。色は DEBUG の stderr ミラーにのみ載せる。
enum LogColor {
    private static let reset = "\u{001B}[0m"

    /// レベル別の前景色。`info` は既定色のまま (色を付けない)。
    static func apply(level: LogLevel, to line: String) -> String {
        guard let code = ansiCode(for: level) else { return line }
        return code + line + reset
    }

    /// 色コード (nil = 色を付けない)。テストから写像を直接担保するため internal。
    ///
    /// dev-leg はターミナル表示専用なので、**bright (high-intensity) ANSI 前景色** (`9x` 系) を使い、
    /// 暗端末でも映える / 地と同化しないようにする。hue は通常色と同じで明度だけ上げるため、
    /// レベル階層 (error=赤 > warning=黄 > notice=cyan) の意味は変わらない。`info` は既定色のまま
    /// (色なし)、`debug` だけは意図的に muted な gray (`90m`) に留め、verbose な debug ログが
    /// ネオンで主張しすぎないようにする。
    static func ansiCode(for level: LogLevel) -> String? {
        switch level {
        case .fault, .error: return "\u{001B}[91m" // bright red
        case .warning:       return "\u{001B}[93m" // bright yellow
        case .notice:        return "\u{001B}[96m" // bright cyan
        case .info:          return nil            // 既定色
        case .debug:         return "\u{001B}[90m" // bright black (gray) — verbose は muted のまま
        }
    }
}
