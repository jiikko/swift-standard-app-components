import SwiftUI

// MARK: - Toast Container View

/// 任意の親 View の上に重ねて、`ToastManaging` の現在トーストを **画面右下** に
/// 表示する layout コンテナ。
///
/// 通常は `View.standardToastContainer(_:)` modifier 経由で使う:
///
/// ```swift
/// ContentView()
///     .standardToastContainer(myAppServices.toastManager)
/// ```
///
/// 設計判断 (lib 化での変更点):
/// - ThumbnailThumb 由来実装は `Environment(\.toastManager)` 経由でマネージャーを
///   取得していたが、lib 側では Environment Key を提供せず **明示的な init 引数**
///   で受け取る。理由: アプリ側がそれぞれの DI 構造 (Factory / Environment Key 等)
///   を持っており、lib が特定の Environment Key を強制すると相性が悪いため。
public struct ToastContainerView: View {
    private enum Layout {
        static let maxWidth: CGFloat = 380
        static let trailingPadding: CGFloat = 20
        static let bottomPadding: CGFloat = 20
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.8
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // existential で受ける。Generic 型にすると `static let Layout` が使えなくなる
    // (Swift "static stored properties not supported in generic types") ため。
    private let manager: any ToastManaging

    /// - Parameter manager: 現在トースト・dismiss を駆動するマネージャー。
    ///   **Observation framework (`@Observable`) 前提**。`currentToast` の読み取りは
    ///   body 内で行うため、`@Observable` ならアクセス追跡で更新が伝搬する。
    ///   従来の `ObservableObject` (`@Published`) はこの container では更新が
    ///   伝搬しない (`@ObservedObject` を持たないため) 点に注意。consumer が
    ///   独自実装する場合も `@Observable` を採用すること。
    public init(manager: any ToastManaging) {
        self.manager = manager
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            if let toast = manager.currentToast {
                ToastView(toast: toast) {
                    manager.dismiss()
                }
                .frame(maxWidth: Layout.maxWidth)
                .padding(.trailing, Layout.trailingPadding)
                .padding(.bottom, Layout.bottomPadding)
                .transition(toastTransition)
                .zIndex(1)
            }
        }
        .animation(
            reduceMotion ? .none : .spring(
                response: Layout.springResponse,
                dampingFraction: Layout.springDamping
            ),
            value: manager.currentToast?.id
        )
        .allowsHitTesting(manager.currentToast != nil)
    }

    private var toastTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        )
    }
}

// MARK: - View Extension

extension View {
    /// 画面右下に標準トースト UI を重ねる。`ToastContainerView` を内部で配置するだけ
    /// の薄い modifier。
    public func standardToastContainer(_ manager: any ToastManaging) -> some View {
        ZStack {
            self
            ToastContainerView(manager: manager)
        }
    }
}
