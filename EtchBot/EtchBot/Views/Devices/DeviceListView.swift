// DeviceListView.swift — EtchBot
// BLE device scanning and pairing.

import SwiftUI

struct DeviceListView: View {

    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var deviceVM: DeviceViewModel
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        NavigationStack {
            List {
                // MARK: — Connected device
                if let connectedProfile = deviceVM.connectedProfile {
                    Section("Connected") {
                        DeviceRow(profile: connectedProfile, isConnected: true) {
                            NavigationLink(destination: DeviceDetailView(profile: connectedProfile)) {
                                EmptyView()
                            }
                        }
                    }
                }

                // MARK: — Scan results
                Section {
                    if bleManager.isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning for EtchBot devices…")
                                .foregroundColor(.secondary)
                        }
                    } else if bleManager.discoveredPeripherals.isEmpty {
                        ContentUnavailableView(
                            "No Devices Found",
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            description: Text("Make sure your EtchBot is powered on and nearby.")
                        )
                    }

                    ForEach(bleManager.discoveredPeripherals) { discovered in
                        DiscoveredDeviceRow(discovered: discovered) {
                            bleManager.connect(to: discovered)
                        }
                    }
                } header: {
                    Text("Available Devices")
                }

                // MARK: — Saved devices
                if !deviceVM.savedDevices.isEmpty {
                    Section("Saved Devices") {
                        ForEach(deviceVM.savedDevices) { profile in
                            NavigationLink(destination: DeviceDetailView(profile: profile)) {
                                SavedDeviceRow(profile: profile)
                            }
                        }
                        .onDelete { offsets in deviceVM.deleteDevices(at: offsets) }
                    }
                }
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { coordinator.closeSheet() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        bleManager.isScanning ? bleManager.stopScanning() : bleManager.startScanning()
                    } label: {
                        Label(
                            bleManager.isScanning ? "Stop" : "Scan",
                            systemImage: bleManager.isScanning ? "stop.circle" : "magnifyingglass"
                        )
                    }
                }
            }
            .task { bleManager.startScanning() }
            .onDisappear { bleManager.stopScanning() }
        }
    }
}

// MARK: — Row views

private struct DeviceRow<Accessory: View>: View {
    let profile: DeviceProfile
    let isConnected: Bool
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isConnected ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(profile.name).font(.body.weight(.medium))
                Text(profile.calibration.isCalibrated ? "Calibrated" : "Needs calibration")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            accessory()
        }
    }
}

private struct DiscoveredDeviceRow: View {
    let discovered: DiscoveredPeripheral
    let onConnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(Color.etchRed)
            VStack(alignment: .leading) {
                Text(discovered.name).font(.body.weight(.medium))
                Text("RSSI: \(discovered.rssi) dBm")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button("Connect", action: onConnect)
                .buttonStyle(.bordered)
                .tint(Color.etchRed)
        }
    }
}

private struct SavedDeviceRow: View {
    let profile: DeviceProfile
    var body: some View {
        VStack(alignment: .leading) {
            Text(profile.name).font(.body)
            if let last = profile.lastConnected {
                Text("Last connected \(last.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
