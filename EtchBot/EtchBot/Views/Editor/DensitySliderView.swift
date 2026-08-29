// DensitySliderView.swift — EtchBot
// Controls for drawing density, contrast, and edge emphasis.

import SwiftUI

struct DensitySliderView: View {

    @Binding var settings: DrawingSettings

    var body: some View {
        VStack(spacing: 16) {

            // MARK: — Density (point count)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Drawing Density")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(settings.pointCount) points")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(Color.etchRed)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.pointCount) },
                        set: { settings.pointCount = Int($0) }
                    ),
                    in: Double(DrawingSettings.pointCountRange.lowerBound)...Double(DrawingSettings.pointCountRange.upperBound),
                    step: 100
                )
                .tint(Color.etchRed)
                HStack {
                    Text("Light").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("Dark").font(.caption2).foregroundColor(.secondary)
                }
            }

            Divider()

            // MARK: — Contrast
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Contrast")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.1f×", settings.contrastMultiplier))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $settings.contrastMultiplier,
                    in: DrawingSettings.contrastRange,
                    step: 0.1
                )
                .tint(Color.etchDark)
            }

            Divider()

            // MARK: — Edge emphasis toggle
            Toggle(isOn: $settings.edgeEmphasisEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edge Emphasis")
                        .font(.subheadline.weight(.semibold))
                    Text("Adds defined contour lines (30% edges, 70% tone)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(Color.etchRed)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
