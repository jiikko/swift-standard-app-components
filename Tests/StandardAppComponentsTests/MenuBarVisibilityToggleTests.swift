import XCTest
import SwiftUI
@testable import StandardAppComponents

@MainActor
final class MenuBarVisibilityToggleTests: XCTestCase {
    func testInitializerCompilesWithDefaultLabel() {
        var isOn = false
        let binding = Binding(get: { isOn }, set: { isOn = $0 })
        let toggle = MenuBarVisibilityToggle(isOn: binding)
        _ = toggle.body
    }

    func testInitializerCompilesWithCustomLabel() {
        var isOn = true
        let binding = Binding(get: { isOn }, set: { isOn = $0 })
        let toggle = MenuBarVisibilityToggle(isOn: binding, label: "ステータスバーに表示")
        _ = toggle.body
    }
}
