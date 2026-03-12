// DeviceStore.swift — EtchBot
// Persists paired device profiles using a JSON file in the app's Documents directory.
// Keyed by BLE peripheral identifier UUID string.

import Foundation

public final class DeviceStore: Sendable {

    private let fileURL: URL

    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent("etchbot_devices.json")
    }

    // MARK: — CRUD

    public func loadAll() -> [DeviceProfile] {
        guard let data = try? Data(contentsOf: fileURL),
              let devices = try? JSONDecoder().decode([DeviceProfile].self, from: data) else {
            return []
        }
        return devices
    }

    public func save(_ profile: DeviceProfile) {
        var devices = loadAll()
        if let idx = devices.firstIndex(where: { $0.id == profile.id }) {
            devices[idx] = profile
        } else {
            devices.append(profile)
        }
        persist(devices)
    }

    public func delete(id: String) {
        var devices = loadAll()
        devices.removeAll { $0.id == id }
        persist(devices)
    }

    private func persist(_ devices: [DeviceProfile]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
