// 最小サンプル: AppLog + LogCategory の使い方 (UI 非依存の StandardAppLogging product)。
// このファイルはビルド対象には入っていない（参照用）。
//
// 各アプリの SPM 依存に
//   .package(url: "git@github.com:jiikko/swift-standard-app-components.git", branch: "master")
// を追加し、target dependencies に "StandardAppLogging" を含めて使う。
// StandardAppComponents (UI) を import できない Infrastructure / Model 層からも import できる。
//
// 詳細・privacy の制約は docs/logging.md を参照。

import Foundation
import StandardAppLogging
import OSLog   // structured レーン (osLogger) の privacy: 補間に必要 (StandardAppLogging は OSLog を re-export しない)

// MARK: - カテゴリ集合 (アプリ側で定義する)

// lib はカテゴリの集合を知らない。アプリは「サブシステム領域ごとに 1 case」の enum を
// LogCategory に適合させる (exhaustive になり、追加が compile で気づける)。
// categoryName / defaultMessagePrivacy は純値で返すこと (actor / main-actor state を読まない)。
enum MyLogCategory: String, LogCategory {
    case app
    case network
    case perf

    var categoryName: String { rawValue }

    // defaultMessagePrivacy は line log (info/error 等) のメッセージ全体にだけ効く。
    // structured レーン (osLogger(for:)) では補間ごとに privacy を明示する。
    var defaultMessagePrivacy: LogPrivacy {
        switch self {
        case .network:      return .private   // secret 近傍。release で <private> に畳む
        case .app, .perf:   return .public
        }
    }
}

// MARK: - composition root

// AppLog は値型 + Sendable。アプリにつき 1 個作って DI で配る (.shared singleton を作らない)。
let appLog = AppLog(subsystem: "com.example.myapp")

func appDidLaunch() {
    appLog.info(.app, "launched")
    appLog.debug(.perf, "warmup done")
}

// MARK: - 依存注入して使う層 (UI 非依存でよい)

struct ImageDecoder {
    let log: AppLog

    func decode(_ data: Data) {
        let elapsedMs = 12  // 実際は計測値
        log.debug(.perf, "thumbnail decoded in \(elapsedMs)ms")
    }
}

struct SyncClient {
    let log: AppLog

    func fetch() {
        do {
            try performRequest()
        } catch {
            // secret を含みうる値は category に関係なく callsite で sanitize してから渡す。
            // (.network カテゴリでも、それ自体は安全網ではない。docs/logging.md 参照)
            log.error(.network, "request failed: \(sanitize(error))")
        }
    }

    private func performRequest() throws { /* ... */ }
    private func sanitize(_ error: Error) -> String { "\(type(of: error))" }
}

// MARK: - structured レーン: 補間ごとに privacy を分けたい callsite

// line log (上の info/error) はメッセージ単位の privacy しか扱えない。
// フィールド単位で公開/秘匿を出し分けたいときは appLog.osLogger(for:) で
// category 規約付きの Logger を得て、返った Logger に直接書く。
// 入口はあくまで appLog なので Logger(subsystem:category:) を手打ちしない
// (= subsystem / category 規約が structured 側でも保たれる)。
// ※ この callsite は import OSLog が必要 (privacy: 補間が OSLogPrivacy を参照するため)。
struct AuthClient {
    let log: AppLog

    func signIn(userID: String, status: Int) {
        log.osLogger(for: MyLogCategory.network).info(
            "user=\(userID, privacy: .private) status=\(status, privacy: .public)"
        )
        // structured レーンは os.Logger のみ (DEBUG stderr ミラーはしない)。
        // stderr でも見たい要約は sanitize 済みの line log を別途出す:
        log.info(.app, "signIn status=\(status)")
    }
}
