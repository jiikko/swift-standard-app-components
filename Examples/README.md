## サンプル

規約を満たす最小サンプル。各アプリでコピペして実装の出発点にする。

- [`MinimalApp.swift`](MinimalApp.swift): `SettingsWindow` + 外観切替 + 言語切替 + ローカライズ検証込みの最小 `App` 実装 (`StandardAppComponents`)
- [`ToastExample.swift`](ToastExample.swift): `ToastManager` + `.standardToastContainer(_:)` + `ToastManaging` 注入の最小実装 (`StandardAppComponents`)
- [`LoggingExample.swift`](LoggingExample.swift): `AppLog` + `LogCategory` enum + DI の最小実装 (`StandardAppLogging`、UI 非依存)

これらは `Package.swift` のビルド対象には含まれない (コピペ元の参照ドキュメント扱い)。

## 関連ドキュメント

- [docs/api-boundaries.md](../docs/api-boundaries.md) — 公開 API ごとの lib / consumer 責務境界
- [docs/settings.md](../docs/settings.md) — Settings ウィンドウ枠 / スロット部品 / ウィンドウ全般 modifier
- [docs/toast.md](../docs/toast.md) — アプリ内通知 (Toast)
- [docs/logging.md](../docs/logging.md) — ロギング facade (`AppLog` / `LogCategory` / `LogPrivacy`)
