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

    func makeNSView(context: Context) -> WindowAttachAwareView {
        WindowAttachAwareView(autosaveName: name)
    }

    func updateNSView(_ nsView: WindowAttachAwareView, context: Context) {
        // name が後から変更された場合や、最初の attach がまだなら再適用する。
        nsView.autosaveName = name
        nsView.applyAutosaveNameIfPossible()
    }
}

/// `viewDidMoveToWindow` で確実に window 取得後に `setFrameAutosaveName` を当てるための
/// NSView サブクラス。`makeNSView` 直後の 1 tick だけだと、`NSHostingController` 配下で
/// その時点で `window` がまだ `nil` のケースで取りこぼす (Codex review 指摘)。
private final class WindowAttachAwareView: NSView {
    var autosaveName: String

    init(autosaveName: String) {
        self.autosaveName = autosaveName
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAutosaveNameIfPossible()
    }

    func applyAutosaveNameIfPossible() {
        guard let window else { return }
        // 既に同名が当たっていれば no-op (NSWindow が saved frame を再読込しないように)。
        guard window.frameAutosaveName != autosaveName else { return }
        window.setFrameAutosaveName(autosaveName)
    }
}
