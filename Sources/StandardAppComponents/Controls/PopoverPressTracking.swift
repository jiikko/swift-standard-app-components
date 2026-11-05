import AppKit

/// ポップオーバーを開いた押下を、離すまで追う (`SplitMenuSegmentedControl` と `StandardPopoverMenuButton` が使う)。
/// 押している間のマウスは押した view のウィンドウに届き、ポップオーバーの行は `onHover` も Button も動かないので、押した側が
/// カーソルの位置 (画面の座標) を `SplitMenuPopoverPresenter.dragMoved` / `dragEnded` へ渡す
@MainActor
enum PopoverPressTracking {
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
