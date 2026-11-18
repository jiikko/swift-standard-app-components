import AppKit

/// `StandardSplitMenuButton(itemsPresenter:)` で開いた押下を、離すまで追う (`SplitMenuSegmentedControl` が使う)。
/// 押している間のマウスは押した view のウィンドウに届き、開いたもの (ポップオーバーの行など) には届かないので、押した側が
/// カーソルの位置 (画面の座標) を presenter の `pressMoved` / `pressEnded` へ渡す
@MainActor
enum SplitMenuPressTracking {
    static func track(in view: NSView, moved: (NSPoint) -> Void, ended: (NSPoint) -> Void) {
        let mask: NSEvent.EventTypeMask = [.leftMouseUp, .leftMouseDragged]
        while let window = view.window,
              let next = window.nextEvent(matching: mask, until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            let point = window.convertPoint(toScreen: next.locationInWindow)
            if next.type == .leftMouseUp {
                ended(point)
                return
            }
            moved(point)
        }
    }
}
