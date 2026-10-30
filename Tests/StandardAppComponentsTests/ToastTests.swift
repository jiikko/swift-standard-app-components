import XCTest
import SwiftUI
@testable import StandardAppComponents

@MainActor
final class ToastTests: XCTestCase {
    // MARK: - Toast model

    func testInitWithDefaults() {
        // 必須引数のみで初期化したとき、id は自動生成 / message・action は nil /
        // duration は 3.0 がデフォルトで適用されること。
        let toast = Toast(style: .success, title: "Saved")
        XCTAssertEqual(toast.style, .success)
        XCTAssertEqual(toast.title, "Saved")
        XCTAssertNil(toast.message)
        XCTAssertNil(toast.action)
        XCTAssertEqual(toast.duration, 3.0)
    }

    func testInitWithExplicitID() {
        // 上書き表示 (同 id で再 show) のために id を外から渡せること。
        let id = UUID()
        let toast = Toast(id: id, style: .info, title: "Hello")
        XCTAssertEqual(toast.id, id)
    }

    func testEquatableComparesByIDOnly() {
        // Equatable は id のみで比較する (Identifiable と整合)。
        // SwiftUI の ForEach / .animation(value:) が id 変化を「トーストの入れ替わり」
        // として拾えるようにする設計を担保する。内容差分での再描画は SwiftUI 側が別途拾う。
        let id = UUID()
        let lhs = Toast(id: id, style: .success, title: "A")
        let rhs = Toast(id: id, style: .error, title: "B", message: "different")
        XCTAssertEqual(lhs, rhs)

        let other = Toast(style: .success, title: "A")
        XCTAssertNotEqual(lhs, other)
    }

    // MARK: - Toast.Style

