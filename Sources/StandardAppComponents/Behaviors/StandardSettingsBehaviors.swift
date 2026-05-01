import SwiftUI
import AppKit

public extension View {
    func standardSettingsBehaviors() -> some View {
        modifier(StandardSettingsBehaviorsModifier())
    }
}

private struct StandardSettingsBehaviorsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onExitCommand {
                NSApp.keyWindow?.close()
            }
    }
}
