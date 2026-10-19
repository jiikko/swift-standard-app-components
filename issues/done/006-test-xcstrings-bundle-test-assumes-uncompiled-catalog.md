# 006 test: testLocalizableXCStringsBundlesAllRequiredKeysWithJaTranslation が、変換前の .xcstrings がバンドルにある前提で落ちる

- 起票: 2026-10-20
- 種別: test
- 状態: done (2026-10-20)
- 発見経路: screen-share-app issue 853 の作業中に `swift test` を全部回したら落ちた。変更前の HEAD (6b7c7af) でも同じく落ちることを、使い捨ての worktree で確かめた

## 問題

`Tests/StandardAppComponentsTests/StandardAppComponentsTests.swift` の `testLocalizableXCStringsBundlesAllRequiredKeysWithJaTranslation` が、
`Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings")` が nil で `XCTUnwrap` に落ちる。

- 2026-10-20 に `swift test` (Apple Swift version 6.4、swiftlang-6.4.0.34.1) で作ったバンドル (`.build/out/Products/Debug/StandardAppComponents_StandardAppComponents.bundle`) には、
  `Contents/Resources/ja.lproj/Localizable.strings` と `en.lproj/Localizable.strings` があり、`Localizable.xcstrings` は無い。
  今の toolchain は、SwiftPM の CLI のビルドでも `.xcstrings` を `.strings` に変換して入れている
- テストのコメントは「xcstrings が bundle に同梱され」を前提にしている (2026-05-03 の「refactor(localization): migrate to .xcstrings (String Catalog)」のときの挙動と思われる。当時の toolchain の挙動は未確認)

## 本体は壊れていない

- `StandardAppComponentsLocalization.missingKeys(in:)` (`Sources/StandardAppComponents/Localization.swift`) は 2 つの形に対応している
  - バンドルに `.xcstrings` があれば JSON を読む (`collectMissingFromCatalog`)
  - 無ければ変換後の `.strings` を言語ごとに読む (`collectMissingFromCompiledStrings`)
- 同じファイルの `testAllRequiredLocalizationKeysAreProvided` (`validateRequiredKeys()` を呼ぶ) は通っている
- `LocalizationMissingKeyTests` は、存在しないキーを混ぜると検出されることを見ていて、今の toolchain でも 2 つ目の経路で効いている

## 残っていた隙

2 つ目の経路は `Bundle.module.localizations` にある言語だけを見る。`ja` の表がまるごとバンドルに入らなければ、`ja` は検査されないまま緑になる。
落ちているテストは本来これ (`en` と `ja` の両方があること) を見ていた。

## 対応方針

テストを、変換の有無に左右されない形に直す: `Bundle.module.localizations` に `en` と `ja` があることを確かめたうえで、
`missingKeys(in: requiredKeys)` が空であることを見る。`.xcstrings` のまま入る toolchain でも、変換される toolchain でも同じ意味になる。

## 反証レビュー

通していない (test の小さな issue で、事実はバンドルの中身と HEAD での失敗を実際に見て確かめた)。

## 進捗

- 2026-10-20 起票
- 2026-10-20 直した: 落ちていたテストを `testBundleHasEnAndJaAndEveryRequiredKeyInBoth` に書き換えた (`Bundle.module.localizations` に en と ja があること + `missingKeys(in: requiredKeys)` が空)。`swift test` 137 件が通る
- 変異: `.xcstrings` から ja の訳を全部抜くと、新しいテストが赤
  - 全部のテストを回すと、`testAllRequiredLocalizationKeysAreProvided` が `fatalError` でプロセスごと先に止まる。そのため、新しいテストだけを回して確かめた
  - 分かったこと: ja の訳を全部抜いても、今の toolchain は `ja.lproj` を作り、全部のキーが「ja に無い」と報告される。「ja の表がまるごと無い」形はこの変異では作れなかった。言語の一覧の assert は、その形 (resource の処理が ja を落とす) への備えとして残す
