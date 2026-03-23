// BLEManager.swift — EtchBot
// Central BLE manager: scanning, connection, state restoration.
// Wraps CBCentralManager with an Observable interface for SwiftUI.

import Foundation
import CoreBluetooth
import Combine

/// BLE scanning and connection state.
public enum BLEManagerState: String, Sendable {
    case unknown        = "Unknown"
    case unsupported    = "Unsupported"
    case unauthorized   = "Unauthorized"
    case poweredOff     = "Bluetooth Off"
    case poweredOn      = "Ready"
    case scanning       = "Scanning"
}

/// A discovered peripheral before pairing.
public struct DiscoveredPeripheral: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    let peripheral: CBPeripheral

    public init(peripheral: CBPeripheral, rssi: Int) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "EtchBot"
        self.rssi = rssi
        self.peripheral = peripheral
    }
}

@MainActor
public final class BLEManager: NSObject, ObservableObject {

    // MARK: — Published state
    @Published public var managerState: BLEManagerState = .unknown
    @Published public var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published public var connectedDevice: BLEDeviceConnection?
    @Published public var isScanning: Bool = false

    // MARK: — Private
    private var centralManager: CBCentralManager!
    private var pendingConnectionPeripheral: CBPeripheral?
    private var scanTimer: Timer?

    // MARK: — Init

    public override init() {
        super.init()
        // Restore state key enables background BLE
        let options: [String: Any] = [
            CBCentralManagerOptionRestoreIdentifierKey: "com.etchbot.app.central"
        ]
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }

    // MARK: — Public API

    /// Start scanning for EtchBot peripherals (max 30 seconds).
    public func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        isScanning = true
        managerState = .scanning
        centralManager.scanForPeripherals(
            withServices: [EtchBotUUID.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        // Auto-stop after 30 seconds
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopScanning() }
        }
    }

    public func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if managerState == .scanning { managerState = .poweredOn }
        scanTimer?.invalidate()
    }

    /// Connect to a discovered peripheral.
    public func connect(to discovered: DiscoveredPeripheral) {
        stopScanning()
        pendingConnectionPeripheral = discovered.peripheral
        centralManager.connect(discovered.peripheral, options: nil)
    }

    /// Disconnect current device.
    public func disconnect() {
        guard let connection = connectedDevice else { return }
        centralManager.cancelPeripheralConnection(connection.peripheral)
    }
}

// MARK: — CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:   managerState = .poweredOn
        case .poweredOff:  managerState = .poweredOff
        case .unauthorized: managerState = .unauthorized
        case .unsupported: managerState = .unsupported
        default:           managerState = .unknown
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discovered = DiscoveredPeripheral(peripheral: peripheral, rssi: RSSI.intValue)
        if let idx = discoveredPeripherals.firstIndex(where: { $0.id == discovered.id }) {
            discoveredPeripherals[idx] = discovered
        } else {
            discoveredPeripherals.append(discovered)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let connection = BLEDeviceConnection(peripheral: peripheral)
        connectedDevice = connection
        connection.discoverServices()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        pendingConnectionPeripheral = nil
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedDevice?.peripheral.identifier == peripheral.identifier {
            connectedDevice = nil
        }
    }

    // Background state restoration
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                if peripheral.state == .connected {
                    let connection = BLEDeviceConnection(peripheral: peripheral)
                    connectedDevice = connection
                    connection.discoverServices()
                }
            }
        }
    }
}
