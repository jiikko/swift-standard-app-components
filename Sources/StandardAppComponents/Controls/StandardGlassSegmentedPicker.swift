import AppKit
import SwiftUI

/// macOS 26 のツールバーのセグメンテッドコントロールと同じ見え方の切り替え。標準のツールバーを使わない
/// 自前のタイトルバー (`.hiddenTitleBar` の上端の行) に置くためのもの。
///
/// 枠の無い文字を 1 つのカプセルに入れ、選んでいるものだけを塗る。カプセルは macOS 26 以降は Liquid Glass
/// (`glassEffect`)、それより前は塗り (`quaternarySystemFill`)。
///
/// 標準の `Picker` + `.pickerStyle(.segmented)` を使わない理由:
/// - `glassEffect` を重ねると、コントロール自身の枠とガラスの枠が二重になる (ガラスにガラスを重ねない)
/// - `NSSegmentedControl` はクリックで first responder を取りうる (キーボードナビゲーションが有効な環境)。
///   取ると、consumer が自前で受けている単キーのショートカットが止まる
///
/// 同じ行にある他のガラスの部品と溶け合わせるなら、consumer 側で `GlassEffectContainer` に入れる (macOS 26 以降)。
///
/// ```swift
/// StandardGlassSegmentedPicker(
///     GridLayout.allCases,
///     selection: viewModel.layout,
///     title: \.rawValue
/// ) { viewModel.updateLayout($0) }
///
/// // 文字の代わりに SF Symbols で並べる。label はカーソルを乗せたときの説明と読み上げに使う
/// StandardGlassSegmentedPicker(
///     GridLayout.allCases,
///     selection: viewModel.layout,
///     systemImage: { $0.symbolName },
///     label: \.rawValue
/// ) { viewModel.updateLayout($0) }
/// ```
///
/// 選んだ値の持ち主は consumer。この view は `selection` を表示し、押されたら `onSelect` を呼ぶだけで、自分では値を変えない。
/// 文字は `onTapGesture` で受けるので、この上からウィンドウはドラッグで動かせない。
/// ダブルクリックは 2 回の押下として届く (タイトルバーの行でウィンドウの拡大を止めるのは consumer の仕事)
public struct StandardGlassSegmentedPicker<Value: Hashable>: View {
    private let options: [Value]
    private let selection: Value
    private let content: (Value) -> SegmentContent
    private let onSelect: (Value) -> Void

    /// - Parameters:
    ///   - options: 左から並べる値。同じ値を 2 度入れない (`id` に使う)
    ///   - selection: 今選んでいる値。`options` に無い値なら、どれも塗らない
    ///   - title: 表示する文字 (verbatim。ローカライズが要るなら consumer が解決した文字を返す)
    ///   - onSelect: 押された値。今選んでいる値を押したときも呼ぶ
    public init(
        _ options: [Value],
        selection: Value,
        title: @escaping (Value) -> String,
        onSelect: @escaping (Value) -> Void
    ) {
        self.options = options
        self.selection = selection
        self.content = { .text(title($0)) }
        self.onSelect = onSelect
    }

    /// 文字の代わりに SF Symbols のアイコンで並べる。
    /// - Parameters:
    ///   - systemImage: 表示する SF Symbols の名前
    ///   - label: カーソルを乗せたときの説明 (`help`) と読み上げに使う文字 (verbatim。ローカライズが要るなら consumer が解決した文字を返す)
    public init(
        _ options: [Value],
        selection: Value,
        systemImage: @escaping (Value) -> String,
        label: @escaping (Value) -> String,
        onSelect: @escaping (Value) -> Void
    ) {
        self.options = options
        self.selection = selection
        self.content = { .symbol(name: systemImage($0), label: label($0)) }
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                segmentLabel(content(option), isSelected: isSelected)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, GlassSegmentedMetrics.segmentHorizontalPadding)
                    .frame(minWidth: GlassSegmentedMetrics.segmentMinWidth, minHeight: GlassSegmentedMetrics.segmentHeight)
                    .background {
                        if isSelected {
                            Capsule().fill(Color.primary.opacity(0.12))
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        onSelect(option)
                    }
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(GlassSegmentedMetrics.inset)
        .fixedSize()
        .modifier(GlassSegmentedSurface())
    }

    @ViewBuilder
    private func segmentLabel(_ content: SegmentContent, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        switch content {
        case .text(let title):
            Text(verbatim: title)
                .font(.system(size: GlassSegmentedMetrics.fontSize, weight: weight))
        case let .symbol(name, label):
            Image(systemName: name)
                .font(.system(size: GlassSegmentedMetrics.symbolSize, weight: weight))
                .help(Text(verbatim: label))
                .accessibilityLabel(Text(verbatim: label))
        }
    }
}

/// 1 つの区切りに出すもの。generic な型の中に置くと `Value` ごとに別の型になるだけなので外に出す
private enum SegmentContent {
    case text(String)
    case symbol(name: String, label: String)
}

/// 寸法。generic な型の中には static な格納プロパティを置けないので外に出す
private enum GlassSegmentedMetrics {
    static let segmentMinWidth: CGFloat = 38
    static let segmentHeight: CGFloat = 24
    static let segmentHorizontalPadding: CGFloat = 8
    static let inset: CGFloat = 3
    static let fontSize: CGFloat = 12
    static let symbolSize: CGFloat = 13
}

/// カプセルの下地。macOS 26 以降はガラス、それより前は塗り
private struct GlassSegmentedSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(Color(nsColor: .quaternarySystemFill), in: .capsule)
        }
    }
}
