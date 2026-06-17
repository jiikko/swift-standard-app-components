# Feedback Components

確認ダイアログとブロッキング進捗オーバーレイの薄い SwiftUI wrapper。

Toast は軽い通知向け、ここにある API は「ユーザーの判断が必要」「処理中に背面操作を止める必要がある」ケース向け。

## Action Confirmation

```swift
struct ContentView: View {
    @State private var isConfirmingDelete = false
    @State private var selectedDocument: Document?

    var body: some View {
        List(documents) { document in
            Button("Delete") {
                selectedDocument = document
                isConfirmingDelete = true
            }
        }
        .standardActionConfirmation(
            isPresented: $isConfirmingDelete,
            title: "Delete Document?",
            subject: selectedDocument,
            destructive: StandardActionButton("Delete", role: .destructive) {
                deleteSelectedDocument()
            },
            message: { document in
                Text("This will permanently delete \(document.title).")
            }
        )
    }
}
```

`subject` は表示対象の entity を consumer 側で保持するための値。通常は `subject` を設定してから `isPresented = true` にする。

`StandardActionButton` は title、`ButtonRole`、main actor handler だけを持つ。文言、action の副作用、対象 entity の lifecycle は consumer 側に残す。

## Blocking Progress Overlay

```swift
struct ContentView: View {
    @State private var isImporting = false

    var body: some View {
        ImportView()
            .standardBlockingProgressOverlay(
                isPresented: $isImporting,
                title: "Importing",
                subtitle: "Processing selected files...",
                onCancel: cancelImport
            )
    }
}
```

`standardBlockingProgressOverlay` は背面 view を disabled にし、indeterminate `ProgressView` と任意の cancel button を表示する。

軽い処理中表示、完了通知、復旧可能なエラーには使わない。長時間の詳細進捗や複雑な cancel policy が必要な場合は app 固有 Sheet / window にする。
