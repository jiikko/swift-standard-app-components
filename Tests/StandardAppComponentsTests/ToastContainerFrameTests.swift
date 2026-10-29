import AppKit
import SwiftUI
import XCTest
@testable import StandardAppComponents

/// `onToastFrameChange` reports the bubble's rectangle, so an AppKit overlay can take clicks on
/// the bubble only (screen-share-app issue 853).
@MainActor
final class ToastContainerFrameTests: XCTestCase {
    private final class Frames {
        var reported: [CGRect?] = []
    }

    private func host(_ manager: ToastManager, frames: Frames, size: CGSize) -> (NSWindow, NSHostingView<AnyView>) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        // A window made in code releases itself on close by default, which ARC then releases again.
        window.isReleasedWhenClosed = false
        let view = NSHostingView(rootView: AnyView(
            Color.clear.standardToastContainer(manager) { frames.reported.append($0) }))
        view.frame = NSRect(origin: .zero, size: size)
        window.contentView = view
        return (window, view)
    }

    func testReportsTheBubbleInsideTheBottomRightPaddingAndNilWhenItGoes() async throws {
        let manager = ToastManager()
        let frames = Frames()
        let size = CGSize(width: 640, height: 360)
        let (window, _) = host(manager, frames: frames, size: size)
        defer { window.close() }

        manager.show(Toast(style: .info, title: "Hello", message: "A message long enough to wrap onto a second line in the bubble", duration: 30))
        try await waitUntil("no frame was reported") { frames.reported.last.flatMap { $0 } != nil }
        let bubble = try XCTUnwrap(frames.reported.last.flatMap { $0 })
        // Top-left origin; the 20 pt trailing and bottom padding is outside the bubble.
        XCTAssertEqual(bubble.maxX, size.width - 20, accuracy: 0.5)
        XCTAssertEqual(bubble.maxY, size.height - 20, accuracy: 0.5)
        XCTAssertLessThanOrEqual(bubble.width, 380.5)
        XCTAssertGreaterThan(bubble.height, 20)

        manager.dismiss()
        try await waitUntil("no nil after the toast went") { frames.reported.last.map { $0 == nil } ?? false }
    }

    /// A message that wraps makes a taller bubble, and the report follows it.
    func testATallerBubbleIsReportedTaller() async throws {
        let size = CGSize(width: 640, height: 360)
        func height(for message: String) async throws -> CGFloat {
            let manager = ToastManager()
            let frames = Frames()
            let (window, _) = host(manager, frames: frames, size: size)
            defer { window.close() }
            manager.show(Toast(style: .info, title: "Hello", message: message, duration: 30))
            try await waitUntil("no frame was reported") { frames.reported.last.flatMap { $0 } != nil }
            let bubble = try XCTUnwrap(frames.reported.last.flatMap { $0 })
            manager.clearAll()
            return bubble.height
        }
        let short = try await height(for: "Short")
        let long = try await height(for: "A message long enough to wrap onto a second line in the bubble, and then some more words")
        XCTAssertGreaterThan(long, short)
    }

    /// Stacked toasts are all drawn: two bubbles report a taller frame than one.
    func testStackedToastsReportATallerFrameThanOne() async throws {
        let manager = ToastManager(presentation: .stacked(maxVisible: 3))
        let frames = Frames()
        let size = CGSize(width: 640, height: 360)
        let (window, _) = host(manager, frames: frames, size: size)
        defer { window.close() }

        manager.show(Toast(style: .info, title: "First", duration: 30))
        try await waitUntil("no frame was reported") { frames.reported.last.flatMap { $0 } != nil }
        let one = try XCTUnwrap(frames.reported.last.flatMap { $0 })

        manager.show(Toast(style: .info, title: "Second", duration: 30))
        try await waitUntil("the frame did not grow for the second toast") {
            (frames.reported.last.flatMap { $0 }?.height ?? 0) > one.height + 20
        }
        manager.clearAll()
        try await waitUntil("no nil after the toasts went") { frames.reported.last.map { $0 == nil } ?? false }
    }

    /// Replacing a toast by `uniqueKey` keeps its id, and the bubble still shows the new content.
    func testReplacingByUniqueKeyRedrawsTheBubbleWithTheNewContent() async throws {
        let manager = ToastManager()
        let frames = Frames()
        let size = CGSize(width: 640, height: 360)
        let (window, _) = host(manager, frames: frames, size: size)
        defer { window.close() }

        manager.show(Toast(style: .info, title: "Short", duration: 30, uniqueKey: "k"))
        try await waitUntil("no frame was reported") { frames.reported.last.flatMap { $0 } != nil }
        let short = try XCTUnwrap(frames.reported.last.flatMap { $0 })

        manager.show(Toast(
            style: .info,
            title: "Short",
            message: "A message long enough to wrap onto a second line in the bubble, and then some more words",
            duration: 30,
            uniqueKey: "k"
        ))
        try await waitUntil("the bubble was not redrawn with the new content") {
            (frames.reported.last.flatMap { $0 }?.height ?? 0) > short.height
        }
        manager.clearAll()
    }
}
