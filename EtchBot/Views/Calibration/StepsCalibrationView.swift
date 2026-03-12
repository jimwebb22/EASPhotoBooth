// StepsCalibrationView.swift — EtchBot
// Step 2/3 of calibration wizard: measure steps-per-mm by drawing test lines.

import SwiftUI

struct StepsCalibrationView: View {

    @EnvironmentObject var calibrationVM: CalibrationViewModel
    let axis: CalibrationAxis
    let onComplete: () -> Void

    @State private var measuredMM: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: axis == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down")
                .font(.system(size: 48))
                .foregroundColor(Color.etchRed)

            Text(axis == .horizontal ? "Horizontal Calibration" : "Vertical Calibration")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("The EtchBot will now draw a \(axis == .horizontal ? "horizontal" : "vertical") line of exactly \(calibrationVM.calibrationLineSteps) steps.")
                    .font(.body)
                Text("1. Tap **Draw Line** below.\n2. Wait for the line to finish.\n3. Measure the line with a ruler.\n4. Enter the length in millimetres.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Button("Draw Line") {
                calibrationVM.drawCalibrationLine(axis: axis)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.etchDark)
            .disabled(calibrationVM.isDrawingCalibration)

            if calibrationVM.isDrawingCalibration {
                ProgressView("Drawing…").padding()
            }

            if calibrationVM.calibrationLineDrawn {
                VStack(spacing: 12) {
                    Text("Line drawn. Measure and enter the length:")
                        .font(.subheadline)
                    HStack {
                        TextField("e.g. 82", text: $measuredMM)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($isInputFocused)
                            .frame(width: 120)
                        Text("mm")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Button("Next") {
                guard let mm = Double(measuredMM), mm > 0 else { return }
                calibrationVM.saveStepsPerMm(axis: axis, measuredMM: mm)
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.etchRed)
            .disabled(measuredMM.isEmpty || !calibrationVM.calibrationLineDrawn)
            .padding(.bottom)
        }
        .padding(.top, 24)
    }
}

enum CalibrationAxis { case horizontal, vertical }
