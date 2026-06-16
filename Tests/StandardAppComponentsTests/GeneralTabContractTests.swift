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

    // MARK: - SettingsWindow init API surface
    //
    // SettingsWindow の公開 init バリエーション (contract のみ / per-tab heights +
    // defaultHeight / width 指定) が崩れていないことを 1 本で担保する。
    // 高さ解決の振る舞い自体は下の resolveTargetHeight 系テストが網羅しているので、
    // ここでは「各 init が呼べて body 評価が通る」= API surface の回帰検出のみが目的。
    func testSettingsWindowInitVariantsRemainAvailable() {
        let contract = GeneralTabContract(
            appearance: { Text("A") },
            language:   { Text("L") }
        )

        // contract のみ
        _ = SettingsWindow(general: contract) { Text("Custom Tab") }.body

        // heights / defaultHeight 指定あり
        _ = SettingsWindow(
            general: contract,
            heights: [
                SettingsWindow<Text>.generalTabId: 350,
                "shortcuts": 600
            ],
            defaultHeight: 400
        ) {
            Text("Custom Tab").tag("shortcuts")
        }.body

        // width 指定あり
        _ = SettingsWindow(
            general: contract,
            width: 520,
            heights: ["shortcuts": 600]
        ) {
            Text("Custom Tab").tag("shortcuts")
        }.body
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
