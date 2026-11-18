import AppKit

/// `StandardSplitMenuButton(itemsPresenter:)` で、⌄ の区画のクリックと枠付きの主の区画の長押しのときに、標準のメニューの代わりに
/// 項目を出すもの (ポップオーバーなど)。出し方は consumer が決める。右クリックと、枠なしの長押しは標準のメニューのまま
/// (キーボード・VoiceOver で選べる経路として残す)。
///
/// 分割ボタンが呼ぶ順:
/// - ⌄ の押下・主の区画の長押し: `toggle` (開いていれば閉じる)。枠付きなら、その押下を離すまでカーソルの位置 (画面の座標) を
///   `pressMoved` に渡し、離したら `pressEnded` に渡す (押したまま項目まで動かして離すと選べるようにするため)
/// - 主の操作を呼ぶ直前: `willPerformPrimaryAction` (開いているリストを閉じるなど)
/// - 項目が変わった: `update(items:)` / 押せなくなった・画面から外れた: `close`
///
/// conformer の義務:
/// - 項目を選んだら `toggle` の `choose` に番号を渡す (操作は分割ボタンが今の項目から引いて呼ぶ。押せない間は呼ばない)
/// - どのメソッドも、開いていないときに呼ばれても何もしない
/// - 開いているものを閉じさせた押下で、開き直さない。外のクリックで閉じる出し方 (`NSPopover` の `.transient` など) は、閉じた後に
///   同じ押下を ⌄ の区画へ届けるので、その押下の `toggle` が来る (押下の `NSEvent.eventNumber` を覚えて見分ける)
/// - 閉じ始めた後の `pressEnded` では選ばない (開いている ⌄ を押して閉じた押下を、消えかけの項目の上で離したとき)。
///   分割ボタンは `toggle` が開いたか閉じたかに関わらず、押下を離すまで `pressMoved` / `pressEnded` を送る
@MainActor
public protocol StandardSplitMenuItemsPresenter: AnyObject {
    /// `anchor` (`view` の座標。⌄ の区画の範囲) に項目を出す。開いていれば閉じる
    func toggle(
        items: [StandardSplitMenuButton.Item],
        relativeTo anchor: NSRect,
        of view: NSView,
        choose: @escaping (Int) -> Void
    )
    /// 開いている間に項目が変わった (今の値の ✓ など)
    func update(items: [StandardSplitMenuButton.Item])
    /// 開いた押下を押したまま動かした (画面の座標)
    func pressMoved(toScreen point: NSPoint)
    /// 開いた押下を離した (画面の座標)
    func pressEnded(atScreen point: NSPoint)
    /// 主の操作を呼ぶ直前
    func willPerformPrimaryAction()
    /// 閉じる
    func close()
}
