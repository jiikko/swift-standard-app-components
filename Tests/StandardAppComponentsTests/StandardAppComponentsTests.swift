import XCTest
@testable import StandardAppComponents

final class StandardAppComponentsTests: XCTestCase {
    func testVersionIsExposed() {
        XCTAssertFalse(StandardAppComponents.version.isEmpty)
    }
}
