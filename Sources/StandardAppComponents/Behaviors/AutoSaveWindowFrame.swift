import SwiftUI
import AppKit

public extension View {
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
