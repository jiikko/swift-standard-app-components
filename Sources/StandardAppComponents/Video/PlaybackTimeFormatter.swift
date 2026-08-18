import Foundation

/// 再生時刻の表示整形の正本。1 時間超で "時:分:秒" に切り替える。
///
/// consumer 側での自前整形は「90 分を "90:00" と表示する」系の再発源になるため、
/// 動画再生 UI の時刻ラベルは必ずここを経由する。
public enum PlaybackTimeFormatter {
    /// 表示スタイル。consumer 間の表記差 (分のゼロ埋め有無) を吸収する。
    public struct Style: Sendable {
        /// true なら 1 時間未満を "MM:SS" (分もゼロ埋め)、false なら "M:SS"。
        /// 時間表示 ("H:MM:SS") の桁は共通で、時のみ非ゼロ埋め。
        public var padsMinutesToTwoDigits: Bool

        /// - Parameter padsMinutesToTwoDigits: 分のゼロ埋め有無 (既定 false = "M:SS")
        public init(padsMinutesToTwoDigits: Bool = false) {
            self.padsMinutesToTwoDigits = padsMinutesToTwoDigits
        }
    }

    // MARK: - 整数秒入口 (桁は値自身で決める)

    /// ミリ秒を整形する (**切り捨て**。`playbackTime` 系の四捨五入とは丸め方向が
    /// 異なるので、同じ値を両入口に渡すと 1 秒ズレうる — 入口を混ぜないこと)。
    /// 負値は 0 に clamp。
    public static func format(milliseconds: Int, style: Style = Style()) -> String {
        format(seconds: max(0, milliseconds / 1_000), style: style)
    }

    /// 秒を整形する。1 時間以上で "時:分:秒" に切替。負値は 0 に clamp。
    public static func format(seconds: Int, style: Style = Style()) -> String {
        let clamped = max(0, seconds)
        return string(totalSeconds: clamped, showsHours: clamped >= 3_600, style: style)
    }

    // MARK: - 再生 transport 入口 (桁は totalDuration で固定する)

    /// 再生時刻を整形する。桁 (時間表示の有無) は `totalDuration` で決める —
    /// 経過時刻が 1 時間未満でも総尺が 1 時間以上なら "H:MM:SS" にし、再生中に
    /// 表示幅が増減しないようにする。`totalDuration` が nil / 非有限のときは
    /// `seconds` 自身で桁を決める。非有限 / 負値の `seconds` は 0 に倒す。
    ///
    /// 入力は AVFoundation の `CMTime.seconds` 等 (信頼できない動画メタデータ由来)
    /// を想定し、非有限・負値・`Int` 変換境界超えを内部で sanitize する。
    public static func playbackTime(
        _ seconds: TimeInterval?,
        totalDuration: TimeInterval?,
        style: Style = Style()
    ) -> String {
        let secs = sanitizedSeconds(seconds) ?? 0
        let scale = sanitizedSeconds(totalDuration) ?? secs
        return string(totalSeconds: secs, showsHours: max(scale, secs) >= 3_600, style: style)
    }

    /// 残り再生時間を "-MM:SS" / "-H:MM:SS" に整形する。丸め誤差等で
    /// `currentTime > totalDuration` でも負にならない ("-00:00" 止まり)。
    public static func remainingPlaybackTime(
        currentTime: TimeInterval?,
        totalDuration: TimeInterval?,
        style: Style = Style()
    ) -> String {
        let total = sanitizedSeconds(totalDuration) ?? 0
        let remaining = max(0, total - (sanitizedSeconds(currentTime) ?? 0))
        return "-" + string(totalSeconds: remaining, showsHours: total >= 3_600, style: style)
    }

    // MARK: - Internal

    /// 非有限 / 負値を nil に倒し、有効値は秒単位で四捨五入する。
    /// `Int(Double)` は Int.max 近傍で trap するため clamp する — `isFinite` でも
    /// timescale=1 + 巨大 value なら有限のまま Int 変換境界を超えうる
    /// (「Int に収まる」の保証にはならない)。
    private static func sanitizedSeconds(_ value: TimeInterval?) -> Int? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        let rounded = value.rounded()
        guard rounded < TimeInterval(Int.max) else { return Int.max }
        return Int(rounded)
    }

    private static func string(totalSeconds: Int, showsHours: Bool, style: Style) -> String {
        if showsHours {
            return String(
                format: "%d:%02d:%02d",
                totalSeconds / 3_600, (totalSeconds / 60) % 60, totalSeconds % 60
            )
        }
        let minutesFormat = style.padsMinutesToTwoDigits ? "%02d:%02d" : "%d:%02d"
        return String(format: minutesFormat, totalSeconds / 60, totalSeconds % 60)
    }
}
