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

    // MARK: - resolveTargetHeight (presentation logic extracted from View)

    func testResolveTargetHeightReturnsMappedHeightWhenPresent() {
        // heights に entry があれば対応する高さを返す。
        let height = SettingsWindow<EmptyView>.resolveTargetHeight(
            selectedTabId: "shortcuts",
            heights: ["shortcuts": 600, "general": 350],
            defaultHeight: 400
        )
        XCTAssertEqual(height, 600)
    }

    func testResolveTargetHeightFallsBackToDefaultWhenKeyMissing() {
        // heights に該当 tag が無ければ defaultHeight にフォールバック。
        // (consumer が一部のタブだけ heights 指定を持っているケース)
        let height = SettingsWindow<EmptyView>.resolveTargetHeight(
            selectedTabId: "untracked-tab",
            heights: ["general": 350],
            defaultHeight: 400
        )
        XCTAssertEqual(height, 400)
    }

    func testResolveTargetHeightFallsBackWhenHeightsIsEmpty() {
        // heights が空 map なら全タブで defaultHeight。
        let height = SettingsWindow<EmptyView>.resolveTargetHeight(
            selectedTabId: SettingsWindowConstants.generalTabId,
            heights: [:],
            defaultHeight: 350
        )
        XCTAssertEqual(height, 350)
    }
}