    func testStyleIconNames() {
        // SF Symbol マッピング。アイコン名の typo / 不在は実機で気付きにくいため
        // テストで固定する。
        XCTAssertEqual(Toast.Style.success.iconName, "checkmark.circle.fill")
        XCTAssertEqual(Toast.Style.error.iconName, "xmark.circle.fill")
        XCTAssertEqual(Toast.Style.warning.iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(Toast.Style.info.iconName, "info.circle.fill")
    }

    func testStyleBackgroundColorIsDistinctPerCase() {
        // 4 case それぞれに固有色が割り当たっていること (誤って同色になっていないか)。
        // 実 RGB 値の検証は ToastView 側の visual test で行う方が筋が良いので、
        // ここでは「全 case で互いに異なる」ことだけを担保する。
        let colors: [Toast.Style: Color] = [
            .success: Toast.Style.success.backgroundColor,
            .error: Toast.Style.error.backgroundColor,
            .warning: Toast.Style.warning.backgroundColor,
            .info: Toast.Style.info.backgroundColor
        ]
        // Color は Equatable だが SwiftUI の Color は内部表現の違いで完全比較できない
        // ことがあるため description ベースで一意性をチェックする。
        let descriptions = Set(colors.values.map { String(describing: $0) })
        XCTAssertEqual(descriptions.count, 4)
    }

    func testStyleTextContrastIsReadable() throws {
        // message は前景色を 0.9 の薄さで描く (ToastView の Layout.messageOpacity)。薄くした後でも WCAG の小さい文字の基準 4.5:1 を満たす
        for style: Toast.Style in [.success, .error, .warning, .info] {
            let background = try XCTUnwrap(srgbComponents(of: style.backgroundColor))
            let foreground = try XCTUnwrap(srgbComponents(of: style.foregroundColor))
            let message = blend(foreground, over: background, alpha: 0.9)
            XCTAssertGreaterThanOrEqual(contrastRatio(message, background), 4.5, "\(style)")
        }
    }

    private typealias RGB = (red: Double, green: Double, blue: Double)

    private func srgbComponents(of color: Color) -> RGB? {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        return (Double(srgb.redComponent), Double(srgb.greenComponent), Double(srgb.blueComponent))
    }

    private func blend(_ top: RGB, over bottom: RGB, alpha: Double) -> RGB {
        (
            top.red * alpha + bottom.red * (1 - alpha),
            top.green * alpha + bottom.green * (1 - alpha),
            top.blue * alpha + bottom.blue * (1 - alpha)
        )
    }

    private func contrastRatio(_ lhs: RGB, _ rhs: RGB) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        func luminance(_ rgb: RGB) -> Double {
            0.212_6 * linear(rgb.red) + 0.715_2 * linear(rgb.green) + 0.072_2 * linear(rgb.blue)
        }
        let lighter = max(luminance(lhs), luminance(rhs))
        let darker = min(luminance(lhs), luminance(rhs))
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - accessibility label (model に切り出した pure 計算)

    func testAccessibilityLabelTitleOnlyWhenMessageIsNil() {
        // message が nil なら title のみ。連結区切りの ". " が誤って付かないこと。
        let toast = Toast(style: .info, title: "Saved")
        XCTAssertEqual(toast.accessibilityLabel, "Saved")
    }

    func testAccessibilityLabelJoinsTitleAndMessageWithPeriodSpace() {
        // message があれば title と ". " 区切りで連結する。VoiceOver が
        // 1 つのコンテンツとして自然に読み上げる粒度を担保する。
        let toast = Toast(style: .error, title: "Failed", message: "Path does not exist")
        XCTAssertEqual(toast.accessibilityLabel, "Failed. Path does not exist")
    }

    func testAccessibilityLabelHandlesEmptyMessage() {
        // message が空文字でも nil として扱わず連結する (consumer の意図を尊重)。
        // 空 message は実用上ほぼ無いが、契約として「.message 非 nil なら連結」を固定する。
        let toast = Toast(style: .info, title: "Title", message: "")
        XCTAssertEqual(toast.accessibilityLabel, "Title. ")
    }

    // MARK: - message copy (context menu)

    func testMessageToCopyIsNilByDefault() {
        // copiesMessage を渡さなければコピー対象は無い (既定は従来どおりメニューを出さない)。
        let toast = Toast(style: .error, title: "Failed", message: "Path does not exist")
        XCTAssertFalse(toast.copiesMessage)
        XCTAssertNil(toast.messageToCopy)
    }

    func testMessageToCopyReturnsFullMessageWhenCopiesMessageIsTrue() {
        // copiesMessage: true なら message の全文がコピー対象になる。
        // 表示は 2 行で truncate されるが、コピーはモデルの文字列から取る契約。
        let toast = Toast(style: .error, title: "Failed", message: "Path does not exist", copiesMessage: true)
        XCTAssertEqual(toast.messageToCopy, "Path does not exist")
    }

    func testMessageToCopyIsNilWhenMessageIsNilEvenIfCopiesMessageIsTrue() {
        // message が無ければコピーする中身が無いので、true でも対象は nil (メニューは出ない)。
        let toast = Toast(style: .success, title: "Saved", copiesMessage: true)
        XCTAssertNil(toast.messageToCopy)
    }

    func testReplacingIDPreservesCopiesMessage() {
        // uniqueKey / 同 id での置き換え (replacingID) で copiesMessage が落ちないこと。
        // フィールドの足し忘れが起きやすい箇所なので契約として固定する。
        let toast = Toast(style: .error, title: "Failed", message: "boom", copiesMessage: true)
        let replaced = toast.replacingID(with: UUID())
        XCTAssertTrue(replaced.copiesMessage)
        XCTAssertEqual(replaced.messageToCopy, "boom")
    }

    // MARK: - ToastAction

    func testActionHandlerIsInvokable() {
        // ToastAction の handler が普通の closure として呼べること。
        // (タップで Manager が handler() を直接呼ぶ前提)
        let expectation = expectation(description: "handler invoked")
        let action = ToastAction(title: "Open") { expectation.fulfill() }
        XCTAssertEqual(action.title, "Open")
        action.handler()
        wait(for: [expectation], timeout: 0.1)
    }
}
