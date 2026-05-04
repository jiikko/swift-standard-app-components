# API 境界

このドキュメントは、公開 API ごとに **StandardAppComponents が提供する範囲** と **consumer アプリが実装する範囲** を明確にするためのもの。

基本方針は次の通り。

| 分類 | lib に置く条件 | consumer に残す条件 |
|---|---|---|
| Contract | UI の欠落や順序違反を型で検知したい。例: `GeneralTabContract` が appearance / language slot を必須化する | 必須項目がアプリごとに変わる |
| Behavior | AppKit / SwiftUI の挙動が全アプリで同じ。例: Settings ウィンドウを ESC で閉じる、window frame を autosave する | アプリ状態、ドキュメント、権限、routing、window ownership に依存する |
| 小さな UI primitive | 共通ラベルを持ち、アプリ lifecycle を知らなくてよい。例: `MenuBarVisibilityToggle` | menu、icon、click handler、status item 生成、文言設計を持つ |
| 値型 | 複数アプリで完全に同形の値。例: `StandardAppearanceMode` | 永続化 migration や業務意味を持つ |

特定アプリの window open、document 管理、error logging、relaunch、menu 構築を知る必要が出た API は、この package ではなく consumer 側に置く。

## Settings Window

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `SettingsWindow<AppTabs>` | SwiftUI `TabView` ベースの Settings ウィンドウ。General タブを先頭に配置。幅 / タブ別高さをサポート。ESC close を内部で適用。General タブに `Cmd+1` を付与 | `Settings { ... }` scene、`GeneralTabContract`、アプリ固有タブ、追加タブの `.tag(...)`、追加タブ用 keyboard shortcut |
| `GeneralTabContract` | General タブの `appearance` / `language` / `appSections` slot。`appearance` と `language` は lib 側で localized `Section` header に包む | 実際の外観 UI、`LanguageSection` を使わない場合の言語 UI、アプリ固有 section |
| `SettingsWindowConstants.generalTabId` / `SettingsWindow.generalTabId` | built-in General タブの安定 tag `"general"` | selection / height map に合わせる追加タブの tag |
| `NotImplementedSlot` | 赤い placeholder と DEBUG の `assertionFailure` | placeholder を一時的に使うかの判断。通常 UI として ship しない |

非ゴール: 全 Settings row、全アプリ固有タブ、preferences model は提供しない。

## Settings 挙動と Window Helper

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `View.standardSettingsBehaviors()` | Settings ウィンドウ専用の ESC close。hosting されている `NSWindow` を閉じる。`SettingsWindow` 内では自動適用済み | `SettingsWindow` を使わず独自 Settings を組む時だけ直接適用する。任意の modal / editor view には使わない |
| `View.autoSaveWindowFrame(name:)` | SwiftUI view が window に attach された後で `NSWindow.frameAutosaveName` を設定する | logical window ごとの安定で一意な autosave name |
| `WindowBackgroundView` | `NSVisualEffectView` の SwiftUI wrapper | どの view に適用するか、material / blending mode の選択 |

制約: `SettingsWindow` は General タブの `Cmd+1` だけを内蔵している。consumer が渡す追加タブ向けの `Cmd+2`, `Cmd+3` などを共通登録する API はまだ無い。現状は追加タブ側で shortcut を付ける。

## 外観

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `StandardAppearanceMode` | `system / light / dark` の enum。raw string、`Codable`、`CaseIterable`、`Sendable`、`preferredColorScheme` を持つ | 永続化 key、migration、`@AppStorage` / settings storage、`appearance` slot に入れる Picker UI |
| `View.applyAppAppearance(_:)` | SwiftUI の `ColorScheme?` に加え、`NSApp.appearance` と既存 `NSWindow.appearance` を更新する | app scene root / Settings root で現在の mode を渡す |

非ゴール: app settings storage は持たない。外観切替をアプリに出すべきかも lib は判断しない。

## 言語

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `LanguageSection` | `language` slot に入れる言語 picker。`AppleLanguages` を読み書きし、System Default を自動追加し、変更後に quit / restart alert を出す | supported languages の一覧。本当に relaunch できる場合だけ `onRestart` closure |
| `LanguageOption` | `code` / `displayName` の値型 | 正しい言語 code と表示名。例: `English`, `日本語` |

`onRestart` を省略した場合、primary action は **Quit Now** で `NSApp.terminate(nil)` を呼ぶ。実際の再起動はしない。consumer が Sparkle relaunch や launch helper などを持つ時だけ `onRestart` を渡す。

非ゴール: consumer アプリの文字列 catalog、文言、リリース時の localization policy は管理しない。

## ログイン時起動

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `LaunchAtLoginService` | `SMAppService.mainApp` の薄い wrapper。`isEnabled` と `setEnabled(_:)`。log / UI は持たない | そのアプリに login item が必要かの判断。直接 service を呼ぶ場合の error handling |
| `LaunchAtLoginToggle` | `SMAppService` と同期する Toggle。scene active 時に再読込し、失敗時は UI を rollback して `onError` へ渡す | app 所有の Settings `Section` に配置すること。`onError` を Toast / Alert / logger へ流すこと |

