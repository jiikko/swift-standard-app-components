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
        // 整数除算 (-1500/1000 = -1) 後の負値も clamp される
        XCTAssertEqual(PlaybackTimeFormatter.format(milliseconds: -1_500), "0:00")
    }

    // MARK: - 負値は 0 に clamp

    func testNegativeInputClampsToZero() {
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: -5), "0:00")
        XCTAssertEqual(PlaybackTimeFormatter.format(milliseconds: -1), "0:00")
    }

    // MARK: - Style (分ゼロ埋め)

    func testPaddedStyleZeroPadsMinutes() {
        let padded = PlaybackTimeFormatter.Style(padsMinutesToTwoDigits: true)
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 5, style: padded), "00:05")
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 65, style: padded), "01:05")
        // 時間表示の桁は style に依らず共通 (時のみ非ゼロ埋め)
        XCTAssertEqual(PlaybackTimeFormatter.format(seconds: 3_600, style: padded), "1:00:00")
    }

    // MARK: - playbackTime (桁は totalDuration で固定)

    private let padded = PlaybackTimeFormatter.Style(padsMinutesToTwoDigits: true)

    func testPlaybackTimeDigitsFollowTotalDuration() {
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(0, totalDuration: 0, style: padded), "00:00")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(3_599, totalDuration: 3_599, style: padded), "59:59")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(3_600, totalDuration: 3_600, style: padded), "1:00:00")
        // 経過 5 秒でも総尺 2 時間なら H:MM:SS 桁 (再生中に幅が揺れない)
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(5, totalDuration: 7_200, style: padded), "0:00:05")
        // 総尺不明 (nil / 非有限) は経過時刻自身で桁を決める
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(5, totalDuration: nil, style: padded), "00:05")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(3_660, totalDuration: .infinity, style: padded), "1:01:00")
        // 総尺メタデータが実尺より短い動画 (VFR / 壊れた moov): 経過時刻側でも時間表示に切り替わる
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(3_700, totalDuration: 120, style: padded), "1:01:40")
    }

    func testPlaybackTimeInvalidElapsedFallsBackToZero() {
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(nil, totalDuration: 120, style: padded), "00:00")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(-1, totalDuration: 120, style: padded), "00:00")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(.nan, totalDuration: 120, style: padded), "00:00")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(.infinity, totalDuration: 120, style: padded), "00:00")
    }

    func testRemainingTimeInvalidCurrentTimeFallsBackToFullDuration() {
        // 不明な現在時刻は 0 に倒す = 残り時間は全尺
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: .nan, totalDuration: 125, style: padded),
            "-02:05"
        )
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: nil, totalDuration: 125, style: padded),
            "-02:05"
        )
    }

    func testPlaybackTimeHugeFiniteValueDoesNotTrap() {
        // Int(Double) は Int.max 近傍 (2^63) で fatalError する。clamp が無いと
        // このテストはプロセスごと落ちる (= 変異検証を兼ねる)。
        _ = PlaybackTimeFormatter.playbackTime(1e20, totalDuration: 1e20, style: padded)
        _ = PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 0, totalDuration: 1e20, style: padded)
        XCTAssertTrue(
            PlaybackTimeFormatter.playbackTime(TimeInterval(Int64.max), totalDuration: nil, style: padded)
                .hasSuffix(":07")
        )
    }

    func testPlaybackTimeDefaultStyleIsNotPadded() {
        // style 省略時の既定は "M:SS" (format(seconds:) の既定と同じ)。
        // 既定を padded に変える変更はここで red になる。
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(65, totalDuration: 120), "1:05")
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 65, totalDuration: 125),
            "-1:00"
        )
    }

    func testPlaybackTimeHourBoundaries() {
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(59, totalDuration: 59, style: padded), "00:59")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(60, totalDuration: 60, style: padded), "01:00")
        // 2 桁時でも時はゼロ埋めしない
        XCTAssertEqual(
            PlaybackTimeFormatter.playbackTime(86_399, totalDuration: 86_399, style: padded),
            "23:59:59"
        )
    }

    func testPlaybackTimeRoundsSeconds() {
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(65.4, totalDuration: 120, style: padded), "01:05")
        XCTAssertEqual(PlaybackTimeFormatter.playbackTime(65.5, totalDuration: 120, style: padded), "01:06")
    }

    // MARK: - remainingPlaybackTime

    func testRemainingTimeIsClampedAndPrefixed() {
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 65, totalDuration: 125, style: padded),
            "-01:00"
        )
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 0, totalDuration: 7_325, style: padded),
            "-2:02:05"
        )
        // 丸め誤差等で current > duration でも "-00:00" 止まり
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 126, totalDuration: 125, style: padded),
            "-00:00"
        )
        // duration 不明は "-00:00" (表示上の安全側)
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 10, totalDuration: nil, style: padded),
            "-00:00"
        )
        // 桁は残量ではなく総尺で固定する (カウントダウン中に表示幅が縮まない)
        XCTAssertEqual(
            PlaybackTimeFormatter.remainingPlaybackTime(currentTime: 100, totalDuration: 3_650, style: padded),
            "-0:59:10"
        )
    }
}
