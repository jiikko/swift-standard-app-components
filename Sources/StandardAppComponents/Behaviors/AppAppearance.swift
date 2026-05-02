import SwiftUI
import AppKit

public extension View {
    /// アプリ全体の外観 (light / dark) を `ColorScheme` で制御する。
    ///
    /// macOS の `Settings` シーンと `Form.formStyle(.grouped)` の組み合わせでは
    /// `.preferredColorScheme(_:)` だけでは grouped 背景の `NSColor` が `NSWindow`
    /// の `effectiveAppearance` を読むため追従しない。さらに、一度
    /// `.preferredColorScheme(.dark)` で `NSWindow.appearance` が明示セット
    /// されると、`.preferredColorScheme(nil)` を当てても per-window appearance が
    /// クリアされず、`Dark → System` の戻しが半端になる。
    ///
    /// 本モディファイアはこれらを以下で解決する:
    /// 1. `NSApp.appearance` を更新 (新規 NSWindow / explicit appearance を持たない既存 NSWindow に効く)
    /// 2. 既存の全 `NSWindow.appearance` を明示的に上書き (`.preferredColorScheme` の取りこぼしをカバー)
    ///
    /// - Parameter scheme: 強制したい `ColorScheme`。`nil` の場合はシステム追従。
    /// - Important: アプリ単位での外観統一を前提とした API。ウィンドウごとに
    ///   異なる外観を出したい場合は本モディファイアを使わず、各ウィンドウで
    ///   `.preferredColorScheme` のみ使用すること。
    func applyAppAppearance(_ scheme: ColorScheme?) -> some View {
        modifier(AppAppearanceModifier(scheme: scheme))
    }
}

private struct AppAppearanceModifier: ViewModifier {
    let scheme: ColorScheme?

    func body(content: Content) -> some View {
        content
            .onChange(of: scheme, initial: true) { _, new in
                let nsAppearance = Self.nsAppearance(for: new)
                NSApp.appearance = nsAppearance
                // `.preferredColorScheme(.dark)` で per-window appearance が
                // 明示セットされた NSWindow は、preferredColorScheme(nil) では
                // クリアされない実装挙動がある。NSApp 側だけ nil にしても
                // window 側に残り続けるので、ここで明示的に揃える。
                for window in NSApp.windows {
                    window.appearance = nsAppearance
                }
            }
    }

    private static func nsAppearance(for scheme: ColorScheme?) -> NSAppearance? {
        switch scheme {
        case .light: NSAppearance(named: .aqua)
        case .dark:  NSAppearance(named: .darkAqua)
        case .none:  nil
        @unknown default: nil
        }
    }
}
