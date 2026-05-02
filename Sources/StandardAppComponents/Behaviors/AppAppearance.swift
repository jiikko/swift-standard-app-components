import SwiftUI
import AppKit

public extension View {
    /// アプリ全体の外観 (light / dark) を `ColorScheme` で制御する。
    ///
    /// macOS の `Settings` シーンと `Form.formStyle(.grouped)` の組み合わせでは
    /// `.preferredColorScheme(_:)` だけでは grouped 背景の `NSColor` が `NSWindow`
    /// の `effectiveAppearance` を読むため追従しない。本モディファイアは
    /// `.preferredColorScheme(_:)` に加えて `NSApp.appearance` を併せて設定し、
    /// SwiftUI / AppKit 双方の見た目を一致させる。
    ///
    /// - Parameter scheme: 強制したい `ColorScheme`。`nil` の場合はシステム追従。
    /// - Important: `NSApp.appearance` は全 `NSWindow` に効くため、アプリ単位での
    ///   外観統一に向く。ウィンドウごとに異なる外観を出したい場合は本モディファイアを
    ///   使わず、各ウィンドウで `.preferredColorScheme` のみ使用すること。
    func applyAppAppearance(_ scheme: ColorScheme?) -> some View {
        modifier(AppAppearanceModifier(scheme: scheme))
    }
}

private struct AppAppearanceModifier: ViewModifier {
    let scheme: ColorScheme?

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(scheme)
            .onChange(of: scheme, initial: true) { _, new in
                NSApp.appearance = Self.nsAppearance(for: new)
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
