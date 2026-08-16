// CalibrationWizardView.swift — EtchBot
// Multi-step calibration wizard guiding the user through:
//   1. Homing
//   2. Horizontal steps/mm
//   3. Vertical steps/mm
//   4. Horizontal backlash
//   5. Vertical backlash
//   6. Confirmation

import SwiftUI

struct CalibrationWizardView: View {

    @EnvironmentObject var calibrationVM: CalibrationViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var step: CalibrationStep = .homing

    enum CalibrationStep: Int, CaseIterable {
        case homing = 0
        case stepsH
        case stepsV
        case backlashH
        case backlashV
        case complete

        var title: String {
            switch self {
            case .homing:    return "Step 1: Home"
            case .stepsH:    return "Step 2: Horizontal Scale"
            case .stepsV:    return "Step 3: Vertical Scale"
            case .backlashH: return "Step 4: Horizontal Backlash"
            case .backlashV: return "Step 5: Vertical Backlash"
            case .complete:  return "Calibration Complete"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(step.rawValue), total: Double(CalibrationStep.allCases.count - 1))
                    .tint(Color.etchRed)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.top, 8)

                // Step content
                ScrollView {
                    stepContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .animation(.easeInOut, value: step)
                }
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { coordinator.closeSheet() }
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .homing:
            HomingStepView { advanceTo(.stepsH) }
        case .stepsH:
            StepsCalibrationView(axis: .horizontal) { advanceTo(.stepsV) }
                .environmentObject(calibrationVM)
        case .stepsV:
            StepsCalibrationView(axis: .vertical) { advanceTo(.backlashH) }
                .environmentObject(calibrationVM)
        case .backlashH:
            BacklashCalibrationView(axis: .horizontal) { advanceTo(.backlashV) }
                .environmentObject(calibrationVM)
        case .backlashV:
            BacklashCalibrationView(axis: .vertical) { advanceTo(.complete) }
                .environmentObject(calibrationVM)
        case .complete:
            CalibrationCompleteView { coordinator.closeSheet() }
        }
    }

    private func advanceTo(_ nextStep: CalibrationStep) {
        withAnimation { step = nextStep }
    }
}

// MARK: — Sub-step views

private struct HomingStepView: View {
    @EnvironmentObject var calibrationVM: CalibrationViewModel
    let onContinue: () -> Void
    @State private var hasHomed = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "house.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.etchRed)

            Text("First, we'll move the Etch-a-Sketch cursor to the home corner (bottom-left).")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Make sure the drawing surface is clear before continuing.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Start Homing") {
                calibrationVM.sendHomeCommand()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { hasHomed = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.etchRed)
            .disabled(calibrationVM.isHoming)

            if calibrationVM.isHoming {
                ProgressView("Homing…").padding()
            }

            Spacer()

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .tint(Color.etchRed)
                .disabled(!hasHomed && !calibrationVM.homingComplete)
                .padding(.bottom)
        }
        .padding(.top, 24)
    }
}

private struct CalibrationCompleteView: View {
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Calibration Complete!")
                .font(.title.bold())

            Text("Your EtchBot settings have been saved. The device is now ready for accurate drawing.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Done") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.etchRed)
                .controlSize(.large)
        }
        .padding(.top, 40)
    }
}
