@testable import StandardAppComponents
import UniformTypeIdentifiers
import XCTest

/// タブのドラッグの item provider は、設定した型だけを出す (同じウィンドウの文字・ファイルの drop 先に混ざらない)
final class StandardTabDragTypeTests: XCTestCase {
    func test_既定は文字の型で出す() {
        let provider = StandardTabStripConfiguration().makeDragItemProvider()
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
    }

    func test_専用の型を渡したらその型だけを出す() {
        let custom = UTType(exportedAs: "com.example.standard-tab-strip-test")
        let provider = StandardTabStripConfiguration(dragType: custom).makeDragItemProvider()
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(custom.identifier))
        XCTAssertFalse(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
        XCTAssertFalse(provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier))
        XCTAssertFalse(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
    }
}
