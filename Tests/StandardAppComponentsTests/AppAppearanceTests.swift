import XCTest
import SwiftUI
@testable import StandardAppComponents

final class AppAppearanceTests: XCTestCase {
    func testApplyAppAppearanceCompilesWithAllSchemes() {
        // 公開 API として ColorScheme? を受け取れることを担保する。
        // body 評価まで踏み込まないのは、modifier 内部で NSApp に触れるため。
        _ = Text("L").applyAppAppearance(.light)
        _ = Text("D").applyAppAppearance(.dark)
        _ = Text("S").applyAppAppearance(nil)
    }
}
