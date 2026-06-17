import XCTest
import SwiftUI
@testable import StandardAppComponents

@MainActor
final class StandardActionConfirmationTests: XCTestCase {
    func testActionButtonStoresTitleRoleAndInvokesHandler() {
        let expectation = expectation(description: "handler invoked")
        let button = StandardActionButton("Delete", role: .destructive) {
            expectation.fulfill()
        }

        XCTAssertEqual(String(describing: button.title), String(describing: LocalizedStringResource("Delete")))
        XCTAssertEqual(button.role, .destructive)

        button.handler()
        wait(for: [expectation], timeout: 0.1)
    }
}
