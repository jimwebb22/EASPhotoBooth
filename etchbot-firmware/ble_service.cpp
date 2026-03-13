// ble_service.cpp — EtchBot Firmware

#include "ble_service.h"
#include "path_storage.h"
#include <string.h>

// ─────────────────────────────────────────────────────────────────────────────
// Globals
// ─────────────────────────────────────────────────────────────────────────────

BLECommandFlags bleCmd = {};
EtchBotBLEService bleService;

// ─────────────────────────────────────────────────────────────────────────────
// Characteristic UUIDs — 128-bit, matching iOS EtchBotUUID definitions
// ─────────────────────────────────────────────────────────────────────────────

static const char* SERVICE_UUID       = "EB010001-0001-1000-8000-00805F9B34FB";
static const char* CHR_STATUS_UUID    = "EB010002-0001-1000-8000-00805F9B34FB";
static const char* CHR_DRAWDATA_UUID  = "EB010003-0001-1000-8000-00805F9B34FB";
static const char* CHR_CONTROL_UUID   = "EB010004-0001-1000-8000-00805F9B34FB";
static const char* CHR_CALIBR_UUID    = "EB010005-0001-1000-8000-00805F9B34FB";
static const char* CHR_TXSTATUS_UUID  = "EB010006-0001-1000-8000-00805F9B34FB";

// ─────────────────────────────────────────────────────────────────────────────
// begin()
// ─────────────────────────────────────────────────────────────────────────────

void EtchBotBLEService::begin() {
    bleCmd.clear();

    // ── BLE stack init ────────────────────────────────────────────────────────
    Bluefruit.begin();
    Bluefruit.setTxPower(4);   // dBm — reduce for shorter range but less power
    Bluefruit.setName("EtchBot");

    Bluefruit.Periph.setConnectCallback(onConnect);
    Bluefruit.Periph.setDisconnectCallback(onDisconnect);

    // ── Service ──────────────────────────────────────────────────────────────
    _service = BLEService(BLEUuid(SERVICE_UUID));
    _service.begin();

    // ── Device Status (Read + Notify, 7 bytes) ───────────────────────────────
    _chrStatus = BLECharacteristic(BLEUuid(CHR_STATUS_UUID));
    _chrStatus.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
    _chrStatus.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
    _chrStatus.setFixedLen(7);
    _chrStatus.begin();
    // Initial value: idle state
    uint8_t initStatus[7] = {STATE_IDLE, 0,0, 0,0, 0, 1};
    _chrStatus.write(initStatus, 7);

    // ── Drawing Data (Write Without Response, variable) ──────────────────────
    _chrDrawData = BLECharacteristic(BLEUuid(CHR_DRAWDATA_UUID));
    _chrDrawData.setProperties(CHR_PROPS_WRITE_WO_RESP);
    _chrDrawData.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
    _chrDrawData.setMaxLen(247);   // max ATT payload
    _chrDrawData.setWriteCallback(onDrawDataWrite);
    _chrDrawData.begin();

    // ── Transfer Control (Write With Response, variable) ─────────────────────
    _chrControl = BLECharacteristic(BLEUuid(CHR_CONTROL_UUID));
    _chrControl.setProperties(CHR_PROPS_WRITE);
    _chrControl.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
    _chrControl.setMaxLen(6);
    _chrControl.setWriteCallback(onControlWrite);
    _chrControl.begin();

    // ── Calibration Data (Read + Write, 12 bytes) ────────────────────────────
    _chrCalibration = BLECharacteristic(BLEUuid(CHR_CALIBR_UUID));
    _chrCalibration.setProperties(CHR_PROPS_READ | CHR_PROPS_WRITE);
    _chrCalibration.setPermission(SECMODE_OPEN, SECMODE_OPEN);
    _chrCalibration.setFixedLen(sizeof(CalibrationWireData));
    _chrCalibration.setWriteCallback(onCalibrationWrite);
    _chrCalibration.begin();
    // Default calibration value
    CalibrationWireData defCal = {
        (uint16_t)(DEFAULT_STEPS_PER_MM_H * 10),
        (uint16_t)(DEFAULT_STEPS_PER_MM_V * 10),
        DEFAULT_BACKLASH_H,
        DEFAULT_BACKLASH_V,
        SPEED_DRAW_DEFAULT_RPM,
        0, 0
    };
    _chrCalibration.write((uint8_t*)&defCal, sizeof(defCal));

    // ── Transfer Status (Read + Notify, 4 bytes) ──────────────────────────────
    _chrTransferStatus = BLECharacteristic(BLEUuid(CHR_TXSTATUS_UUID));
    _chrTransferStatus.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
    _chrTransferStatus.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
    _chrTransferStatus.setFixedLen(4);
    _chrTransferStatus.begin();
    uint8_t initTx[4] = {0, 0, 0, 0};
    _chrTransferStatus.write(initTx, 4);

    // ── Advertising ───────────────────────────────────────────────────────────
    Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
    Bluefruit.Advertising.addTxPower();
    Bluefruit.Advertising.addService(_service);
    Bluefruit.Advertising.addName();
    Bluefruit.Advertising.restartOnDisconnect(true);
    Bluefruit.Advertising.setInterval(32, 244);   // units: 0.625ms
    Bluefruit.Advertising.setFastTimeout(30);     // 30s fast, then slow
    Bluefruit.Advertising.start(0);              // 0 = no timeout

    DBG_PRINTLN("[BLE] Service started, advertising");
}

