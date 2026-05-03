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

    // MARK: - SettingsWindowConstants

    func testGeneralTabIdConstantIsStable() {
        // `appTabs` の追加タブが `.tag(...)` で selection binding を合わせるための
        // 安定 ID。値が変わると consumer 側の hardcoded `.tag("general")` 等が
        // 知らないうちに壊れるため、wire-format 相当として固定化する。
        XCTAssertEqual(SettingsWindowConstants.generalTabId, "general")
    }

    func testGeneralTabIdMatchesGenericTypeAccessor() {
        // 同じ値が `SettingsWindow<AppTabs>.generalTabId` でも露出している契約。
        // generic 型パラメータ越しの参照が `SettingsWindowConstants` と一致しているか
        // を担保する (どちらでも同じ ID を取れる二経路の契約)。
        XCTAssertEqual(SettingsWindow<EmptyView>.generalTabId, SettingsWindowConstants.generalTabId)
    }
}
