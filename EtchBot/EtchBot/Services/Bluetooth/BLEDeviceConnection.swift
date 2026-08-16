// BLEDeviceConnection.swift — EtchBot
// Per-device connection handler: service discovery, characteristic access,
// status subscriptions.

import Foundation
import CoreBluetooth
import Combine

@MainActor
public final class BLEDeviceConnection: NSObject, ObservableObject {

    // MARK: — Published state
    @Published public var deviceStatus: DeviceStatus?
    @Published public var transferStatus: TransferStatus?
    @Published public var isReady: Bool = false  // true once all characteristics are discovered
    @Published public var calibration: CalibrationData?

    // MARK: — Internal
    let peripheral: CBPeripheral
    private var statusCharacteristic: CBCharacteristic?
    private var drawingDataCharacteristic: CBCharacteristic?
    private var transferControlCharacteristic: CBCharacteristic?
    private var calibrationCharacteristic: CBCharacteristic?
    private var transferStatusCharacteristic: CBCharacteristic?

    // MARK: — Init

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    // MARK: — Service discovery

    func discoverServices() {
        peripheral.discoverServices([EtchBotUUID.service])
    }

    // MARK: — Command sending

    public func sendCommand(_ command: TransferCommand, payload: Data = Data()) {
        guard let char = transferControlCharacteristic else { return }
        var data = Data([command.rawValue])
        data.append(payload)
        peripheral.writeValue(data, for: char, type: .withResponse)
    }

    public func sendStartTransfer(totalBytes: UInt32) {
        var payload = Data(capacity: 4)
        payload.append(UInt8(totalBytes & 0xFF))
        payload.append(UInt8((totalBytes >> 8) & 0xFF))
        payload.append(UInt8((totalBytes >> 16) & 0xFF))
        payload.append(UInt8((totalBytes >> 24) & 0xFF))
        sendCommand(.startTransfer, payload: payload)
    }

    /// Write a chunk of drawing data (no response to maximise throughput).
    public func writeDrawingChunk(_ chunk: Data) {
        guard let char = drawingDataCharacteristic else { return }
        peripheral.writeValue(chunk, for: char, type: .withoutResponse)
    }

    public func readCalibration() {
        guard let char = calibrationCharacteristic else { return }
        peripheral.readValue(for: char)
    }

    public func writeCalibration(_ cal: CalibrationData) {
        guard let char = calibrationCharacteristic else { return }
        peripheral.writeValue(cal.toWireFormat(), for: char, type: .withResponse)
    }
}

// MARK: — CBPeripheralDelegate

extension BLEDeviceConnection: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services where service.uuid == EtchBotUUID.service {
            peripheral.discoverCharacteristics([
                EtchBotUUID.deviceStatus,
                EtchBotUUID.drawingData,
                EtchBotUUID.transferControl,
                EtchBotUUID.calibrationData,
                EtchBotUUID.transferStatus
            ], for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let chars = service.characteristics else { return }
        for char in chars {
            switch char.uuid {
            case EtchBotUUID.deviceStatus:
                statusCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            case EtchBotUUID.drawingData:
                drawingDataCharacteristic = char
            case EtchBotUUID.transferControl:
                transferControlCharacteristic = char
            case EtchBotUUID.calibrationData:
                calibrationCharacteristic = char
            case EtchBotUUID.transferStatus:
                transferStatusCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            default: break
            }
        }
        // Ready when we have all 5 characteristics
        let allFound = statusCharacteristic != nil
            && drawingDataCharacteristic != nil
            && transferControlCharacteristic != nil
            && calibrationCharacteristic != nil
            && transferStatusCharacteristic != nil
        if allFound { isReady = true }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        switch characteristic.uuid {
        case EtchBotUUID.deviceStatus:
            deviceStatus = DeviceStatus(data: data)
        case EtchBotUUID.transferStatus:
            transferStatus = TransferStatus(data: data)
        case EtchBotUUID.calibrationData:
            calibration = CalibrationData.fromWireFormat(data)
        default: break
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Log errors in debug builds
        #if DEBUG
        if let error { print("[BLE] Write error on \(characteristic.uuid): \(error)") }
        #endif
    }
}