// ─────────────────────────────────────────────────────────────────────────────
// Notify helpers
// ─────────────────────────────────────────────────────────────────────────────

void EtchBotBLEService::notifyStatus(DeviceState state, uint16_t currentMove,
                                      uint16_t totalMoves, uint8_t errorCode,
                                      uint8_t powerStatus) {
    uint8_t buf[7];
    buf[0] = (uint8_t)state;
    buf[1] = (uint8_t)(currentMove & 0xFF);
    buf[2] = (uint8_t)(currentMove >> 8);
    buf[3] = (uint8_t)(totalMoves & 0xFF);
    buf[4] = (uint8_t)(totalMoves >> 8);
    buf[5] = errorCode;
    buf[6] = powerStatus;
    _chrStatus.write(buf, 7);
    if (Bluefruit.connected()) {
        _chrStatus.notify(buf, 7);
    }
}

void EtchBotBLEService::notifyTransferStatus(uint8_t chunks, uint16_t bytes, bool ready) {
    uint8_t buf[4];
    buf[0] = chunks;
    buf[1] = (uint8_t)(bytes & 0xFF);
    buf[2] = (uint8_t)(bytes >> 8);
    buf[3] = ready ? 1 : 0;
    _chrTransferStatus.write(buf, 4);
    if (Bluefruit.connected()) {
        _chrTransferStatus.notify(buf, 4);
    }
}

void EtchBotBLEService::setCalibrationValue(const CalibrationWireData& cal) {
    _chrCalibration.write((const uint8_t*)&cal, sizeof(cal));
}

// ─────────────────────────────────────────────────────────────────────────────
// BLE Callbacks (called from BLE stack task — keep short, set flags only)
// ─────────────────────────────────────────────────────────────────────────────

void EtchBotBLEService::onDrawDataWrite(uint16_t, BLECharacteristic*, uint8_t* data, uint16_t len) {
    // Directly append chunk to path storage (safe — only called when in RECEIVING state)
    if (pathStorage.appendChunk(data, len)) {
        // Notify iOS: ready for next chunk
        bleService.notifyTransferStatus(
            pathStorage.chunksReceived(),
            (uint16_t)pathStorage.bytesReceived(),
            true
        );
    } else {
        // Buffer overflow — signal not ready
        bleService.notifyTransferStatus(
            pathStorage.chunksReceived(),
            (uint16_t)pathStorage.bytesReceived(),
            false
        );
    }
}

void EtchBotBLEService::onControlWrite(uint16_t, BLECharacteristic*, uint8_t* data, uint16_t len) {
    if (len < 1) return;
    const uint8_t cmd = data[0];
    DBG_PRINTF("[BLE] Control command: 0x%02X\n", cmd);

    switch (cmd) {
        case CMD_START_TRANSFER:
            bleCmd.startTransfer     = true;
            bleCmd.transferTotalBytes = (len >= 5)
                ? ((uint32_t)data[1]
                   | ((uint32_t)data[2] << 8)
                   | ((uint32_t)data[3] << 16)
                   | ((uint32_t)data[4] << 24))
                : 0;
            break;
        case CMD_END_TRANSFER:    bleCmd.endTransfer  = true; break;
        case CMD_START_DRAWING:   bleCmd.startDrawing = true; break;
        case CMD_PAUSE:           bleCmd.pause        = true; break;
        case CMD_RESUME:          bleCmd.resume       = true; break;
        case CMD_CANCEL:          bleCmd.cancel       = true; break;
        case CMD_HOME:            bleCmd.home         = true; break;
        case CMD_CALIBRATE_H:     bleCmd.calibrateH   = true; break;
        case CMD_CALIBRATE_V:     bleCmd.calibrateV   = true; break;
        case CMD_CALIBRATE_BH:    bleCmd.calibrateBH  = true; break;
        case CMD_CALIBRATE_BV:    bleCmd.calibrateBV  = true; break;
        case CMD_SET_SPEED:
            if (len >= 2) {
                bleCmd.setSpeed = true;
                bleCmd.newSpeed = data[1];
            }
            break;
        default:
            DBG_PRINTF("[BLE] Unknown command: 0x%02X\n", cmd);
            break;
    }
}

void EtchBotBLEService::onCalibrationWrite(uint16_t, BLECharacteristic*, uint8_t* data, uint16_t len) {
    if (len < sizeof(CalibrationWireData)) return;
    memcpy((void*)&bleCmd.newCalibration, data, sizeof(CalibrationWireData));
    bleCmd.calibrationWritten = true;
    DBG_PRINTLN("[BLE] Calibration data received");
}

void EtchBotBLEService::onConnect(uint16_t conn_hdl) {
    DBG_PRINTLN("[BLE] Central connected");
    (void)conn_hdl;
}

void EtchBotBLEService::onDisconnect(uint16_t conn_hdl, uint8_t reason) {
    DBG_PRINTF("[BLE] Central disconnected (reason 0x%02X) — drawing continues\n", reason);
    (void)conn_hdl;
    // The drawing executor continues regardless — Feather is autonomous.
}
