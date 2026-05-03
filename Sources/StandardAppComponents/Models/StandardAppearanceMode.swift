import SwiftUI

/// アプリ外観モード (System / Light / Dark) を表す純粋な値型。
///
/// **設計**:
/// - データ型 + `ColorScheme?` 変換のみ。永続化や `@AppStorage` などのキャッシュ
///   ロジック、アプリ固有の業務ルールには **依存しない**。これは lib が consumer の
///   永続化モデルやキー名を知ってしまうと依存方向が逆流するため。
/// - consumer は `@AppStorage("appearanceMode") private var raw: String = ...rawValue`
///   のように **自前** で永続化し、`StandardAppearanceMode(rawValue:)` で復元、
///   `.preferredColorScheme` を `applyAppAppearance(_:)` に渡す薄いアダプタを書く。
///
/// **なぜ lib 化したか**:
/// `enum AppearanceMode { case system, light, dark }` という 3 ケース enum と
/// `var preferredColorScheme: ColorScheme? { ... }` 変換は **複数の社内アプリで
/// 完全に同形のものが繰り返し定義** されていた (ThumbnailThumb / vlc-mvp /
/// DualNote 等)。`applyAppAppearance(_:)` lib API の自然な相方として lib に
/// 集約しておく価値が大きい。
///
/// **使い方**:
/// ```swift
/// // Settings 画面の Picker
/// @AppStorage("appearanceMode") private var raw: String = StandardAppearanceMode.system.rawValue
///
/// var mode: StandardAppearanceMode {
///     StandardAppearanceMode(rawValue: raw) ?? .system
/// }
///
/// Picker("テーマ", selection: Binding(
///     get: { mode },
///     set: { raw = $0.rawValue }
/// )) {
///     Text("システム").tag(StandardAppearanceMode.system)
///     Text("ライト").tag(StandardAppearanceMode.light)
///     Text("ダーク").tag(StandardAppearanceMode.dark)
/// }
///
/// // Scene root で外観を当てる
/// .applyAppAppearance(mode.preferredColorScheme)
/// ```
public enum StandardAppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    /// `applyAppAppearance(_:)` に渡す `ColorScheme?`。
    /// `system` は `nil` を返し OS の effective appearance に追従する。
    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
