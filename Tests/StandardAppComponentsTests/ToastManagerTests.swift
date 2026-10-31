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
        try await waitUntil("the toast was not dismissed after its duration") { manager.currentToast == nil }
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

    // MARK: - ホバー中の自動消去の停止

    func testPauseAutoDismissKeepsTheToastPastItsDuration() async throws {
        let manager = ToastManager()
        let toast = Toast(style: .error, title: "Long error", duration: 0.1)
        manager.show(toast)
        manager.pauseAutoDismiss(for: toast.id)

        // 「消えないこと」の確認なので、待つべき成立条件が無い。duration (0.1) の数倍待つ。
        try await Task.sleep(for: .seconds(0.4))
        XCTAssertEqual(manager.currentToast?.id, toast.id)
        manager.clearAll()
    }

    func testResumeAutoDismissDismissesAfterTheDurationAgain() async throws {
        let manager = ToastManager()
        let toast = Toast(style: .error, title: "Long error", duration: 0.1)
        manager.show(toast)
        manager.pauseAutoDismiss(for: toast.id)
        manager.resumeAutoDismiss(for: toast.id)
        // resume は消すのではなく、duration を数え直す
        XCTAssertEqual(manager.currentToast?.id, toast.id)

        try await waitUntil("the toast was not dismissed after resume") { manager.currentToast == nil }
    }

    func testPauseForAnotherToastDoesNotStopTheCurrentOne() async throws {
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "Current", duration: 0.1))
        manager.pauseAutoDismiss(for: UUID())

        try await waitUntil("the current toast was not dismissed") { manager.currentToast == nil }
    }

    func testLateResumeFromThePreviousToastDoesNotUnpauseTheNextOne() async throws {
        // 閉じた吹き出しの onHover(false) が、次の吹き出しの onHover(true) の後に届く順序を再現する。
        let manager = ToastManager()
        let first = Toast(style: .info, title: "First", duration: 10)
        // 出るのを待つ間に自動で消えないよう、長い duration で出す。短い duration で出すと、待ちの見る間隔
        // (負荷の高い CI で 0.1 秒を超える) の間に出て消え、出たことを見逃す
        let second = Toast(style: .info, title: "Second", duration: 10)
        manager.show(first)
        manager.show(second)
        manager.pauseAutoDismiss(for: first.id)
        manager.dismiss()
        try await waitUntil("the second toast did not appear") { manager.currentToast?.id == second.id }

        manager.pauseAutoDismiss(for: second.id)
        // 止めたまま短い duration に差し替える (止めている間は消去を予約しない)。停止が解かれれば 0.1 秒で消える
        manager.show(Toast(style: .info, title: "Second", duration: 0.1).replacingID(with: second.id))
        manager.resumeAutoDismiss(for: first.id)

        // 「消えないこと」の確認なので、待つべき成立条件が無い。duration (0.1) の数倍待つ。
        try await Task.sleep(for: .seconds(0.4))
        XCTAssertEqual(manager.currentToast?.id, second.id)
        manager.clearAll()
    }

    // MARK: - 1 件ずつの待ち (.oneAtATime)

    func testShowDuringTheDelayAfterDismissWaitsUntilTheDelayEnds() async throws {
        // 消えかけの吹き出しと次の吹き出しを重ねないため、dismiss から processingDelay の間に来た show は待つ。
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "First", duration: 10))
        manager.dismiss()
        manager.show(Toast(style: .info, title: "Second", duration: 10))
        XCTAssertNil(manager.currentToast)

        try await waitUntil("the second toast did not appear after the delay") { manager.currentToast?.title == "Second" }
        manager.clearAll()
    }

    // MARK: - 複数を並べる (.stacked)

    func testStackedShowsUpToMaxVisibleAtOnceInOrder() {
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        for title in ["A", "B", "C"] {
            manager.show(Toast(style: .info, title: title, duration: 10))
        }
        XCTAssertEqual(manager.visibleToasts.map(\.title), ["A", "B", "C"])
        XCTAssertEqual(manager.currentToast?.title, "C")
        manager.clearAll()
    }

    func testStackedOverflowWaitsAndAppearsWhenOneIsDismissed() async throws {
        let manager = ToastManager(presentation: .stacked(maxVisible: 2))
        let first = Toast(style: .info, title: "A", duration: 10)
        manager.show(first)
        manager.show(Toast(style: .info, title: "B", duration: 10))
        manager.show(Toast(style: .info, title: "C", duration: 10))
        XCTAssertEqual(manager.visibleToasts.map(\.title), ["A", "B"])

        manager.dismiss(id: first.id)
        XCTAssertEqual(manager.visibleToasts.map(\.title), ["B"])
        try await waitUntil("the queued toast did not appear") { manager.visibleToasts.map(\.title) == ["B", "C"] }
        manager.clearAll()
    }

    func testStackedFillsEveryFreeSlotAfterTheDelay() async throws {
        // 待ちの間に 2 件消えたら、待ちの終わりに 2 件とも出す。
        let manager = ToastManager(presentation: .stacked(maxVisible: 2))
        let first = Toast(style: .info, title: "A", duration: 10)
        let second = Toast(style: .info, title: "B", duration: 10)
        manager.show(first)
        manager.show(second)
        manager.show(Toast(style: .info, title: "C", duration: 10))
        manager.show(Toast(style: .info, title: "D", duration: 10))

        manager.dismiss(id: first.id)
        manager.dismiss(id: second.id)
        try await waitUntil("both free slots were not filled") { manager.visibleToasts.map(\.title) == ["C", "D"] }
        manager.clearAll()
    }

    func testStackedAutoDismissRemovesOnlyItsOwnToast() async throws {
        // 短い方を先に出す。タイマーが currentToast (いちばん新しい Long) を消す形だと落ちる。
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        manager.show(Toast(style: .info, title: "Short", duration: 0.1))
        manager.show(Toast(style: .info, title: "Long", duration: 10))

        try await waitUntil("the short toast was not dismissed") { manager.visibleToasts.map(\.title) == ["Long"] }
        manager.clearAll()
    }

    func testStackedPauseKeepsOnlyThePausedToast() async throws {
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        let hovered = Toast(style: .info, title: "Hovered", duration: 0.1)
        manager.show(hovered)
        manager.show(Toast(style: .info, title: "Other", duration: 0.1))
        manager.pauseAutoDismiss(for: hovered.id)

        try await waitUntil("the other toast was not dismissed") { manager.visibleToasts.map(\.title) == ["Hovered"] }
        manager.clearAll()
    }

    // MARK: - 置き換え (同じ id / uniqueKey)

    func testSameUniqueKeyReplacesTheVisibleToastAndKeepsItsID() {
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        let first = Toast(style: .warning, title: "Busy 1", duration: 10, uniqueKey: "busy")
        manager.show(first)
        manager.show(Toast(style: .warning, title: "Busy 2", duration: 10, uniqueKey: "busy"))

        XCTAssertEqual(manager.visibleToasts.count, 1)
        XCTAssertEqual(manager.visibleToasts.first?.title, "Busy 2")
        XCTAssertEqual(manager.visibleToasts.first?.id, first.id)
        manager.clearAll()
    }

    func testSameUniqueKeyReplacesTheQueuedToast() async throws {
        let manager = ToastManager()
        let shown = Toast(style: .info, title: "Shown", duration: 10)
        manager.show(shown)
        manager.show(Toast(style: .warning, title: "Busy 1", duration: 10, uniqueKey: "busy"))
        manager.show(Toast(style: .warning, title: "Busy 2", duration: 10, uniqueKey: "busy"))
        manager.show(Toast(style: .info, title: "After", duration: 10))

        manager.dismiss(id: shown.id)
        try await waitUntil("the replaced queued toast did not appear") { manager.currentToast?.title == "Busy 2" }
        manager.dismiss()
        try await waitUntil("the next toast did not appear") { manager.currentToast?.title == "After" }
        manager.clearAll()
    }

    func testToastsWithoutUniqueKeyAreNotMerged() {
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        manager.show(Toast(style: .info, title: "Same", duration: 10))
        manager.show(Toast(style: .info, title: "Same", duration: 10))
        XCTAssertEqual(manager.visibleToasts.count, 2)
        manager.clearAll()
    }

    func testSameIDReplacesTheVisibleToast() {
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        let id = UUID()
        manager.show(Toast(id: id, style: .info, title: "Old", duration: 10))
        manager.show(Toast(id: id, style: .info, title: "New", duration: 10))
        XCTAssertEqual(manager.visibleToasts.map(\.title), ["New"])
        manager.clearAll()
    }

    func testReplacingRestartsTheDurationWithTheNewToast() async throws {
        let manager = ToastManager()
        manager.show(Toast(style: .info, title: "Short", duration: 0.1, uniqueKey: "k"))
        manager.show(Toast(style: .info, title: "Long", duration: 10, uniqueKey: "k"))

        // 「消えないこと」の確認なので、待つべき成立条件が無い。古い duration (0.1) の数倍待つ。
        try await Task.sleep(for: .seconds(0.4))
        XCTAssertEqual(manager.currentToast?.title, "Long")
        manager.clearAll()
    }

    func testReplacingAPausedToastKeepsItPaused() async throws {
        let manager = ToastManager()
        let first = Toast(style: .info, title: "First", duration: 0.1, uniqueKey: "k")
        manager.show(first)
        manager.pauseAutoDismiss(for: first.id)
        manager.show(Toast(style: .info, title: "Second", duration: 0.1, uniqueKey: "k"))

        // 「消えないこと」の確認なので、待つべき成立条件が無い。duration (0.1) の数倍待つ。
        try await Task.sleep(for: .seconds(0.4))
        XCTAssertEqual(manager.currentToast?.title, "Second")

        manager.resumeAutoDismiss(for: first.id)
        try await waitUntil("the replaced toast was not dismissed after resume") { manager.currentToast == nil }
    }

    // MARK: - 置き換えで一意を保つ (表示中とキューを合わせて、同じ id・同じ uniqueKey は 1 件だけ)

    func testReplacingDropsAnotherVisibleToastWithTheSameKey() {
        // id は A に、key は B に当たる toast を出すと、A を置き換えて B は消す。
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        let first = Toast(style: .info, title: "A", duration: 10)
        manager.show(first)
        manager.show(Toast(style: .info, title: "B", duration: 10, uniqueKey: "k"))

        manager.show(Toast(id: first.id, style: .info, title: "New", duration: 10, uniqueKey: "k"))
        XCTAssertEqual(manager.visibleToasts.map(\.title), ["New"])
        XCTAssertEqual(manager.visibleToasts.first?.id, first.id)
        manager.clearAll()
    }

    func testReplacingAVisibleToastDropsAQueuedToastWithTheSameKey() async throws {
        let manager = ToastManager()
        let shown = Toast(style: .info, title: "Shown", duration: 10)
        manager.show(shown)
        manager.show(Toast(style: .info, title: "Queued", duration: 10, uniqueKey: "k"))

        manager.show(Toast(id: shown.id, style: .info, title: "New", duration: 10, uniqueKey: "k"))
        XCTAssertEqual(manager.currentToast?.title, "New")
        manager.dismiss()
        // 「出ないこと」の確認なので、待つべき成立条件が無い。キューの待ち (0.3 秒) より十分長く待つ。
        try await Task.sleep(for: dismissProcessingWindow)
        XCTAssertNil(manager.currentToast)
    }

    func testReplacingAQueuedToastDropsAnotherQueuedToastWithTheSameKey() async throws {
        let manager = ToastManager()
        let shown = Toast(style: .info, title: "Shown", duration: 10)
        let queuedByID = Toast(style: .info, title: "Queued 1", duration: 10)
        manager.show(shown)
        manager.show(queuedByID)
        manager.show(Toast(style: .info, title: "Queued 2", duration: 10, uniqueKey: "k"))

        manager.show(Toast(id: queuedByID.id, style: .info, title: "New", duration: 10, uniqueKey: "k"))
        manager.dismiss()
        try await waitUntil("the replaced queued toast did not appear") { manager.currentToast?.title == "New" }
        manager.dismiss()
        // 「出ないこと」の確認なので、待つべき成立条件が無い。キューの待ち (0.3 秒) より十分長く待つ。
        try await Task.sleep(for: dismissProcessingWindow)
        XCTAssertNil(manager.currentToast)
    }

    func testDismissWithNothingShownDoesNotDelayTheNextShow() {
        // 何も出ていないときの dismiss() は何もしない (待ちを始めない)。
        let manager = ToastManager()
        manager.dismiss()
        manager.show(Toast(style: .info, title: "Now", duration: 10))
        XCTAssertEqual(manager.currentToast?.title, "Now")
        manager.clearAll()
    }
}
