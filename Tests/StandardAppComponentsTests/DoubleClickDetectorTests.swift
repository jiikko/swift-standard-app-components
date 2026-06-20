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

    // MARK: - public API surface

    func testCheckDoubleClickNoArgFirstClickIsSingle() {
        // 引数省略の public 経路 (= production callsite と同じ) が動くことの smoke。
        // 初回 click は必ず single。
        let detector = DoubleClickDetector()
        XCTAssertFalse(detector.checkDoubleClick())
    }
}
