# StandardAppComponents

Personal SPM. macOS アプリ向けの再利用可能な標準コンポーネント / モディファイア集。

API は **consumer がアプリのどこに置くか** を軸に分類している (Swift の型分類ではない)。

## Settings

`Settings { ... }` シーン用。Settings ウィンドウを組み立てるための core 型と、General タブに流し込める opt-in な汎用トグル群。

### Core

| API | 役割 |
|-----|------|
| `SettingsWindow` | macOS Settings シーン本体。General タブ + 任意の app タブを `TabView` で構成。`width` / `heights` (per-tab) / `defaultHeight` を受け取り、タブ切り替え時に高さがアニメーション付きで遷移する。`SettingsWindow.generalTabId` で General タブの tag 定数を公開。 |
| `GeneralTabContract` | General タブの「Appearance / Language / アプリ独自セクション」スロット契約。consumer は各 slot に View を渡すだけで General タブが組み上がる。 |
| `View.standardSettingsBehaviors()` | Settings シーン専用の挙動。現状は ESC で owning window を閉じる。隠し `Button` + `.keyboardShortcut(.cancelAction)` ベースで、TextField にフォーカスがあっても確実に発火する (`.onExitCommand` の取りこぼしを回避)。`attachedSheet` 表示中は sheet 側を優先。`SettingsWindow` は内部で自動適用する。 |

### General タブ向け Toggle (opt-in)

`GeneralTabContract.appSections` に Section ごと差し込んで使う、複数アプリで頻出する設定項目のトグル群。**必要なアプリだけが採用する** (ドキュメント編集系・プレイヤー系では通常不要)。

| API | 役割 |
|-----|------|
| `LaunchAtLoginToggle` | 「ログイン時に開く」を切り替える labeled Toggle。`LaunchAtLoginService` と双方向同期し、System Settings 側で外部変更されても `scenePhase == .active` 時に再読込する。`@AppStorage` 等にキャッシュせず、毎回 system 状態を読むことで真実の所在を `SMAppService` に集約する。 |
| `LaunchAtLoginService` | 上記 Toggle の実体。`SMAppService.mainApp` の薄いラッパーで、`isEnabled` 取得と `setEnabled(_:)` を提供。Bundle ID は `Bundle.main` から自動解決。**自前 UI で制御したい consumer はこちらを直接使う**。 |
| `MenuBarVisibilityToggle` | 「メニューバーに表示」を切り替える labeled Toggle。`Binding<Bool>` を受け取るのみで、**NSStatusItem の生成 / 破棄やアイコン / メニュー実装は consumer 側に閉じる** (各アプリ固有のため)。consumer は binding の変化を観測して NSStatusItem を生成 / 破棄する。 |

## Window

任意のウィンドウ / アプリ全体に当てる modifier 群。Settings 限定ではなく、メインウィンドウや独自ウィンドウにも適用できる。

| API | 役割 |
|-----|------|
| `View.applyAppAppearance(_ scheme: ColorScheme?)` | アプリ全体の外観 (light / dark / system) を切り替える。`.preferredColorScheme` だけでは追従しない `Settings` × `Form.formStyle(.grouped)` の罠を吸収するため、`NSApp.appearance` と全 `NSWindow.appearance` も同時更新する。 |
| `View.autoSaveWindowFrame(name: String)` | hosting している `NSWindow` に `setFrameAutosaveName` を当て、ウィンドウサイズと位置を `UserDefaults` に永続化する。 |
| `WindowBackgroundView` | `NSVisualEffectView` を SwiftUI から使うラッパー。`.background(WindowBackgroundView())` で macOS 標準アプリと同じ vibrancy material を当てられる。フラットな `Color` 塗りでは Settings 等と視覚的に揃わない問題を解消。 |

## Localization

| API | 役割 |
|-----|------|
| `StandardAppComponentsLocalization.requiredKeys` | lib が同梱 View で使う必須ローカライズキーの一覧 (`General` / `Appearance` / `Language` / `Open at Login` / `Show in Menu Bar`)。 |
| `StandardAppComponentsLocalization.validateRequiredKeys()` | `Localizable.xcstrings` を直接 parse して、必須キーが全 supported locale (`en` / `ja` ...) で翻訳済みエントリを持っているか検証。**1 件でも欠けていれば `fatalError` で停止**。consumer はアプリ起動時に呼び出してローカライズ漏れを早期検出する。 |

ローカライズ辞書は `Sources/StandardAppComponents/Resources/Localizable.xcstrings` (String Catalog) で一元管理。consumer 側に翻訳追加は不要 (lib が必要とする文言は lib が責任を持つ)。新しい lib API を追加する時は xcstrings に対応エントリを追加し、`requiredKeys` にキーを追記すること (起動時 validation で漏れが落ちる)。

## Build

```bash
swift build
swift test
```

## 運用ルール

このリポジトリ用の Claude Code 向け運用ルールは [CLAUDE.md](./CLAUDE.md) を参照。
要点: **commit したら必ず origin に push する** (consumer アプリが SPM の `branch: master` で参照しているため)。
