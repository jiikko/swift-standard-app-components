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

---

## 決定 (2026-10-31): 採用する

ユーザー指示 (2026-10-31): vlc-multi-video-player のタブを SAC へ移し、obaket でも使う。DualNote のメモ帳のプロジェクトのタブも同じ種類。

「2 つ目の consumer が同じ形で要るようになってから」の条件を、3 つの consumer の実装を読んで確かめた (2026-10-31):

| 要素 | vlc (WorkspaceTabBar) | obaket (TabBarView) | DualNote (ProjectTabBarView) |
|---|---|---|---|
| 選んでいるタブを見える所へ送る (追加・選択・幅の変化) | あり (ScrollViewReader、次の main の回) | あり (同じ形 + 中央に寄せる + 幅の変化で寄せ直す) | なし (送らない) |
| ドラッグで並べ替え (hover で並びを動かす live move) | あり (DropDelegate、左右半分で前後) | あり (DropDelegate、index の前後) | あり (dropDestination + 末尾の drop 先) |
| hover で × を出す・+ を並びの後ろ | あり | あり | + あり・削除は右クリック等 |
| 閉じたタブを幅 0 まで縮めて消す | あり | なし | なし |
| 見た目 | Chrome 風 (本体と同じ色の塗りで下端をつなぐ) | 角丸の薄い塗り | 上・左右の枠線 |
| 名前の変更 | ダブルクリック (タイトルバーの行なので app 固有の受け方) | なし | ダブルクリック (DoubleClickDetector) |

lib に置くのは「表示 + ジェスチャ」まで。タブの生成・破棄・選択・並べ替えの確定・永続化・名前・閉じる前の確認は consumer の callback に残す (本 issue の論点のとおり)。
見た目は 1 つ (Chrome 風) に揃える。consumer ごとの見た目の差し替えの口は持たない (色の 1 つだけ受ける)。

## API (案)

```swift
public struct StandardTabStrip<Item: Identifiable, Label: View, MenuItems: View>: View {
    public init(
        _ items: [Item],
        activeID: Item.ID?,
        selectedFill: Color,                                   // 選んでいるタブの塗り。タブの下の本体と同じ色を渡す (下端でつながって見える)
        onSelect: @escaping (Item.ID) -> Void,
        onClose: ((Item.ID) -> Void)? = nil,                   // nil なら × を出さない。確認を挟むかは consumer
        onAdd: (() -> Void)? = nil,                            // nil なら + を出さない
        onMove: ((_ moving: Item.ID, _ target: Item.ID, _ placement: StandardTabMovePlacement) -> Void)? = nil,  // nil なら並べ替えない
        canDrag: @escaping (Item) -> Bool = { _ in true },     // 名前の変更中などに止める
        @ViewBuilder label: @escaping (Item, StandardTabState) -> Label,      // タブの中身 (アイコン・題名・入力欄)
        @ViewBuilder contextMenu: @escaping (Item) -> MenuItems
    )
}

public enum StandardTabMovePlacement: Sendable { case before, after }

public struct StandardTabState: Equatable, Sendable {
    public let isActive: Bool
    public let isHovered: Bool
    public let isDragging: Bool
    /// 閉じて縮めている途中 (この item は consumer の items にもう無い。描くための値は lib が最後に受け取った item)
    public let isClosing: Bool
}
```

lib が持つもの:
- 並び: 横スクロールの中にタブと + を並べる。タブの幅は 72〜170pt、高さ 30pt、行の下端に揃える
- 見た目: 選んでいるタブを `selectedFill` で塗り、上の角を丸め、下端の両脇を反らせる (Chrome)。隣り合う選んでいないタブの間に区切り線、hover で薄い塗り、hover で ×
- 選んでいるタブを見える所へ送る: `activeID` と行の幅が変わったら、次の main actor の番で `scrollTo(anchor: .center)` (obaket の実測: その場では幅が決まる前で効かない / anchor 無しだと端で切れる)
- 閉じたときのアニメーション: items から抜けた (閉じた) タブを並びに残して幅を 0 まで縮める。足す・並べ替え・総入れ替えのときは縮めない (vlc の WorkspaceTabClosing をそのまま移す)
- ドラッグの並べ替え: タブの中身を drag source にし、hover した相手のタブの左右半分で前後を決めて `onMove` を呼ぶ (同じ組の連続の hover は 1 回だけ)。
  item provider は lib 固有の型で `.ownProcess` に限る (他のアプリの文字のドラッグを受けない)
- クリック: タブを押したら `onSelect`。ダブルクリック・名前の変更は持たない (consumer が `label` の中で受ける。vlc はタイトルバーの行なので、ウィンドウの拡大と取り合う app 固有の受け方が要る)
- 文言: × の help「Close Tab」、+ の help「New Tab」(lib の catalog に ja を持ち、requiredKeys に足す)

consumer に残るもの: タブの一覧と順の持ち主、閉じる前の確認、最後の 1 枚を閉じたときの扱い (obaket はウィンドウを閉じる)、名前の変更 (入力欄は `label` の中)、題名の中身 (アイコン・spinner・pill)、
閉じて縮めている間に描く値 (lib は最後に受け取った item を `label` に渡す。item が live な model を指すなら、consumer が `isClosing` で写しを描く)。

## 移行の順

