@testable import StandardAppComponents
import AppKit
import SwiftUI
import XCTest

/// `StandardGlassSegmentedPicker.emphasizing(_:color:)`: 選んでいるかとは別に、1 つの区切りの絵を指定の色で描く
@MainActor
final class StandardGlassSegmentedPickerTests: XCTestCase {
    private func picker(selection: String) -> StandardGlassSegmentedPicker<String> {
        StandardGlassSegmentedPicker(["a", "b", "c"], selection: selection, systemImage: { _ in "square" }, label: { $0 }) { _ in }
    }

    func test_目立たせる区切りは指定の色_それ以外は選んでいるかで色を決める() {
        let emphasized = picker(selection: "b").emphasizing("c", color: .yellow)
        XCTAssertEqual(emphasized.foreground(for: "c"), .yellow)
        XCTAssertEqual(emphasized.foreground(for: "b"), .primary, "選んでいる区切り")
        XCTAssertEqual(emphasized.foreground(for: "a"), .secondary)
    }

    func test_選んでいる区切りを目立たせるときも指定の色_nilなら目立たせない() {
        XCTAssertEqual(picker(selection: "c").emphasizing("c", color: .yellow).foreground(for: "c"), .yellow)
        let plain = picker(selection: "b").emphasizing(nil, color: .yellow)
        XCTAssertEqual(plain.foreground(for: "c"), .secondary)
        XCTAssertEqual(plain.foreground(for: "b"), .primary)
    }

    /// 描いた絵に、目立たせる色 (黄) の画素が出る。目立たせなければ出ない (色を決める関数を body が使っていることの確認)
    func test_目立たせる区切りは描いた絵に色が出る() throws {
        XCTAssertGreaterThan(try yellowPixels(picker(selection: "a").emphasizing("c", color: Color(nsColor: .systemYellow))), 0)
        XCTAssertEqual(try yellowPixels(picker(selection: "a").emphasizing(nil, color: Color(nsColor: .systemYellow))), 0)
    }

    private func yellowPixels(_ view: StandardGlassSegmentedPicker<String>) throws -> Int {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        var count = 0
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if color.redComponent > 0.7, color.greenComponent > 0.6, color.blueComponent < 0.3 { count += 1 }
            }
        }
        return count
    }
}
