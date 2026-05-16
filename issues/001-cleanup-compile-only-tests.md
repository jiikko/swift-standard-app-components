# コンパイル確認だけの低価値テストを整理する

umbrella audit 由来 (元: `my-products/issues/020-cleanup-meaningless-tests.md` の「2. 「コンパイル & body 評価できる」だけの SwiftUI テスト群」)

---

## 背景

umbrella 側の audit で、`StandardAppComponentsTests` 配下に「コンパイルが通った時点で既に確認できている内容しかテストしていない」テスト群が指摘された。本体が `_ = view.body` や `_ = applyAppAppearance(...)` で式が成立することだけを確認しており、`XCTAssert*` も実質的な振る舞い検証も無い。

これらは:

- ビルドが通れば常に pass する (= `swift build` で同等の保証が得られる)
- body 評価でクラッシュする SwiftUI コードはビルド成功時点では検出できないので、ランタイムで body を 1 回評価しても shield にならない
- 「テストがある」という誤った安心感を生み、本当に検証すべき振る舞い (mapping / 状態遷移 / contract) の不足を見えにくくする

## 対象ファイル / 該当テスト

すべて `Tests/StandardAppComponentsTests/` 配下:

| ファイル | テスト | 判定 |
|---|---|---|
| `MenuBarVisibilityToggleTests.swift` (l.7-19) | `testInitializerCompilesWithDefaultLabel` / `testInitializerCompilesWithCustomLabel` | **完全削除** |
| `LaunchAtLoginTests.swift` (l.12 / 17) | コンパイル確認系 2 件 | **完全削除** |
| `AppAppearanceTests.swift` (l.7-13) | `testApplyAppAppearanceCompilesWithAllSchemes` | **完全削除** (mapping テスト l.23-38 が実用カバレッジを担保しているのでこれだけ落として可) |
| `GeneralTabContractTests.swift` (l.24-67) | `testSettingsWindowAcceptsContract` / `testSettingsWindowAcceptsPerTabHeights` / `testSettingsWindowAcceptsWidth` | **改善 (統合)** — `resolveTargetHeight` 系テスト (l.87-) が同じ presentation logic を網羅しているので、`SettingsWindow.init` の API バリエーション確認は **1 つに統合** |

## 完了条件

- 上記「完全削除」対象のテストを削除する
- `GeneralTabContractTests` の 3 件は 1 件の `init` バリエーション確認テストに統合する (テスト名で「init API surface が崩れていないことを確認する」意図を明示)
- `swift test` が pass する
- 削除されたテスト名を replace する形で振る舞いベースのテスト (mapping / state transition) を追加できる場合は追加する。追加できない場合は無理に作らない (= 削除のみで OK)

## やらないこと

- テスト全体の運用方針を大きく変えない (= 命名規約・XCTest → Swift Testing 移行などは別 issue)
- カバレッジ目標などは追加しない

## 関連 (背景情報)

- umbrella audit issue: `my-products/issues/020-cleanup-meaningless-tests.md`
- umbrella 側の「ぼやきポイント」: `lib/swift-standard-app-components` のテストが「コンパイルできること」を XCTest 経由で確認するスタイルが多いのは、SPM の build 検証と機能テストの境界が曖昧なため。テスト名を `testInitializerCompiles...` から `testMappingReturnsExpected...` 方向にリネームしていく方針を README / `docs/` に明文化すると、後から触る人が判断に迷わない。本 issue では命名規約までは扱わないが、追加 issue として検討可
- `apps/vlc-multi-video-player/scripts/lint-low-value-tests` に「アサーション無しテスト」検出スクリプトが既にある (本 lib にもポーティング検討の余地あり)
