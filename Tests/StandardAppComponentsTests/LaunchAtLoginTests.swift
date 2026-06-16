import XCTest
import ServiceManagement
@testable import StandardAppComponents

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    /// service の API surface が公開されていることだけ担保する。
    /// `isEnabled` / `status` は読み取りのみで副作用が無いため、テスト実行中に呼んでも安全。
    func testServiceIsEnabledIsReadable() {
        _ = LaunchAtLoginService.isEnabled
        _ = LaunchAtLoginService.status
    }

    /// `SMAppService.Status` → `LaunchAtLoginStatus` の正規化 mapping。
    /// `.notFound` (および `@unknown default`) が `.unavailable` に畳まれることが契約
    /// (UI はトグルを無効化する)。`@unknown default` 経路は既知 case しか合成できない
    /// ため直接は踏めない — switch に書かれていることをコンパイルで担保する。
    func testStatusMappingNormalizesAllKnownCases() {
        XCTAssertEqual(LaunchAtLoginStatus(SMAppService.Status.enabled), .enabled)
        XCTAssertEqual(LaunchAtLoginStatus(SMAppService.Status.notRegistered), .notRegistered)
        XCTAssertEqual(LaunchAtLoginStatus(SMAppService.Status.requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginStatus(SMAppService.Status.notFound), .unavailable)
    }
}
