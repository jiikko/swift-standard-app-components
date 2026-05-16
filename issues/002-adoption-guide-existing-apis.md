# 既存 API (Toast / SettingsWindow / ShortcutSettingsTab) の採用ガイドを整備する

umbrella audit 由来 (元: `my-products/issues/013-refactor-ui-components-extraction.md` のうち「A. lib 既存 API への移行」セクション = #1 Toast / #2 Settings シーン / #3 ショートカット設定タブ)

---

## 背景

umbrella 側 audit で、`Toast` / `SettingsWindow` / `ShortcutSettingsTab` を **lib に同等 API が既にあるにも関わらず各 app が独自再実装している** ことが判明した。具体的な重複箇所は以下:

### Toast (`Toast` / `ToastManaging` / `ToastManager` / `ToastView` / `ToastContainerView` / `.standardToastContainer(_:)` が既に提供されているのに再実装)

- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Services/ToastManager.swift` (独自 `@Observable class ToastManager`、`showInfo/showSuccess/showWarning/showError`、duration 既定値、`pauseDismiss`/`resumeDismiss` の hover 制御まで自前実装)
- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Services/ToastNotifier.swift`
- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Views/ToastView.swift`
- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Models/ToastMessage.swift` / `ToastMessages.swift`
- `apps/DualNoteApp/Shared/Sources/DualNoteShared/Views/ToastView.swift` (success/warning 2 種 capsule + `ToastStyle` enum)
- `apps/DualNoteApp/Shared/Sources/DualNoteShared/ViewModels/NotificationPresenter.swift` / `AppState.swift` / `MemoViewModel+CRUD.swift` の `showToast(...)`

### Settings シーン (`SettingsWindow` + `.standardSettingsBehaviors()` が既に提供されているのに再実装)

- `apps/dotfiles-gui/Sources/Features/Settings/SettingsView.swift` (raw `TabView` + 自前 `DockIconController` + `.background(SettingsWindowEscapeHandler())`)
- `apps/dotfiles-gui/Sources/Features/Settings/SettingsWindowEscapeHandler.swift` (`NSEvent.addLocalMonitorForEvents(matching: .keyDown)` で `keyCode == 53` を取り `window.performClose(nil)`)
- `apps/DualNoteApp/macOS/Sources/Views/SettingsView.swift` (raw `TabView` + `.background(SettingsWindowEscHandler())`)
- `apps/DualNoteApp/macOS/Sources/Views/SettingsWindowEscHandler.swift` (上と同形)

### ShortcutSettingsTab (`ShortcutSettingsTab` / `StandardShortcutGroup` / `StandardShortcutItem` が既に提供されているのに再実装)

- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Views/Settings/ShortcutsSettingsTab.swift` (`ShortcutContextSection` をローカル `private struct` で実装。lib の `ShortcutSettingsTab` 自体がこの VLC 実装を generalize したものなのに、移行が完了していない)
- `apps/vlc-multi-video-player/VLCMultiVideoPlayer/Views/Settings/ShortcutRowView.swift` / `ShortcutRowSkeleton.swift` / `KeyboardShortcutChip.swift`

## lib 側のスコープ

**追加実装は不要。** 既に API は揃っており、不足は consumer 側の移行が進んでいないこと。lib 側でやることは「採用しやすくする」ためのドキュメント整備のみ:

1. **採用ガイド (`docs/adoption.md` または各 `docs/*.md` への追記)** — 各 app が独自実装から lib API に移行する時の典型 migration 手順を書く
   - Toast: `pauseDismiss/resumeDismiss` 等の hover 制御は lib `ToastView` 側で `onHover` を fire するので置換可能、`ToastStyle.success/.warning` → `Toast.Style.success/.warning` の 1:1 対応表
   - SettingsWindow: ESC 監視 NSViewRepresentable は **削除** (`.standardSettingsBehaviors()` が同じ責務)、`DockIconController` のような consumer 固有挙動は残す
   - ShortcutSettingsTab: `groupedBindings` を `StandardShortcutGroup` 配列に詰め直すだけで View 側が消える
2. **API surface の examples** — `Examples/` ディレクトリ (既存) に「最小構成で動く Toast / SettingsWindow / ShortcutSettingsTab consumer 例」を 1 ファイルずつ
3. **`README.md` / `docs/*.md` から既存独自実装の判別フロー** — 「自分の app が以下に該当したら lib 化対象」のチェックリスト

## 完了条件

- `docs/adoption.md` (または同等のガイド) が追加され、上記 3 API の移行手順が書かれている
- 既存 `Examples/` のサンプルが各 API の最小ユースケースをカバーしている
- README から adoption guide への導線がある

## やらないこと

- **lib に新規 API を追加しない**。本 issue のスコープは「既に提供している API を採用してもらう」こと
- **各 consumer app のコードに手を入れない**。移行作業自体は umbrella 側の別 issue (= umbrella `013` の各 app refactor) で扱う
- API surface の breaking change を入れない

## 関連 (背景情報)

- umbrella audit issue: `my-products/issues/013-refactor-ui-components-extraction.md` (#1, #2, #3 セクション)
- umbrella rule: `my-products/.claude/rules/standard-app-components.md` — 「Settings / ショートカット / Toast は StandardAppComponents を使うこと」
- lib 既存 API 境界: `docs/api-boundaries.md` の「Settings Window」「Toast」「ショートカット設定タブ」セクション
- lib 既存ドキュメント: `docs/settings.md` / `docs/toast.md`
