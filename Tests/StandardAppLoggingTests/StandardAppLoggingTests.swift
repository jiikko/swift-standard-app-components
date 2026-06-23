import XCTest
import OSLog
@testable import StandardAppLogging

/// 副作用 (os.Logger / stderr) は SPM 単体テストで観測しにくいため、
/// `AppLog` から切り出した**純粋な写像規則**を直接担保する
/// (色コード / OSLogType 写像 / privacy 解決 / level ラベル整列)。これらが壊れると
/// 「error なのに色が付かない」「private 既定が public になる」「色なしログから
/// level が消える」等の静かな回帰になるため、最小限ここを押さえる。
final class StandardAppLoggingTests: XCTestCase {

    // MARK: - Color mapping

    func testErrorAndFaultAreBrightRed() {
        XCTAssertEqual(LogColor.ansiCode(for: .error), "\u{001B}[91m")
        XCTAssertEqual(LogColor.ansiCode(for: .fault), "\u{001B}[91m")
    }

    func testWarningIsBrightYellow() {
        XCTAssertEqual(LogColor.ansiCode(for: .warning), "\u{001B}[93m")
    }

    func testNoticeIsBrightCyan() {
        XCTAssertEqual(LogColor.ansiCode(for: .notice), "\u{001B}[96m")
    }

    func testDebugIsGray() {
        XCTAssertEqual(LogColor.ansiCode(for: .debug), "\u{001B}[90m")
    }

    func testInfoHasNoColor() {
        XCTAssertNil(LogColor.ansiCode(for: .info))
    }

    func testApplyWrapsWithResetWhenColored() {
        let out = LogColor.apply(level: .error, to: "[net] boom")
        XCTAssertEqual(out, "\u{001B}[91m[net] boom\u{001B}[0m")
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

    // MARK: - Category default privacy (line log 専用)

    func testCategoryDefaultMessagePrivacyIsRespected() {
        XCTAssertEqual(SampleCategory.secret.defaultMessagePrivacy, .private)
        XCTAssertEqual(SampleCategory.safe.defaultMessagePrivacy, .public)
    }

    // MARK: - colorize 既定の env 判定

    func testColorizeDefaultIsTrueWithCleanEnv() {
        XCTAssertTrue(AppLog.colorizeDefault(environment: [:]))
        XCTAssertTrue(AppLog.colorizeDefault(environment: ["TERM": "xterm-256color"]))
    }

    func testColorizeDefaultIsFalseWhenNoColorPresent() {
        // NO_COLOR は値の有無で判定 (空文字でも off)。https://no-color.org
        XCTAssertFalse(AppLog.colorizeDefault(environment: ["NO_COLOR": ""]))
        XCTAssertFalse(AppLog.colorizeDefault(environment: ["NO_COLOR": "1"]))
    }

    func testColorizeDefaultIsFalseInCI() {
        XCTAssertFalse(AppLog.colorizeDefault(environment: ["CI": "true"]))
    }

    func testColorizeDefaultIsFalseForDumbTerminal() {
        XCTAssertFalse(AppLog.colorizeDefault(environment: ["TERM": "dumb"]))
        // dumb 以外の TERM は色を消さない
        XCTAssertTrue(AppLog.colorizeDefault(environment: ["TERM": "xterm"]))
    }

    // MARK: - structured / OSLog-native lane

    func testOSLoggerForReturnsLoggerAndAcceptsPerFieldPrivacy() {
        // structured レーンは raw Logger を返す。返った Logger に対しては
        // 補間リテラルが呼び出し箇所に来るので per-field privacy がコンパイルできる
        // (StructuredAppLog wrapper が不可能だったのと対照的)。実行して crash しないこと。
        let appLog = AppLog(subsystem: "com.example.tests")
        let logger = appLog.osLogger(for: SampleCategory.secret)
        logger.error("status=\(200, privacy: .public) token=\("abc", privacy: .private)")
    }

    // MARK: - Level label (色なし sink 向け)

    func testLevelLabelsMatchCaseNames() {
        XCTAssertEqual(LogLevel.debug.label, "debug")
        XCTAssertEqual(LogLevel.info.label, "info")
        XCTAssertEqual(LogLevel.notice.label, "notice")
        XCTAssertEqual(LogLevel.warning.label, "warning")
        XCTAssertEqual(LogLevel.error.label, "error")
        XCTAssertEqual(LogLevel.fault.label, "fault")
    }

    func testLabelColumnWidthIsLongestBracketedLabel() {
        // "[warning]" が最長 (9)。整列幅の契約を固定する。
        XCTAssertEqual(LogLevel.labelColumnWidth, 9)
    }

    // MARK: - DEBUG mirror line formatting

    func testMirrorLineColorizedWrapsBodyByLevelWithoutLevelText() {
        // colorize=true (開発ビュー): level は ANSI 色で表し、本文は [category] message のみ。
        XCTAssertEqual(
            AppLog.mirrorLine(level: .error, category: "network", message: "boom", colorize: true),
            "\u{001B}[91m[network] boom\u{001B}[0m"
        )
    }

    func testMirrorLineColorizedInfoHasNoColorAndNoLevelText() {
        // info は LogColor.ansiCode が nil なので colorize=true でも色が付かない。
        // colorize=true なので level テキストも付かない。
        XCTAssertEqual(
            AppLog.mirrorLine(level: .info, category: "app", message: "hi", colorize: true),
            "[app] hi"
        )
    }

    func testMirrorLineNotColorizedPrependsLevelLabel() {
        // colorize=false (grep / CI / tmp/debug.log): 色が使えないので [level] を文字で前置。
        XCTAssertEqual(
            AppLog.mirrorLine(level: .error, category: "network", message: "boom", colorize: false),
            "[error]   [network] boom"
        )
        XCTAssertEqual(
            AppLog.mirrorLine(level: .info, category: "perf", message: "decoded in 12ms", colorize: false),
            "[info]    [perf] decoded in 12ms"
        )
    }

    func testMirrorLineNotColorizedAlignsCategoryColumn() {
        // 最長 level "[warning]" はパディングなしで、category 列が他レベルと揃う。
        XCTAssertEqual(
            AppLog.mirrorLine(level: .warning, category: "network", message: "retry", colorize: false),
            "[warning] [network] retry"
        )
    }
}

// MARK: - Fixtures

private enum SampleCategory: String, LogCategory {
    case secret
    case safe

    var categoryName: String { rawValue }
    var defaultMessagePrivacy: LogPrivacy {
        switch self {
        case .secret: return .private
        case .safe: return .public
        }
    }
}
