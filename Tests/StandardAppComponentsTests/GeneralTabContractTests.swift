import XCTest
import SwiftUI
@testable import StandardAppComponents

final class GeneralTabContractTests: XCTestCase {
    func testInitializerWithRequiredSlotsCompiles() {
        let contract = GeneralTabContract(
            appearance: { Text("Appearance") },
            language:   { Text("Language") }
        )
        XCTAssertNotNil(contract.appearance)
        XCTAssertNotNil(contract.language)
    }

    func testInitializerWithOptionalAppSections() {
        let contract = GeneralTabContract(
            appearance:  { Text("Appearance") },
            language:    { Text("Language") },
            appSections: { Text("Custom") }
        )
        XCTAssertNotNil(contract.appSections)
    }

    func testSettingsWindowAcceptsContract() {
        let contract = GeneralTabContract(
            appearance: { Text("A") },
            language:   { Text("L") }
        )
        let window = SettingsWindow(general: contract) { Text("Custom Tab") }
        _ = window.body
    }

    func testSettingsWindowAcceptsMaxHeight() {
        let contract = GeneralTabContract(
            appearance: { Text("A") },
            language:   { Text("L") }
        )
        // maxHeight 指定ありの公開 init が利用可能であること、および body 評価が通ることを担保する。
        let window = SettingsWindow(general: contract, maxHeight: 600) { Text("Custom Tab") }
        _ = window.body
    }
}