1. lib に `StandardTabStrip` を足す (vlc の実装から、上の lib の範囲を切り出す)。純粋な判断 (閉じたかの見分け・縮めているタブの差し込み位置・ドラッグの前後) はテストを持って移す
2. vlc を置き換える (見た目・挙動は今と同じ)
3. obaket を置き換える (見た目は角丸 → Chrome 風に変わる。`ViewThatFits` で並べる / スクロールを切り替える obaket の挙動は lib に無いので、移す前に要否を決める)
4. DualNote を置き換える (名前の変更の外側クリックの確定・+ の popover・末尾の drop 先・削除の確認は consumer に残る。見た目は枠線 → Chrome 風)

## 設計の反証レビュー (2026-10-31、Opus。read-only) と、受けて直した API

指摘 14 件のうち、採ったもの (実装に入れた):
- タブの外枠の accessibility (ボタン・選択の状態・「Close Tab」の操作) は lib が持ち、identifier を consumer が渡す口 `accessibilityIdentifier` を足した (obaket の E2E が `tab-bar.tab.<uuid>` で探す)
- + の右に consumer の view を置く口 `trailingAccessory` (DualNote の読み込み中の表示。popover の起点にも使える) と、+ の置き方 `addButtonPlacement` (`.pinnedWhenOverflowing` は obaket の「溢れたら + をスクロールの外に出す」)
- × をタブごとに出し分ける `canClose(item, state)` (DualNote の消せないタブ・vlc の名前の入力中)
- 閉じたときの動き `closeAnimation: .collapse | .none` と、タブが帯から消えた知らせ `onTabRemoved(id)` (consumer がタブごとの値を捨てる時点。初版の `onCollapseFinished` から改名。下の「vlc の置き換えのレビュー」)
- タブ全体に重ねる `tabOverlay` と、× を避ける幅 `StandardTabStripConfiguration.closeButtonReservedWidth` (vlc のダブルクリックで名前を変える範囲が余白まで届く)
- 送り直しは表示の幅の変化と、縮めきった後 (選んでいたタブを閉じたとき)
- ドラッグの型は文字 (`NSItemProvider(object: NSString)`) にして、consumer の Info.plist に型を宣言させない。受けるのは lib がドラッグを始めたものだけ (`validateDrop` が lib の dragging の状態を見る)
- 取り消したドラッグの直後のクリックも選択に使う (vlc は 1 回捨てていた)
- タブの幅・高さ・help の文言・縮める animation は `StandardTabStripConfiguration` で変えられる。callback は `@MainActor`。任意の口は `AnyView` を返す closure で受け、generic を増やさない

ユーザーの決定 (2026-10-31): 見た目は Chrome 風 1 つに揃える (obaket・DualNote の見た目は変わる)。

採らなかったもの:
- id を KeyPath で受ける init: Identifiable にした値の型を consumer が作る方が、label に渡す値 (縮める間の写し) の扱いと揃う
- `.disabled` の外がけで hover・drop が止まるかの確認: consumer ごとに確かめる (DualNote の移行のときに見る)

## 実装 (2026-10-31)

`Sources/StandardAppComponents/Tabs/`: `StandardTabStrip` (並べ方・入力の受け方)、`StandardTabStripModel` (hover・ドラッグ・幅・縮めている間の並びと値。
縮めきった後始末が古い view の値を見ないよう class に置いた)、`StandardTabChrome` (1 枚の見た目)、`StandardTabDropDelegate`、`StandardTabClosing` (純粋な判断。テスト 10 本)、
`StandardTabStripTypes` (`StandardTabState` / `StandardTabStripConfiguration` / `StandardTabShape`)。文言「Close Tab」「New Tab」を catalog と requiredKeys に足した。

移行: vlc は同じ日に置き換える。obaket と DualNote は別の作業 (それぞれの repo) で置き換える。


## vlc の置き換えのレビュー (2026-10-31)

vlc を置き換えた差分を、変更前の実装と並べて反証させた (read-only の Opus 1 体)。lib 側で直したもの:

- **選んだタブを送るのは隠れているときだけにした**。初版は選ぶたびに中央へ寄せていたので、見えている端のタブを押しても帯が 0.2 秒動き、
  ダブルクリックの 2 回目が隣のタブに当たって別のタブの名前の変更が始まりえた (vlc の変更前は anchor 無しで、見えていれば動かなかった)。
  タブごとにスクロールの見えている所に対する左右の端を覚え (`StandardTabStripModel.needsScroll`)、全部見えていれば送らない。
  中央へ寄せるのは隠れている・切れているときだけ (obaket の実測「anchor 無しだと端のタブが切れて残る」はこちらで残す)
- **`onCollapseFinished` を `onTabRemoved` に改名し、縮めずに外れたタブ (置き換え・総入れ替え・縮めない設定) もすぐ知らせる**。
  初版は縮めたタブしか知らせず、consumer がタブごとに持つ値 (vlc の題名の写し) が [a] → [b] の置き換えで残り続けた
- 消した vlc のテストのうち lib に無かった境界 (ちょうど中央は後ろ・幅が負なら前・縮めるタブが無ければ前の並びを見ない) を足した
- 行き先の無かった教訓をコメントに移した (帯の下端に寄せて切る理由・閉じたと見分ける前提 = 一覧を 1 回で書き換える)

採らなかったもの (consumer ごとに見る): × と + の色 (`Color.secondary`) を consumer の色にできるか、名前の入力中のタブにも × の枠が残って入力欄が狭いこと、
入力中のタブにも「Close Tab」の読み上げの操作が付くこと。
