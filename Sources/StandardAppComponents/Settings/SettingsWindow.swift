import SwiftUI

public struct SettingsWindow<AppTabs: View>: View {
    private let general: GeneralTabContract
    private let width: CGFloat?
    private let heights: [String: CGFloat]
    private let defaultHeight: CGFloat
    private let appTabs: () -> AppTabs

    @State private var selectedTabId: String
    @State private var currentHeight: CGFloat

    /// General タブを識別する固定 tag。consumer の `appTabs` 側もすべての追加タブに
    /// `.tag("...")` を当てる必要がある (selection binding が String 一致で動くため)。
    public static var generalTabId: String { "general" }

    /// - Parameters:
    ///   - general: General タブのスロット契約
    ///   - width: ウィンドウの横幅 (全タブ共通)。`nil` (デフォルト) なら TabView の
    ///     自然な幅 (タブ内コンテンツ依存) に従う。Settings ウィンドウは慣例的に
    ///     全タブで横幅を揃えるため、per-tab ではなく単一値で受け取る。
    ///   - heights: タブの tag (`String`) → そのタブを表示する時のウィンドウ高さの map。
    ///     存在しない tag は `defaultHeight` にフォールバック。タブを切り替えると
    ///     対応する高さに **アニメーション付きで変動** する。
    ///   - defaultHeight: `heights` に entry がないタブに使うデフォルト高さ (default 350pt)。
    ///   - appTabs: アプリ独自の追加タブ。すべてに `.tag("...")` が必要。
    public init(
        general: GeneralTabContract,
        width: CGFloat? = nil,
        heights: [String: CGFloat] = [:],
        defaultHeight: CGFloat = 350,
        @ViewBuilder appTabs: @escaping () -> AppTabs = { EmptyView() }
    ) {
        self.general = general
        self.width = width
        self.heights = heights
        self.defaultHeight = defaultHeight
        self.appTabs = appTabs
        self._selectedTabId = State(initialValue: Self.generalTabId)
        self._currentHeight = State(initialValue: heights[Self.generalTabId] ?? defaultHeight)
    }

    public var body: some View {
        TabView(selection: $selectedTabId) {
            GeneralTabContent(contract: general)
                .tag(Self.generalTabId)
                .tabItem { Label("General", systemImage: "gearshape") }
                .keyboardShortcut("1", modifiers: .command)

            appTabs()
        }
        // selection 切り替えで height を変更する。fixedSize ではなく明示的な
        // .frame(height:) にしているのは、TabView の "ideal" が全タブ max にキャッシュ
        // されてしまい、短いタブに切り替えても縮まない挙動を回避するため。
        // width は nil なら .frame 側で no-op (制約しない) になる。
        .frame(width: width, height: currentHeight)
        .onChange(of: selectedTabId) { _, newId in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentHeight = height(for: newId)
            }
        }
        .standardSettingsBehaviors()
    }

    private func height(for tabId: String) -> CGFloat {
        heights[tabId] ?? defaultHeight
    }
}
