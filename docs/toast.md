# アプリ内通知 (Toast)

画面右下に出すソフトな通知 (保存完了 / エラー通知 / 軽量な情報メッセージ) を **キュー管理 + 自動消去 + アクションボタン** 込みで提供する。各アプリで `Task.sleep` ベタ書きの toast を作らず、ここに集約する。

`apps/` 配下のアプリでアプリ内通知 (toast) を使うときは、必ずこの API を採用すること (umbrella リポジトリ側 `.claude/rules/toast.md` で明文化)。

## モデル

| API | 役割 |
|---|---|
| `Toast` | 1 件の toast データ。`id` / `style` / `title` / `message` / `duration` / `action` を保持。同じ `id` で再 `show` すれば既存表示を上書きできる |
| `Toast.Style` | 見た目バリエーション (`success` / `error` / `warning` / `info`)。Material Design 300〜400 系の固定パレット (緑 / 赤 / アンバー / 青) と SF Symbol アイコン (`checkmark.circle.fill` 等) が紐付く。前景色は常に白でコントラスト確保 |
| `ToastAction` | 任意のアクションボタン (例: 「Finder で開く」)。`title` + `@Sendable () -> Void` の `handler`。タップで `handler` が走り、その後 toast は自動 dismiss |
| `ToastText` | `message` 用の sum 型。リテラルは `.localized(LocalizedStringResource)` (catalog 経由)、動的値は `.verbatim(String)` で **明示的に** 分離。catalog バイパスをコンパイル時に潰す目的 (#340 / #344) |

## Manager / プロトコル

| API | 役割 |
|---|---|
| `ToastManaging` | manager の契約 (`@MainActor`)。`currentToast` / `show(_:)` / `showSuccess` / `showError` / `showInfo` / `showWarning` / `showWithAction` / `dismiss()` / `clearAll()`。consumer / View はこのプロトコル越しに依存し、テストではモックを差し込む |
| `ToastManager` | デフォルト実装。キュー / 自動消去タイマー / dismiss を一元管理。アプリにつき 1 インスタンス。`@State` / DI コンテナ / `AppServices` で保持し、シングルトンを避ける |
| 便利メソッド (extension) | `showSuccess(_:message:duration:)` (default 3.0s) / `showError(_:message:)` (default 5.0s, error は長め) / `showInfo` (3.0s) / `showWarning` (4.0s) / `showWithAction` (5.0s)。`message` / `duration` 省略可 |

## View / view modifier

| API | 役割 |
|---|---|
| `ToastView` | 1 件の toast を描画する pure UI。アイコン + タイトル + メッセージ + (任意) アクションボタン + 閉じるボタン |
| `ToastContainer` | `ToastManaging` を観測し、画面右下に `ToastView` を出すコンテナ。フェード / スライドのアニメーションを内蔵 |
| `View.standardToastContainer(_:)` | ルート View に **1 回だけ** 当てる modifier。container を ZStack で重ねて toast manager を環境にも乗せる |

## ローカライズ

- `title` は `LocalizedStringResource`。リテラル渡しで Xcode の xcstrings 抽出と実行時 catalog 解決の両方を自動で経る
- `message` は `ToastText?`。動的値 (例: error の `localizedDescription`) は **必ず** `.verbatim(...)` でラップし、catalog lookup が走らないようにする
- 設計の経緯 (ThumbnailThumb 由来):
  - #340: catalog バイパス (ラップ忘れ) をコンパイル時に潰すため `LocalizedStringResource` に移行
  - #344: 動的値まで catalog lookup される副作用を是正するため、`message` を `ToastText` で localized / verbatim を分離

## 採用パターン

```swift
import StandardAppComponents
import SwiftUI

@main
struct MyApp: App {
    @State private var toastManager = ToastManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.toastManager, toastManager)   // DI
                .standardToastContainer(toastManager)        // ルートに 1 回だけ
        }
    }
}

struct SaveButton: View {
    @Environment(\.toastManager) private var toastManager

    var body: some View {
        Button("保存") {
            do {
                try save()
                toastManager.showSuccess("保存しました")
            } catch {
                toastManager.showError(
                    "保存に失敗しました",
                    message: .verbatim(error.localizedDescription)
                )
            }
        }
    }
}
```

- ViewModel / Service から呼ぶときは `ToastManaging` をイニシャライザで受け取り、`.shared` シングルトンに依存しない (テストでモック注入できるように)
- カスタム duration / action が必要なら `Toast(...)` を直接組み立てて `show(_:)` に渡す
- `.standardToastContainer(_:)` を **ネストして複数置かない**。表示が重複する

**採用すべきアプリ種別**: 保存 / エクスポート / コピー / 同期完了など「軽い完了通知」が頻出するアプリ全般。
**採用しないアプリ種別**: 中断不可の致命的エラーや、ユーザー判断が必須な確認系 ── これらは toast ではなく Alert / Sheet を使う。
