import SwiftUI

// MARK: - Toast Container View

/// 任意の親 View の上に重ねて、`ToastManaging` の表示中のトースト (`visibleToasts`) を **画面右下** に
/// 縦に並べて表示する layout コンテナ。新しいトーストを上に積む (下に足すと、既にある吹き出しが全部押し上がり、
/// 読んでいる吹き出しがカーソルの下から逃げるため)。1 件ずつ出す manager では今までどおり 1 件だけ出る。
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
        static let stackSpacing: CGFloat = 8
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.8
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // existential で受ける。Generic 型にすると `static let Layout` が使えなくなる
    // (Swift "static stored properties not supported in generic types") ため。
    private let manager: any ToastManaging
    private let onToastFrameChange: ((CGRect?) -> Void)?

    /// `onToastFrameChange` が報告する矩形の座標空間 (この container の左上が原点)
    private static let coordinateSpaceName = "StandardAppComponents.ToastContainer"

    /// - Parameter manager: 現在トースト・dismiss を駆動するマネージャー。
    ///   **Observation framework (`@Observable`) 前提**。`currentToast` の読み取りは
    ///   body 内で行うため、`@Observable` ならアクセス追跡で更新が伝搬する。
    ///   従来の `ObservableObject` (`@Published`) はこの container では更新が
    ///   伝搬しない (`@ObservedObject` を持たないため) 点に注意。consumer が
    ///   独自実装する場合も `@Observable` を採用すること。
    ///   - onToastFrameChange: 吹き出しの矩形が変わるたびに呼ぶ (省略可)。複数を並べているときは、並べた全体の
    ///     矩形 (吹き出しの間と、幅の狭い吹き出しの横の空きも含む)。座標はこの container の
    ///     左上が原点で、右と下の余白は含まない。トーストが全部消えたら nil。AppKit の view に重ねた
    ///     container が、吹き出しの上だけクリックを受けて他を下へ通すために使う (container は全面を
    ///     覆うので、吹き出しの位置を知らないと全面のクリックを奪う。screen-share-app issue 853)。
    ///     退場のフェード中は既に nil になる
    public init(manager: any ToastManaging, onToastFrameChange: ((CGRect?) -> Void)? = nil) {
        self.manager = manager
        self.onToastFrameChange = onToastFrameChange
    }

    public var body: some View {
        let toasts = manager.visibleToasts
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            // 並びは空でも描く。`if` で並びごと出し入れすると、空から 1 件になるときに挿入されるのが並びになり、
            // 吹き出しに付けた transition (右からの slide-in) が効かない
            VStack(alignment: .trailing, spacing: Layout.stackSpacing) {
                // 新しいものを上に積む
                ForEach(toasts.reversed().map(BubbleItem.init)) { item in
                    bubble(for: item.toast)
                }
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(Self.coordinateSpaceName))
            } action: { frame in
                // 空の並びの矩形 (大きさ 0) は報告しない。全部消えたら nil (下の onChange)
                onToastFrameChange?(toasts.isEmpty ? nil : frame)
            }
            .padding(.trailing, Layout.trailingPadding)
            .padding(.bottom, Layout.bottomPadding)
            .zIndex(1)
        }
        .animation(
            reduceMotion ? .none : .spring(
                response: Layout.springResponse,
                dampingFraction: Layout.springDamping
            ),
            value: toasts.map(\.id)
        )
        .allowsHitTesting(!toasts.isEmpty)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .onChange(of: toasts.isEmpty) { _, isEmpty in
            if isEmpty { onToastFrameChange?(nil) }
        }
    }

    /// `ForEach` に渡す包み。`Toast` をそのまま渡すと、`ForEach` は要素を `Toast` の `==` (id しか比べない) で比べ、
    /// 同じ id のまま中身を置き換えた (`uniqueKey` での置き換え) 吹き出しを描き直さない。Equatable にしないことで毎回描き直させる。
    private struct BubbleItem: Identifiable {
        let toast: Toast
        var id: Toast.ID { toast.id }
    }

    private func bubble(for toast: Toast) -> some View {
        ToastView(toast: toast) {
            manager.dismiss(id: toast.id)
        }
        // マウスが乗っている間は自動消去を止める (長い文を読み切るため)
        .onHover { isHovering in
            if isHovering {
                manager.pauseAutoDismiss(for: toast.id)
            } else {
                manager.resumeAutoDismiss(for: toast.id)
            }
        }
        // 乗せたまま吹き出しが消える (ウィンドウを閉じる等) と onHover(false) が来ないことがあり、止めたまま
        // 残ると後続のトーストもキューで待ち続ける。消えたら解く (id が違えば何もしないので、次のトーストは動かさない)
        .onDisappear {
            manager.resumeAutoDismiss(for: toast.id)
        }
        .frame(maxWidth: Layout.maxWidth)
        .transition(toastTransition)
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
    /// 画面右下に標準トースト UI を重ねる (表示中のトーストを縦に並べる)。`ToastContainerView` を内部で配置するだけ
    /// の薄い modifier。
    /// `onToastFrameChange` は ``ToastContainerView/init(manager:onToastFrameChange:)`` を参照。
    public func standardToastContainer(
        _ manager: any ToastManaging, onToastFrameChange: ((CGRect?) -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            ToastContainerView(manager: manager, onToastFrameChange: onToastFrameChange)
        }
    }
}
