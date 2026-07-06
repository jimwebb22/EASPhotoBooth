// DensitySliderView.swift — EtchBot
// Controls for drawing density, contrast, and edge emphasis.

import SwiftUI

struct DensitySliderView: View {

    @Binding var settings: DrawingSettings

    var body: some View {
        VStack(spacing: 16) {

            // MARK: — Render style
            VStack(alignment: .leading, spacing: 6) {
                Text("Line Style")
                    .font(.subheadline.weight(.semibold))
                Picker("Line Style", selection: $settings.renderStyle) {
                    Text("Contour").tag(DrawingSettings.RenderStyle.hybrid)
                    Text("Classic Dots").tag(DrawingSettings.RenderStyle.stipple)
                }
                .pickerStyle(.segmented)
                Text(settings.renderStyle == .hybrid
                     ? "Lines follow the image's contours; dots fill in shading."
                     : "Classic TSP art: one line hopping between shading dots.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

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

            // MARK: — Tone (density gamma)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Shading Depth")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "γ %.1f", settings.toneGamma))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $settings.toneGamma,
                    in: DrawingSettings.toneGammaRange,
                    step: 0.1
                )
                .tint(Color.etchDark)
                HStack {
                    Text("Soft").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("Punchy").font(.caption2).foregroundColor(.secondary)
                }
            }

            Divider()

            // MARK: — Advanced
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Adaptive Contrast (CLAHE)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(String(format: "%.0f%%", settings.claheStrength * 100))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $settings.claheStrength,
                            in: DrawingSettings.claheStrengthRange,
                            step: 0.05
                        )
                        .tint(Color.etchDark)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Background Cutoff")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(String(format: "%.0f%%", settings.backgroundCutoff * 100))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $settings.backgroundCutoff,
                            in: DrawingSettings.backgroundCutoffRange,
                            step: 0.01
                        )
                        .tint(Color.etchDark)
                        Text("Tones lighter than this are left blank — no stray dots in white areas.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Advanced")
                    .font(.subheadline.weight(.semibold))
            }

            // MARK: — Edge emphasis (stipple style only; the hybrid style
            // draws contours explicitly)
            if settings.renderStyle == .stipple {
                Divider()

                Toggle(isOn: $settings.edgeEmphasisEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edge Emphasis")
                            .font(.subheadline.weight(.semibold))
                        Text("Blends detected contours into the dot density")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(Color.etchRed)

                if settings.edgeEmphasisEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Edge Strength")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(String(format: "%.0f%%", settings.edgeWeight * 100))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $settings.edgeWeight,
                            in: DrawingSettings.edgeWeightRange,
                            step: 0.05
                        )
                        .tint(Color.etchDark)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
