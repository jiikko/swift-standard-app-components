import SwiftUI

public struct SettingsWindow<AppTabs: View>: View {
    private let general: GeneralTabContract
    private let width: CGFloat?
    private let heights: [String: CGFloat]
    private let defaultHeight: CGFloat
    private let appTabs: () -> AppTabs

    @State private var selectedTabId: String
    /// 実描画用の高さ。`targetHeight` (= heights[selectedTabId] ?? defaultHeight) を
    /// `withAnimation` 経由で書き込むことで「アニメーションは frame height だけに限定」
    /// する。`.animation(value:)` をルートに当てると TabView サブツリーまで
    /// アニメーションが伝播するため避ける (Codex review R2 #2)。
    @State private var animatedHeight: CGFloat?

    /// General タブを識別する固定 tag。consumer の `appTabs` 側もすべての追加タブに
    /// `.tag("...")` を当てる必要がある (selection binding が String 一致で動くため)。
    ///
    /// - Note: `SettingsWindow` は `AppTabs: View` で generic 化されているため
    ///   consumer から参照する時 `SettingsWindow<EmptyView>.generalTabId` のように
    ///   型パラメータ指定が必要になる。簡潔に参照したい場合は
    ///   `SettingsWindowConstants.generalTabId` を使うこと (値は同じ)。
    public static var generalTabId: String { SettingsWindowConstants.generalTabId }

    /// - Parameters:
    ///   - general: General タブのスロット契約
    ///   - width: ウィンドウの横幅 (全タブ共通)。`nil` (デフォルト) なら TabView の
    ///     自然な幅 (タブ内コンテンツ依存) に従う。Settings ウィンドウは慣例的に
    ///     全タブで横幅を揃えるため、per-tab ではなく単一値で受け取る。
    ///   - heights: タブの tag (`String`) → そのタブを表示する時のウィンドウ高さの map。
    ///     存在しない tag は `defaultHeight` にフォールバック。タブを切り替えると
    ///     対応する高さに **アニメーション付きで変動** する。consumer 側で動的に
    ///     map を更新した場合も、現在表示中のタブを含めて反映される (derived 値)。
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
    }

    public var body: some View {
        TabView(selection: $selectedTabId) {
            GeneralTabContent(contract: general)
                .tag(Self.generalTabId)
                .tabItem {
                    Label {
                        Text("General", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                .keyboardShortcut("1", modifiers: .command)

            appTabs()
        }
        // selection 切り替えで height を変更する。fixedSize ではなく明示的な
        // .frame(height:) にしているのは、TabView の "ideal" が全タブ max にキャッシュ
        // されてしまい、短いタブに切り替えても縮まない挙動を回避するため。
        // width は nil なら .frame 側で no-op (制約しない) になる。
        //
        // height は `targetHeight` (heights[selectedTabId] ?? defaultHeight) を
        // 真実の所在として保ち、`animatedHeight` は描画用キャッシュ。
        // `.animation(value:)` をルートに当てると TabView サブツリーにも animation が
        // 伝播するため、`withAnimation` ブロック内で代入してアニメーション対象を
        // frame height に限定する。
        //
        // animation は overshoot しない easeInOut。spring(damping<1.0) だと身長が
        // 縮むタブに切り替えた瞬間に下端が目標より小さい高さまで突き抜けてから戻り、
        // 上端の content が「上にバウンス」して見えるため。
        .frame(width: width, height: animatedHeight ?? targetHeight)
        .onAppear {
            // 初期値が未設定なら現在の targetHeight を non-animated に流し込む。
            if animatedHeight == nil {
                animatedHeight = targetHeight
            }
        }
        .onChange(of: targetHeight) { _, newValue in
            withAnimation(.easeInOut(duration: 0.25)) {
                animatedHeight = newValue
            }
        }
        .standardSettingsBehaviors()
    }

    /// 現在の `selectedTabId` に対応する目標高さ。`heights` map に entry がなければ
    /// `defaultHeight` にフォールバック。derived 値なので `heights` / `defaultHeight` を
    /// consumer 側で動的に変更しても直ちに反映される (`onChange(of: targetHeight)`
    /// 経由で animatedHeight に伝搬し、frame height のみアニメーションする)。
    private var targetHeight: CGFloat {
        heights[selectedTabId] ?? defaultHeight
    }
}
