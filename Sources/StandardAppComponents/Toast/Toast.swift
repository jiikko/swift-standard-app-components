import SwiftUI

// MARK: - Toast Model

/// 1 件のトースト通知データ。`ToastManaging` のキューに入って順に表示される。
public struct Toast: Identifiable, Equatable {
    /// 一意 ID。同じ id 同士のみ等価扱い。
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

    /// - Parameters:
    ///   - id: 既存の Toast を上書き表示したい時のみ明示。通常は省略 (`UUID()`)。
    ///   - style: 見た目とアクセシビリティラベルに影響。
    ///   - title: 必須の 1 行目。
    ///   - message: 補足。`nil` ならタイトルのみ表示。
    ///   - duration: 自動消去までの秒数。デフォルト 3.0。
    ///   - action: 任意のアクションボタン。`nil` なら閉じるボタンのみ。
    public init(
        id: UUID = UUID(),
        style: Style,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 3.0,
        action: ToastAction? = nil
    ) {
        self.id = id
        self.style = style
        self.title = title
        self.message = message
        self.duration = duration
        self.action = action
    }

    public static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
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
public struct ToastAction {
    /// ボタンに表示する文字列 (例: 「Finder で開く」)。
    public let title: String
    /// タップ時に呼ばれる callback。`@Sendable` で actor 越境を許す。
    public let handler: @Sendable () -> Void

    /// - Parameters:
    ///   - title: ボタンに表示する文字列。
    ///   - handler: タップ時に呼ぶ callback。`@Sendable` で MainActor 越境を許す。
    @preconcurrency
    public init(title: String, handler: @Sendable @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}
