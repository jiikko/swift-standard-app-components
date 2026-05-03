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

    func testSettingsWindowAcceptsPerTabHeights() {
        let contract = GeneralTabContract(
            appearance: { Text("A") },
            language:   { Text("L") }
        )
        // heights / defaultHeight 指定ありの公開 init が利用可能であること、および
        // body 評価が通ることを担保する。
        let window = SettingsWindow(
            general: contract,
            heights: [
                SettingsWindow<Text>.generalTabId: 350,
                "shortcuts": 600
            ],
            defaultHeight: 400
        ) {
            Text("Custom Tab").tag("shortcuts")
        }
        _ = window.body
    }

    func testSettingsWindowAcceptsWidth() {
        let contract = GeneralTabContract(
            appearance: { Text("A") },
            language:   { Text("L") }
        )
        // width 指定ありの公開 init が利用可能であることを担保する。
        let window = SettingsWindow(
            general: contract,
            width: 520,
            heights: ["shortcuts": 600]
        ) {
            Text("Custom Tab").tag("shortcuts")
        }
        _ = window.body
    }
}
