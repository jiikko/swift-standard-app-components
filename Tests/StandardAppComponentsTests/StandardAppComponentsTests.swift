import XCTest
@testable import StandardAppComponents

final class StandardAppComponentsTests: XCTestCase {
    func testVersionIsExposed() {
        XCTAssertFalse(StandardAppComponents.version.isEmpty)
    }

    /// requiredKeys が全 supported locale で揃っていることを CI で担保する。
    /// validateRequiredKeys() は欠けがあると fatalError で停止するので、
    /// 通常テスト実行で何も起きない = 全キーが揃っているという assertion になる。
    func testAllRequiredLocalizationKeysAreProvided() {
        StandardAppComponentsLocalization.validateRequiredKeys()
    }
}
