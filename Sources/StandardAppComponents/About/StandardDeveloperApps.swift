import Foundation

/// 同じ開発者 (jiikko) が App Store に出しているアプリの 1 本。「他のアプリ」の導線 (`StandardAboutPanel`) に並べる。
public struct StandardDeveloperApp: Equatable, Sendable {
    /// App Store で配信している地域
    public enum Availability: Equatable, Sendable {
        /// 世界 (EU を除く)。どのストアフロントのユーザーにも出してよい
        case worldwide
        /// 日本のみ。日本以外のストアフロントのユーザーに出すと「お住まいの国では利用できません」に飛ぶ
        case japanOnly
    }

    /// 表示名 (App Store の名前)
    public let name: String
    /// このアプリの bundle id。自分のアプリを一覧から外すのに使う
    public let bundleIdentifier: String
    public let appStoreID: String
    public let availability: Availability
    /// 一言の説明 (App Store のサブタイトル)。言語コード (`"ja"` / `"en"`) → 文。無い言語は他の言語へ落とす
    public let summaries: [String: String]

    public init(
        name: String,
        bundleIdentifier: String,
        appStoreID: String,
        availability: Availability,
        summaries: [String: String]
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.appStoreID = appStoreID
        self.availability = availability
        self.summaries = summaries
    }

    public var appStoreURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    /// `languageCode` の一言。無ければ英語、それも無ければ日本語。どれも無ければ nil (名前だけを出す)
    public func summary(languageCode: String) -> String? {
        summaries[languageCode] ?? summaries["en"] ?? summaries["ja"]
    }
}

/// 同じ開発者のアプリの一覧 (issue: vlc-multi-video-player 441)。アプリを足すときはここに 1 行足すと、この部品を使う全部のアプリに出る。
///
/// 一言の説明は各アプリの App Store のサブタイトル (`releases/current/metadata/<locale>/subtitle.txt` など) を写したもの。
/// サブタイトルを変えたらここも直す。
public enum StandardDeveloperApps {
    /// 全部のアプリ (並び順は About に出す順)
    public static let all: [StandardDeveloperApp] = [
        StandardDeveloperApp(
            name: "Video Grid Player", bundleIdentifier: "com.jiikko.VLCMultiVideoPlayer", appStoreID: "6758890486",
            availability: .worldwide, summaries: ["en": "Play up to 9 videos at once", "ja": "最大9本の動画を同時再生"]
        ),
        StandardDeveloperApp(
            name: "Obaket", bundleIdentifier: "com.jiikko.obaket", appStoreID: "6768261740",
            availability: .worldwide, summaries: ["en": "Cloud storage browser", "ja": "クラウドストレージブラウザ"]
        ),
        StandardDeveloperApp(
            name: "ThumbnailThumb", bundleIdentifier: "com.jiikko.thumbnailthumb", appStoreID: "6757274992",
            availability: .worldwide, summaries: ["en": "Thumbnail Maker for Creators", "ja": "サムネイル作成に特化したアプリ"]
        ),
        StandardDeveloperApp(
            name: "Multi-Video Player for Dropbox", bundleIdentifier: "com.jiikko.dropbox-video-player",
            appStoreID: "6756692198", availability: .worldwide, summaries: ["en": "Play multiple videos at once"]
        ),
        StandardDeveloperApp(
            name: "DualNote", bundleIdentifier: "com.jiikko.dualnote", appStoreID: "6759564454",
            availability: .japanOnly, summaries: ["en": "Side-by-side notes for macOS", "ja": "日記 × メモ エディタ"]
        ),
        StandardDeveloperApp(
            name: "ベビーノート", bundleIdentifier: "com.jiikko.babynote", appStoreID: "6758397772",
            availability: .japanOnly, summaries: ["ja": "授乳・睡眠・おむつをかんたん記録"]
        ),
        StandardDeveloperApp(
            name: "SnapTrim", bundleIdentifier: "com.jiikko.snaptrim", appStoreID: "6756988299",
            availability: .japanOnly, summaries: [:]
        ),
        StandardDeveloperApp(
            name: "DotfilesSyncer", bundleIdentifier: "com.dotfilessyncer.app", appStoreID: "6759445122",
            availability: .japanOnly, summaries: ["ja": "dotfiles を自動 Git 同期"]
        )
    ]

    /// 日本のストアフロントの国コード (StoreKit の `Storefront.countryCode` は ISO 3166-1 alpha-3)
    static let japanStorefront = "JPN"

    /// 一覧に出すアプリ。自分 (`excludingBundleIdentifier`) を外し、日本のみのアプリは日本のストアフロントのときだけ出す。
    /// ストアフロントが分からない (nil。オフライン・App Store から入れていないビルド) ときは日本のみのアプリを出さない
    /// (出すと、日本以外のユーザーを「利用できません」のページに送りうる)
    public static func otherApps(
        excludingBundleIdentifier ownBundleIdentifier: String?,
        storefrontCountryCode: String?
    ) -> [StandardDeveloperApp] {
        all.filter { app in
            guard app.bundleIdentifier != ownBundleIdentifier else { return false }
            switch app.availability {
            case .worldwide:
                return true
            case .japanOnly:
                return storefrontCountryCode == japanStorefront
            }
        }
    }
}
