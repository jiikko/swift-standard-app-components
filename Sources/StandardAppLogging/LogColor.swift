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
    static func ansiCode(for level: LogLevel) -> String? {
        switch level {
        case .fault, .error: return "\u{001B}[31m" // red
        case .warning:       return "\u{001B}[33m" // yellow
        case .notice:        return "\u{001B}[36m" // cyan
        case .info:          return nil            // 既定色
        case .debug:         return "\u{001B}[90m" // bright black (gray)
        }
    }
}
