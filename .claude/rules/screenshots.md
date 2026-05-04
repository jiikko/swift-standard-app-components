# README 用スクリーンショットの再生成ルール

## ルール

- **README に載せるスクショを撮り直すときは `bin/generate-screenshots` を使う**こと
- 手動でスクショを撮り直して `docs/images/*.png` に放り込まない
- スクショの種類を増やす / 構図を変える時は `Tools/ScreenshotGenerator/main.swift` を編集して `bin/generate-screenshots` で再生成する。手撮りで `docs/images/` に追加しない

```bash
# README 用 PNG を再生成
bin/generate-screenshots

# = 内部で `swift run ScreenshotGenerator`
```

実行すると `docs/images/*.png` (Settings の Light/Dark + Toast 5 種) が上書き再生成される。

## なぜ手撮り禁止か

| 観点 | 手撮り | `bin/generate-screenshots` |
|---|---|---|
| 再現性 | 撮影時のディスプレイ解像度・ウィンドウサイズ・OS バージョンに依存 | コードで固定 (frame size / scale=2 / colorScheme) |
| 言語切替 | 日英別々に撮り直しが必要 | コードで `.preferredColorScheme(.light/.dark)` を切り替えるだけ |
| Light/Dark | macOS の外観切替で OS 全体を切り替えて 2 回撮影が必要 | コードで両方を 1 回の実行で出す |
| chrome | 手撮りすると NSWindow chrome が混じる (lib の意図と違う構図) | `ScreenshotGenerator` 側で View 単位に切り出して撮るので chrome は混じらない |
| diff レビュー | PNG が「なぜ変わったか」が説明できない (撮影者の手元状態に依存) | 「コードを変えた → 撮り直した」の因果が `ScreenshotGenerator` の git diff で追える |
| CI 検証 | 困難 | `bin/generate-screenshots` を CI で走らせて diff を検査可能 (将来) |

## UI 変更時のフロー

1. lib の SwiftUI コード (`Sources/StandardAppComponents/...`) を変更
2. **同コミットで** `bin/generate-screenshots` を実行
3. `git diff docs/images/` で変化を確認
4. PNG 差分 + コードを 1 コミットに含める

スクショだけが古い、コードだけが新しい、という乖離を発生させない。

## 新しいスクショを増やす

新規 component を README に載せたい場合:

1. `Tools/ScreenshotGenerator/main.swift` の `main()` に `write(view:..., name:..., in: outputDir)` (or `writeViaHosting(...)`) を追加
2. View builder メソッドを追加 (`toastSample` / `settingsGeneralContent` の例を参考に)
3. `bin/generate-screenshots` で生成
4. README に `![...](docs/images/<name>.png)` を追記

## 撮影方式の使い分け (`Tools/ScreenshotGenerator/main.swift` 内)

- **`write(view:name:in:)`** → `ImageRenderer` で直接描画。pure SwiftUI View (Toast 系) はこっち
- **`writeViaHosting(view:size:name:in:)`** → NSHostingController + offscreen NSWindow + `bitmapImageRepForCachingDisplay`。`Form.formStyle(.grouped)` / `TabView` 等の AppKit 統合が深い View はこっち (ImageRenderer 単独では blank になる)

新しい component を撮る時は、まず `ImageRenderer` で試して、blank / "unavailable" placeholder (黄色背景に赤の禁止マーク) になったら `writeViaHosting` に切り替える。

## やること / やらないこと

- ✓ UI 変更時は同コミットで `bin/generate-screenshots` を回す
- ✓ スクショの種類を増やす時は `ScreenshotGenerator` のコードを足してから生成
- ✗ Cmd+Shift+4 等の手動キャプチャを `docs/images/` に置く
- ✗ macOS の外観切替を弄って Light/Dark を別々に手撮りする
- ✗ `docs/images/*.png` だけをコミットして `Tools/ScreenshotGenerator/main.swift` 側を更新しない (差分の出処不明な PNG を残さない)

## 関連

- 実装: [`Tools/ScreenshotGenerator/main.swift`](../../Tools/ScreenshotGenerator/main.swift)
- ラッパー: [`bin/generate-screenshots`](../../bin/generate-screenshots)
- 出力先: [`docs/images/`](../../docs/images/)
- README 埋め込み箇所: [`README.md`](../../README.md) の「スクリーンショット」セクション
