// StandardAppComponents
//
// jiikko の macOS アプリ群が共通で使う UI 規約と振る舞いを提供する SPM パッケージ。
//
// 現在は最小スケルトン。実装は段階的に追加していく:
// - Settings/      … SettingsWindow / GeneralTabContract
// - MenuBar/       … MenuBarAgent / MenuBarContract / MenuBarVisibilitySection
// - Lifecycle/     … LaunchAtLoginContract / AboutContract
// - Behaviors/     … standardSettingsBehaviors / autoSaveWindowFrame 等
// - Internal/      … NotImplementedSlot 等

import Foundation

public enum StandardAppComponents {
    public static let version = "0.0.1"
}
