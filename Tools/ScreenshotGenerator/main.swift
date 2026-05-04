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
//   ウィンドウ内コンテンツ」「Toast 単体」など pure SwiftUI View 部分のみ。
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
    /// section header は executable target から `Bundle.module` が見えないため
    /// 英語リテラルで直接書く (lib 側は `Text("Appearance", bundle: .module)` で
    /// catalog 解決するが、screenshot 用途では英語固定で十分)。
    static func settingsGeneralContent(scheme: ColorScheme) -> some View {
        Form {
            Section {
                AppearanceSampleSection()
            } header: {
                Text("Appearance")
            }

            Section {
                LanguageSection(supportedLanguages: [
                    .init(code: "en", displayName: "English"),
                    .init(code: "ja", displayName: "日本語")
                ])
            } header: {
                Text("Language")
            }

            Section {
                // lib 提供のデフォルトラベル (`Bundle.module` 解決の "Open at Login" /
                // "Show in Menu Bar") をそのまま採用する。executable から `Bundle.module`
                // は見えないが、`LaunchAtLoginToggle.swift` 自体は lib target の中で
                // resources を bundle 解決するので screenshot 内でも正しく表示される。
                LaunchAtLoginToggle()
                MenuBarVisibilityToggle(isOn: .constant(true))
            } header: {
                Text("その他")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
        .preferredColorScheme(scheme)
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
