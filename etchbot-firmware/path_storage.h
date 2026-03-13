// path_storage.h — EtchBot Firmware
// 50KB RAM buffer for receiving and storing the encoded drawing path over BLE.
// Handles chunked incoming writes, CRC-16/IBM verification, and header parsing.

#pragma once
#include <stdint.h>
#include <stddef.h>
#include "config.h"

// ─────────────────────────────────────────────────────────────────────────────
// Path Header (parsed from the first 12 bytes of the buffer)
// ─────────────────────────────────────────────────────────────────────────────

struct PathHeader {
    uint16_t moveCount;          // total number of 2-byte move commands
    uint16_t widthSteps;         // drawing width in motor steps
    uint16_t heightSteps;        // drawing height in motor steps
    uint16_t estimatedSeconds;   // estimated draw time
    uint16_t payloadCRC;         // CRC-16 of payload bytes only
};

// ─────────────────────────────────────────────────────────────────────────────
// PathStorage class
// ─────────────────────────────────────────────────────────────────────────────

class PathStorage {
public:
    // Called when iOS sends START_TRANSFER with totalBytes.
    // Resets buffer and prepares for incoming data.
    void beginTransfer(uint32_t totalBytes);

    // Called for each incoming Drawing Data characteristic write.
    // Returns true if chunk was accepted, false if buffer would overflow.
    bool appendChunk(const uint8_t* data, uint16_t len);

    // Called when iOS sends END_TRANSFER.
    // Verifies magic bytes and CRC-16. Returns true on success.
    bool finalise();

    // True after a successful finalise().
    bool isValid() const { return _valid; }

    // Parsed header (valid only after finalise() returns true).
    const PathHeader& header() const { return _header; }

    // Pointer to the first move command byte (payload after 12-byte header).
    const uint8_t* payloadPtr() const { return _buf + PATH_HEADER_SIZE; }

    // Total bytes received so far.
    uint32_t bytesReceived() const { return _writePos; }

    // Expected total bytes (from START_TRANSFER).
    uint32_t totalExpected() const { return _totalExpected; }

    // Chunks received so far.
    uint16_t chunksReceived() const { return _chunksReceived; }

    // Reset to idle state.
    void reset();

private:
    // The 50KB RAM buffer — largest allocation in the firmware.
    uint8_t _buf[PATH_BUFFER_SIZE];

    uint32_t _writePos        = 0;
    uint32_t _totalExpected   = 0;
    uint16_t _chunksReceived  = 0;
    bool     _valid           = false;
    PathHeader _header        = {};

    // CRC-16/IBM — matches iOS Data.crc16 extension (poly 0xA001 reflected)
    static uint16_t crc16(const uint8_t* data, size_t len);

    // Parse header fields from _buf[0..11]
    bool parseHeader();
};

// Global singleton
extern PathStorage pathStorage;
