import AppKit

/// シングルクリック遅延なしでダブルクリックを検出するための helper。
///
/// ## なぜ `TapGesture(count: 2)` を使わないか
/// SwiftUI / AppKit は同じ view に `TapGesture(count: 2)` が attach されていると、
/// 1 回目の tap が来た時点で single としては発火せず、`NSEvent.doubleClickInterval`
/// (≈ 250-500ms) のあいだ「2 回目が来るか」を待つ。これによりシングルクリックの
/// レスポンスが体感ラグになる。
///
/// この detector は「いま来た click だけ」を見て、前回の click 時刻・ターゲットと
/// 比較するため、未来の 2 click 目を待たない (= single は即時発火)。`NSTableView` の
/// `primaryAction` のような native なダブルクリック機構を持たない `LazyVGrid` /
/// 任意の `Button` ベース UI で「即時 single + ダブルクリック起動」を両立させたい
/// ときに使う。
///
/// ## 同一ターゲット判定の 2 モード
/// 「直前の click と今回の click が同じターゲットか」の判定方法を 2 つ持つ。
/// **1 instance につき 1 モードだけを使うこと。** 両 method を交互に呼ぶとモードが
/// 切り替わり、モード跨ぎの click 系列は常に single 起点に戻る (= double にならない)。
///
/// - **位置モード** `checkDoubleClick(at:)`: 直前 click との距離が `distanceThreshold`
///   (既定 10pt) 以内なら同一ターゲット。canvas 上の実座標で複数ターゲットを 1 instance
///   で識別したいとき (例: ThumbnailThumb の要素 double-click)。row / cell ごとに別
///   instance を持つ運用なら `at: .zero` 固定でもよい (instance 自体がターゲットを
///   兼ねるため距離は常に 0)。
/// - **id モード** `checkDoubleClick(id:)`: 直前 click と id が等しければ同一ターゲット。
///   tab / row など離散的な識別子で 1 instance を共有して判定したいとき (例: DualNote の
///   project tab)。1 instance には **同じ型の id だけ** を渡すこと (型が違えば別ターゲット
///   扱い。`AnyHashable` の数値ブリッジ等で別 id 型が誤一致するのを型でも弾く)。
///
/// ## 使用方法
/// ```swift
/// // 位置モード (canvas 実座標)
/// if detector.checkDoubleClick(at: value.location) { activate(element) }
///
/// // id モード (離散ターゲット)
/// if detector.checkDoubleClick(id: project.id) { open(project) }
/// ```
public final class DoubleClickDetector {
    private enum Mode {
        case location
        case id
    }

    /// `NSEvent.doubleClickInterval` の floor (秒)。**0 以上を想定** (負値を渡しても
    /// `max(systemInterval, minimumInterval)` で system 値がそのまま使われるだけで、
    /// クラッシュはしない)。
    ///
    /// **なぜ floor が必要か** (= obaket 2026-05-23 観測): macOS の
    /// "Double-click speed" を最 Fast に振ったユーザー環境では
    /// `NSEvent.doubleClickInterval` が 0.15s = 150ms にまで縮む。この値をそのまま
    /// 使うと、通常の double click (200-300ms 間隔) すら double として認識されず、
    /// 起動 (open / activate) しない。
    ///
    /// **300ms の根拠**: macOS の "Fast" 設定で約 0.25s、"Default" で約 0.5s。300ms を
    /// floor にすると Fast ユーザーの設定意図は尊重しつつ Fastest (0.15s) の極端な
    /// 短さは救う。system 設定が floor より長い場合はそれに従う (= ユーザー設定を
    /// 上書きしない)。floor を入れたくない consumer は `minimumInterval: 0` を渡す。
    private let minimumInterval: TimeInterval

    /// ダブルクリックと認識する最大距離 (point)。**位置モード (`checkDoubleClick(at:)`)
    /// 専用**で、id モードでは使われない。
    private let distanceThreshold: CGFloat

