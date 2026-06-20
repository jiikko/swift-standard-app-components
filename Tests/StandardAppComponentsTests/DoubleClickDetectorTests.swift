import XCTest
@testable import StandardAppComponents

/// `DoubleClickDetector` の判定ロジックを決定論的に検証する。
///
/// `checkDoubleClick(at:)` は `Date.now` / `NSEvent.doubleClickInterval` に依存して
/// 非決定論的になるため、internal な `evaluate(at:now:systemInterval:)` seam を
/// 使って時刻と system interval を注入する (= 実時間 sleep / 実機の
/// "Double-click speed" 設定に依存しない)。
final class DoubleClickDetectorTests: XCTestCase {
    /// 基準時刻 (固定)。`Date.now` を避けて決定論性を担保する。
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    // MARK: - interval clamp (floor)

    func testFloorAppliesWhenSystemIntervalShorterThanMinimum() {
        // Fastest 設定 (systemInterval = 0.15s) でも、floor 0.3s が効くことで
        // 0.25s 間隔の通常 double click が成立する。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.15))
        XCTAssertTrue(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.25), systemInterval: 0.15))
    }

    func testWithoutFloorFastestSettingDropsNormalDoubleClick() {
        // floor 無効 (minimumInterval = 0) だと、Fastest 設定 (0.15s) では
        // 0.25s 間隔の double click が落ちる (= floor 導入前の退行を再現)。
        // これが obaket で floor を入れた理由の回帰テスト。
        let detector = DoubleClickDetector(minimumInterval: 0)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.15))
        XCTAssertFalse(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.25), systemInterval: 0.15))
    }

    func testSystemIntervalHonoredWhenLongerThanFloor() {
        // system 設定が floor より長いときは system に従う (= 上書きしない)。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.5))
        // 0.4s 間隔: floor 0.3 は超えるが system 0.5 未満なので double 成立。
        XCTAssertTrue(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.4), systemInterval: 0.5))
    }

    // MARK: - interval expiry

    func testExpiredIntervalIsNotDoubleClick() {
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        // effectiveInterval = max(0.3, 0.3) = 0.3。0.5s 経過は超過 → single 扱い。
        XCTAssertFalse(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.5), systemInterval: 0.3))
    }

    // MARK: - distance threshold

    func testDistanceBeyondThresholdIsNotDoubleClick() {
        // 時間内でも、距離が閾値 (既定 10pt) を超えると double にならない。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(at: CGPoint(x: 100, y: 0), now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    func testDistanceWithinThresholdIsDoubleClick() {
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        // 距離 5pt (< 10pt 閾値) かつ時間内 → double 成立。
        XCTAssertTrue(detector.evaluate(at: CGPoint(x: 3, y: 4), now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    func testCustomDistanceThreshold() {
        // distanceThreshold を狭めると、既定なら double になる距離が落ちる。
        let detector = DoubleClickDetector(minimumInterval: 0.3, distanceThreshold: 2)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(at: CGPoint(x: 3, y: 4), now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    // MARK: - reset semantics (連打 3 連)

    func testTripleClickDoesNotProduceTwoDoubleClicks() {
        // 1→2 で double 成立後に state を reset するので、2→3 は double にならない。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        XCTAssertTrue(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.2), systemInterval: 0.3))
        // 4 click 目は再び double になれる。
        XCTAssertTrue(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.3), systemInterval: 0.3))
    }

    func testExplicitResetClearsState() {
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        detector.reset()
        // reset 後は前回 click が無かった扱い → 直後の click も single。
        XCTAssertFalse(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    // MARK: - id mode

    func testIDSameTargetWithinIntervalIsDoubleClick() {
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: "tab-a", now: t0, systemInterval: 0.3))
        XCTAssertTrue(detector.evaluate(id: "tab-a", now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    func testIDDifferentTargetIsNotDoubleClick() {
        // 時間内でも、別 id への 2 連クリックは double にならない (= 別 tab を続けて
        // click しても起動しない)。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: "tab-a", now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(id: "tab-b", now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    func testIDExpiredIntervalIsNotDoubleClick() {
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: "tab", now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(id: "tab", now: t0.addingTimeInterval(0.5), systemInterval: 0.3))
    }

    func testIDFloorApplies() {
        // floor は id モードでも効く (位置モードと共通コア)。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: 1, now: t0, systemInterval: 0.15))
        XCTAssertTrue(detector.evaluate(id: 1, now: t0.addingTimeInterval(0.25), systemInterval: 0.15))
    }

    func testIDTripleClickDoesNotProduceTwoDoubleClicks() {
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: "tab", now: t0, systemInterval: 0.3))
        XCTAssertTrue(detector.evaluate(id: "tab", now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(id: "tab", now: t0.addingTimeInterval(0.2), systemInterval: 0.3))
    }

    func testIDTypeMismatchIsNotDoubleClick() {
        // 同じ数値でも型が違えば別ターゲット。AnyHashable の数値ブリッジ
        // (AnyHashable(1 as Int) == AnyHashable(1 as Int64)) による誤一致を型で弾く。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: 1 as Int, now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(id: 1 as Int64, now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    // MARK: - cross-mode 境界 (1 instance = 1 mode 想定)

    func testCrossModeSwitchLocationThenIDDoesNotDoubleClick() {
        // 直前が位置モードなら、id モードの click は同一ターゲットにならない。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(at: .zero, now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(id: 1, now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    func testCrossModeSwitchIDThenLocationDoesNotDoubleClick() {
        // 逆方向: 直前が id モードなら、位置モードの click は同一ターゲットにならない。
        let detector = DoubleClickDetector(minimumInterval: 0.3)

        XCTAssertFalse(detector.evaluate(id: 1, now: t0, systemInterval: 0.3))
        XCTAssertFalse(detector.evaluate(at: .zero, now: t0.addingTimeInterval(0.1), systemInterval: 0.3))
    }

    // MARK: - public API surface

    func testPublicSurfaceFirstClickIsSingle() {
        // 引数つきの public 経路 (= production callsite と同じ) が動くことの smoke。
        // 初回 click は両モードとも必ず single。
        XCTAssertFalse(DoubleClickDetector().checkDoubleClick(at: .zero))
        XCTAssertFalse(DoubleClickDetector().checkDoubleClick(id: 1))
    }
}
