# 新規 API 追加検討: タブストリップ UI (Safari/Xcode 風タブバー + ドラッグ並べ替え)

ある consumer app で「Safari/Xcode 風の本物のタブ」風ストリップを実装しており、そこにドラッグ並べ替えを足したい流れで「このタブ UI 自体を lib に切り出せないか」という発想が出た。本 issue ではその切り出しの是非と最小 API を検討する。

---

## 背景

複数のドキュメント / ワークスペースを横並びのタブで切り替える UI は、Safari / Chrome / Xcode に代表される macOS の定番パターン。典型的な機能要素:

- フラットな矩形タブ、active はコンテンツ色 + 上端アクセントバー、inactive は透明 + 区切り線、close (×) はホバー時のみ
- 新規タブ (+) / close (×) / 水平スクロール
- タブ名の表示 (中身ベースの自動名 / 手動リネーム) と inline rename
- **single-click 即時化**: `.onTapGesture(count: 2)` を併用すると single tap が `NSEvent.doubleClickInterval` ぶん遅延するため、本 lib の `DoubleClickDetector` (id モード) で「single 即時 + ダブルクリックで rename」を両立する (= 既に本 lib の API を consume するパターンが確立している)

ここに **ドラッグ並べ替え** を足したい。タブの drag-and-drop reorder は上記 app 群の標準操作で、マルチドキュメント / マルチワークスペース型 app で同形になりやすい。

## 検討したいこと

この「タブストリップ UI」を **薄い macOS primitive として lib に切り出す価値があるか**、あるなら最小公倍数 API は何か。

`docs/api-boundaries.md` の方針 (= 「広い UI kit ではない。明確な cross-app value がある薄い macOS primitive のみ追加する」) と、`MenuBarAgent` / `MenuBarContract` を「icon・menu・click behavior・lifecycle がアプリ固有」として **提供しない**と決めた前例に照らして判断する。タブバーは「見た目 + ドラッグ/クリックのインタラクション」は cross-app だが、「タブが何か・どう生成/破棄/永続化するか」はアプリ固有という、ちょうど境界線上にある。

## 論点 (api-boundaries との緊張)

タブバーは 2 つの責務が混ざる:

1. **表示 + ジェスチャ** (cross-app primitive 候補): タブの矩形描画 / active 強調 / ホバー / 区切り線 / 水平スクロール / single 即時クリック / ダブルクリック / **ドラッグ並べ替えの drop 位置計算とアニメーション** / inline rename フィールド
2. **lifecycle** (アプリ固有 = consumer に残す): タブの生成 / 破棄 / 選択 / 並べ替え結果の確定 / 永続化 / タブ名の source of truth / 各タブが保持するリソースの管理

`MenuBarVisibilityToggle` が `Binding<Bool>` + 共通 label だけに絞って lifecycle を排除したのは「小さな UI primitive」の典型だが、タブストリップは `onSelect` / `onClose` / `onAddTab` / `onRename` / `onReorder` を持つ **interactive composite** で、薄さの度合いはむしろ `ShortcutSettingsTab` や `standardActionConfirmation` に近い。共通する設計原則は「**lifecycle 副作用は lib に持たせず callback で consumer に押し出す**」こと。**1 (表示+ジェスチャ) だけを lib、2 (lifecycle) は callback/表示モデル経由で consumer** に寄せられるかが採否の鍵。

## 提案 API イメージ (採用する場合)

表示モデル + callback のみを受け、内部状態 (drag 中の並び / rename draft) は lib が持つが、確定は callback で consumer に返す形:

```swift
public struct StandardTabStrip<Tab: Identifiable>: View {
    public init(
        tabs: [Tab],
        activeID: Tab.ID?,
        title: @escaping (Tab) -> String,          // 表示名 (自動名/手動名の解決は consumer)
        onSelect: @escaping (Tab.ID) -> Void,
        onClose: ((Tab.ID) -> Void)? = nil,         // nil なら × を出さない
        onReorder: @escaping (_ from: IndexSet, _ to: Int) -> Void,   // ドラッグ並べ替え確定
        onAddTab: (() -> Void)? = nil,              // nil なら + を出さない
        onRename: ((Tab.ID, String) -> Void)? = nil // nil なら inline rename 無効
    )
}
```

- 見た目 (active 塗り / アクセントバー / 区切り線) は lib が macOS 標準寄りの素朴な描画で持つ。brand color は `tint` のような薄い差し込みに留める (Design tokens は持たない方針を維持)
- ドラッグ並べ替えは lib 内で drop 位置計算 + アニメーションを完結させ、結果だけ `onReorder` で返す
- single 即時クリック + ダブルクリック rename は既存 `DoubleClickDetector` (本 lib) を内部利用
- inline rename の TextField / focus / submit-blur-esc も lib 内に閉じ、確定文字列だけ `onRename` で返す

consumer に残るもの: タブの lifecycle (生成/破棄/選択/並べ替えの実体・永続化)、タブ名の自動/手動解決、各タブのリソース管理。

## 採否の判断基準

- **cross-app value**: 現時点で同形のタブストリップを必要とする app は 1 つ。**1 app だけなら speculative extraction になる** ので、まず consumer 側で drag-reorder を実装してパターンを固め、2 つ目の需要が見えた時点で切り出す方が安全 (複数 app で同形が確認できてから lib 化する。`done/003` も同じ「複数 app の重複を確認してから検討」の立て付け)
- **薄さを保てるか**: 表示+ジェスチャだけに絞り lifecycle を callback に追い出せるか。追い出せず「タブの中身や永続化を知る」設計になるなら `MenuBarAgent` と同じ理由で **提供しない**
- **見た目の差**: active 強調 / アクセントバー / 区切り線 / × の出し方は app ごとに brand tone が出る部分。`StandardEmptyStateView` を「design-system 寄り」として除外したのと同じ懸念があるか

## 完了条件

いずれかで決着:

1. **採用 + lib に追加** — `docs/api-boundaries.md` に「タブストリップ」セクションを追加、`Sources` に `StandardTabStrip` (+ ドラッグ並べ替え) を追加、`Tests` 追加、`docs/*.md` で documenting。consumer を移行
2. **不採用** — 「提供しない API」表に「タブストリップ」を追記し、除外理由 (lifecycle がアプリ固有 / 見た目が brand 依存 / 2 つ目 consumer 不在 等) を残す

判断順序の推奨: **まず consumer 側でドラッグ並べ替えを実装** → パターンが固まり 2 つ目の consumer 需要が見えたら本 issue の切り出しを再評価。

## やらないこと

- speculative extraction (consumer 1 つの段階で先に lib へ切り出す)。まず app 側で drag-reorder を固める
- Design tokens / brand color システムには踏み込まない (既存方針維持)
- タブの lifecycle (生成/破棄/永続化) を lib に持ち込まない。持ち込む設計しか成立しないなら不採用に倒す

## 関連

- 本 lib 既存: `DoubleClickDetector` (`Sources/StandardAppComponents/Gesture/`) — タブの single 即時クリックで利用するパターンの起点
- API 境界: `docs/api-boundaries.md` の「提供しない API」(`MenuBarAgent` / `StandardEmptyStateView` の除外理由) と「小さな UI primitive」の判定軸
- 既存 issue `done/003` — 「複数 app で同形を確認してから lib 化を検討する」立て付けの先例
