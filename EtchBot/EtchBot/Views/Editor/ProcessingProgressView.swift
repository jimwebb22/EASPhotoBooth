// ProcessingProgressView.swift — EtchBot
// Shown during Voronoi stippling and TSP solving.

import SwiftUI

struct ProcessingProgressView: View {

    let phase: ProcessingPhase
    let progress: Double  // 0.0–1.0
    let detail: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.etchRed)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color.etchRed)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

public enum ProcessingPhase: String {
    case preprocessing    = "Preprocessing Image"
    case stippling        = "Voronoi Stippling"
    case solvingTSP       = "Solving Drawing Path"
    case optimizing       = "Optimizing Path"
    case encoding         = "Encoding for Device"

    var title: String { rawValue }
}
