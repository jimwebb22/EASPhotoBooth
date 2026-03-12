// DeviceDetailView.swift — EtchBot
// Per-device settings, calibration status, and advanced controls.

import SwiftUI

struct DeviceDetailView: View {

    let profile: DeviceProfile
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var deviceVM: DeviceViewModel

    var body: some View {
        List {
            Section("Device Info") {
                LabeledContent("Name", value: profile.name)
                LabeledContent("ID", value: String(profile.id.prefix(8)) + "…")
                LabeledContent("Added", value: profile.dateAdded.formatted(date: .abbreviated, time: .omitted))
                if let last = profile.lastConnected {
                    LabeledContent("Last Connected", value: last.formatted(.relative(presentation: .named)))
                }
            }

            Section("Calibration") {
                LabeledContent("Status") {
                    Text(profile.calibration.isCalibrated ? "Calibrated" : "Not Calibrated")
                        .foregroundColor(profile.calibration.isCalibrated ? .green : .orange)
                }
                LabeledContent("Steps/mm (H)", value: String(format: "%.1f", profile.calibration.stepsPerMmHorizontal))
                LabeledContent("Steps/mm (V)", value: String(format: "%.1f", profile.calibration.stepsPerMmVertical))
                LabeledContent("Backlash H", value: "\(profile.calibration.backlashHorizontalSteps) steps")
                LabeledContent("Backlash V", value: "\(profile.calibration.backlashVerticalSteps) steps")
                LabeledContent("Drawing Speed", value: "\(profile.calibration.drawingSpeedRPM) RPM")

                NavigationLink("Run Calibration Wizard") {
                    CalibrationWizardView()
                }
                .foregroundColor(Color.etchRed)
            }

            Section("Actions") {
                if deviceVM.connectedProfile?.id == profile.id {
                    Button("Home EtchBot") {
                        deviceVM.sendHomeCommand()
                    }
                    Button("Disconnect") {
                        deviceVM.disconnect()
                    }
                    .foregroundColor(.orange)
                } else {
                    Button("Connect") {
                        deviceVM.connectToSaved(profile: profile)
                    }
                    .foregroundColor(Color.etchRed)
                }

                Button("Remove Device", role: .destructive) {
                    deviceVM.remove(profile: profile)
                }
            }
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
