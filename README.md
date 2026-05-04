# StandardAppComponents

Personal SPM for SwiftUI **macOS apps only**.

This package collects small, repeated macOS app primitives that are worth keeping consistent across apps: Settings window structure, language selection, launch-at-login toggles, menu bar visibility toggles, window behaviors, app appearance helpers, and toast notifications.

The package is intentionally not a full design system. It provides the parts that are stable across apps and leaves app-specific policy, storage, navigation, copy, and lifecycle decisions to the consumer app.

## Scope

| In scope | Out of scope |
|---|---|
| Swift / SwiftUI macOS apps | iOS / watchOS apps |
| Thin AppKit wrappers that remove repeated boilerplate | Full cross-platform abstraction |
| Shared Settings window contract and behavior | App-specific Settings tabs and business rules |
| Shared small controls with common localized labels | Full menu bar agent / status item lifecycle |
| Toast queue, rendering, and manager protocol | Fatal errors, confirmations, or flows that need Alert / Sheet |

`Package.swift` is fixed to `platforms: [.macOS(.v14)]`. Several APIs depend on AppKit, `NSWindow`, `NSApp`, `NSVisualEffectView`, and `SMAppService.mainApp`.

## Boundary Rule

Before adding or using an API, classify it this way:

| Category | Put it in this package when... | Keep it in the consumer app when... |
|---|---|---|
| Contract | Missing or misordered UI should be caught by the type shape. Example: `GeneralTabContract` requires appearance and language slots. | The required fields differ per app. |
| Behavior | The AppKit / SwiftUI behavior is the same everywhere. Example: ESC closes a Settings window, autosave a window frame. | The behavior depends on app state, documents, permissions, routing, or window ownership. |
| Small UI primitive | The control has a common label and no app lifecycle knowledge. Example: `MenuBarVisibilityToggle`. | The UI owns menus, icons, click handlers, status item creation, or app-specific copy. |
| Model value | The value is repeated exactly across apps. Example: `StandardAppearanceMode`. | The value is persisted with app-specific migration rules or has business meaning. |

If an API would need to know how a specific app opens windows, manages documents, logs errors, relaunches itself, or builds menus, it does not belong here.

## Public API Responsibilities

### Settings Window

| API | Package provides | Consumer provides |
|---|---|---|
| `SettingsWindow<AppTabs>` | A SwiftUI `TabView`-based Settings window. General tab is first. Width and per-tab height support. ESC close behavior is applied internally. General tab has `Cmd+1`. | The `Settings { ... }` scene, the `GeneralTabContract`, app-specific tabs, `.tag(...)` values for extra tabs, and any extra keyboard shortcuts for those tabs. |
| `GeneralTabContract` | Required slots for General tab: `appearance`, `language`, and optional `appSections`. The package wraps `appearance` and `language` in localized `Section` headers. | Actual appearance UI, actual language UI if not using `LanguageSection`, and app-specific sections. |
| `SettingsWindowConstants.generalTabId` / `SettingsWindow.generalTabId` | Stable `"general"` tag for the built-in General tab. | Use matching string tags for additional tabs when relying on selection / height maps. |
| `NotImplementedSlot` | A visible red placeholder plus `assertionFailure` in DEBUG. Useful as an intentional temporary slot filler. | Decide whether a placeholder is acceptable. Do not ship it as normal product UI. |

Non-goal: this package does not provide every Settings row, every app-specific tab, or a complete preferences model.

### Settings Behaviors And Window Helpers

| API | Package provides | Consumer provides |
|---|---|---|
| `View.standardSettingsBehaviors()` | Settings-window-only ESC close behavior using the hosting `NSWindow`. `SettingsWindow` already applies it. | Apply directly only if building a custom Settings window without `SettingsWindow`. Do not use for arbitrary modal/editor views. |
| `View.autoSaveWindowFrame(name:)` | Sets `NSWindow.frameAutosaveName` after the SwiftUI view attaches to a window. | A stable, unique autosave name per logical window. |
| `WindowBackgroundView` | `NSVisualEffectView` wrapper for macOS vibrancy backgrounds. | Choose where it belongs visually and which material/blending mode to use. |

Current limitation: `Cmd+1` for General is built into `SettingsWindow`, but common registration for `Cmd+2`, `Cmd+3`, etc. on consumer-provided tabs is not yet a package-level API. Add those shortcuts in the consumer app for now.

### Appearance

