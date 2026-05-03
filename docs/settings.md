# 設定 (Settings) ウィンドウ

macOS アプリの **「設定 (Settings) ウィンドウ」を中心とした共通化**。タブ構成、ESC で閉じる挙動、外観切替、言語切替、`SMAppService` ラッパー、ローカライズ漏れ検証、`Settings × Form.formStyle(.grouped)` の罠対策を 1 箇所に集約する。

## 設計の軸: 必須 / オプションの分離

ライブラリは **「Settings ウィンドウの枠 (mandatory)」** と **「General タブに差し込める部品 (optional)」** を分けて提供する。consumer は枠を 1 つだけ採用し、部品はアプリ性質に応じて取捨選択する。

```
Settings { ... }                    ← consumer の Scene
   └─ SettingsWindow                ← [必須] 枠 (lib がタブ・ESC 挙動・高さアニメを担当)
        ├─ General タブ (固定)
        │    ├─ appearance slot     ← [必須スロット] consumer が View を 1 つ渡す
        │    ├─ language slot       ← [必須スロット] 同上
        │    └─ appSections slot    ← [必須スロット] 任意 Section 群を流し込む
        │
        ├─ アプリ独自タブ群           ← [optional] consumer が `appTabs` で渡す
        └─ ESC で閉じる挙動           ← [自動付与] standardSettingsBehaviors
```

各スロットを埋めるための **再利用可能な部品** (= optional) を lib が提供する。下表の右列は機能名称と対応する API を併記する。

| スロット | 推奨 / 任意の埋め方 | 機能名称 (API) |
|---|---|---|
| `appearance` | 推奨: 値型 + modifier の組み合わせ | 外観モード値 (`StandardAppearanceMode`) + アプリ全体外観切替 (`View.applyAppAppearance(_:)`) |
| `language` | 推奨: lib 提供のセクション View をそのまま | 表示言語切替 (`LanguageSection` + `LanguageOption`) |
| `appSections` | アプリ独自 Section 群を任意に。下記 General タブ向け汎用トグルを混ぜて良い | ログイン時起動 (`LaunchAtLoginToggle` / `LaunchAtLoginService`) / メニューバー表示切替 (`MenuBarVisibilityToggle`) |

`appearance` / `language` slot は consumer が自前 View で埋めても構わない (lib 提供の `LanguageSection` 等を使わない自由がある)。**lib 部品の採用は強制ではない**。

---

## 共通化の中身 (mandatory: 必ず lib が担う)

### Settings ウィンドウ枠 (`SettingsWindow`)

`Settings { SettingsWindow(general: ..., appTabs: { ... }) }` 1 行から組み立てる Settings シーン本体。

- General タブを必ず先頭に配置 (Cmd+1 で focus)
- タブ識別子は `SettingsWindowConstants.generalTabId` (`"general"`) で公開。`appTabs` 側の追加タブにも `.tag("...")` を付けて selection binding を一致させる
- `width` / `heights` (per-tab) / `defaultHeight` を受け取り、タブ切替で **ウィンドウ高さがアニメーション付きで遷移**
- ESC キーでウィンドウを閉じる挙動を内部で自動付与 (`View.standardSettingsBehaviors()` を `SettingsWindow` の body 内で呼んでいる)

### General タブの 3 スロット契約 (`GeneralTabContract`)

`SettingsWindow(general:)` が必ず受け取る契約。各スロットに View を渡すだけで General タブが組み上がる。

| スロット | 役割 | レンダリング |
|---|---|---|
| `appearance: () -> View` | 外観セクションの本体 | `Section { ... } header: { Text("Appearance", bundle: .module) }` で囲まれて出力 |
| `language: () -> View` | 言語セクションの本体 | `Section { ... } header: { Text("Language", bundle: .module) }` で囲まれて出力 |
| `appSections: () -> View` | アプリ独自セクション群 | そのまま流し込まれる (consumer 側で `Section { ... } header: { ... }` を含める) |

セクションヘッダー文言 (`Appearance` / `Language` / `General`) は lib 側 xcstrings で en / ja 翻訳済み。consumer 側に翻訳追加は不要。

### Settings シーン専用挙動 (`View.standardSettingsBehaviors()`)

