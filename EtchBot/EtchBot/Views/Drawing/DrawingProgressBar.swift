// DrawingProgressBar.swift — EtchBot
// Progress bar with percentage, move counts, and estimated time remaining.

import SwiftUI

struct DrawingProgressBar: View {

    let currentMove: Int
    let totalMoves: Int
    let estimatedSecondsRemaining: Int

    var fraction: Double {
        guard totalMoves > 0 else { return 0 }
        return Double(currentMove) / Double(totalMoves)
    }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(Color.etchRed)
                .scaleEffect(x: 1, y: 2, anchor: .center)

            HStack {
                Text("\(currentMove) / \(totalMoves) moves")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Spacer()

                Text(timeRemainingString)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(Color.etchRed)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private var timeRemainingString: String {
        if estimatedSecondsRemaining <= 0 { return "Almost done" }
        let minutes = estimatedSecondsRemaining / 60
        let seconds = estimatedSecondsRemaining % 60
        if minutes > 0 { return "~\(minutes)m \(seconds)s left" }
        return "~\(seconds)s left"
    }
}
