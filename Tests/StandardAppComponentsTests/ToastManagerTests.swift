import XCTest
import SwiftUI
@testable import StandardAppComponents

@MainActor
final class ToastManagerTests: XCTestCase {
    /// dismiss → 次トースト表示までの待機時間 (ToastManager 内部定数 0.3 秒)。
    /// 内部実装を直接参照できないため、テスト側で同値を保持して timing 待機に使う。
    /// 余裕を見て 0.5 秒待つ。
    private let dismissProcessingWindow: Duration = .seconds(0.5)

    // MARK: - Initial state

    func testInitialStateHasNoCurrentToast() {
        let manager = ToastManager()
        XCTAssertNil(manager.currentToast)
    }

    // MARK: - show

    func testShowSetsCurrentToastImmediately() {
        let manager = ToastManager()
        let toast = Toast(style: .info, title: "Hello", duration: 10)
        manager.show(toast)
        XCTAssertEqual(manager.currentToast?.id, toast.id)
        XCTAssertEqual(manager.currentToast?.title, "Hello")
        manager.clearAll()
    }

    func testSecondShowQueuesUntilFirstDismisses() async throws {
        // 最初のトースト表示中に来た 2 件目はキューに入り、currentToast は最初のまま。
        // 1 件目を dismiss → 内部の processingDelay 経過後に 2 件目に切り替わる。
        let manager = ToastManager()
        let first = Toast(style: .info, title: "First", duration: 10)
        let second = Toast(style: .info, title: "Second", duration: 10)
        manager.show(first)
        manager.show(second)
        XCTAssertEqual(manager.currentToast?.title, "First")

        manager.dismiss()
        try await Task.sleep(for: dismissProcessingWindow)
        XCTAssertEqual(manager.currentToast?.title, "Second")
        manager.clearAll()
    }

    // MARK: - 便利メソッド

    func testShowSuccessUsesSuccessStyleAndTitle() {
        let manager = ToastManager()
        manager.showSuccess("Saved", duration: 10)
        XCTAssertEqual(manager.currentToast?.style, .success)
        XCTAssertEqual(manager.currentToast?.title, "Saved")
        manager.clearAll()
    }

    func testShowErrorUsesErrorStyleAndLongerDuration() {
        // エラーは default で 5 秒に伸ばされる (DisplayConstants.errorDuration)。
        let manager = ToastManager()
        manager.showError("Failed")
        XCTAssertEqual(manager.currentToast?.style, .error)
        XCTAssertEqual(manager.currentToast?.title, "Failed")
        XCTAssertEqual(manager.currentToast?.duration, 5.0)
        manager.clearAll()
    }

    func testShowInfoUsesInfoStyle() {
        let manager = ToastManager()
        manager.showInfo("Updated", duration: 10)
        XCTAssertEqual(manager.currentToast?.style, .info)
        XCTAssertEqual(manager.currentToast?.title, "Updated")
        manager.clearAll()
    }

    func testShowWarningUsesWarningStyle() {
        let manager = ToastManager()
        manager.showWarning("Heads up", duration: 10)
        XCTAssertEqual(manager.currentToast?.style, .warning)
        XCTAssertEqual(manager.currentToast?.title, "Heads up")
        manager.clearAll()
    }

    func testShowWithActionStoresActionAndIsInvokable() {
        let manager = ToastManager()
        let invoked = expectation(description: "action handler invoked")
        let action = ToastAction(title: "Open") { invoked.fulfill() }
        manager.showWithAction(
            style: .success,
            title: "Done",
            duration: 10,
            action: action
        )
        XCTAssertEqual(manager.currentToast?.style, .success)
        XCTAssertEqual(manager.currentToast?.action?.title, "Open")
        manager.currentToast?.action?.handler()
        wait(for: [invoked], timeout: 0.1)
        manager.clearAll()
    }

    func testVerbatimMessageBypassesLocalizationCatalog() {
        // .verbatim で渡したメッセージは catalog lookup を経ずそのまま resolve される。
        // (catalog バイパスをコンパイル時に潰す ToastText の設計を Manager 経由でも担保する)
        let manager = ToastManager()
        let userInput = "Path: /private/tmp/Foo Bar.png"
        manager.showError("Failed", message: .verbatim(userInput))
        XCTAssertEqual(manager.currentToast?.message, userInput)
        manager.clearAll()
    }

    // MARK: - dismiss

