import Observation
import SwiftUI

/// `StandardTabStrip` の状態: hover・ドラッグ・タブの幅、閉じたタブを縮めている間の並びと値。
///
/// view の struct に持たせると、縮めきったときの後始末 (`withAnimation` の completion) が古い struct の `items` を見る。
/// class に置き、いつ読んでも最新の並びを見るようにする
@MainActor
@Observable
final class StandardTabStripModel<Item: Identifiable> {
    struct ClosingTab {
        let item: Item
        let width: CGFloat
        var isCollapsed: Bool
    }

    var hoveredID: Item.ID?
    var draggingID: Item.ID?
    var lastMove: StandardTabMoveKey<Item.ID>?

    private(set) var widths: [Item.ID: CGFloat] = [:]
    private(set) var closingTabs: [Item.ID: ClosingTab] = [:]
    /// 前に描いた consumer のタブの id の並び。次の描画でタブが閉じられた (抜けた) かを見分ける
    private var renderedIDs: [Item.ID] = []
    /// 前に描いた並び (縮めている途中の閉じたタブを含む)。閉じたタブをどこに残すかを決める
    private var displayedIDs: [Item.ID] = []
    /// 前に描いた consumer のタブ。閉じた直後 (consumer の一覧から抜けた後) も、縮めている間はこれで描く
    @ObservationIgnored private var renderedItems: [Item.ID: Item] = [:]

    /// 描く並び。閉じた直後の描画ではまだ `closingTabs` に入っていない (onChange は描画の後) ので、同じ見分けでここでも残す
    func entries(for items: [Item], collapses: Bool) -> [StandardTabClosing.Entry<Item.ID>] {
        let ids = items.map(\.id)
        let justClosedIDs = collapses ? StandardTabClosing.closedIDs(from: renderedIDs, to: ids) : []
        return StandardTabClosing.entries(
            live: ids,
            closing: Set(closingTabs.keys).union(justClosedIDs),
            previousOrder: displayedIDs
        )
    }

    /// 縮めている途中のタブ (閉じた直後で `closingTabs` にまだ入っていなければ、前に描いた値から作る)
    func closingTab(id: Item.ID, fallbackWidth: CGFloat) -> ClosingTab? {
        closingTabs[id] ?? renderedItems[id].map { ClosingTab(item: $0, width: widths[id] ?? fallbackWidth, isCollapsed: false) }
    }

    func width(for id: Item.ID, fallback: CGFloat) -> CGFloat {
        widths[id] ?? fallback
    }

    func start(with items: [Item]) {
        renderedIDs = items.map(\.id)
        displayedIDs = renderedIDs
        renderedItems = Self.byID(items)
    }

    func recordWidth(_ width: CGFloat, for id: Item.ID) {
        // 0 幅 (初回・レイアウトの途中) は持たない。持つと、ドラッグの前後が hover の位置によらず前に倒れる
        if width > 0, widths[id] != width {
            widths[id] = width
        }
    }

    func resetDrag() {
        draggingID = nil
        lastMove = nil
    }

    /// consumer のタブの一覧が変わった。閉じたタブを縮める支度をし、消えたタブの hover・ドラッグを片付ける
    func itemsDidChange(
        _ items: [Item],
        displayed: [Item.ID],
        collapses: Bool,
        fallbackWidth: CGFloat,
        animation: Animation,
        onCollapseFinished: (@MainActor (Item.ID) -> Void)?
    ) {
        let ids = items.map(\.id)
        let closedIDs = collapses ? StandardTabClosing.closedIDs(from: renderedIDs, to: ids) : []
        displayedIDs = displayed
        for id in closedIDs {
            closingTabs[id] = closingTab(id: id, fallbackWidth: fallbackWidth)
        }
        renderedIDs = ids
        // 縮めている途中のタブの値は残す (それ以外の閉じた値は持たない)
        var nextItems = Self.byID(items)
        for id in closingTabs.keys where nextItems[id] == nil {
            nextItems[id] = renderedItems[id]
        }
        renderedItems = nextItems
        let liveIDs = Set(ids)
        widths = widths.filter { liveIDs.contains($0.key) || closingTabs[$0.key] != nil }
        if let draggingID, !liveIDs.contains(draggingID) {
            resetDrag()
        }
        if let hoveredID, !liveIDs.contains(hoveredID) {
            self.hoveredID = nil
        }
        startCollapsing(closedIDs, animation: animation, onCollapseFinished: onCollapseFinished)
    }

    /// 閉じたタブを元の幅で 1 回描いてから幅を 0 まで縮め、縮めきったら外す
    private func startCollapsing(
        _ closedIDs: [Item.ID],
        animation: Animation,
        onCollapseFinished: (@MainActor (Item.ID) -> Void)?
    ) {
        guard !closedIDs.isEmpty else { return }
        Task { @MainActor in
            withAnimation(animation) {
                for id in closedIDs {
                    closingTabs[id]?.isCollapsed = true
                }
            } completion: { [self] in
                finishCollapsing(closedIDs, onCollapseFinished: onCollapseFinished)
            }
        }
    }

    private func finishCollapsing(_ closedIDs: [Item.ID], onCollapseFinished: (@MainActor (Item.ID) -> Void)?) {
        // 縮めている途中に同じ id を足し直した (consumer の一覧に戻ってきた) ものは、生きているタブとして残す
        let liveIDs = Set(renderedIDs)
        for id in closedIDs {
            closingTabs[id] = nil
            if !liveIDs.contains(id) {
                renderedItems[id] = nil
                widths[id] = nil
            }
            onCollapseFinished?(id)
        }
        displayedIDs.removeAll { closedIDs.contains($0) && !liveIDs.contains($0) }
    }

    private static func byID(_ items: [Item]) -> [Item.ID: Item] {
        Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
