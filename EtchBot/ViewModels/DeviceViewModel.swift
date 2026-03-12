// DeviceViewModel.swift — EtchBot
// Manages paired device state: connecting, saving profiles, calibration data sync.

import Foundation
import Combine

@MainActor
public final class DeviceViewModel: ObservableObject {

    @Published public var savedDevices: [DeviceProfile] = []
    @Published public var connectedProfile: DeviceProfile?

    public var isConnected: Bool { connectedProfile != nil }
    public var connectedDeviceName: String { connectedProfile?.name ?? "Unknown" }

    private let bleManager: BLEManager
    private let deviceStore: DeviceStore
    private var cancellables = Set<AnyCancellable>()

    public init(bleManager: BLEManager, deviceStore: DeviceStore) {
        self.bleManager = bleManager
        self.deviceStore = deviceStore
        self.savedDevices = deviceStore.loadAll()
        bindToConnection()
    }

    // MARK: — Connection binding

    private func bindToConnection() {
        bleManager.$connectedDevice
            .sink { [weak self] connection in
                guard let self else { return }
                if let conn = connection {
                    let id = conn.peripheral.identifier.uuidString
                    // Look up or create a profile
                    if let existing = self.savedDevices.first(where: { $0.id == id }) {
                        var updated = existing
                        updated.lastConnected = Date()
                        self.connectedProfile = updated
                        self.deviceStore.save(updated)
                        self.savedDevices = self.deviceStore.loadAll()
                    } else {
                        // New device — create and save
                        let name = conn.peripheral.name ?? "EtchBot"
                        let profile = DeviceProfile(id: id, name: name, lastConnected: Date())
                        self.connectedProfile = profile
                        self.deviceStore.save(profile)
                        self.savedDevices = self.deviceStore.loadAll()
                    }
                } else {
                    self.connectedProfile = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: — Pairing

    public func pairDevice(discovered: DiscoveredPeripheral, name: String) {
        bleManager.connect(to: discovered)
        // Profile will be created when connection succeeds (bindToConnection)
    }

    // MARK: — Commands

    public func sendHomeCommand() {
        bleManager.connectedDevice?.sendCommand(.home)
    }

    public func disconnect() {
        bleManager.disconnect()
    }

    public func connectToSaved(profile: DeviceProfile) {
        if let discovered = bleManager.discoveredPeripherals.first(where: { $0.id.uuidString == profile.id }) {
            bleManager.connect(to: discovered)
        } else {
            bleManager.startScanning()
        }
    }

    public func remove(profile: DeviceProfile) {
        deviceStore.delete(id: profile.id)
        savedDevices = deviceStore.loadAll()
    }

    public func deleteDevices(at offsets: IndexSet) {
        let toDelete = offsets.map { savedDevices[$0] }
        toDelete.forEach { deviceStore.delete(id: $0.id) }
        savedDevices = deviceStore.loadAll()
    }
}
