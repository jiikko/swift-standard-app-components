import XCTest
import SwiftUI
import AppKit
@testable import StandardAppComponents

final class WindowBackgroundViewTests: XCTestCase {
    func testInitializerWithDefaults() {
        let view = WindowBackgroundView()
        XCTAssertEqual(view.material, .windowBackground)
        XCTAssertEqual(view.blendingMode, .behindWindow)
    }

    func testInitializerWithCustomMaterial() {
        let view = WindowBackgroundView(material: .sidebar, blendingMode: .withinWindow)
        XCTAssertEqual(view.material, .sidebar)
        XCTAssertEqual(view.blendingMode, .withinWindow)
    }

    /// makeNSView / updateNSView の挙動を検証するには SwiftUI の hosting が必要で、
    /// `NSViewRepresentable.Context` を unit test レイヤから合法的に組み立てる手段がない。
    /// 中身が trivial な passthrough のため、これらは公開 API の存在確認に留め、
    /// 実際の NSVisualEffectView 設定は integration / smoke test で担保する方針。
    func testMakeAndUpdateAreExposed() {
        let view = WindowBackgroundView()
        // 公開 API として呼び出し可能であること（context 引数は signature を満たすためだけに必要）
        let _: (WindowBackgroundView.Context) -> NSVisualEffectView = view.makeNSView
        let _: (NSVisualEffectView, WindowBackgroundView.Context) -> Void = view.updateNSView
    }
}
