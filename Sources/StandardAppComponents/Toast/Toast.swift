import SwiftUI

// MARK: - Toast Model

/// 1 件のトースト通知データ。`ToastManaging` のキューに入って順に表示される。
///
/// `Equatable` は **id のみで比較** する (Identifiable と整合させる目的)。
/// SwiftUI の `ForEach` / `.animation(value:)` 等で「トーストの入れ替わり」を
/// アニメーション粒度として扱うために、内容変化ではなく id 変化を「別物」と
/// する設計。ToastView 内で title / message を読み取って表示するため内容差分
/// での再描画は別途 SwiftUI が拾う。
public struct Toast: Identifiable, Equatable {
    /// 一意 ID。
    public let id: UUID
    /// success / error / warning / info の見た目バリエーション。
    public let style: Style
    /// タイトル (1 行目)。
    public let title: String
    /// 補足メッセージ (任意。最大 2 行で truncate される)。
    public let message: String?
    /// 自動消去までの秒数。
    public let duration: TimeInterval
    /// 任意のアクションボタン (例: 「Finder で開く」)。
    public let action: ToastAction?
    /// 重複させたくない通知に付けるキー。同じキーのトーストが表示中かキューに居れば、
    /// `ToastManager.show(_:)` は新しく足さずにそれを置き換える (元の id を引き継ぐので、渡した `id` は使われない)。
    /// `nil` なら重複を許す。
    public let uniqueKey: String?
    /// 右クリックのコンテキストメニューから `message` をコピーできるようにするか。
    /// `true` でも `message` が `nil` ならメニューは出ない (コピーする中身が無いため)。
    public let copiesMessage: Bool

    /// - Parameters:
    ///   - id: 通常は省略 (`UUID()`)。consumer 側で安定 id を持って同一トーストとして
    ///     扱いたい (例: 進捗通知を id 固定でログから追跡する) 場合のみ明示。
    ///     同じ id のトーストが表示中かキューに居れば、`ToastManager.show(_:)` はそれを置き換える
    ///     (表示を id で並べるので、同じ id を 2 件持たない)。
    ///   - style: 見た目とアクセシビリティラベルに影響。
    ///   - title: 必須の 1 行目。
    ///   - message: 補足。`nil` ならタイトルのみ表示。
    ///   - duration: 自動消去までの秒数。デフォルト 3.0。
    ///   - action: 任意のアクションボタン。`nil` なら閉じるボタンのみ。
    ///   - uniqueKey: 重複させたくない通知に付けるキー (`uniqueKey` プロパティを参照)。
    ///   - copiesMessage: `true` なら右クリックのコンテキストメニューから `message` をコピーできる。
    public init(
        id: UUID = UUID(),
        style: Style,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 3.0,
        action: ToastAction? = nil,
        uniqueKey: String? = nil,
        copiesMessage: Bool = false
    ) {
        self.id = id
        self.style = style
        self.title = title
        self.message = message
        self.duration = duration
        self.action = action
        self.uniqueKey = uniqueKey
        self.copiesMessage = copiesMessage
    }

    /// 中身はそのままで、id だけを差し替えた写し。置き換えで元の id を引き継ぐときに使う
    /// (吹き出しが入り直さず、ホバーの停止も同じ id のまま続く)。
    func replacingID(with id: UUID) -> Toast {
        Toast(
            id: id,
            style: style,
            title: title,
            message: message,
            duration: duration,
            action: action,
            uniqueKey: uniqueKey,
            copiesMessage: copiesMessage
        )
    }

    public static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }

    /// VoiceOver 等のアクセシビリティで読み上げる文字列。`title` を必須、`message` が
    /// あれば `". "` 区切りで連結する。`ToastView` の accessibility label として使う。
    /// View 側の private に閉じず model に持たせることで、文字列組み立ての契約を
    /// 単体テストできる (Codex review R2 ぼやきフォロー)。
    public var accessibilityLabel: String {
        guard let message else { return title }
        return "\(title). \(message)"
    }

    /// コンテキストメニューでコピーする文字列。`copiesMessage` が `true` のときだけ `message` を返す。
    /// 返すのは表示用に truncate された文ではなくモデルの全文。条件分岐を View 側に置かず
    /// model の pure 計算に寄せることで単体テストできる (`accessibilityLabel` と同じ方針)。
    public var messageToCopy: String? {
        copiesMessage ? message : nil
    }
}

// MARK: - Toast Style

/// Material Design 300〜400 系を参考にした柔らかい色合い。
/// View / View modifier で `style.iconName` / `style.backgroundColor` を参照する。
private enum ToastColorComponents {
    /// #66BB6A Soft Green
    static let successGreen = (red: 0.4, green: 0.733, blue: 0.416)
    /// #E57373 Soft Red
    static let errorRed = (red: 0.898, green: 0.451, blue: 0.451)
    /// #FFB74D Soft Amber
    static let warningAmber = (red: 1.0, green: 0.718, blue: 0.302)
    /// #64B5F6 Soft Blue
    static let infoBlue = (red: 0.392, green: 0.710, blue: 0.965)
}

extension Toast {
    /// トースト見た目のバリエーション。アイコン / 背景色 / 文字色が紐づく。
    public enum Style: Sendable {
        case success
        case error
        case warning
        case info

        /// SF Symbol 名。
        public var iconName: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "xmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }

        /// 背景色 (Material Design 300〜400 系)。
        public var backgroundColor: Color {
            switch self {
            case .success:
                let comp = ToastColorComponents.successGreen
                return Color(red: comp.red, green: comp.green, blue: comp.blue)
            case .error:
                let comp = ToastColorComponents.errorRed
                return Color(red: comp.red, green: comp.green, blue: comp.blue)
            case .warning:
                let comp = ToastColorComponents.warningAmber
                return Color(red: comp.red, green: comp.green, blue: comp.blue)
            case .info:
                let comp = ToastColorComponents.infoBlue
                return Color(red: comp.red, green: comp.green, blue: comp.blue)
            }
        }

        /// 前景色 (アイコン / 文字)。背景色とのコントラストを優先して常に白。
        public var foregroundColor: Color { .white }
    }
}

// MARK: - Toast Action

/// アクションボタン付き Toast に渡す callback。タップで `handler` が走り、
/// その後 Toast は自動的に dismiss される。
///
/// `handler` は SwiftUI の `Button` action から呼ばれるため `@MainActor`
/// に固定する。consumer 側の `ViewModel.someAction()` を直接呼び出せて、
/// background work が必要なら handler の中で `Task { ... }` に逃がす契約。
public struct ToastAction: Sendable {
    /// ボタンに表示する文字列 (例: 「Finder で開く」)。
    public let title: String
    /// タップ時に呼ばれる callback。`@MainActor` 固定で UI コールバックとして扱う。
    public let handler: @MainActor @Sendable () -> Void

    /// - Parameters:
    ///   - title: ボタンに表示する文字列。
    ///   - handler: タップ時に呼ぶ callback。`@MainActor` で `Button` action と同じ
    ///     isolation。background work は handler 内で `Task { ... }` に逃がす。
    public init(title: String, handler: @MainActor @Sendable @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}
