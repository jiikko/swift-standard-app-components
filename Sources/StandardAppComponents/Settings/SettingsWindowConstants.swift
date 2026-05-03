import Foundation

/// `SettingsWindow` 関連の generic 型に依存しない定数置き場。
///
/// `SettingsWindow.generalTabId` も同じ値を露出しているが、`SettingsWindow` は
/// `AppTabs: View` で generic 化されているため consumer 側で参照する時に
/// `SettingsWindow<EmptyView>.generalTabId` のように generic 型パラメータを
/// 明示する必要があり書きにくい。本 enum 経由なら `SettingsWindowConstants.generalTabId`
/// で簡潔に参照できる。
///
/// 例:
/// ```swift
/// SettingsWindow(
///     general: contract,
///     heights: [
///         SettingsWindowConstants.generalTabId: 360,  // generic 不要
///         "shortcuts": 600
///     ]
/// ) { ... }
/// ```
public enum SettingsWindowConstants {
    /// General タブを識別する固定 tag。`SettingsWindow.generalTabId` と等価で、
    /// 値も同じ `"general"`。consumer は `appTabs` の追加タブに `.tag("...")`
    /// を当てる時の selection binding 一致用にこの値を参照する。
    public static let generalTabId: String = "general"
}