| API | Package provides | Consumer provides |
|---|---|---|
| `StandardAppearanceMode` | Shared `system / light / dark` enum with stable raw string values, `Codable`, `CaseIterable`, `Sendable`, and `preferredColorScheme`. | Persistence key, migration, `@AppStorage` / settings storage, and the picker UI in the `appearance` slot. |
| `View.applyAppAppearance(_:)` | Applies the selected `ColorScheme?` to SwiftUI and updates `NSApp.appearance` / open `NSWindow.appearance` where needed. | Call it at app scene roots and Settings roots with the currently selected mode. |

Non-goal: the package does not own app settings storage. It does not decide whether an app should expose theme selection.

### Language

| API | Package provides | Consumer provides |
|---|---|---|
| `LanguageSection` | A ready-made language picker for the `language` slot. It reads and writes `AppleLanguages`, adds a System Default option, and shows a restart/quit alert after changes. | Supported language list. Optional relaunch closure if the app can actually restart itself. |
| `LanguageOption` | Value type for supported language entries: `code` and `displayName`. | Correct language codes and display names. Usually native names such as `English` and `日本語`. |

Default behavior: if `onRestart` is omitted, the primary alert action is **Quit Now** and calls `NSApp.terminate(nil)`. Pass `onRestart` only when the consumer app has a real relaunch path.

Non-goal: the package does not manage app-specific localization keys, app content strings, or release-time localization policy.

### Launch At Login

| API | Package provides | Consumer provides |
|---|---|---|
| `LaunchAtLoginService` | Thin wrapper around `SMAppService.mainApp`: `isEnabled` and `setEnabled(_:)`. No logging. No UI. | Decide whether launch-at-login makes sense for the app. Handle thrown errors if calling the service directly. |
| `LaunchAtLoginToggle` | Labeled Toggle that syncs with `SMAppService`, refreshes when the scene becomes active, rolls back UI on errors, and reports errors through `onError`. | Put it inside an app-owned Settings `Section`. Route `onError` to the app's toast, alert, or logger. |

Use for menu bar utilities, sync clients, and apps where background availability is a feature. Do not add it to document/editor/media apps just because the API exists.

### Menu Bar Visibility

| API | Package provides | Consumer provides |
|---|---|---|
| `MenuBarVisibilityToggle` | Only a localized labeled Toggle for "Show in Menu Bar" / "メニューバーに表示". It binds to a `Binding<Bool>`. | Persistence, observing the binding, creating/destroying `NSStatusItem` or `MenuBarExtra`, menu content, icon, primary click behavior, window routing, and lifecycle. |

Explicit non-goal: this package does **not** provide `MenuBarAgent`, `MenuBarContract`, menu construction, status item ownership, or click behavior. Those are app-specific and should stay in the consumer app.

### Toast

| API | Package provides | Consumer provides |
|---|---|---|
| `Toast` / `Toast.Style` / `ToastAction` / `ToastText` | Toast data model, style palette, action model, and explicit localized vs verbatim message handling. | Message content, action behavior, and choosing Toast vs Alert/Sheet. |
| `ToastManaging` | Protocol for dependency injection and tests. Methods are `@MainActor`; the protocol itself remains actor-agnostic so it can work with consumer DI. | Store and pass the manager through the app's own DI pattern. |
| `ToastManager` | Default `@Observable` queue manager with auto-dismiss, manual dismiss, and bounded queue behavior. | Create one app-level instance. Avoid global singletons unless the consumer app already uses that pattern intentionally. |
| `ToastView` / `ToastContainerView` / `View.standardToastContainer(_:)` | Standard bottom-right toast rendering and root-view overlay modifier. | Attach the container once near the root view and pass the manager explicitly. |

Important boundary: this package does **not** provide an Environment key for toast. Consumer apps have different DI structures, so the manager is passed explicitly to `standardToastContainer(_:)`. Add your own Environment key in the app if that fits your architecture.

Use toast for lightweight completion, informational, and recoverable error messages. Use Alert or Sheet for destructive confirmations, blocking decisions, or fatal failures.

### Localization Validation

| API | Package provides | Consumer provides |
|---|---|---|
| `StandardAppComponentsLocalization.requiredKeys` | List of package-owned localization keys required by package UI. | Usually nothing. |
| `StandardAppComponentsLocalization.validateRequiredKeys()` | Startup validation that package-owned keys exist in the package resource bundle for all supported package locales. Fails fast if the package ships incomplete localization. | Call once during app startup if the app uses package UI. |
| `StandardAppComponentsLocalization.bundle` / `lookupString(forKey:locale:)` | Accessors mainly useful for tests and diagnostics. | Avoid building app UI around these unless there is a clear diagnostic need. |

