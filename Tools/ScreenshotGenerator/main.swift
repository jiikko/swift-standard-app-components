// README 用のスクリーンショットを `ImageRenderer` で生成する開発者ツール。
//
// 用途: `lib/swift-standard-app-components/docs/images/` に PNG を再生成する。
//
// 使い方:
//   swift run ScreenshotGenerator
//   または bin/generate-screenshots
//
// 注意:
// - NSWindow chrome (タイトルバー / 閉じるボタン / vibrancy 背景) は SwiftUI View
//   ベースの `ImageRenderer` では再現されない。本ツールが捕捉するのは「Settings
//   ウィンドウ内コンテンツ」「タブの帯」「Toast 単体」など SwiftUI View 部分のみ。
// - `applyAppAppearance` は NSWindow.appearance を更新する modifier だが、
//   本ツール下では実 NSWindow が無いので no-op になる。Light/Dark の差は
//   `.preferredColorScheme(_:)` で表現する。

import AppKit
import SwiftUI
import StandardAppComponents

@main
@MainActor
enum ScreenshotGenerator {
    static func main() {
        let outputDir = URL(fileURLWithPath: "docs/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Settings General タブの中身: NSHostingController 経由でしか描画できない
        // (`Form.formStyle(.grouped)` / `TabView` は ImageRenderer 単独だと layout が解決
        // できず blank or "unavailable" placeholder になるため)。
        let settingsSize = NSSize(width: 520, height: 460)
        writeViaHosting(
            view: settingsGeneralContent(scheme: .light),
            size: settingsSize,
            name: "settings-general-light",
            in: outputDir
        )
        writeViaHosting(
            view: settingsGeneralContent(scheme: .dark),
            size: settingsSize,
            name: "settings-general-dark",
            in: outputDir
        )
        writeViaHosting(
            view: shortcutSettingsSample(),
            size: NSSize(width: 560, height: 430),
            name: "settings-shortcuts",
            in: outputDir
        )

        // タブの帯: 中で ScrollView を使うので ImageRenderer では描けない (hosting 経由)。
        let tabStripSize = NSSize(width: 640, height: 96)
        writeViaHosting(view: tabStripSample(scheme: .light), size: tabStripSize, name: "tab-strip-light", in: outputDir)
        writeViaHosting(view: tabStripSample(scheme: .dark), size: tabStripSize, name: "tab-strip-dark", in: outputDir)

        // Toast 各種: Toast は pure SwiftUI なので ImageRenderer で十分。
        write(view: toastSample(.success, title: "Saved"), name: "toast-success", in: outputDir)
        write(
            view: toastSample(
                .error,
                title: "Failed to save",
                message: "Disk does not have enough free space"
            ),
            name: "toast-error",
            in: outputDir
        )
        write(view: toastSample(.warning, title: "Network is unstable"), name: "toast-warning", in: outputDir)
        write(view: toastSample(.info, title: "Update available"), name: "toast-info", in: outputDir)
        write(view: toastSampleWithAction(), name: "toast-with-action", in: outputDir)

        print("Generated screenshots in \(outputDir.path)")
    }

    // MARK: - View builders

    /// Settings の General タブの中身 (Form 直接)。`SettingsWindow` の `TabView` は
    /// `ImageRenderer` で描画できない (Settings Scene context が無いと内部 layout が
    /// 解決できず "unavailable" プレースホルダになる) ため、Tab を含まない
    /// `Form.formStyle(.grouped)` で General タブ相当を直接組む。
    /// Examples/MinimalApp.swift の構成 + `appSections` slot に lib 提供の汎用
    /// toggle (`LaunchAtLoginToggle` / `MenuBarVisibilityToggle`) を流し込んだ形を撮る。
    ///
    /// 表示は **`LocalizedStringResource` の `locale:` を `ja` で明示固定** する。
    /// `.environment(\.locale)` だけでは catalog lookup の locale を上書きできない
    /// ため、`Text(LocalizedStringResource(..., locale: ja))` 経由で ja 解決を強制。
    /// consumer 側 demo 部品の文言 (テーマ / システム / ライト / ダーク) は lib API
    /// ではないため hardcoded JP。
    static func settingsGeneralContent(scheme: ColorScheme) -> some View {
        Form {
            Section {
                AppearanceSampleSection()
            } header: {
                libText("Appearance")
            }

            Section {
                LanguageSection(supportedLanguages: [
                    .init(code: "en", displayName: "English"),
                    .init(code: "ja", displayName: "日本語")
                ])
            } header: {
                libText("Language")
            }

            Section {
                // lib 提供のデフォルトラベル ("Open at Login" / "Show in Menu Bar") を
                // そのまま採用する。lib 側の `Text(..., bundle: .module)` は env locale を
                // 上書きできないため、screenshot 上では system locale (= 通常 EN) で resolve。
                // section header だけ libText() で ja 固定にしている関係で見た目が混在する点
                // は許容 (代替案: lib 側 toggle ラベルも consumer 側で `LocalizedStringResource`
                // 化する API を作るが、ぼやきの本筋から外れるため見送り)。
                LaunchAtLoginToggle()
                MenuBarVisibilityToggle(isOn: .constant(true))
            } header: {
                libText("Other")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
        .preferredColorScheme(scheme)
    }

    /// Lib catalog のキーを `ja` ロケールで明示解決した `Text` を返す。
    /// SPM CLI build では `String(localized:)` / `LocalizedStringResource(_, locale:)`
    /// が xcstrings JSON を直接読まず source language (en) にフォールバックするため、
    /// lib 提供の `StandardAppComponentsLocalization.lookupString(forKey:locale:)` で
    /// 直接 ja 値を取り出して Text に渡す。
    static func libText(_ key: String) -> Text {
        let value = StandardAppComponentsLocalization.lookupString(forKey: key, locale: "ja") ?? key
        return Text(value)
    }

    /// Toast 単体 (action なし) のサンプル。背景を薄くつけて影が見えるようにする。
    static func toastSample(_ style: Toast.Style, title: String, message: String? = nil) -> some View {
        ToastView(
            toast: Toast(style: style, title: title, message: message),
            onDismiss: {}
        )
        .padding(24)
        .frame(width: 420)
        .background(Color(white: 0.95))
    }

    /// アクションボタン付き Toast のサンプル。
    static func toastSampleWithAction() -> some View {
        ToastView(
            toast: Toast(
                style: .success,
                title: "Exported file",
                action: ToastAction(title: "Show in Finder") { /* no-op for screenshot */ }
            ),
            onDismiss: {}
        )
        .padding(24)
        .frame(width: 420)
        .background(Color(white: 0.95))
    }

    /// ショートカット設定タブのサンプル。VLCMultiVideoPlayer 由来のレイアウトを
    /// lib の表示モデル (`StandardShortcutGroup` / `StandardShortcutItem`) だけで再現する。
    static func shortcutSettingsSample() -> some View {
        ShortcutSettingsTab(
            groups: [
                StandardShortcutGroup(
                    id: "global",
                    title: "Global",
                    subtitle: "App-wide shortcuts",
                    items: [
                        StandardShortcutItem(
                            id: "togglePlayPause",
                            title: "Play / Pause",
                            shortcut: "Space"
                        ),
                        StandardShortcutItem(
                            id: "toggleSidebar",
                            title: "Toggle Sidebar",
                            shortcut: "⌘E",
                            isCustomized: true
                        )
                    ]
                ),
                StandardShortcutGroup(
                    id: "fullscreen",
                    title: "Fullscreen",
                    subtitle: "Fullscreen shortcuts",
                    items: [
                        StandardShortcutItem(
                            id: "exitFullscreen",
                            title: "Exit Fullscreen",
                            shortcut: "Esc",
                            isEditable: false
                        ),
                        StandardShortcutItem(
                            id: "seekForward",
                            title: "Seek Forward",
                            shortcut: "→"
                        )
                    ]
                )
            ],
            recordingItemID: "toggleSidebar",
            conflictWarning: "Conflicts with Toggle Search",
            onShortcutClick: { _ in },
            onReset: { _ in },
            onResetAll: {}
        )
        .frame(width: 560, height: 430)
        .background(Color(NSColor.windowBackgroundColor))
    }

    struct TabSampleItem: Identifiable, Equatable {
        let id: Int
        let symbol: String
        let title: String
    }

    /// `StandardTabStrip` の既定の見た目 (Chrome 風)。帯の地を一段沈め、選んでいるタブを下の本体と同じ色で塗って下端でつなぐ。
    /// 帯の地・本体・境の線は consumer が描くもの (lib は描かない) なので、ここで見本の色を置く。
    static func tabStripSample(scheme: ColorScheme) -> some View {
        let dark = scheme == .dark
        let pane = dark ? Color(white: 0.17) : Color(white: 0.98)
        let strip = dark ? Color(white: 0.10) : Color(white: 0.89)
        let line = dark ? Color(white: 0.26) : Color(white: 0.80)
        let items = [
            TabSampleItem(id: 1, symbol: "folder", title: "Documents"),
            TabSampleItem(id: 2, symbol: "photo", title: "Photos"),
            TabSampleItem(id: 3, symbol: "film", title: "Movies"),
            TabSampleItem(id: 4, symbol: "music.note", title: "Music"),
        ]
        return VStack(spacing: 0) {
            StandardTabStrip(
                items,
                activeID: 2,
                selectedFill: pane,
                configuration: StandardTabStripConfiguration(activeIndicatorColor: .accentColor),
                onSelect: { _ in },
                onClose: { _ in },
                onAdd: {}
            ) { item, state in
                Label(item.title, systemImage: item.symbol)
                    .font(.system(size: 12, weight: state.isActive ? .medium : .regular))
                    .foregroundStyle(state.isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(alignment: .bottom) { Rectangle().fill(line).frame(height: 1) }
            .background(strip)
            pane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, scheme)
        .preferredColorScheme(scheme)
    }

    // MARK: - Render to PNG (ImageRenderer route — pure SwiftUI views)

    static func write<V: View>(view: V, name: String, in dir: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let nsImage = renderer.nsImage else {
            FileHandle.standardError.write(Data("Failed to render \(name)\n".utf8))
            return
        }
        savePNG(nsImage, name: name, in: dir)
    }

    // MARK: - Render via NSHostingController + offscreen NSWindow

    /// `ImageRenderer` 単独で描画できない SwiftUI View (Form.formStyle(.grouped),
    /// TabView 等の AppKit 統合が深い view) を NSHostingController + offscreen NSWindow
    /// 経由でレンダリングする。NSWindow は visible にせずに content view の layout を
    /// 強制し、`bitmapImageRepForCachingDisplay` で snapshot する。
    static func writeViaHosting<V: View>(view: V, size: NSSize, name: String, in dir: URL) {
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(origin: .zero, size: size)

        // NSWindow に attach することで NSAppearance / NSWindow.contentLayoutGuide 等の
        // SwiftUI が前提する environment を満たす。`.titled` 付きの通常 window として
        // 構築するが、実際には order-front せず visible にしないので画面には出ない。
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.layoutIfNeeded()
        hosting.view.layoutSubtreeIfNeeded()

        // SwiftUI は layout を deferred で commit することがあるため、run-loop を
        // 1 サイクル回してから snapshot する。
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        guard let bitmap = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else {
            FileHandle.standardError.write(Data("Failed to allocate bitmap for \(name)\n".utf8))
            return
        }
        hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmap)

        let image = NSImage(size: hosting.view.bounds.size)
        image.addRepresentation(bitmap)
        savePNG(image, name: name, in: dir)
    }

    // MARK: - Common PNG writer

    static func savePNG(_ image: NSImage, name: String, in dir: URL) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Failed to encode PNG \(name)\n".utf8))
            return
        }
        let url = dir.appendingPathComponent("\(name).png")
        do {
            try png.write(to: url)
            print("Wrote \(url.path)")
        } catch {
            FileHandle.standardError.write(Data("Failed to write \(name): \(error)\n".utf8))
        }
    }
}

// MARK: - Sample sub-views (consumer 側 demo 相当)

/// `appearance` slot に流し込むサンプル View。`AppearanceSection` 相当を inline で再現。
private struct AppearanceSampleSection: View {
    @State private var mode: StandardAppearanceMode = .system

    var body: some View {
        Picker("テーマ", selection: $mode) {
            Text("System").tag(StandardAppearanceMode.system)
            Text("Light").tag(StandardAppearanceMode.light)
            Text("Dark").tag(StandardAppearanceMode.dark)
        }
        .pickerStyle(.segmented)
    }
}