ESC で owning window を閉じる。隠し `Button` + `.keyboardShortcut(.cancelAction)` ベースで実装しており、`TextField` 等にフォーカスがあっても通常 ESC が届く (`.onExitCommand` は responder chain の事情で取りこぼすことがあるため避けている)。`SettingsWindow` 内で自動適用されているため通常 consumer が直接呼ぶ必要はない。

`.cancelAction` は SwiftUI / OS 世代に依存する仕組みで「絶対に取りこぼさない保証」ではない。実機で TextField focus 中の ESC 不発が再現した場合は `NSWindow` 単位の `keyDown` 捕捉に切り替える方針 (現状その問題は観測されていないため、`.cancelAction` ベースに留めて複雑度を抑えている)。

### 起動時ローカライズ検証 (`StandardAppComponentsLocalization.validateRequiredKeys()`)

アプリ起動時に 1 度呼ぶと、lib 側 View が必要とする全キー (`General` / `Appearance` / `Language` / `Open at Login` / `Show in Menu Bar` / `LanguageSection` 関連 5 件) が **全 supported locale で翻訳済み** かを検証。1 件でも欠けていれば `fatalError` で停止 (Debug / Release 共通)。consumer 側に翻訳追加は不要、漏れは lib のリリース前に CI で検出する想定。

---

## 共通化の中身 (optional: General タブのスロットに差し込む部品)

各部品は **使う / 使わない を consumer 側で選択** する。下記 "採用すべきアプリ種別" を判断材料にする。

### 外観切替 (`StandardAppearanceMode` + `View.applyAppAppearance(_:)`)

外観モード (system / light / dark) の **値型と挙動** をセットで提供する。永続化は consumer の関心。

| API | 役割 |
|---|---|
| `StandardAppearanceMode` | `system / light / dark` の 3 case enum。`String` raw, `Codable`, `CaseIterable`, `Sendable`。`var preferredColorScheme: ColorScheme?` 変換を持つ。`@AppStorage("...")` の永続化キーや UserDefaults は consumer 側に置く (lib 側で永続化レイヤーには触らない) |
| `View.applyAppAppearance(_ scheme: ColorScheme?)` | アプリ全体の外観を切り替える ViewModifier。`.preferredColorScheme` だけでは追従しない `Settings × Form.formStyle(.grouped)` の罠を吸収するため、`NSApp.appearance` と全 `NSWindow.appearance` を同時更新する |

**採用すべきアプリ種別**: 外観モードをユーザーに選ばせる要件があるアプリ。ほとんどの macOS アプリは OS 追従固定で問題ない (= 採用しない)。明示的な Light/Dark 切替が UX 要件にあるときだけ。

`appearance` slot に流し込む書き方の例:

```swift
@AppStorage("appearanceMode") private var raw: String = StandardAppearanceMode.system.rawValue

// slot 実装
Picker("テーマ", selection: appearanceBinding) {
    Text("システム").tag(StandardAppearanceMode.system)
    Text("ライト").tag(StandardAppearanceMode.light)
    Text("ダーク").tag(StandardAppearanceMode.dark)
}
.pickerStyle(.segmented)

// Scene root で外観適用
.applyAppAppearance(currentMode.preferredColorScheme)
```

### 表示言語切替 (`LanguageSection` + `LanguageOption`)

言語ピッカー View そのもの (= UI を含むセクション全体)。`AppleLanguages` UserDefaults 操作と再起動 alert まで lib 側で完結する。

| API | 役割 |
|---|---|
| `LanguageSection(supportedLanguages:onRestart:)` | `language` slot に流し込む View。`Picker` 変更で **即時 apply** → alert を出す UX (Apple System Settings の言語変更フローに揃える)。`onRestart` の有無で alert ボタンの文言と挙動が変わる: **`onRestart = nil` (デフォルト)** だと「Later / **Quit Now**」が出て Quit Now で `NSApp.terminate(nil)` を呼ぶ (= 終了するだけで再起動はしない)。**`onRestart` 渡し** だと「Later / **Restart Now**」が出て Restart Now で `onRestart()` を呼ぶ。consumer が Sparkle relaunch / launch helper 等で本当に再起動できる時だけ closure を渡し、relaunch 経路がなければ default のまま使うこと |
| `LanguageOption(code:displayName:)` | 選択肢の値型。`code` は `AppleLanguages` UserDefaults に書き込む ISO 639-1 (例: `"en"` / `"ja"`)、`displayName` は Picker 表示文字列 (各言語の native 表記推奨) |

