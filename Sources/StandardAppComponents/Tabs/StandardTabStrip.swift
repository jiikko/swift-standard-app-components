import AppKit
import SwiftUI

/// タブの帯 (Chrome と同じ見え方)。選んでいるタブを本体と同じ色で塗り、下端の両脇を反らせて本体へつなぐ。
///
/// lib が持つのは「表示 + ジェスチャ」: 並べる・選ぶ・閉じる (×)・足す (+)・ドラッグで並べ替える・選んでいるタブを見える所へ送る・
/// 閉じたタブを並びに残したまま幅を 0 まで縮めて消す。タブの一覧と順の持ち主・閉じる前の確認・名前の変更・タブの中身 (アイコン・題名・入力欄)・
/// 最後の 1 枚を閉じたときの扱いは consumer に残す (callback で返す)。
///
/// 置く場所の前提: 帯の下端が本体 (`selectedFill` と同じ色) に接していること。帯と本体の境の線は consumer が帯より奥 (`background`) に描く
/// (選んでいるタブがその線の上を塗って本体とつながる)。
///
/// ```swift
/// StandardTabStrip(
///     tabs, activeID: activeID, selectedFill: Color(nsColor: .windowBackgroundColor),
///     onSelect: { store.select($0) },
///     onClose: { store.close($0) },
///     onAdd: { store.add() },
///     onMove: { store.move($0, relativeTo: $1, placement: $2) }
/// ) { tab, state in
///     Text(verbatim: tab.title).foregroundStyle(state.isActive ? .primary : .secondary)
/// }
/// ```
@MainActor
public struct StandardTabStrip<Item: Identifiable, Label: View>: View {
    private let items: [Item]
    private let activeID: Item.ID?
    private let selectedFill: Color
    private let configuration: StandardTabStripConfiguration
    private let actions: Actions
    private let slots: Slots
    private let label: (Item, StandardTabState) -> Label

    @State private var model = StandardTabStripModel<Item>()

    /// - Parameters:
    ///   - items: 左から並べるタブ。同じ id を 2 度入れない
    ///   - activeID: 選んでいるタブ
    ///   - selectedFill: 選んでいるタブの塗り。タブの下の本体と同じ色を渡す (下端でつながって見える)
    ///   - configuration: 寸法・閉じるときの動き・+ の置き方・help の文言
    ///   - onSelect: タブを押した
    ///   - onClose: × を押した (nil なら × を出さない)。閉じる前の確認は consumer が挟む
    ///   - canClose: × を出すか (タブごと。名前の入力中や消せないタブで止める)
    ///   - onAdd: + を押した (nil なら + を出さない)
    ///   - onMove: ドラッグで並べ替えた。`moving` を `target` の前 / 後ろへ (nil なら並べ替えない)
    ///   - canDrag: ドラッグを始められるか (名前の入力中などで止める)
    ///   - onCollapseFinished: 閉じたタブを縮めきって並びから外した。consumer が縮める間のために持っていた写しを捨てる時点
    ///   - accessibilityIdentifier: タブの accessibility の identifier (UI テストで探す)
    ///   - tabOverlay: タブ全体に重ねる view (× の所も覆う。× を避けるなら `StandardTabStripConfiguration.closeButtonReservedWidth` だけ右を空ける)
    ///   - trailingAccessory: + の右 (+ が無ければタブの右) に置く view (読み込み中の表示・popover の起点など)
    ///   - contextMenu: タブの右クリックのメニュー
    ///   - label: タブの中身。`state.isClosing` のとき、`item` は consumer の一覧からもう抜けている (lib が最後に受け取った値)
    public init(
        _ items: [Item],
        activeID: Item.ID?,
        selectedFill: Color,
        configuration: StandardTabStripConfiguration = StandardTabStripConfiguration(),
        onSelect: @escaping @MainActor (Item.ID) -> Void,
        onClose: (@MainActor (Item.ID) -> Void)? = nil,
        canClose: @escaping @MainActor (Item, StandardTabState) -> Bool = { _, _ in true },
        onAdd: (@MainActor () -> Void)? = nil,
        onMove: (@MainActor (_ moving: Item.ID, _ target: Item.ID, _ placement: StandardTabMovePlacement) -> Void)? = nil,
        canDrag: @escaping @MainActor (Item) -> Bool = { _ in true },
        onCollapseFinished: (@MainActor (Item.ID) -> Void)? = nil,
        accessibilityIdentifier: @escaping @MainActor (Item) -> String? = { _ in nil },
        tabOverlay: (@MainActor (Item, StandardTabState) -> AnyView)? = nil,
        trailingAccessory: (@MainActor () -> AnyView)? = nil,
        contextMenu: (@MainActor (Item) -> AnyView)? = nil,
        @ViewBuilder label: @escaping (Item, StandardTabState) -> Label
    ) {
        self.items = items
        self.activeID = activeID
        self.selectedFill = selectedFill
        self.configuration = configuration
        self.actions = Actions(
            onSelect: onSelect, onClose: onClose, canClose: canClose, onAdd: onAdd, onMove: onMove,
            canDrag: canDrag, onCollapseFinished: onCollapseFinished
        )
        self.slots = Slots(
            accessibilityIdentifier: accessibilityIdentifier, tabOverlay: tabOverlay,
            trailingAccessory: trailingAccessory, contextMenu: contextMenu
        )
        self.label = label
    }

