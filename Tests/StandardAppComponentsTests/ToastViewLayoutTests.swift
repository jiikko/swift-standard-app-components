import AppKit
import SwiftUI
import XCTest
@testable import StandardAppComponents

/// How many lines of `message` the bubble shows. Two lines cut a failure reason in half (obaket, 2026-11-13).
@MainActor
final class ToastViewLayoutTests: XCTestCase {
    /// The bubble's height for a message of `lines` lines. Explicit newlines make the line count independent of
    /// the width and the font's wrapping.
    private func height(lines: Int) -> CGFloat {
        let message = (1...lines).map { "Line \($0)" }.joined(separator: "\n")
        let toast = Toast(style: .error, title: "Upload failed", message: message)
        let view = NSHostingView(rootView: ToastView(toast: toast, onDismiss: {}).frame(width: 380))
        return view.fittingSize.height
    }

    func testShowsUpToFourLinesOfTheMessage() {
        let one = height(lines: 1)
        let two = height(lines: 2)
        let lineHeight = two - one
        XCTAssertGreaterThan(lineHeight, 5, "a second line did not make the bubble taller")
        // Lines 3 and 4 are laid out: each adds one line's height. This measures the layout, not the pixels, and does not
        // see the tooltip (`.help`).
        XCTAssertEqual(height(lines: 4), one + 3 * lineHeight, accuracy: 1.0)
    }

    func testCutsTheMessageAfterFourLines() {
        XCTAssertEqual(height(lines: 8), height(lines: 4), accuracy: 0.5)
    }
}
