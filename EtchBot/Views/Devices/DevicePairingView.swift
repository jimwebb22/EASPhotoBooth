// DevicePairingView.swift — EtchBot
// Pairing confirmation flow shown after selecting a discovered device.

import SwiftUI

struct DevicePairingView: View {

    let discovered: DiscoveredPeripheral
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var customName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color.etchRed)

                Text("Pair with \(discovered.name)?")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Name")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    TextField("My EtchBot", text: $customName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                Text("The device will be saved and calibration data can be set up after pairing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Pair") {
                    let name = customName.isEmpty ? discovered.name : customName
                    deviceVM.pairDevice(discovered: discovered, name: name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.etchRed)
                .controlSize(.large)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { customName = discovered.name }
        }
    }
}
