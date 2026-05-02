import SwiftUI

public struct SettingsWindow<AppTabs: View>: View {
    private let general: GeneralTabContract
    private let appTabs: () -> AppTabs
    private let maxHeight: CGFloat?

    /// - Parameters:
    ///   - general: General タブのスロット契約
    ///   - maxHeight: タブ切り替え時にウィンドウが伸びる **上限の高さ**。`nil` (デフォルト) なら
    ///     上限なしで TabView の自然なサイズに従う。値を指定すると、各タブの自然な高さが
    ///     上限に達するまではタブごとに高さが可変、超える分はそのタブ内 (`Form` 等) の
    ///     スクロールで吸収される。**全タブの高さを揃える従来挙動には戻らない** ことに注意。
    ///   - appTabs: アプリ独自の追加タブ
    public init(
        general: GeneralTabContract,
        maxHeight: CGFloat? = nil,
        @ViewBuilder appTabs: @escaping () -> AppTabs = { EmptyView() }
    ) {
        self.general = general
        self.maxHeight = maxHeight
        self.appTabs = appTabs
    }

    public var body: some View {
        TabView {
            GeneralTabContent(contract: general)
                .tabItem { Label("General", systemImage: "gearshape") }
                .keyboardShortcut("1", modifiers: .command)

            appTabs()
        }
        // タブ切り替えで高さがそのタブの自然なサイズに追従するように fixedSize で縦に貼り付ける。
        // 上に frame(maxHeight:) を被せることで「上限まで伸ばすが超えない」を実現する。
        .frame(maxHeight: maxHeight ?? .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .standardSettingsBehaviors()
    }
}
