# 新規 API 追加検討: EmptyStateView / ActionConfirmation / BlockingProgressOverlay

umbrella audit 由来 (元: `my-products/issues/013-refactor-ui-components-extraction.md` のうち「B. lib への新規追加 + 各 app の移行」セクション = #4 EmptyStateView / #5 ConfirmationDialog modifier / #6 BlockingProgressOverlay)

---

## 背景

umbrella 側 audit で、「lib に未収容だが複数 app が同形に再実装している UI」が 3 種類見つかった。本 issue では **lib への新規追加が妥当かを検討し、追加する場合は最小公倍数 API を設計する**。

ただし、lib の API 境界方針 (`docs/api-boundaries.md` 末尾) には `Design tokens / common buttons / empty states` が「提供しないもの」として明示されている (理由: 「広い UI kit ではない。明確な cross-app value がある薄い macOS primitive のみ追加する」)。本 issue の各候補が **その除外条件を覆すだけの cross-app value を持つか** を含めて検討する。

## 候補

### A. `StandardEmptyStateView` (icon + title + optional description + optional actions)

**重複実装**:
- `apps/DualNoteApp/Shared/Sources/DualNoteShared/Views/EmptyStateView.swift` — public な `EmptyStateView(icon:title:description:expandFrame:)` を既に汎用 SPM Package として持っている (`Theme.secondaryText` / `Theme.primaryText` の依存があるだけ)
- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Views/VideoGrid/EmptySlotView.swift` — icon + label 縦並び。ドロップターゲット時に色が変わる以外は EmptyStateView と等価
- `apps/ThumbnailThumb/ThumbnailThumb/Sources/Views/Components/EmptyCanvasView.swift` — icon + title + description + アクションボタン群 + ヒント。複合だが内側のブロックは同じパターン
- baby-note / dotfiles-gui の List 空表示でも手書き VStack が散在

**提案 API イメージ**:
```swift
public struct StandardEmptyStateView<Actions: View>: View {
    public init(
        systemImage: String,
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
        tint: Color? = nil,               // ドロップターゲット時の強調用 (nil なら .secondary)
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    )
}
```

- VLC の `EmptySlotView` は `isTargeted` で色を差し替えるので `tint` で吸収
- ThumbnailThumb の `EmptyCanvasView` は `actions` slot に "Add image / Add text / Add shape" を渡す形で再構成
- DualNoteShared の `expandFrame` は `Color.clear.overlay { ... }` で囲む adapter で代替可

**論点**: API 境界の「empty state は持たない」方針との整合。複数 app で同形が確認されているので、「持たない」方針を見直すか、`StandardEmptyStateView` を「primitive な値伝達 View のみ」 (= Theme 依存なし、actions slot だけ) に絞って例外を作るか、判断が必要。

### B. `View.standardActionConfirmation(...)` (primary / secondary / destructive / cancel の一般化)

**重複実装**:
- `apps/DualNoteApp/macOS/Sources/Views/ConflictResolutionDialogModifier.swift` — `confirmationDialog(_:isPresented:titleVisibility:presenting:)` を `Entity: Sendable` で generics 化、`onOverwrite / onReload / onShowDiff` の 3 アクション + cancel
- `apps/DualNoteApp/macOS/Sources/Views/DiaryColumnDialogsModifier.swift` / `MemoColumnDialogsModifier.swift` — 同形を複数並べる呼び出し側
- `apps/baby-note/...FamilyParticipantDetailView.swift` / `ChildManagementView.swift` 等で「削除して大丈夫?」系の `.confirmationDialog(...) { ... } message: { ... }` が手書きで散在

**提案 API イメージ**:
```swift
public struct StandardActionConfirmation<Subject>: ViewModifier where Subject: Hashable {
    public init(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subject: Subject?,
        primary: ActionButton,
        secondary: ActionButton? = nil,
        destructive: ActionButton? = nil,
        cancel: LocalizedStringResource = "Cancel",
        message: @escaping (Subject) -> Text
    )
}

public struct ActionButton {
    public let title: LocalizedStringResource
    public let handler: () -> Void
    public let role: ButtonRole?       // .destructive / .cancel / nil
}
```

- DualNote の overwrite/reload/showDiff は `primary` / `secondary` / `destructive` に割り当て可
- 「単に削除確認」のケースは `destructive` だけ渡して使える
- ルール `standard-app-components.md` 末尾: 「Toast で扱うべきではない blocking decision (破壊的確認・致命的エラー) は Alert / Sheet」と一致

**論点**: SwiftUI 標準 `.confirmationDialog(...)` で十分なケースが多く、薄い wrapper が本当に価値を生むか要評価。生む場合のみ採用。

### C. `View.standardBlockingProgressOverlay(...)` (処理中で操作不能な全画面オーバーレイ)

**重複実装**:
- `apps/fdup-macos/Sources/FilecodeMatcher/Views/Components/BlockingOverlayDialog.swift` — `ProgressView` + title + subtitle + content slot + cancel ボタンの全画面 modal オーバーレイ
- `apps/DualNoteApp/macOS/Sources/Views/SettingsView.swift` の `.loadingOverlay(isPresented:message:animation:)` — 進捗 message + spinner
- dotfiles-gui の同期中表示も独自に手書き

**提案 API イメージ**:
```swift
public extension View {
    func standardBlockingProgressOverlay(
        isPresented: Binding<Bool>,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        onCancel: (() -> Void)? = nil   // nil ならキャンセル不能
    ) -> some View
}
```

- fdup-macos の `strokedCard(radius: .large)` 等の theme 依存は consumer 側に残し、lib では `.background(.ultraThinMaterial)` + `RoundedRectangle` の素朴な見た目で実装
- content slot を持たせるかは要検討 (持たせると過剰仕様になりやすいので最初は title/subtitle/cancel のみで開始)

**論点**: 3 app で形が揃ったが、「全画面 blocking UX」自体が macOS HIG として議論の余地あり (代替案: Sheet の indeterminate ProgressView)。採用前に HIG 整合性も確認。

## 完了条件

各候補ごとに以下のいずれかで決着:

1. **採用 + lib に追加** — API 境界ドキュメント (`docs/api-boundaries.md`) の「提供しない」リストから外し、Sources に追加、Tests 追加、`docs/*.md` で documenting
2. **不採用** — 「提供しない」方針を維持し、その判断理由を `docs/api-boundaries.md` 末尾の根拠表に追記 (将来の再評価のため)

判断順序の推奨: **B → C → A**。B/C は consumer 側の「blocking decision の標準化」という明確な cross-app value があるので採用しやすい。A は API 境界方針と正面衝突するので最後に判断。

## やらないこと

- 全 3 つを無条件に lib に入れない。**個別判断**
- 各 consumer の移行作業自体はこの issue で扱わない (= umbrella 側の別 issue)
- Theme tokens / Design system 的な広い UI kit には踏み込まない (= 既存方針維持)

## 関連 (背景情報)

- umbrella audit issue: `my-products/issues/013-refactor-ui-components-extraction.md` (#4, #5, #6 セクション)
- lib API 境界: `docs/api-boundaries.md` の末尾「提供しない API」セクション (`Design tokens / common buttons / empty states` を明示除外)
- umbrella rule: `my-products/.claude/rules/standard-app-components.md` の Toast / Alert / Sheet 使い分け基準
