import SwiftUI
import AppKit

public extension View {
    /// macOS の Settings シーン用の標準挙動を当てる。
    ///
    /// 現状の責務は **ESC キーで Settings ウィンドウを閉じる** こと。
    /// 隠し `Button` + `.keyboardShortcut(.cancelAction)` ベースで実装しており、
    /// `TextField` / `Picker` 等にフォーカスがあっても ESC が確実に届く
    /// (`.onExitCommand` は responder chain の事情で TextField 等にフォーカスがあると
    /// 取りこぼすことがあるため避けている)。
    ///
    /// 閉じる対象は `NSApp.keyWindow` ではなく、本 modifier が attach された View が
    /// 実際に hosting されている `NSWindow` を `NSViewRepresentable` 経由で捕捉して使う。
    /// さらに `attachedSheet` が表示中なら何もせず、sheet 側の ESC 処理を優先する。
    ///
    /// - Important: **macOS Settings シーン専用** の挙動。modal / inline editor 等
    ///   別文脈の View に当てると意図しない close を引き起こすので注意。
    func standardSettingsBehaviors() -> some View {
        modifier(StandardSettingsBehaviorsModifier())
    }
}

private struct StandardSettingsBehaviorsModifier: ViewModifier {
    @State private var hostingWindow: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(SettingsWindowAccessor { hostingWindow = $0 })
            .background(escapeShortcut)
    }

    private var escapeShortcut: some View {
        // 隠し Button + .cancelAction で responder chain にショートカットを登録する。
        // 視覚 / hit area / focus / accessibility の全方位で副作用が出ないよう modifier を畳んでおく。
        Button {
            guard let window = hostingWindow,
                  window.attachedSheet == nil else { return }
            window.performClose(nil)
        } label: {
            EmptyView()
        }
        .keyboardShortcut(.cancelAction)
        .buttonStyle(.plain)
        .focusable(false)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

/// 自身が hosting されている `NSWindow` を closure 経由で通知する補助 NSViewRepresentable。
/// `NSApp.keyWindow` 依存を避け、本 modifier が attach された View 配下の NSWindow を確実に掴むために使う。
private struct SettingsWindowAccessor: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? WindowAccessorView else { return }
        view.onWindowChange = onWindowChange
    }

    @MainActor
    final class WindowAccessorView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // SwiftUI の view update サイクル中に @State を書き換えると warning が出るため、
            // 次の run-loop に defer して通知する。
            Task { @MainActor [weak self] in
                self?.onWindowChange?(self?.window)
            }
        }
    }
}
