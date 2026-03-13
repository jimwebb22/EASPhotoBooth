// ble_service.h — EtchBot Firmware
// BLE GATT service definition and command handling.
//
// EtchBot Service: EB010001-0001-1000-8000-00805F9B34FB
// Characteristics:
//   0002 — Device Status    (Read, Notify)  7 bytes
//   0003 — Drawing Data     (Write NR)      variable, up to MTU-3 bytes per write
//   0004 — Transfer Control (Write)         1+ bytes
//   0005 — Calibration Data (Read, Write)   12 bytes
//   0006 — Transfer Status  (Read, Notify)  4 bytes
//
// BLE callbacks set volatile command flags; the main loop reads and acts on them.
// This prevents long blocking operations inside BLE interrupt context.

#pragma once
#include <stdint.h>
#include <bluefruit.h>
#include "config.h"

// ─────────────────────────────────────────────────────────────────────────────
// Transfer Control command codes (match iOS TransferCommand enum)
// ─────────────────────────────────────────────────────────────────────────────

enum ControlCommand : uint8_t {
    CMD_START_TRANSFER  = 0x01,
    CMD_END_TRANSFER    = 0x02,
    CMD_START_DRAWING   = 0x10,
    CMD_PAUSE           = 0x11,
    CMD_RESUME          = 0x12,
    CMD_CANCEL          = 0x13,
    CMD_HOME            = 0x20,
    CMD_CALIBRATE_H     = 0x30,
    CMD_CALIBRATE_V     = 0x31,
    CMD_CALIBRATE_BH    = 0x32,
    CMD_CALIBRATE_BV    = 0x33,
    CMD_SET_SPEED       = 0x40,
};

// ─────────────────────────────────────────────────────────────────────────────
// Device state (matches iOS DeviceState enum)
// ─────────────────────────────────────────────────────────────────────────────

enum DeviceState : uint8_t {
    STATE_IDLE        = 0,
    STATE_RECEIVING   = 1,
    STATE_DRAWING     = 2,
    STATE_PAUSED      = 3,
    STATE_COMPLETE    = 4,
    STATE_ERROR       = 5,
    STATE_HOMING      = 6,
    STATE_CALIBRATING = 7,
};

// ─────────────────────────────────────────────────────────────────────────────
// CalibrationWireData — matches iOS CalibrationData.toWireFormat() (12 bytes)
// ─────────────────────────────────────────────────────────────────────────────

struct CalibrationWireData {
    uint16_t stepsPerMmH_x10;   // stepsPerMmH * 10 (1 decimal place)
    uint16_t stepsPerMmV_x10;
    uint16_t backlashH;
    uint16_t backlashV;
    uint16_t speedRPM;
    uint8_t  homeOffsetX;
    uint8_t  homeOffsetY;
} __attribute__((packed));

// ─────────────────────────────────────────────────────────────────────────────
// Volatile flags set by BLE callbacks, read by main loop
// ─────────────────────────────────────────────────────────────────────────────

struct BLECommandFlags {
    volatile bool startTransfer;
    volatile uint32_t transferTotalBytes;

    volatile bool endTransfer;
    volatile bool startDrawing;
    volatile bool pause;
    volatile bool resume;
    volatile bool cancel;
    volatile bool home;
    volatile bool calibrateH;
    volatile bool calibrateV;
    volatile bool calibrateBH;
    volatile bool calibrateBV;
    volatile bool setSpeed;
    volatile uint8_t newSpeed;
    volatile bool calibrationWritten;
    volatile CalibrationWireData newCalibration;

    void clear() {
        startTransfer     = false;
        endTransfer       = false;
        startDrawing      = false;
        pause             = false;
        resume            = false;
        cancel            = false;
        home              = false;
        calibrateH        = false;
        calibrateV        = false;
        calibrateBH       = false;
        calibrateBV       = false;
        setSpeed          = false;
        calibrationWritten = false;
    }
};

extern BLECommandFlags bleCmd;

// ─────────────────────────────────────────────────────────────────────────────
// EtchBotBLEService
// ─────────────────────────────────────────────────────────────────────────────

class EtchBotBLEService {
public:
    // Call from setup() — registers service and starts advertising.
    void begin();

    // Call from loop() when device state or progress changes.
    // Sends Device Status notification to all connected centrals.
    void notifyStatus(DeviceState state, uint16_t currentMove, uint16_t totalMoves,
                      uint8_t errorCode = 0, uint8_t powerStatus = 1);

    // Send Transfer Status notification (called after each chunk is accepted).
    void notifyTransferStatus(uint8_t chunksReceived, uint16_t bytesReceived, bool readyForNext);

    // Update the Calibration Data characteristic value (e.g. after loading from flash).
    void setCalibrationValue(const CalibrationWireData& cal);

    bool isConnected() const { return Bluefruit.connected(); }

private:
    BLEService          _service;
    BLECharacteristic   _chrStatus;
    BLECharacteristic   _chrDrawData;
    BLECharacteristic   _chrControl;
    BLECharacteristic   _chrCalibration;
    BLECharacteristic   _chrTransferStatus;

    // Static callback shims (Adafruit library needs C-style function pointers)
    static void onDrawDataWrite(uint16_t conn_hdl, BLECharacteristic* chr, uint8_t* data, uint16_t len);
    static void onControlWrite(uint16_t conn_hdl, BLECharacteristic* chr, uint8_t* data, uint16_t len);
    static void onCalibrationWrite(uint16_t conn_hdl, BLECharacteristic* chr, uint8_t* data, uint16_t len);
    static void onConnect(uint16_t conn_hdl);
    static void onDisconnect(uint16_t conn_hdl, uint8_t reason);
};

extern EtchBotBLEService bleService;
