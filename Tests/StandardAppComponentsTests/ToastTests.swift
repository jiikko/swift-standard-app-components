import XCTest
import SwiftUI
@testable import StandardAppComponents

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
        // 同じ id を持つ Toast は Equatable で等しいと扱われ、別 id は不等。
        // id 一致を「同一トースト」と判定する設計 (上書き表示の区別) を担保する。
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

    func testStyleForegroundColorIsAlwaysWhite() {
        // 背景色のコントラストを優先して全 case で前景は白に固定する設計。
        let white = String(describing: Color.white)
        for style: Toast.Style in [.success, .error, .warning, .info] {
            XCTAssertEqual(String(describing: style.foregroundColor), white)
        }
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
