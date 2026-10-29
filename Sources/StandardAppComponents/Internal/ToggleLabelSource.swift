import SwiftUI

/// 標準のトグルのラベルを、どの bundle で解決するかで区別する。
/// - `.libDefault`: lib 同梱の xcstrings の文言を使う。`Text(_, bundle: .module)` で lib の bundle を明示するため、
///   `LocalizedStringKey` (= consumer の main bundle で解決) ではなく専用の case を持つ。
/// - `.custom`: consumer 側で解決する `LocalizedStringKey` をそのまま `Text` に渡す。
enum ToggleLabelSource {
    case libDefault
    case custom(LocalizedStringKey)

    /// `.libDefault` のときは `libDefault` を、`.custom` のときは consumer の文言を返す。
    /// lib の文言は呼び出し側に `Text("…", bundle: .module)` のリテラルで書かせる
    /// (変数経由にすると xcstrings の抽出がその key を拾わない)。
    func text(libDefault: () -> Text) -> Text {
        switch self {
        case .libDefault:
            libDefault()
        case .custom(let key):
            Text(key)
        }
    }
}
