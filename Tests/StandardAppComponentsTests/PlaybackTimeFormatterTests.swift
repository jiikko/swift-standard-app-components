import XCTest
@testable import StandardAppComponents

final class PlaybackTimeFormatterTests: XCTestCase {
    // MARK: - 1 時間未満 (分:秒)

    func testZeroSeconds() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 0), "0:00")
    }

    func testUnderOneMinute() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 9), "0:09")
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 59), "0:59")
    }

    func testUnderOneHour() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 60), "1:00")
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 59 * 60 + 59), "59:59")
    }

    // MARK: - 1 時間以上 (時:分:秒)
    // 90 分を "90:00" と表示する自前整形バグの再発防止。

    func testExactlyOneHour() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 3600), "1:00:00")
    }

    func testNinetyMinutesSwitchesToHourFormat() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 90 * 60), "1:30:00")
    }

    func testHoursMinutesSecondsPadding() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 3600 + 5 * 60 + 7), "1:05:07")
    }

    // MARK: - milliseconds 入口

    func testMillisecondsTruncatesTowardZero() {
        XCTAssertEqual(PlaybackTimeFormatter.format(milliseconds: 999), "0:00")
        XCTAssertEqual(PlaybackTimeFormatter.format(milliseconds: 61_000), "1:01")
    }

    // MARK: - 負値は 0 に clamp

    func testNegativeInputClampsToZero() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: -5), "0:00")
        XCTAssertEqual(PlaybackTimeFormatter.format(milliseconds: -1), "0:00")
    }
}
