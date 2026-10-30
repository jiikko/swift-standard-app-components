import SwiftUI

/// ドラッグの並べ替えで、同じ組の連続の hover を 1 回にするための鍵
struct StandardTabMoveKey<ID: Hashable>: Equatable {
    let moving: ID
    let target: ID
    let placement: StandardTabMovePlacement
}

/// 並べ替えの drop 先 (相手のタブ)。hover の位置が相手の左右半分のどちらかで前後を決め、並びを live に動かす
struct StandardTabDropDelegate<ID: Hashable>: DropDelegate {
    let targetID: ID
    let tabWidth: CGFloat
    @Binding var draggingID: ID?
    @Binding var lastMove: StandardTabMoveKey<ID>?
    let onMove: (@MainActor (ID, ID, StandardTabMovePlacement) -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        // lib がドラッグを始めたものだけを受ける (他のアプリの文字のドラッグは受けない)
        MainActor.assumeIsolated { draggingID != nil && onMove != nil }
    }

    func dropEntered(info: DropInfo) {
        applyMove(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        applyMove(info: info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated {
            draggingID = nil
            lastMove = nil
        }
        return true
    }

    private func applyMove(info: DropInfo) {
        // DropDelegate は nonisolated だが、AppKit は main thread で呼ぶ
        MainActor.assumeIsolated {
            guard let moving = draggingID, moving != targetID, let onMove else { return }
            let placement = StandardTabMovePlacement.placement(locationX: info.location.x, tabWidth: tabWidth)
            let move = StandardTabMoveKey(moving: moving, target: targetID, placement: placement)
            // 同じ組の連続の hover で 2 度動かさない
            guard lastMove != move else { return }
            lastMove = move
            withAnimation(.easeInOut(duration: 0.15)) {
                onMove(moving, targetID, placement)
            }
        }
    }
}
