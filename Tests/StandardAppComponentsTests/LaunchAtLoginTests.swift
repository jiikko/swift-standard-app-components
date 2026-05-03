import XCTest
import SwiftUI
@testable import StandardAppComponents

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    /// View としての初期化と body 評価が通ることを担保。
    /// 実際の system register/unregister 副作用は検証しない (テスト実行ホストの
    /// ログイン項目を書き換えてしまうため)。
    func testToggleInitializerCompilesWithDefaultLabel() {
        let toggle = LaunchAtLoginToggle()
        _ = toggle.body
    }

    func testToggleInitializerCompilesWithCustomLabel() {
        let toggle = LaunchAtLoginToggle(label: "起動時に開く")
        _ = toggle.body
    }

    /// service の API surface が公開されていることだけ担保する。
    /// `isEnabled` は読み取りのみで副作用が無いため、テスト実行中に呼んでも安全。
    func testServiceIsEnabledIsReadable() {
        _ = LaunchAtLoginService.isEnabled
    }
}
