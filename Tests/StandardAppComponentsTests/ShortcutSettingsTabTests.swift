import XCTest
import SwiftUI
@testable import StandardAppComponents

final class ShortcutSettingsTabTests: XCTestCase {
    func testShortcutModelsAreHashableAndIdentifiable() {
        let item = StandardShortcutItem(
            id: "playPause",
            title: "Play / Pause",
            shortcut: "Space",
            isEditable: true,
            isCustomized: false
        )
        let group = StandardShortcutGroup(
            id: "global",
            title: "Global",
            subtitle: "App-wide shortcuts",
            items: [item]
        )

        XCTAssertEqual(item.id, "playPause")
        XCTAssertEqual(group.items, [item])
    }

    func testShortcutSettingsTabInitializerCompiles() {
        let tab = ShortcutSettingsTab(
            groups: [
                StandardShortcutGroup(
                    id: "global",
                    title: "Global",
                    items: [
                        StandardShortcutItem(
                            id: "playPause",
                            title: "Play / Pause",
                            shortcut: "Space"
                        )
                    ]
                )
            ],
            recordingItemID: "playPause",
            conflictWarning: "Conflicts with Toggle Sidebar",
            onShortcutClick: { _ in },
            onReset: { _ in },
            onResetAll: {}
        )

        _ = tab.body
    }
}
