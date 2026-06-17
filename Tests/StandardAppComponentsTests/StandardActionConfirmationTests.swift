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

    func testConfirmationConfigurationSuppressesSubjectActionsAndMessageWhenSubjectIsMissing() {
        let configuration = StandardActionConfirmationConfiguration(
            hasSubject: false,
            primary: StandardActionButton("Overwrite") {},
            secondary: StandardActionButton("Reload") {},
            destructive: StandardActionButton("Delete", role: .destructive) {}
        )

        XCTAssertFalse(configuration.showsSubjectActions)
        XCTAssertFalse(configuration.showsMessage)
        XCTAssertTrue(configuration.actionButtons.isEmpty)
    }

    func testConfirmationConfigurationExposesButtonsInStableOrderWhenSubjectExists() {
        let configuration = StandardActionConfirmationConfiguration(
            hasSubject: true,
            primary: StandardActionButton("Overwrite") {},
            secondary: StandardActionButton("Reload") {},
            destructive: StandardActionButton("Delete", role: .destructive) {}
        )

        XCTAssertTrue(configuration.showsSubjectActions)
        XCTAssertTrue(configuration.showsMessage)
        XCTAssertEqual(configuration.actionButtons.count, 3)
        XCTAssertEqual(
            configuration.actionButtons.map { String(describing: $0.title) },
            [
                String(describing: LocalizedStringResource("Overwrite")),
                String(describing: LocalizedStringResource("Reload")),
                String(describing: LocalizedStringResource("Delete"))
            ]
        )
        XCTAssertEqual(configuration.actionButtons.map(\.role), [nil, nil, .destructive])
    }

    func testConfirmationConfigurationSkipsMissingOptionalButtons() {
        let configuration = StandardActionConfirmationConfiguration(
            hasSubject: true,
            primary: nil,
            secondary: StandardActionButton("Show Diff") {},
            destructive: nil
        )

        XCTAssertEqual(configuration.actionButtons.count, 1)
        XCTAssertEqual(
            String(describing: configuration.actionButtons[0].title),
            String(describing: LocalizedStringResource("Show Diff"))
        )
    }
}

@MainActor
final class StandardBlockingProgressOverlayTests: XCTestCase {
    func testOverlayConfigurationBlocksBackgroundOnlyWhenPresented() {
        let hidden = StandardBlockingProgressOverlayConfiguration(isPresented: false, hasCancelAction: false)
        XCTAssertFalse(hidden.showsOverlay)
        XCTAssertFalse(hidden.disablesBackground)

        let visible = StandardBlockingProgressOverlayConfiguration(isPresented: true, hasCancelAction: false)
        XCTAssertTrue(visible.showsOverlay)
        XCTAssertTrue(visible.disablesBackground)
    }

    func testOverlayConfigurationShowsCancelButtonOnlyWhenHandlerExists() {
        let withoutCancel = StandardBlockingProgressOverlayConfiguration(isPresented: true, hasCancelAction: false)
        XCTAssertFalse(withoutCancel.showsCancelButton)

        let withCancel = StandardBlockingProgressOverlayConfiguration(isPresented: true, hasCancelAction: true)
        XCTAssertTrue(withCancel.showsCancelButton)
    }
}
