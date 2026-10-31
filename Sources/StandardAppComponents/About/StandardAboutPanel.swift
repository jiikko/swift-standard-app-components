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

    /// 他のアプリを並べたときに標準の幅 (284pt) へ足す幅。標準の幅では「名前 — 一言」が折り返す。
    /// 2026-11-01 のユーザー指示で 200pt 広げた後、左右の余白が広いとの指示で 120pt にした
    /// (いちばん長い行は約 324pt。説明欄 388pt で左右に約 32pt ずつ空く)
    static let creditsExtraWidth: CGFloat = 120

    /// 広げたパネル。同じ説明欄で開き直すと AppKit は同じパネルを使い回すので、2 回目は広げない (足すと開くたびに広がる)。
    /// 説明欄が違うと AppKit は別のパネル (別のオブジェクト) を作り、幅は標準に戻る (macOS 26 で実測) ので、そちらは改めて広げる
    @MainActor private static weak var widenedPanel: NSWindow?

    /// パネルを広げなかった理由 (`show` の `onWidenSkipped` に渡す)。パネルは標準の幅のまま開く
    public enum WidenSkipReason: Equatable, Sendable {
        /// 開いたはずの About パネルが、説明欄の中身で見つからない
        case panelNotFound
        /// パネルの中の作りが、幅を決めている制約を見つけられない形だった (macOS の版で変わりうる)
        case layoutNotRecognized
        /// 制約を広げたが、パネルの幅が付いてこなかった
        case widthDidNotFollow
    }

    /// 標準の About パネルを開く。ストアフロントを最大 `storefrontTimeout` 待ってから、出せる他のアプリを説明欄に並べ、
    /// パネルを `creditsExtraWidth` だけ広げる (出せるアプリが無ければ説明欄はアプリの既定のまま、幅も標準のまま)。
    ///
    /// - Parameter onWidenSkipped: パネルを広げられなかったときに呼ぶ。パネルは標準の幅で開いている。
    ///   lib はログを書かないので、consumer が自分の logger に warn で流す
    @MainActor
    public static func show(
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        onWidenSkipped: (@MainActor (WidenSkipReason) -> Void)? = nil
    ) async {
        let country = await storefrontCountryCode()
        let apps = StandardDeveloperApps.otherApps(
            excludingBundleIdentifier: ownBundleIdentifier,
            storefrontCountryCode: country
        )
        guard !apps.isEmpty else {
            NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        let credits = credits(
            for: apps,
            languageCode: preferredLanguageCode(),
            heading: String(localized: "More Apps by the Developer", bundle: .module)
        )
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
        // orderFront は同期でパネルを作って載せるので、描画の前 (同じ run loop の回) に広げられる
        if let panel = NSApplication.shared.windows.first(where: { aboutPanel($0, showing: credits.string) }) {
            if let reason = widenOnce(panel) {
                onWidenSkipped?(reason)
            }
        } else {
            onWidenSkipped?(.panelNotFound)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// まだ広げていないパネルなら `creditsExtraWidth` だけ広げる。使い回されたパネルには足さない
    @MainActor
    static func widenOnce(_ panel: NSWindow) -> WidenSkipReason? {
        guard panel !== widenedPanel else { return nil }
        if let reason = widen(panel, by: creditsExtraWidth) { return reason }
        widenedPanel = panel
        return nil
    }

    /// `window` が、説明欄に `creditsText` を出している About パネルか
    @MainActor
    static func aboutPanel(_ window: NSWindow, showing creditsText: String) -> Bool {
        guard window is NSPanel, let contentView = window.contentView else { return false }
        return containsTextView(contentView, showing: creditsText)
    }

    @MainActor
    private static func containsTextView(_ view: NSView, showing text: String) -> Bool {
        if let textView = view as? NSTextView, textView.string == text { return true }
        return view.subviews.contains { containsTextView($0, showing: text) }
    }

    /// 標準の About パネルを `extra` だけ広げ、中心を保つ。広げられなければ理由を返し、パネルは標準の幅のまま残す。
    ///
    /// 標準のパネルの幅は、中の NSStackView とその中の欄 (名前・版・説明欄) の `width == 定数` の制約で決まっていて、
    /// ウィンドウの枠を `setFrame` で広げても戻される (macOS 26 で実測。284pt のまま)。そのため制約の定数を足す。
    /// 足すのはパネルの幅いっぱいの欄 (`fullWidthTolerance` の内) だけで、アイコン (64pt) のような幅の決まった部品は足さない
    /// (足すとアイコンの枠が横に伸びる。macOS が幅の決まったボタンなどを足しても伸ばさない)。
    /// 作りは文書化されていないので、NSStackView の幅の制約が 1 本に決まらない・幅いっぱいの欄が無いときは何もしない (標準の幅で開く)。
    @MainActor
    @discardableResult
    static func widen(_ panel: NSWindow, by extra: CGFloat) -> WidenSkipReason? {
        guard let contentView = panel.contentView,
              let stack = contentView.subviews.first as? NSStackView,
              case let stackWidths = fixedWidthConstraints(of: stack), stackWidths.count == 1,
              let stackWidth = stackWidths.first?.constant else {
            return .layoutNotRecognized
        }
        var constraints: [NSLayoutConstraint] = []
        collectFixedWidthConstraints(in: stack, into: &constraints)
        constraints = constraints.filter { $0.constant >= stackWidth - fullWidthTolerance }
        // stack 自身の 1 本だけなら、中の欄が想定の作りではない (stack だけ広げても欄は 284pt のまま)
        guard constraints.count >= 2 else { return .layoutNotRecognized }
        let before = panel.frame
        for constraint in constraints {
            constraint.constant += extra
        }
        // 枠は制約を変えても次のレイアウトの回まで付いてこないので、中心を保った枠を自分で入れる
        var frame = before
        frame.size.width += extra
        frame.origin.x = before.midX - frame.width / 2
        panel.setFrame(frame, display: true)
        panel.layoutIfNeeded()
        guard abs(panel.frame.width - frame.width) < 1, abs(stack.frame.width - contentView.bounds.width) < 1 else {
            // 付いてこなかったら戻す (欄だけが広がって、パネルの外へはみ出すのを残さない)
            for constraint in constraints {
                constraint.constant -= extra
            }
            panel.setFrame(before, display: true)
            panel.layoutIfNeeded()
            return .widthDidNotFollow
        }
        return nil
    }

    /// `view` 自身に付いた `width == 定数` の制約 (内容の大きさ・autoresizing から作られた制約は含めない)
    @MainActor
    private static func fixedWidthConstraints(of view: NSView) -> [NSLayoutConstraint] {
        view.constraints.filter { constraint in
            type(of: constraint) == NSLayoutConstraint.self
                && constraint.firstAttribute == .width && constraint.relation == .equal
                && constraint.secondItem == nil && constraint.firstItem === view
        }
    }

    /// 幅いっぱいの欄とみなす、stack の幅との差の上限。標準のパネルの欄は stack の 284pt に対して 268pt・264pt (macOS 26 で実測)
    static let fullWidthTolerance: CGFloat = 32

    @MainActor
    private static func collectFixedWidthConstraints(in view: NSView, into result: inout [NSLayoutConstraint]) {
        result += fixedWidthConstraints(of: view)
        for subview in view.subviews {
            collectFixedWidthConstraints(in: subview, into: &result)
        }
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
    private let onWidenSkipped: (@MainActor (StandardAboutPanel.WidenSkipReason) -> Void)?

    /// - Parameter onWidenSkipped: About パネルを広げられなかったとき (標準の幅で開いたとき) に呼ぶ。
    ///   consumer の logger に warn で流す (`StandardAboutPanel.show` を参照)
    public init(onWidenSkipped: (@MainActor (StandardAboutPanel.WidenSkipReason) -> Void)? = nil) {
        self.onWidenSkipped = onWidenSkipped
    }

    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "About \(Self.appName)", bundle: .module)) {
                Task { await StandardAboutPanel.show(onWidenSkipped: onWidenSkipped) }
            }
        }
    }

    static var appName: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleDisplayName"] as? String) ?? (info?["CFBundleName"] as? String) ?? ProcessInfo.processInfo.processName
    }
}
