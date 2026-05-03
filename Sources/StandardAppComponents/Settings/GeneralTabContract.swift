import SwiftUI

/// 設定ウィンドウ「General」タブの構成スロットを束ねる契約型。
/// `SettingsWindow` に渡して、各セクションの中身をアプリ側から差し込む。
public struct GeneralTabContract {
    let appearance: AnyView
    let language: AnyView
    let appSections: AnyView

    /// 必須スロット (`appearance` / `language`) と任意スロット (`appSections`) を受け取って
    /// contract を生成する。各 ViewBuilder は General タブの `Form` 配下で評価される。
    public init<Appearance: View, Language: View, AppSections: View>(
        @ViewBuilder appearance: () -> Appearance,
        @ViewBuilder language: () -> Language,
        @ViewBuilder appSections: () -> AppSections = { EmptyView() }
    ) {
        self.appearance = AnyView(appearance())
        self.language = AnyView(language())
        self.appSections = AnyView(appSections())
    }
}
