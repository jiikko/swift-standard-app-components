import AppKit
import StoreKit
import SwiftUI

/// macOS 標準の About パネルを開き、説明欄 (credits) に同じ開発者の他のアプリ (`StandardDeveloperApps`) を書き足す。
///
/// 標準のパネル (アイコン・名前・版・著作権) はそのまま使う。独自の About ウィンドウは作らない (2026-11-01 のユーザー決定。
/// vlc-multi-video-player issue 441)。割り込みはせず、About を開いた人にだけ見せる。
///
/// ```swift
/// .commands {
///     StandardAboutCommands()   // App メニューの「<アプリ名> について」をこれに差し替える
/// }
/// ```
public enum StandardAboutPanel {
    /// ストアフロントを待つ上限。超えたら分からない (nil) として、日本のみのアプリを出さずに開く
    static let storefrontTimeout: Duration = .seconds(1)

    /// 標準の About パネルを開く。ストアフロントを最大 `storefrontTimeout` 待ってから、出せる他のアプリを説明欄に並べる
    /// (出せるアプリが無ければ説明欄はアプリの既定のまま)
    @MainActor
    public static func show(ownBundleIdentifier: String? = Bundle.main.bundleIdentifier) async {
        let country = await storefrontCountryCode()
        let apps = StandardDeveloperApps.otherApps(
            excludingBundleIdentifier: ownBundleIdentifier,
            storefrontCountryCode: country
        )
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if !apps.isEmpty {
            options[.credits] = credits(
                for: apps,
                languageCode: preferredLanguageCode(),
                heading: String(localized: "More Apps by the Developer", bundle: .module)
            )
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 説明欄の中身。見出しの後に 1 行 1 アプリで「名前 (App Store へのリンク) — 一言」を並べる
    static func credits(for apps: [StandardDeveloperApp], languageCode: String, heading: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 2
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let result = NSMutableAttributedString(string: heading + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])
        for (index, app) in apps.enumerated() {
            result.append(NSAttributedString(string: app.name, attributes: [
                .font: font, .link: app.appStoreURL, .paragraphStyle: paragraph
            ]))
            if let summary = app.summary(languageCode: languageCode) {
                result.append(NSAttributedString(string: " — " + summary, attributes: [
                    .font: font, .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph
                ]))
            }
            if index < apps.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: paragraph]))
            }
        }
        return result
    }

    /// アプリの表示言語 (`AppleLanguages` での切り替えを含む) の言語コード
    static func preferredLanguageCode() -> String {
        guard let localization = Bundle.main.preferredLocalizations.first else { return "en" }
        return Locale(identifier: localization).language.languageCode?.identifier ?? "en"
    }

    /// App Store のストアフロントの国コード。上限 (`storefrontTimeout`) までに分からなければ nil
    static func storefrontCountryCode() async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await Storefront.current?.countryCode }
            group.addTask {
                try? await Task.sleep(for: storefrontTimeout)
                return nil
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
    }
}

/// App メニューの「<アプリ名> について」を `StandardAboutPanel` に差し替える
public struct StandardAboutCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "About \(Self.appName)", bundle: .module)) {
                Task { await StandardAboutPanel.show() }
            }
        }
    }

    static var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String) ?? ProcessInfo.processInfo.processName
    }
}