    func testDismissClearsCurrentToast() {
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "X", duration: 10))
        XCTAssertNotNil(manager.currentToast)
        manager.dismiss()
        XCTAssertNil(manager.currentToast)
        manager.clearAll()
    }

    func testAutoDismissAfterDuration() async throws {
        // duration 経過で自動的に dismiss されること。タイマーの実装が壊れていないか担保する。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "Auto", duration: 0.1))
        XCTAssertNotNil(manager.currentToast)
        try await Task.sleep(for: .seconds(0.25))  // duration 0.1 + 多少の余裕
        XCTAssertNil(manager.currentToast)
        manager.clearAll()
    }

    // MARK: - clearAll

    func testClearAllResetsCurrentAndQueue() async throws {
        // clearAll: currentToast を nil に / キューを空に / 次トースト処理タスクを cancel。
        // 呼んだ後にいくら待っても何も表示されないこと。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "First", duration: 10))
        manager.show(Toast(style: .info, title: "Second", duration: 10))
        manager.show(Toast(style: .info, title: "Third", duration: 10))
        XCTAssertNotNil(manager.currentToast)

        manager.clearAll()
        XCTAssertNil(manager.currentToast)

        // dismiss 後の processingDelay 経過後にキューから次が出てこないこと。
        try await Task.sleep(for: dismissProcessingWindow)
        XCTAssertNil(manager.currentToast)
    }

    // MARK: - cancellation 連鎖の回帰ガード (#fix(Toast): cancelled timer tasks chain extra dismisses)

    func testManualDismissAdvancesQueueByExactlyOne() async throws {
        // 手動 dismiss を 1 回呼んだら、processingDelay 経過後にキューは 1 件だけ進むこと。
        // CancellationError swallow バグ (cancel された auto-dismiss task が後続を実行) が
        // あると 2〜3 件先まで進む。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "current", duration: 10))
        manager.show(Toast(style: .info, title: "next-1", duration: 10))
        manager.show(Toast(style: .info, title: "next-2", duration: 10))

        manager.dismiss()
        try await Task.sleep(for: dismissProcessingWindow)

        XCTAssertEqual(manager.currentToast?.title, "next-1")
        manager.clearAll()
    }

    func testClearAllPreventsCancelledQueueTaskFromResuming() async throws {
        // dismiss → clearAll → wait > processingDelay でキューが復活しないこと。
        // dismiss が schedule した queueProcessingTask は clearAll で cancel されるが、
        // CancellationError swallow バグがあると processQueue を呼んでしまい、
        // clearAll で空にしたはずのキューが復活する。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "current", duration: 10))
        manager.show(Toast(style: .info, title: "next", duration: 10))

        manager.dismiss()
        manager.clearAll()
        try await Task.sleep(for: dismissProcessingWindow)

        XCTAssertNil(manager.currentToast)
    }

    func testDismissDoesNotChainExtraDismissFromCancelledAutoTimer() async throws {
        // 手動 dismiss は auto-dismiss task (10s sleep 中) を cancel する。
        // cancel された auto-dismiss が CancellationError を握り潰して self.dismiss() を
        // 余計に呼ぶと、queueProcessingTask が再度 cancel されて連鎖が起きる。
        // 1 件しかキューに居ない状態で dismiss → wait → currentToast が次の要素 1 件で
        // 止まり、queue が空になっていること (連鎖していないこと) を担保する。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "current", duration: 10))
        manager.show(Toast(style: .info, title: "tail", duration: 10))

        manager.dismiss()
        try await Task.sleep(for: dismissProcessingWindow)

        XCTAssertEqual(manager.currentToast?.title, "tail")

        // 連鎖していれば tail も既に dismiss 済みで、もう 1 回 sleep するとさらに先に
        // 進む / nil になる。連鎖していなければ tail のまま (auto-dismiss は 10s 先)。
        try await Task.sleep(for: dismissProcessingWindow)
        XCTAssertEqual(manager.currentToast?.title, "tail")
        manager.clearAll()
    }

    // MARK: - キュー上限

    func testQueueDropsOldestWhenExceedingMaxSize() async throws {
        // キュー上限 5 件 (DisplayConstants.maxQueueSize)。
        // currentToast 1 件 + queue 7 件 push すると、キューは古い 2 件を捨てて
        // [q3, q4, q5, q6, q7] に縮む。dismiss → next は q3。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "current", duration: 10))
        XCTAssertEqual(manager.currentToast?.title, "current")

        for index in 1...7 {
            manager.show(Toast(style: .info, title: "queued-\(index)", duration: 10))
        }

        // current を dismiss してキューを 1 つ進める。
        manager.dismiss()
        try await Task.sleep(for: dismissProcessingWindow)

        // queued-1 / queued-2 はキュー溢れで落ちているので、queued-3 が出てくる。
        XCTAssertEqual(manager.currentToast?.title, "queued-3")
        manager.clearAll()
    }
}
