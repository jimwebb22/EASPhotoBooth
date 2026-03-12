// DrawingCompleteView.swift — EtchBot
// Shown when the EtchBot finishes drawing.

import SwiftUI

struct DrawingCompleteView: View {

    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
                .symbolEffect(.bounce)

            Text("Drawing Complete!")
                .font(.title.bold())

            Text("Your Etch-a-Sketch has finished drawing. The cursor is holding its final position.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Done") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.etchRed)
                .controlSize(.large)
        }
        .padding()
    }
}
