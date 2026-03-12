// DeviceProfile.swift — EtchBot
// Represents a paired EtchBot hardware device, including its BLE identity
// and calibration data.

import Foundation

/// Connection state of a paired device.
public enum DeviceConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case drawing
    case paused
    case homing
    case calibrating
    case error
}

/// A paired EtchBot device profile.
public struct DeviceProfile: Identifiable, Codable, Sendable, Equatable {
    /// The BLE peripheral identifier (UUID string from CBPeripheral.identifier).
    public let id: String
    /// User-visible name (from CBPeripheral.name, editable by user).
    public var name: String
    /// Calibration data for this specific device.
    public var calibration: CalibrationData
    /// Date this device was first paired.
    public let dateAdded: Date
    /// Date of last successful connection.
    public var lastConnected: Date?

    public init(
        id: String,
        name: String,
        calibration: CalibrationData = .defaults,
        dateAdded: Date = Date(),
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.calibration = calibration
        self.dateAdded = dateAdded
        self.lastConnected = lastConnected
    }
}
