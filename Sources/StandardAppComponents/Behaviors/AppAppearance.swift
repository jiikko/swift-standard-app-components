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
    /// 2. 既存の `NSWindow.appearance` を明示的に上書き (`.preferredColorScheme` の取りこぼしをカバー)。
    ///    メニューバーの status item の window は除く (OS のメニューバーの外観に従わせる。`AppAppearanceWindows`)
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
                let nsAppearance = AppAppearanceMapping.nsAppearance(for: new)
                NSApp.appearance = nsAppearance
                // `.preferredColorScheme(.dark)` で per-window appearance が
                // 明示セットされた NSWindow は、preferredColorScheme(nil) では
                // クリアされない実装挙動がある。NSApp 側だけ nil にしても
                // window 側に残り続けるので、ここで明示的に揃える。
                AppAppearanceWindows.apply(nsAppearance, to: NSApp.windows)
            }
    }
}

/// アプリの外観を既存の window に当てる。メニューバーの status item の window (`NSStatusBarWindow`、level は `.statusBar`) は
/// `NSApp.windows` に入るが、上書きしない。上書きすると status item のボタンがメニューバーではなくアプリの外観で描かれ、
/// アプリをライトにすると暗いメニューバーの上で template image が黒くなる (`NSApp.appearance` の上書きは status item に効かないことを
/// macOS 26.7 で実測した)。status item の外観は OS のメニューバーに任せる。
enum AppAppearanceWindows {
    static func apply(_ appearance: NSAppearance?, to windows: [NSWindow]) {
        for window in windows where followsAppAppearance(window) {
            window.appearance = appearance
        }
    }

    static func followsAppAppearance(_ window: NSWindow) -> Bool {
        window.level != .statusBar
    }
}

/// `ColorScheme?` ↔ `NSAppearance?` の純粋写像。
/// View modifier から切り出してあるのは、SwiftUI の render cycle を必要としない
/// 単体テスト (`AppAppearanceTests`) で写像規則を直接担保できるようにするため。
enum AppAppearanceMapping {
    static func nsAppearance(for scheme: ColorScheme?) -> NSAppearance? {
        switch scheme {
        case .light: NSAppearance(named: .aqua)
        case .dark:  NSAppearance(named: .darkAqua)
        case .none:  nil
        @unknown default: nil
        }
    }
}
