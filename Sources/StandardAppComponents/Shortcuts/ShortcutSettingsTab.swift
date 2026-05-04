import SwiftUI

/// Settings ウィンドウ用のショートカット設定タブ。
///
/// lib が担当するのは、VLCMultiVideoPlayer 由来の「context ごとのカード」「ショートカット
/// chip」「録音中表示」「reset ボタン」「Reset All」配置まで。録音、永続化、競合判定、
/// 実際のショートカット登録は consumer 側の責務。
public struct ShortcutSettingsTab: View {
    private let groups: [StandardShortcutGroup]
    private let recordingItemID: String?
    private let conflictWarning: String?
    private let resetAllTitle: LocalizedStringKey?
    private let onShortcutClick: (StandardShortcutItem) -> Void
    private let onReset: (StandardShortcutItem) -> Void
    private let onResetAll: () -> Void

    public init(
        groups: [StandardShortcutGroup],
        recordingItemID: String? = nil,
        conflictWarning: String? = nil,
        resetAllTitle: LocalizedStringKey? = nil,
        onShortcutClick: @escaping (StandardShortcutItem) -> Void,
        onReset: @escaping (StandardShortcutItem) -> Void,
        onResetAll: @escaping () -> Void
    ) {
        self.groups = groups
        self.recordingItemID = recordingItemID
        self.conflictWarning = conflictWarning
        self.resetAllTitle = resetAllTitle
        self.onShortcutClick = onShortcutClick
        self.onReset = onReset
        self.onResetAll = onResetAll
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(groups) { group in
                    ShortcutGroupCard(
                        group: group,
                        recordingItemID: recordingItemID,
                        conflictWarning: conflictWarning,
                        onShortcutClick: onShortcutClick,
                        onReset: onReset
                    )
                }

                if hasAnyCustomization {
                    HStack {
                        Spacer()
                        Button(action: onResetAll) {
                            if let resetAllTitle {
                                Text(resetAllTitle)
                            } else {
                                Text("Reset All to Default", bundle: .module)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasAnyCustomization: Bool {
        groups.contains { group in
            group.items.contains(where: \.isCustomized)
        }
    }
}

public struct StandardShortcutGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let items: [StandardShortcutItem]

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        items: [StandardShortcutItem]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }
}

public struct StandardShortcutItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let shortcut: String
    public let isEditable: Bool
    public let isCustomized: Bool

    public init(
        id: String,
        title: String,
        shortcut: String,
        isEditable: Bool = true,
        isCustomized: Bool = false
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.isEditable = isEditable
        self.isCustomized = isCustomized
    }
}

private struct ShortcutGroupCard: View {
    let group: StandardShortcutGroup
    let recordingItemID: String?
    let conflictWarning: String?
    let onShortcutClick: (StandardShortcutItem) -> Void
    let onReset: (StandardShortcutItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.headline)
                if let subtitle = group.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(group.items) { item in
                    ShortcutRow(
                        item: item,
                        isRecording: recordingItemID == item.id,
                        conflictWarning: recordingItemID == item.id ? conflictWarning : nil,
                        onShortcutClick: { onShortcutClick(item) },
                        onReset: { onReset(item) }
                    )

                    if item.id != group.items.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ShortcutRow: View {
    let item: StandardShortcutItem
    let isRecording: Bool
    let conflictWarning: String?
    let onShortcutClick: () -> Void
    let onReset: () -> Void

    var body: some View {
        ShortcutRowSkeleton(title: item.title) {
            if let conflictWarning, isRecording {
                Text(conflictWarning)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }

            if item.isEditable {
                Button(action: onShortcutClick) {
                    shortcutChip
                }
                .buttonStyle(.plain)
            } else {
                KeyboardShortcutChip(text: item.shortcut, foreground: .secondary)
            }

            if item.isEditable, item.isCustomized {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("Reset to Default", bundle: .module))
            } else {
                ShortcutRowSkeleton<EmptyView>.trailingAlignmentPlaceholder
            }
        }
    }

    @ViewBuilder
    private var shortcutChip: some View {
        if isRecording {
            KeyboardShortcutChip(
                text: String(localized: "Press a key...", bundle: .module),
                foreground: .accentColor,
                isRecording: true,
                isMonospaced: false
            )
        } else {
            KeyboardShortcutChip(
                text: item.shortcut,
                foreground: item.isCustomized ? .accentColor : .secondary
            )
        }
    }
}

private struct ShortcutRowSkeleton<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .frame(minWidth: 140, alignment: .leading)

            Spacer()

            trailing()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

private extension ShortcutRowSkeleton {
    static var trailingAlignmentPlaceholder: some View {
        Color.clear.frame(width: 16, height: 16)
    }
}

private struct KeyboardShortcutChip: View {
    let text: String
    var foreground: Color = .secondary
    var isRecording = false
    var isMonospaced = true

    var body: some View {
        Text(text)
            .font(.system(
                size: 11,
                weight: .medium,
                design: isMonospaced ? .monospaced : .default
            ))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1)
                }
            }
    }
}
