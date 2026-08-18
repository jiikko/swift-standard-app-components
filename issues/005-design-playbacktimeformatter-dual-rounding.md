# 005 design: PlaybackTimeFormatter に丸め方向の違う 2 入口が同居している

- 起票: 2026-08-18
- 種別: design
- 状態: open
- 発見経路: vlc/obaket の時刻整形統合 (2026-08-18) の敵対的レビュー

## 問題

`PlaybackTimeFormatter` は 2 アプリの既存仕様を挙動不変で合流させた結果、
同一型に丸め方向の異なる入口が同居している:

| 入口 | 丸め | 由来 |
|---|---|---|
| `format(milliseconds:)` | 切り捨て (`ms / 1_000`) | vlc の旧 `PlaybackTimeFormatter` |
| `playbackTime(_:totalDuration:)` / `remainingPlaybackTime` | 四捨五入 (`.rounded()`) | obaket の旧 `ObaketFormatters` |

同じ 1,900ms が入口次第で "0:01" / "00:02" になる。現状は各アプリ内で入口が
一貫しているため実害は未発生で、doc の注意書き (「入口を混ぜないこと」) と
テスト (`testMillisecondsTruncatesTowardZero` / `testPlaybackTimeRoundsSeconds`)
で現仕様を pin してあるだけ。設計としては解けていない。

## 対応方針の候補

- 丸め方針を `Style` に昇格して既定を統一する (どちらかのアプリの表示が
  1 秒単位で変わるため、変更側アプリの表示仕様変更として扱う)
- または `format(milliseconds:)` を deprecate して `playbackTime` 系に一本化する

## trigger (このときに着手する)

- どちらかのアプリが時刻表示の丸め仕様を変えたくなったとき
- 3 つ目の consumer が時刻整形を使い始めるとき (仕様選択を迫られる前に統一する)

## 関連

- `Sources/StandardAppComponents/Video/PlaybackTimeFormatter.swift` (doc に対比を明記済み)
- vlc issue 402 (callsite の Int 変換が lib sanitize を迂回する問題。同じ統合の残課題)