    public var body: some View {
        let entries = model.entries(for: items, collapses: collapses)
        layout(entries: entries)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .clipped()
            .onAppear { model.start(with: items) }
            .onChange(of: items.map(\.id)) { _, _ in
                model.itemsDidChange(
                    items,
                    displayed: entries.map(\.id),
                    collapses: collapses,
                    fallbackWidth: configuration.tabWidth.lowerBound,
                    animation: configuration.collapseAnimation,
                    onCollapseFinished: actions.onCollapseFinished
                )
            }
            // タブの隙間や + など、どのタブにも乗らない所へ drop されたときにドラッグの状態を片付ける (タブの drop 先が優先される)
            .onDrop(of: [.text], isTargeted: nil) { _ in
                let wasDragging = model.draggingID != nil
                model.resetDrag()
                return wasDragging
            }
    }

    private var collapses: Bool {
        configuration.closeAnimation == .collapse
    }

    // MARK: - 並べ方

    @ViewBuilder
    private func layout(entries: [StandardTabClosing.Entry<Item.ID>]) -> some View {
        switch configuration.addButtonPlacement {
        case .inline:
            scrollingTabs(entries: entries, includesTrailingControls: true)
        case .pinnedWhenOverflowing:
            // 収まるときはタブの直後に + を並べ、溢れたときだけ + をスクロールの外 (右端) に出す (タブが多くても + が見える)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    tabRow(entries: entries, includesTrailingControls: true)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 0) {
                    scrollingTabs(entries: entries, includesTrailingControls: false)
                    trailingControls
                }
            }
        }
    }

    private func scrollingTabs(entries: [StandardTabClosing.Entry<Item.ID>], includesTrailingControls: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                tabRow(entries: entries, includesTrailingControls: includesTrailingControls)
            }
            .scrollIndicators(.hidden)
            // 選んでいるタブが隠れていたら見える所へ送る (足したタブ・番号で選んだタブ・復元・ウィンドウの幅の変化)。
            // その場で送ると、足したタブの位置が決まる前で効かないので、次の main actor の番で送る。
            // 中央に寄せる (寄せないと端のタブが途中で切れて残る)。見るのは表示の幅 (中身の幅だと縮めている毎フレームで送り直す)
            .onAppear { scrollToActive(proxy) }
            .onChange(of: activeID) { _, _ in scrollToActive(proxy) }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in scrollToActive(proxy) }
            .onChange(of: model.closingTabs.isEmpty) { _, isEmpty in
                // 選んでいたタブを閉じたとき、送り先は縮める前の並びで決まる。縮めきってから送り直す
                if isEmpty { scrollToActive(proxy) }
            }
        }
    }

    private func tabRow(entries: [StandardTabClosing.Entry<Item.ID>], includesTrailingControls: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { position, entry in
                Group {
                    if let index = entry.liveIndex {
                        tab(items[index], separatorAfter: showsSeparator(after: position, in: entries))
                            .id(entry.id)
                    } else if let closing = model.closingTab(id: entry.id, fallbackWidth: configuration.tabWidth.lowerBound) {
                        StandardClosingTabChrome(
                            content: label(closing.item, state(for: closing.item, isClosing: true)),
                            width: closing.width,
                            isCollapsed: closing.isCollapsed,
                            configuration: configuration
                        )
                    }
                }
                // 足したタブ・縮めきって外すタブに transition を付けない
                .transition(.identity)
            }
            if includesTrailingControls {
                trailingControls
            }
        }
        // 両端のタブの下端の反り (`StandardTabShape.flare`) を切らない
        .padding(.horizontal, StandardTabShape.defaultFlare + 2)
    }

    @ViewBuilder
    private var trailingControls: some View {
        if let onAdd = actions.onAdd {
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(configuration.addHelp ?? StandardTabStripConfiguration.defaultAddHelp)
            .padding(.leading, 4)
        }
        if let trailingAccessory = slots.trailingAccessory {
            trailingAccessory()
        }
    }

    // MARK: - タブ

    private func state(for item: Item, isClosing: Bool = false) -> StandardTabState {
        StandardTabState(
            isActive: !isClosing && item.id == activeID,
            isHovered: !isClosing && model.hoveredID == item.id,
            isDragging: !isClosing && model.draggingID == item.id,
            isClosing: isClosing
        )
    }

    private func tab(_ item: Item, separatorAfter: Bool) -> some View {
        let id = item.id
        let tabState = state(for: item)
        let showsClose = actions.onClose != nil && actions.canClose(item, tabState)
        return StandardTabChrome(
            content: label(item, tabState)
                .modifier(TabDragSource(isEnabled: actions.onMove != nil && actions.canDrag(item)) {
                    model.draggingID = id
                    model.lastMove = nil
                    // 中身は使わない (並べ替えは hover の live move で行い、相手は lib の dragging の状態で確かめる)。
                    // 文字の型にするのは、consumer の Info.plist に型を宣言させないため
                    return NSItemProvider(object: StandardTabStripConfiguration.dragPayload as NSString)
                }),
            isActive: tabState.isActive,
            isHovered: tabState.isHovered,
            isDragging: tabState.isDragging,
            isAnyDragging: model.draggingID != nil,
            showsClose: showsClose,
            separatorAfter: separatorAfter,
            selectedFill: selectedFill,
            configuration: configuration
        ) {
            actions.onClose?(id)
        }
        // 幅を覚えておく (ドラッグの前後を hover の位置で決める・閉じたタブを縮め始める幅)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            model.recordWidth(width, for: id)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 取り消されたドラッグの状態が残っていたら、ここで片付けてから選ぶ (この 1 回のクリックも選択に使う)
            model.resetDrag()
            actions.onSelect(id)
        }
        .modifier(TabSlotsModifier(overlay: slots.tabOverlay.map { make in make(item, tabState) },
                                   menu: slots.contextMenu.map { make in make(item) }))
        .onHover { hovering in
            model.hoveredID = hovering ? id : (model.hoveredID == id ? nil : model.hoveredID)
        }
        .onDrop(of: [.text], delegate: StandardTabDropDelegate(
            targetID: id,
            tabWidth: model.width(for: id, fallback: configuration.tabWidth.lowerBound),
            draggingID: Bindable(model).draggingID,
            lastMove: Bindable(model).lastMove,
            onMove: actions.onMove
        ))
        .modifier(TabAccessibility(
            isActive: tabState.isActive,
            identifier: slots.accessibilityIdentifier(item),
            onSelect: { actions.onSelect(id) },
            onClose: showsClose ? { actions.onClose?(id) } : nil
        ))
    }

    /// entries の position のタブの右に区切り線を出すか。自分も右隣も生きていて、どちらも選んでいないときだけ
    private func showsSeparator(after position: Int, in entries: [StandardTabClosing.Entry<Item.ID>]) -> Bool {
        guard position + 1 < entries.count,
              entries[position].liveIndex != nil, entries[position + 1].liveIndex != nil else { return false }
        return entries[position].id != activeID && entries[position + 1].id != activeID
    }

    private func scrollToActive(_ proxy: ScrollViewProxy) {
        guard let activeID else { return }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(activeID, anchor: .center)
            }
        }
    }

    // MARK: - 型

    private struct Actions {
        let onSelect: @MainActor (Item.ID) -> Void
        let onClose: (@MainActor (Item.ID) -> Void)?
        let canClose: @MainActor (Item, StandardTabState) -> Bool
        let onAdd: (@MainActor () -> Void)?
        let onMove: (@MainActor (Item.ID, Item.ID, StandardTabMovePlacement) -> Void)?
        let canDrag: @MainActor (Item) -> Bool
        let onCollapseFinished: (@MainActor (Item.ID) -> Void)?
    }

    private struct Slots {
        let accessibilityIdentifier: @MainActor (Item) -> String?
        let tabOverlay: (@MainActor (Item, StandardTabState) -> AnyView)?
        let trailingAccessory: (@MainActor () -> AnyView)?
        let contextMenu: (@MainActor (Item) -> AnyView)?
    }
}

/// consumer が渡した、タブ全体に重ねる view と右クリックのメニュー
private struct TabSlotsModifier: ViewModifier {
    let overlay: AnyView?
    let menu: AnyView?

    func body(content: Content) -> some View {
        content
            .overlay { overlay }
            .contextMenu { menu }
    }
}

/// タブの読み上げ: ボタン・選んでいる状態・「Close Tab」の操作・UI テスト用の identifier
private struct TabAccessibility: ViewModifier {
    let isActive: Bool
    let identifier: String?
    let onSelect: () -> Void
    let onClose: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect() }
            .accessibilityAction(named: Text("Close Tab", bundle: .module)) {
                onClose?()
            }
            .accessibilityIdentifier(identifier ?? "")
    }
}
