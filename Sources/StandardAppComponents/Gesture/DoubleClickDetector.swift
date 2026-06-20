import AppKit

/// シングルクリック遅延なしでダブルクリックを検出するための helper。
///
/// ## なぜ `TapGesture(count: 2)` を使わないか
/// SwiftUI / AppKit は同じ view に `TapGesture(count: 2)` が attach されていると、
/// 1 回目の tap が来た時点で single としては発火せず、`NSEvent.doubleClickInterval`
/// (≈ 250-500ms) のあいだ「2 回目が来るか」を待つ。これによりシングルクリックの
/// レスポンスが体感ラグになる。
///
/// この detector は「いま来た click だけ」を見て、前回の click 時刻・位置と比較する
/// ため、未来の 2 click 目を待たない (= single は即時発火)。`NSTableView` の
/// `primaryAction` のような native なダブルクリック機構を持たない `LazyVGrid` /
/// 任意の `Button` ベース UI で「即時 single + ダブルクリック起動」を両立させたい
/// ときに使う。
///
/// ## 使用方法
/// ```swift
/// @State private var doubleClickDetector = DoubleClickDetector()
///
/// Button {
///     // single click 動作 (即時)
///     viewModel.select(object)
///
///     // double click 動作 (前回 click から interval 内なら true)
///     if doubleClickDetector.checkDoubleClick() {
///         viewModel.activate(object)
///     }
/// } label: { ... }
/// ```
///
/// ## 配置に関する注意 (= row / cell ごとに別 instance を持つこと)
/// `distanceThreshold` は同位置 (既定 10pt 以内) を double 条件にしている。row / cell
/// が **同じ detector instance を共有**し、かつ呼び出し側で `at:` を省略 (= `.zero`
/// 固定) すると、別 row への 2 連 click が同位置扱いで double 誤判定する。
///
/// → callsite 側で `@State` を **list の row / cell の View 内に持つ** ことで、
/// SwiftUI の view identity (`ForEach` の id) ごとに別 instance を割り当てる。
public final class DoubleClickDetector {
    /// `NSEvent.doubleClickInterval` の floor (秒)。
    ///
    /// **なぜ floor が必要か** (= obaket 2026-05-23 観測): macOS の
    /// "Double-click speed" を最 Fast に振ったユーザー環境では
    /// `NSEvent.doubleClickInterval` が 0.15s = 150ms にまで縮む。
    /// この値をそのまま使うと、通常の double click (200-300ms 間隔)
    /// すら double として認識されず、起動 (open / activate) しない。
    ///
    /// **300ms の根拠**: macOS の "Fast" 設定 (= デフォルトより速い側) で
    /// 約 0.25s、"Default" で約 0.5s。300ms を floor にすると、Fast 設定
    /// ユーザーの設定意図 (= 速め判定希望) はぎりぎり尊重しつつ、Fastest
    /// 設定 (0.15s) の極端な短さは救う。
    ///
    /// system 設定が floor より長い場合はそれに従う (= ユーザー設定を上書き
    /// しない方向)。Finder / NSCollectionView などの system UI も内部的に
    /// 同様のクランプを噛ませていると推測される (= 0.15s 設定でも Finder
    /// のアイコン double-click open は動く)。
    private let minimumInterval: TimeInterval

    /// ダブルクリックと認識する最大距離 (point)。
    /// 同じ row / cell の中の click は位置がほぼ動かないので、`at:` を省略
    /// (= `.zero`) してもこの閾値内に収まる。
    private let distanceThreshold: CGFloat

    private var lastClickTime: Date = .distantPast
    private var lastClickLocation: CGPoint = .zero

    /// - Parameters:
    ///   - minimumInterval: `NSEvent.doubleClickInterval` の floor (秒)。既定 0.3。
    ///     0 を渡すと floor 無効 (= system 設定の生値をそのまま使う)。
    ///   - distanceThreshold: double と認識する最大移動距離 (point)。既定 10。
    public init(minimumInterval: TimeInterval = 0.3, distanceThreshold: CGFloat = 10) {
        self.minimumInterval = minimumInterval
        self.distanceThreshold = distanceThreshold
    }

    /// ダブルクリックかどうかを判定し、内部状態を更新する。
    ///
    /// - Parameter location: 現在の click 位置。row / cell 単位で detector を
    ///   持つ運用なら省略 (= `.zero` 固定) で問題ない。
    /// - Returns: 前回 click から実効 interval 以内 かつ `distanceThreshold`
    ///   以内なら `true`。
    public func checkDoubleClick(at location: CGPoint = .zero) -> Bool {
        evaluate(at: location, now: Date.now, systemInterval: NSEvent.doubleClickInterval)
    }

    /// 検出状態を明示的に reset (例: directory への cd-in で view が
    /// 置き換わる前に呼ぶ)。
    public func reset() {
        lastClickTime = .distantPast
        lastClickLocation = .zero
    }

    /// 判定の純粋部分。production では `checkDoubleClick(at:)` が `Date.now` /
    /// `NSEvent.doubleClickInterval` を流す。test は `now` / `systemInterval` を
    /// 注入して決定論的に評価する (= 実時間 sleep / 実機の system 設定に依存しない)。
    func evaluate(at location: CGPoint, now: Date, systemInterval: TimeInterval) -> Bool {
        let effectiveInterval = max(systemInterval, minimumInterval)
        let timeSinceLastClick = now.timeIntervalSince(lastClickTime)
        let distance = hypot(location.x - lastClickLocation.x, location.y - lastClickLocation.y)

        let isDoubleClick = timeSinceLastClick < effectiveInterval &&
            distance < distanceThreshold

        if isDoubleClick {
            // 連打 3 連が「double + double」と判定されないよう state を reset。
            lastClickTime = .distantPast
            lastClickLocation = .zero
        } else {
            lastClickTime = now
            lastClickLocation = location
        }

        return isDoubleClick
    }
}
