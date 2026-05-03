import SwiftUI

// MARK: - ToastText

/// Toast メッセージ用の型。catalog ルックアップする値と verbatim 表示する値を
/// 型レベルで区別する (ThumbnailThumb #344 由来)。
///
/// - `.localized`: catalog でロケール解決される。リテラル渡しは
///   `ExpressibleByStringLiteral` 経由で自動的にこちらになる。
/// - `.verbatim`: catalog ルックアップを経由せずそのまま表示する。
///   `error.localizedDescription` / `url.lastPathComponent` 等の
///   既に locale 解決済み・ユーザー入力由来の文字列に使う。
public enum ToastText: Sendable {
    case localized(LocalizedStringResource)
    case verbatim(String)
}

extension ToastText: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .localized(LocalizedStringResource(stringLiteral: value))
    }
}

extension ToastText {
    /// 表示用の最終的な `String` に解決する。
    /// - `.localized`: catalog から解決
    /// - `.verbatim`: そのまま返す
    public func resolve() -> String {
        switch self {
        case .localized(let resource): String(localized: resource)
        case .verbatim(let value): value
        }
    }
}
