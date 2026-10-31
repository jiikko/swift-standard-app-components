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
    /// 足したタブの動きが終わった回数。選んだタブを送り直す合図
    var settledOpenCount = 0

    private(set) var widths: [Item.ID: CGFloat] = [:]
    private(set) var closingTabs: [Item.ID: ClosingTab] = [:]
    /// 前に描いた consumer のタブの id の並び。次の描画でタブが閉じられた (抜けた) かを見分ける
    private var renderedIDs: [Item.ID] = []
    /// 前に描いた並び (縮めている途中の閉じたタブを含む)。閉じたタブをどこに残すかを決める
    private var displayedIDs: [Item.ID] = []
    /// 前に描いた consumer のタブ。閉じた直後 (consumer の一覧から抜けた後) も、縮めている間はこれで描く
    @ObservationIgnored private var renderedItems: [Item.ID: Item] = [:]
    /// スクロールの見えている所に対するタブの左右の端と、見えている所の幅。選んだタブを送るかを決める。
    /// スクロールのたびに変わるので観測しない (body を描き直させない)
    @ObservationIgnored private var visibleSpans: [Item.ID: ClosedRange<CGFloat>] = [:]
    @ObservationIgnored var viewportWidth: CGFloat = 0

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

    /// 足したタブ (足した直後の描画で、まだ `itemsDidChange` が前の並びを書き換える前に見分ける)
    func openedIDs(for items: [Item]) -> [Item.ID] {
        StandardTabOpening.openedIDs(from: renderedIDs, to: items.map(\.id))
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

    /// タブの左右の端 (スクロールの見えている所の座標)
    func recordVisibleSpan(minX: CGFloat, maxX: CGFloat, for id: Item.ID) {
        guard minX <= maxX else { return }
        visibleSpans[id] = minX...maxX
    }

    /// 選んだタブを見える所へ送るか。全部見えていれば送らない (押したタブの下で帯が動くと、ダブルクリックの 2 回目が
    /// 隣のタブに当たる)。隠れている・一部が切れている・まだ測っていない (足した直後) なら送る
    func needsScroll(to id: Item.ID) -> Bool {
        guard let span = visibleSpans[id] else { return true }
        return !Self.isFullyVisible(span, viewportWidth: viewportWidth)
    }

    static func isFullyVisible(_ span: ClosedRange<CGFloat>, viewportWidth: CGFloat) -> Bool {
        // 端数の丸めで 0.5pt はみ出しても見えていると見る
        viewportWidth > 0 && span.lowerBound >= -0.5 && span.upperBound <= viewportWidth + 0.5
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
        onTabRemoved: (@MainActor (Item.ID) -> Void)?
    ) {
        let ids = items.map(\.id)
        let closedIDs = collapses ? StandardTabClosing.closedIDs(from: renderedIDs, to: ids) : []
        // 縮めずに一覧から外れたタブ (縮めない設定・置き換え・総入れ替え)。すぐ外れたと知らせる (縮めるタブは縮めきってから)
        let liveIDSet = Set(ids)
        let removedNowIDs = renderedIDs.filter { !liveIDSet.contains($0) && !closedIDs.contains($0) }
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
        widths = widths.filter { liveIDSet.contains($0.key) || closingTabs[$0.key] != nil }
        visibleSpans = visibleSpans.filter { liveIDSet.contains($0.key) }
        if let draggingID, !liveIDSet.contains(draggingID) {
            resetDrag()
        }
        if let hoveredID, !liveIDSet.contains(hoveredID) {
            self.hoveredID = nil
        }
        for id in removedNowIDs {
            onTabRemoved?(id)
        }
        startCollapsing(closedIDs, animation: animation, onTabRemoved: onTabRemoved)
    }

    /// 閉じたタブを元の幅で 1 回描いてから幅を 0 まで縮め、縮めきったら外す
    private func startCollapsing(
        _ closedIDs: [Item.ID],
        animation: Animation,
        onTabRemoved: (@MainActor (Item.ID) -> Void)?
    ) {
        guard !closedIDs.isEmpty else { return }
        Task { @MainActor in
            withAnimation(animation) {
                for id in closedIDs {
                    closingTabs[id]?.isCollapsed = true
                }
            } completion: { [self] in
                finishCollapsing(closedIDs, onTabRemoved: onTabRemoved)
            }
        }
    }

    private func finishCollapsing(_ closedIDs: [Item.ID], onTabRemoved: (@MainActor (Item.ID) -> Void)?) {
        // 縮めている途中に同じ id を足し直した (consumer の一覧に戻ってきた) ものは、生きているタブとして残す
        let liveIDs = Set(renderedIDs)
        for id in closedIDs {
            closingTabs[id] = nil
            if !liveIDs.contains(id) {
                renderedItems[id] = nil
                widths[id] = nil
                onTabRemoved?(id)
            }
        }
        displayedIDs.removeAll { closedIDs.contains($0) && !liveIDs.contains($0) }
    }

    private static func byID(_ items: [Item]) -> [Item.ID: Item] {
        Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
