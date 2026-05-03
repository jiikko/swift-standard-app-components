import SwiftUI
import AppKit

public extension View {
    /// ウィンドウのサイズ・位置を `NSWindow.frameAutosaveName` 経由で永続化する。
    ///
    /// - Parameter name: AutosaveName。アプリ内で重複させないこと。複数ウィンドウを
    ///   サポートする場合は windowID 等で一意化する。
    func autoSaveWindowFrame(name: String) -> some View {
        background(WindowFrameAutosaver(name: name))
    }
}

private struct WindowFrameAutosaver: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            view?.window?.setFrameAutosaveName(name)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
