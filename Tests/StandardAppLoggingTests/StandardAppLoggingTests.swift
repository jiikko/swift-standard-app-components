import XCTest
import OSLog
@testable import StandardAppLogging

/// 副作用 (os.Logger / NSLog) は SPM 単体テストで観測しにくいため、
/// `AppLog` から切り出した**純粋な写像規則**を直接担保する
/// (色コード / OSLogType 写像 / privacy 解決)。これらが壊れると
/// 「error なのに色が付かない」「private 既定が public になる」等の
/// 静かな回帰になるため、最小限ここを押さえる。
final class StandardAppLoggingTests: XCTestCase {

    // MARK: - Color mapping

    func testErrorAndFaultAreRed() {
        XCTAssertEqual(LogColor.ansiCode(for: .error), "\u{001B}[31m")
        XCTAssertEqual(LogColor.ansiCode(for: .fault), "\u{001B}[31m")
    }

    func testWarningIsYellow() {
        XCTAssertEqual(LogColor.ansiCode(for: .warning), "\u{001B}[33m")
    }

    func testInfoHasNoColor() {
        XCTAssertNil(LogColor.ansiCode(for: .info))
    }

    func testApplyWrapsWithResetWhenColored() {
        let out = LogColor.apply(level: .error, to: "[net] boom")
        XCTAssertEqual(out, "\u{001B}[31m[net] boom\u{001B}[0m")
    }

    func testApplyLeavesInfoUnchanged() {
        XCTAssertEqual(LogColor.apply(level: .info, to: "[net] hi"), "[net] hi")
    }

    // MARK: - OSLogType mapping (Apple の Logger と同じ畳み方)

    func testOSLogTypeMapping() {
        XCTAssertEqual(LogLevel.debug.osLogType, .debug)
        XCTAssertEqual(LogLevel.info.osLogType, .info)
        XCTAssertEqual(LogLevel.notice.osLogType, .default)
        XCTAssertEqual(LogLevel.warning.osLogType, .error)
        XCTAssertEqual(LogLevel.error.osLogType, .error)
        XCTAssertEqual(LogLevel.fault.osLogType, .fault)
    }

    // MARK: - Category default privacy

    func testCategoryDefaultPrivacyIsRespected() {
        XCTAssertEqual(SampleCategory.secret.defaultPrivacy, .private)
        XCTAssertEqual(SampleCategory.safe.defaultPrivacy, .public)
    }

    // MARK: - DEBUG mirror line formatting

    func testMirrorLineWrapsCategoryAndMessage() {
        XCTAssertEqual(
            AppLog.mirrorLine(level: .info, category: "network", message: "boom", colorize: false),
            "[network] boom"
        )
    }

    func testMirrorLineColorizesByLevel() {
        XCTAssertEqual(
            AppLog.mirrorLine(level: .error, category: "network", message: "boom", colorize: true),
            "\u{001B}[31m[network] boom\u{001B}[0m"
        )
    }

    func testMirrorLineColorizeFalseLeavesLinePlain() {
        XCTAssertEqual(
            AppLog.mirrorLine(level: .error, category: "network", message: "boom", colorize: false),
            "[network] boom"
        )
    }

    func testMirrorLineInfoHasNoColorEvenWhenColorized() {
        // info は LogColor.ansiCode が nil なので colorize=true でも色が付かない。
        XCTAssertEqual(
            AppLog.mirrorLine(level: .info, category: "app", message: "hi", colorize: true),
            "[app] hi"
        )
    }
}

// MARK: - Fixtures

private enum SampleCategory: String, LogCategory {
    case secret
    case safe

    var categoryName: String { rawValue }
    var defaultPrivacy: LogPrivacy {
        switch self {
        case .secret: return .private
        case .safe: return .public
        }
    }
}
