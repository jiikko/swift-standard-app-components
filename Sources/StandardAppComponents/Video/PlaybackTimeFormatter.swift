import Foundation

/// 再生時刻の表示整形の正本。1 時間超で "時:分:秒" に切り替える。
///
/// consumer 側での自前整形は「90 分を "90:00" と表示する」系の再発源になるため、
/// 動画再生 UI の時刻ラベルは必ずここを経由する。
public enum PlaybackTimeFormatter {
    /// ミリ秒を "分:秒" (1 時間超は "時:分:秒") に整形する。負値は 0 に clamp。
    public static func format(milliseconds: Int) -> String {
        format(seconds: max(0, milliseconds / 1_000))
    }

    /// 秒を "分:秒" (1 時間超は "時:分:秒") に整形する。負値は 0 に clamp。
    public static func format(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60
        let remainingSeconds = clamped % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
