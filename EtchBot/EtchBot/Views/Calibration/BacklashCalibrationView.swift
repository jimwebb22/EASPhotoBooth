// BacklashCalibrationView.swift — EtchBot
// Backlash measurement via visual pattern selection.

import SwiftUI

struct BacklashCalibrationView: View {

    @EnvironmentObject var calibrationVM: CalibrationViewModel
    let axis: CalibrationAxis
    let onComplete: () -> Void

    @State private var selectedPatternIndex: Int? = nil
    let backlashOptions = [0, 30, 60, 90, 120]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.etchRed)

            Text("\(axis == .horizontal ? "Horizontal" : "Vertical") Backlash")
                .font(.title2.bold())

            Text("The EtchBot will draw 5 test patterns with different backlash settings (\(backlashOptions.map{"\($0)"}.joined(separator: ", ")) steps). Select the pattern that looks most **aligned and straight**.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Draw Test Patterns") {
                calibrationVM.drawBacklashPatterns(axis: axis)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.etchDark)
            .disabled(calibrationVM.isDrawingCalibration)

            if calibrationVM.isDrawingCalibration {
                ProgressView("Drawing patterns…").padding()
            }

            if calibrationVM.backlashPatternsDrawn {
                VStack(spacing: 12) {
                    Text("Which pattern looks best?")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 12) {
                        ForEach(backlashOptions.indices, id: \.self) { i in
                            Button {
                                selectedPatternIndex = i
                            } label: {
                                VStack(spacing: 4) {
                                    Text("Pattern\n\(i + 1)")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                    Text("\(backlashOptions[i])")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(selectedPatternIndex == i ? Color.etchRed : Color(.systemGray5))
                                .foregroundColor(selectedPatternIndex == i ? .white : .primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Button("Save & Continue") {
                if let idx = selectedPatternIndex {
                    calibrationVM.saveBacklash(axis: axis, steps: backlashOptions[idx])
                }
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.etchRed)
            .disabled(selectedPatternIndex == nil)
            .padding(.bottom)
        }
        .padding(.top, 24)
    }
}
