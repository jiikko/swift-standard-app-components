import XCTest
import AppKit
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

    // MARK: - Mapping (ColorScheme? -> NSAppearance?)
    //
    // Modifier 本体が NSApp に副作用を出す部分は SwiftUI の render cycle がいるため
    // SPM 単体テストでは検証しにくい。代わりに「写像規則」を `AppAppearanceMapping`
    // に切り出してあるので、こちらを直接担保する。
    // 写像が壊れる = `applyAppAppearance(.dark)` が darkAqua じゃないものを設定する、という
    // 致命的な回帰になるため、最小限ここだけは押さえる。

    func testMappingLightReturnsAqua() {
        let appearance = AppAppearanceMapping.nsAppearance(for: .light)
        XCTAssertEqual(appearance?.name, .aqua)
    }

    func testMappingDarkReturnsDarkAqua() {
        let appearance = AppAppearanceMapping.nsAppearance(for: .dark)
        XCTAssertEqual(appearance?.name, .darkAqua)
    }

    func testMappingNilReturnsNil() {
        // System 追従モード: NSApp.appearance を nil にすることで NSApp が
        // OS の effectiveAppearance に追従するようになる。
        let appearance = AppAppearanceMapping.nsAppearance(for: nil)
        XCTAssertNil(appearance)
    }
}
