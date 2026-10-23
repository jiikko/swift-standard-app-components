import XCTest
import AppKit
import SwiftUI
@testable import StandardAppComponents

final class AppAppearanceTests: XCTestCase {
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

    // MARK: - Windows

    // status item の window (level `.statusBar`) を上書きすると、メニューバーのアイコンがアプリの外観で描かれる。
    func testApplySkipsStatusBarLevelWindows() {
        let normal = NSWindow(contentRect: .init(x: 0, y: 0, width: 10, height: 10), styleMask: [.titled], backing: .buffered, defer: true)
        let statusBar = NSWindow(contentRect: .init(x: 0, y: 0, width: 10, height: 10), styleMask: [.borderless], backing: .buffered, defer: true)
        statusBar.level = .statusBar
        let dark = NSAppearance(named: .darkAqua)

        AppAppearanceWindows.apply(dark, to: [normal, statusBar])

        XCTAssertEqual(normal.appearance?.name, .darkAqua)
        XCTAssertNil(statusBar.appearance)
    }

    func testApplyNilClearsAppWindowsButLeavesStatusBarWindows() {
        let normal = NSWindow(contentRect: .init(x: 0, y: 0, width: 10, height: 10), styleMask: [.titled], backing: .buffered, defer: true)
        normal.appearance = NSAppearance(named: .darkAqua)
        let statusBar = NSWindow(contentRect: .init(x: 0, y: 0, width: 10, height: 10), styleMask: [.borderless], backing: .buffered, defer: true)
        statusBar.level = .statusBar
        statusBar.appearance = NSAppearance(named: .vibrantDark)

        AppAppearanceWindows.apply(nil, to: [normal, statusBar])

        XCTAssertNil(normal.appearance)
        XCTAssertEqual(statusBar.appearance?.name, .vibrantDark)
    }
}
