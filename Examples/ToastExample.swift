// 最小サンプル: ToastManager + standardToastContainer の使い方。
// このファイルはビルド対象には入っていない（参照用）。

import SwiftUI
import StandardAppComponents

@main
struct ToastExampleApp: App {
    @State private var toastManager = ToastManager()

    var body: some Scene {
        WindowGroup {
            ToastExampleView(toastManager: toastManager)
                .standardToastContainer(toastManager)
        }
    }
}

struct ToastExampleView: View {
    let toastManager: any ToastManaging

    var body: some View {
        VStack(spacing: 12) {
            Button("Show Success") {
                toastManager.showSuccess("Saved")
            }

            Button("Show Error") {
                toastManager.showError(
                    "Save Failed",
                    message: .verbatim("The destination is not writable.")
                )
            }
        }
        .frame(width: 320, height: 180)
    }
}
