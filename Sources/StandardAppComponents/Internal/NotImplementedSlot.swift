import SwiftUI

public struct NotImplementedSlot: View {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
            Text("Not Implemented: \(name)")
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.red)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.red, lineWidth: 1)
        )
        .onAppear {
            #if DEBUG
            assertionFailure("UI contract violation: \(name) is not implemented")
            #endif
        }
    }
}