    private var lastClickTime: Date = .distantPast
    private var lastMode: Mode?
    private var lastClickLocation: CGPoint = .zero
    private var lastClickID: AnyHashable?
    private var lastClickIDType: Any.Type?

    /// - Parameters:
    ///   - minimumInterval: `NSEvent.doubleClickInterval` の floor (秒)。既定 0.3。
    ///     0 を渡すと floor 無効 (= system 設定の生値をそのまま使う)。
    ///   - distanceThreshold: 位置モードで double と認識する最大移動距離 (point)。既定 10。
    public init(minimumInterval: TimeInterval = 0.3, distanceThreshold: CGFloat = 10) {
        self.minimumInterval = minimumInterval
        self.distanceThreshold = distanceThreshold
    }

    /// 位置モードでダブルクリックかどうかを判定し、内部状態を更新する。
    ///
    /// - Parameter location: 現在の click 位置。row / cell 単位で detector を持つ運用なら
    ///   `.zero` 固定で問題ない。
    /// - Returns: 直前 click から実効 interval 以内 かつ `distanceThreshold` 以内なら `true`。
    public func checkDoubleClick(at location: CGPoint) -> Bool {
        evaluate(at: location, now: .now, systemInterval: NSEvent.doubleClickInterval)
    }

    /// id モードでダブルクリックかどうかを判定し、内部状態を更新する。
    ///
    /// - Parameter id: click 対象の識別子。直前 click と **同じ型・同じ値** の id のときだけ
    ///   double になりうる。
    /// - Returns: 直前 click から実効 interval 以内 かつ 同一 id なら `true`。
    public func checkDoubleClick<ID: Hashable>(id: ID) -> Bool {
        evaluate(id: id, now: .now, systemInterval: NSEvent.doubleClickInterval)
    }

    /// 検出状態を明示的に reset (例: directory への cd-in / drag 開始で view が
    /// 置き換わる前に呼ぶ)。
    public func reset() {
        lastClickTime = .distantPast
        lastMode = nil
        lastClickLocation = .zero
        lastClickID = nil
        lastClickIDType = nil
    }

    // MARK: - 決定論的判定 (test seam)

    /// 位置モード判定の純粋部分。production では `checkDoubleClick(at:)` が `.now` /
    /// `NSEvent.doubleClickInterval` を流す。test は `now` / `systemInterval` を注入して
    /// 決定論的に評価する。
    func evaluate(at location: CGPoint, now: Date, systemInterval: TimeInterval) -> Bool {
        let isSameTarget = lastMode == .location &&
            hypot(location.x - lastClickLocation.x, location.y - lastClickLocation.y) < distanceThreshold
        return resolve(now: now, systemInterval: systemInterval, isSameTarget: isSameTarget) {
            lastMode = .location
            lastClickLocation = location
        }
    }

    /// id モード判定の純粋部分。
    func evaluate<ID: Hashable>(id: ID, now: Date, systemInterval: TimeInterval) -> Bool {
        let boxed = AnyHashable(id)
        let isSameTarget = lastMode == .id &&
            lastClickIDType == ID.self &&
            lastClickID == boxed
        return resolve(now: now, systemInterval: systemInterval, isSameTarget: isSameTarget) {
            lastMode = .id
            lastClickID = boxed
            lastClickIDType = ID.self
        }
    }

    /// 時間判定 + floor + 連打 reset の共通コア。モード差分は `isSameTarget` と `record` のみ。
    private func resolve(now: Date, systemInterval: TimeInterval, isSameTarget: Bool, record: () -> Void) -> Bool {
        let effectiveInterval = max(systemInterval, minimumInterval)
        let isDoubleClick = now.timeIntervalSince(lastClickTime) < effectiveInterval && isSameTarget

        if isDoubleClick {
            // 連打 3 連が「double + double」と判定されないよう state を reset。
            reset()
        } else {
            lastClickTime = now
            record()
        }

        return isDoubleClick
    }
}