**採用すべきアプリ種別**: アプリ内ローカライズを複数言語提供するアプリ。

`language` slot に流し込む例:

```swift
LanguageSection(
    supportedLanguages: [
        .init(code: "en", displayName: "English"),
        .init(code: "ja", displayName: "日本語")
    ]
)
```

### ログイン時に開く (`LaunchAtLoginToggle` + `LaunchAtLoginService`)

`SMAppService.mainApp` の薄いラッパーを **service と Toggle View の 2 層** で提供する。`appSections` 内の `Section` に Toggle を流し込む想定。

| API | 役割 |
|---|---|
| `LaunchAtLoginService` | `SMAppService.mainApp` の薄いラッパー。`isEnabled` 読み取りと `setEnabled(_:)` を提供。Bundle ID は `Bundle.main` から自動解決。**`@MainActor` 制約は付けていない** ため、`applicationDidFinishLaunching` 等の MainActor 上だが actor isolation を強制したくないコンテキストや、Background Task からも呼べる |
| `LaunchAtLoginToggle(label:onError:)` | service と双方向同期する labeled Toggle。System Settings 側で外部変更されても `scenePhase == .active` で再読込する。`@AppStorage` 等にキャッシュせず毎回 system 状態を読むことで真実の所在を `SMAppService` に集約。`onError` callback で system 操作失敗時を consumer の Toast / alert / log に流せる (lib は print/OSLog しない) |

**採用すべきアプリ種別**: メニューバー常駐ユーティリティ (clipboard manager, window manager 等)、同期クライアント (Dropbox 系)。
**採用しないアプリ種別**: ドキュメント編集アプリ (Pages / Photoshop 系) / メディアプレイヤー ── ユーザーが「使いたい時だけ開く」UX が前提のアプリは login 時自動起動を入れない (Apple 自身も Pages / Keynote / Final Cut に付けていない)。

### メニューバーに表示 (`MenuBarVisibilityToggle`)

「メニューバーに表示」切替 Toggle の UI のみ。**NSStatusItem の生成 / 破棄、アイコン、メニュー項目、クリックハンドラはすべて consumer の関心** で lib は持たない。

| API | 役割 |
|---|---|
| `MenuBarVisibilityToggle(isOn:label:)` | `Binding<Bool>` を受けるだけの labeled Toggle。consumer は binding の変化を `.onChange(of:)` 等で観測して NSStatusItem を出し分ける |

**lib に存在する付加価値**: localized label 「メニューバーに表示 / Show in Menu Bar」を複数アプリで共有する点だけ。同種の薄い Toggle を将来追加する場合も localized label 共有以外の責務を持たせない (持たせるならアプリ固有 sub に降ろす)。

**採用すべきアプリ種別**: メインウィンドウ + オプショナルなメニューバー常駐の **両方** を持つアプリ。常時メニューバー only のアプリ (= 常時表示固定で toggle 不要) や、メニューバー機能を持たないアプリでは採用しない。

---

## ウィンドウ全般向け modifier (Settings に限らず)

メインウィンドウや独自ウィンドウにも適用できる macOS ウィンドウ挙動。Settings 限定ではない。

| 機能名称 (API) | 役割 |
|---|---|
| ウィンドウ背景 vibrancy (`WindowBackgroundView`) | `NSVisualEffectView` を SwiftUI から使うラッパー。`.background(WindowBackgroundView())` で macOS 標準アプリと同じ vibrancy material を当てる。フラットな `Color` 塗りでは Settings 等と視覚的に揃わない問題を解消 |
| ウィンドウ位置・サイズ永続化 (`View.autoSaveWindowFrame(name:)`) | hosting している `NSWindow` に `setFrameAutosaveName` を当て、ウィンドウサイズと位置を `UserDefaults` に永続化する |

---

## 最小サンプル

[`Examples/MinimalApp.swift`](../Examples/MinimalApp.swift) を参照。