Non-goal: consumer app string catalogs remain the consumer app's responsibility.

### Misc

| API | Package provides | Consumer provides |
|---|---|---|
| `StandardAppComponents.version` | A simple package version string. | Do not treat it as a SemVer source of truth unless release automation is added. |

## APIs This Package Intentionally Does Not Provide

| Not provided | Reason |
|---|---|
| `AboutContract` / custom About window | macOS standard About panel and app-specific implementations are enough. Version, copyright, acknowledgements, and license presentation vary by app. |
| `MenuBarAgent` / `MenuBarContract` | Icon, menu, click behavior, status item lifecycle, and window routing are app-specific. Shared scope is limited to `MenuBarVisibilityToggle`. |
| Sparkle setup helper | Update channels, relaunch behavior, signing, feed URLs, and distribution models differ by app. |
| Global shortcut registrar | Permissions, collision handling, user customization, and lifecycle vary by app. |
| Notification permission flow | Notification copy, timing, permissions UX, and app purpose are product-specific. |
| App settings persistence | Keys, migrations, defaults, and compatibility rules belong to each app. |
| Design tokens / common buttons / empty states | This is not a broad UI kit. Add only repeated macOS primitives with clear cross-app value. |

## Minimal Settings Example

[`Examples/MinimalApp.swift`](Examples/MinimalApp.swift) contains a complete minimal app using `SettingsWindow`, appearance selection, `LanguageSection`, and localization validation.

Short form:

```swift
import SwiftUI
import StandardAppComponents

@main
struct MyApp: App {
    @AppStorage("appearanceMode")
    private var rawAppearanceMode = StandardAppearanceMode.system.rawValue

    init() {
        StandardAppComponentsLocalization.validateRequiredKeys()
    }

    private var appearanceMode: StandardAppearanceMode {
        StandardAppearanceMode(rawValue: rawAppearanceMode) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyAppAppearance(appearanceMode.preferredColorScheme)
        }

        Settings {
            SettingsWindow(
                general: GeneralTabContract(
                    appearance: {
                        AppearancePicker(rawMode: $rawAppearanceMode)
                    },
                    language: {
                        LanguageSection(supportedLanguages: [
                            .init(code: "en", displayName: "English"),
                            .init(code: "ja", displayName: "日本語")
                        ])
                    },
                    appSections: {
                        Section {
                            LaunchAtLoginToggle()
                        } header: {
                            Text("Startup")
                        }
                    }
                ),
                width: 520,
                heights: [SettingsWindowConstants.generalTabId: 280]
            )
            .applyAppAppearance(appearanceMode.preferredColorScheme)
        }
    }
}
```

## Minimal Toast Example

```swift
import SwiftUI
import StandardAppComponents

@main
struct MyApp: App {
    @State private var toastManager = ToastManager()

    var body: some Scene {
        WindowGroup {
            ContentView(toastManager: toastManager)
                .standardToastContainer(toastManager)
        }
    }
}

struct ContentView: View {
    let toastManager: any ToastManaging

    var body: some View {
        Button("Save") {
            toastManager.showSuccess("Saved")
        }
    }
}
```

## Screenshots

### Settings Window

| Light | Dark |
|---|---|
| ![Settings (Light)](docs/images/settings-general-light.png) | ![Settings (Dark)](docs/images/settings-general-dark.png) |

NSWindow chrome is not fully represented in the offscreen SwiftUI screenshot generator. Real app windows look more native.

### Toast

| Style | Screenshot |
|---|---|
| Success | ![Toast Success](docs/images/toast-success.png) |
| Error | ![Toast Error](docs/images/toast-error.png) |
| Warning | ![Toast Warning](docs/images/toast-warning.png) |
| Info | ![Toast Info](docs/images/toast-info.png) |
| With action | ![Toast With Action](docs/images/toast-with-action.png) |

Regenerate screenshots with:

```bash
bin/generate-screenshots
```

## Additional Docs

| Topic | Doc |
|---|---|
| Settings details | [docs/settings.md](docs/settings.md) |
| Toast details | [docs/toast.md](docs/toast.md) |

## Build

```bash
swift build
swift test
bin/generate-screenshots
```

## Repo Operations

Repository-specific agent rules live in [CLAUDE.md](CLAUDE.md).

Important operational rule: after committing changes in this package, push to `origin`. Consumer apps currently reference this package by `branch: master`, so local-only commits will not be visible to them.