採用候補は menu bar utility、sync client、background availability が価値になるアプリ。document editor / media player のように「使う時だけ開く」アプリへ無条件に入れない。

## ショートカット設定タブ

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `ShortcutSettingsTab` | VLCMultiVideoPlayer 由来の Settings 用ショートカットタブ UI。context ごとのカード、行レイアウト、shortcut chip、録音中 chip、競合 warning 表示、個別 reset、Reset All 配置 | ショートカット一覧の生成、録音開始 / キャンセル、key event capture、永続化、競合判定、実際の shortcut 登録 |
| `StandardShortcutGroup` | タブ UI に渡す context 表示モデル。`id` / `title` / `subtitle` / `items` | アプリ固有 context 名と説明文 |
| `StandardShortcutItem` | タブ UI に渡す shortcut 行表示モデル。`id` / `title` / `shortcut` / `isEditable` / `isCustomized` | アプリ固有 command ID、表示名、現在の shortcut 文字列、編集可否、カスタマイズ済み判定 |

この API は「ショートカット設定の見た目」を揃えるためのもの。`NSEvent` monitor、global shortcut registration、conflict policy、UserDefaults / SwiftData などの保存形式は consumer 側に残す。

## メニューバー表示

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `MenuBarVisibilityToggle` | `"Show in Menu Bar"` / `"メニューバーに表示"` の localized label を持つ Toggle。`Binding<Bool>` を受けるだけ | 永続化、binding 変更監視、`NSStatusItem` / `MenuBarExtra` の作成破棄、menu 内容、icon、primary click、window routing、lifecycle |

明示的な非ゴール: `MenuBarAgent`、`MenuBarContract`、menu construction、status item ownership、click behavior は提供しない。これらはアプリ固有なので consumer に置く。共通化は `MenuBarVisibilityToggle` のみに限定する。

## Toast

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `Toast` / `Toast.Style` / `ToastAction` / `ToastText` | Toast data model、style palette、action model、localized / verbatim message の明示的な分離 | message content、action behavior、Toast と Alert / Sheet の使い分け |
| `ToastManaging` | DI / test 用 protocol。各 method は `@MainActor`、protocol 全体は consumer DI と相性を保つため actor-agnostic | app 側の DI pattern に合わせた保持 / 受け渡し |
| `ToastManager` | default の `@Observable` queue manager。auto-dismiss、manual dismiss、bounded queue | app-level に 1 instance 作る。global singleton にするかは consumer architecture 側の判断 |
| `ToastView` / `ToastContainerView` / `View.standardToastContainer(_:)` | 右下表示の標準 UI と root overlay modifier | root 近くに 1 回だけ container を付け、manager を明示的に渡す |

重要: この package は Toast 用 `EnvironmentKey` を提供しない。consumer ごとに DI 構造が違うため、`standardToastContainer(_:)` には manager を明示的に渡す。必要なら consumer 側で独自 Environment key を作る。

Toast は軽い完了通知、情報通知、復旧可能なエラー通知に使う。破壊的確認、blocking decision、致命的エラーは Alert / Sheet にする。

## ローカライズ検証

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `StandardAppComponentsLocalization.requiredKeys` | lib UI が必要とする localization key 一覧 | 通常なし |
| `StandardAppComponentsLocalization.validateRequiredKeys()` | package resource bundle 内の必要 key が supported locale で揃っているか起動時に検証。不足時は fail fast | package UI を使う app の起動時に 1 回呼ぶ |
| `StandardAppComponentsLocalization.bundle` / `lookupString(forKey:locale:)` | 主に test / diagnostic 用 accessor | 明確な diagnostic 理由がない限り app UI 構築に使わない |

非ゴール: consumer アプリ自身の string catalog は consumer 側の責務。

## Misc

| API | lib が提供するもの | consumer が実装するもの |
|---|---|---|
| `StandardAppComponents.version` | 単純な package version string | release automation が入るまでは SemVer の真実として扱わない |

## 提供しない API

| 提供しないもの | 理由 |
|---|---|
| `AboutContract` / 独自 About window | macOS 標準 About panel または各アプリ実装で十分。version、copyright、acknowledgements、license 表示はアプリごとの差が大きい |
| `MenuBarAgent` / `MenuBarContract` | icon、menu、click behavior、status item lifecycle、window routing がアプリ固有。共通化は `MenuBarVisibilityToggle` に限定 |
| Sparkle setup helper | update channel、relaunch、署名、feed URL、配布形態がアプリごとに違う |
| Global shortcut registrar | 権限、衝突処理、user customization、lifecycle がアプリごとに違う |
| Notification permission flow | 通知文言、タイミング、permission UX、アプリ目的が product-specific |
| App settings persistence | key、migration、default、互換性ルールは各アプリ責務 |
| Design tokens / common buttons / empty states | 広い UI kit ではない。明確な cross-app value がある薄い macOS primitive のみ追加する |
