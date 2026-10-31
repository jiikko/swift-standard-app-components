import AppKit
@testable import StandardAppComponents
import XCTest

/// About パネルに書き足す「同じ開発者のアプリ」の一覧と、説明欄の中身。
@MainActor
final class StandardAboutPanelTests: XCTestCase {
    func test_自分を外し_日本のみのアプリは日本のストアフロントのときだけ出す() {
        let own = "com.jiikko.VLCMultiVideoPlayer"
        let japan = StandardDeveloperApps.otherApps(excludingBundleIdentifier: own, storefrontCountryCode: "JPN")
        let usa = StandardDeveloperApps.otherApps(excludingBundleIdentifier: own, storefrontCountryCode: "USA")
        let unknown = StandardDeveloperApps.otherApps(excludingBundleIdentifier: own, storefrontCountryCode: nil)

        XCTAssertFalse(japan.contains { $0.bundleIdentifier == own }, "自分のアプリは出さない")
        XCTAssertTrue(japan.contains { $0.availability == .japanOnly }, "日本のストアフロントなら日本のみのアプリも出す")
        XCTAssertFalse(usa.contains { $0.availability == .japanOnly }, "日本以外では「利用できません」に飛ぶので出さない")
        XCTAssertFalse(unknown.contains { $0.availability == .japanOnly }, "ストアフロントが分からないときは出さない側に倒す")
        XCTAssertEqual(usa.map(\.name), ["Obaket", "ThumbnailThumb", "Multi-Video Player for Dropbox"])
        XCTAssertEqual(Set(usa.map(\.bundleIdentifier)), Set(unknown.map(\.bundleIdentifier)))
    }

    func test_一覧のbundle_idとApp_StoreのIDは重ならない() {
        // 重なると、自分を外すときに別のアプリまで外れる / 別のアプリのページへ飛ぶ
        let apps = StandardDeveloperApps.all
        XCTAssertEqual(Set(apps.map(\.bundleIdentifier)).count, apps.count)
        XCTAssertEqual(Set(apps.map(\.appStoreID)).count, apps.count)
        for app in apps {
            XCTAssertEqual(app.appStoreURL.host, "apps.apple.com")
            XCTAssertTrue(app.appStoreID.allSatisfy(\.isNumber), "\(app.name) の App Store の ID")
        }
    }

    func test_一言は表示言語を優先し_無ければ英語_日本語へ落とし_どれも無ければ出さない() {
        let both = StandardDeveloperApp(name: "A", bundleIdentifier: "a", appStoreID: "1", availability: .worldwide,
                                        summaries: ["en": "English", "ja": "日本語"])
        let japaneseOnly = StandardDeveloperApp(name: "B", bundleIdentifier: "b", appStoreID: "2", availability: .japanOnly,
                                                summaries: ["ja": "日本語"])
        let none = StandardDeveloperApp(name: "C", bundleIdentifier: "c", appStoreID: "3", availability: .worldwide, summaries: [:])
        XCTAssertEqual(both.summary(languageCode: "ja"), "日本語")
        XCTAssertEqual(both.summary(languageCode: "de"), "English")
        XCTAssertEqual(japaneseOnly.summary(languageCode: "en"), "日本語")
        XCTAssertNil(none.summary(languageCode: "en"))
    }

    func test_説明欄は見出しの後に1行1アプリで名前をApp_Storeへのリンクにする() {
        let apps = [
            StandardDeveloperApp(name: "Alpha", bundleIdentifier: "a", appStoreID: "111", availability: .worldwide,
                                 summaries: ["en": "First app"]),
            StandardDeveloperApp(name: "Beta", bundleIdentifier: "b", appStoreID: "222", availability: .worldwide, summaries: [:])
        ]

        let credits = StandardAboutPanel.credits(for: apps, languageCode: "en", heading: "More Apps")

        XCTAssertEqual(credits.string, "More Apps\nAlpha — First app\nBeta")
        let alpha = (credits.string as NSString).range(of: "Alpha")
        XCTAssertEqual(credits.attribute(.link, at: alpha.location, effectiveRange: nil) as? URL,
                       URL(string: "https://apps.apple.com/app/id111"))
        let beta = (credits.string as NSString).range(of: "Beta")
        XCTAssertEqual(credits.attribute(.link, at: beta.location, effectiveRange: nil) as? URL,
                       URL(string: "https://apps.apple.com/app/id222"))
        let summary = (credits.string as NSString).range(of: "First app")
        XCTAssertNil(credits.attribute(.link, at: summary.location, effectiveRange: nil), "一言はリンクにしない")
        XCTAssertNil(credits.attribute(.link, at: 0, effectiveRange: nil), "見出しはリンクにしない")
    }
}
