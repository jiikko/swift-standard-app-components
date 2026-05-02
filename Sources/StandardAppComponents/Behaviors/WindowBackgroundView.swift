import AppKit
import SwiftUI

/// `NSVisualEffectView` を SwiftUI から使うためのラッパー。
///
/// macOS の `Settings` シーン等は内部的に `NSVisualEffectView` (vibrancy material) で
/// 描画されるため、フラットな `Color` のベタ塗りでは同じ色値を当てても視覚的には揃わない。
/// 標準アプリ (Finder / Mail / Settings 等) と同じ rendering pipeline に乗せたい場合に
/// `.background(WindowBackgroundView())` を当てる。
///
/// デフォルトは `material: .windowBackground` / `blendingMode: .behindWindow` で、
/// 標準的な window background を再現する。`state` は `.followsWindowActiveState` 固定で、
/// key / 非 key ウィンドウの見え方も標準に揃える。
public struct WindowBackgroundView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .windowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
