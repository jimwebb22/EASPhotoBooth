// path_storage.cpp — EtchBot Firmware

#include "path_storage.h"
#include <string.h>

// Global singleton
PathStorage pathStorage;

// ─────────────────────────────────────────────────────────────────────────────
// Public methods
// ─────────────────────────────────────────────────────────────────────────────

void PathStorage::beginTransfer(uint32_t totalBytes) {
    reset();
    _totalExpected = (totalBytes < PATH_BUFFER_SIZE) ? totalBytes : PATH_BUFFER_SIZE;
    DBG_PRINTF("[PATH] Transfer started, expecting %u bytes\n", _totalExpected);
}

bool PathStorage::appendChunk(const uint8_t* data, uint16_t len) {
    if (_writePos + len > PATH_BUFFER_SIZE) {
        DBG_PRINTLN("[PATH] ERROR: chunk would overflow buffer");
        return false;
    }
    memcpy(_buf + _writePos, data, len);
    _writePos      += len;
    _chunksReceived += 1;
    DBG_PRINTF("[PATH] Chunk %u received, %u / %u bytes\n",
               _chunksReceived, _writePos, _totalExpected);
    return true;
}

bool PathStorage::finalise() {
    _valid = false;

    // Minimum viable path: 12-byte header + at least one 2-byte move
    if (_writePos < PATH_HEADER_SIZE + 2) {
        DBG_PRINTLN("[PATH] ERROR: too few bytes to be a valid path");
        return false;
    }

    // Check magic bytes
    if (_buf[0] != PATH_MAGIC_BYTE_0 || _buf[1] != PATH_MAGIC_BYTE_1) {
        DBG_PRINTF("[PATH] ERROR: bad magic bytes 0x%02X 0x%02X\n", _buf[0], _buf[1]);
        return false;
    }

    if (!parseHeader()) {
        return false;
    }

    // Verify CRC-16 over payload only (bytes after 12-byte header)
    size_t payloadLen = _writePos - PATH_HEADER_SIZE;
    uint16_t computed = crc16(_buf + PATH_HEADER_SIZE, payloadLen);
    if (computed != _header.payloadCRC) {
        DBG_PRINTF("[PATH] ERROR: CRC mismatch — computed 0x%04X, stored 0x%04X\n",
                   computed, _header.payloadCRC);
        return false;
    }

    // Sanity check: moveCount must match payload size
    uint32_t expectedPayload = (uint32_t)_header.moveCount * 2u;
    if (payloadLen < expectedPayload) {
        DBG_PRINTF("[PATH] ERROR: payload %u bytes < expected %u bytes for %u moves\n",
                   (unsigned)payloadLen, (unsigned)expectedPayload, _header.moveCount);
        return false;
    }

    _valid = true;
    DBG_PRINTF("[PATH] Validated — %u moves, %u×%u steps, ~%us\n",
               _header.moveCount, _header.widthSteps,
               _header.heightSteps, _header.estimatedSeconds);
    return true;
}

void PathStorage::reset() {
    _writePos       = 0;
    _totalExpected  = 0;
    _chunksReceived = 0;
    _valid          = false;
    memset(&_header, 0, sizeof(_header));
}

// ─────────────────────────────────────────────────────────────────────────────
// Private methods
// ─────────────────────────────────────────────────────────────────────────────

bool PathStorage::parseHeader() {
    // All uint16 fields are little-endian
    _header.moveCount        = (uint16_t)(_buf[2])  | ((uint16_t)(_buf[3])  << 8);
    _header.widthSteps       = (uint16_t)(_buf[4])  | ((uint16_t)(_buf[5])  << 8);
    _header.heightSteps      = (uint16_t)(_buf[6])  | ((uint16_t)(_buf[7])  << 8);
    _header.estimatedSeconds = (uint16_t)(_buf[8])  | ((uint16_t)(_buf[9])  << 8);
    _header.payloadCRC       = (uint16_t)(_buf[10]) | ((uint16_t)(_buf[11]) << 8);

    if (_header.moveCount == 0) {
        DBG_PRINTLN("[PATH] ERROR: moveCount is zero");
        return false;
    }
    return true;
}

// CRC-16/IBM: poly 0x8005, init 0x0000, reflect in/out.
// Matches the iOS Swift implementation (poly constant 0xA001 = bit-reversed 0x8005).
uint16_t PathStorage::crc16(const uint8_t* data, size_t len) {
    uint16_t crc = 0x0000;
    for (size_t i = 0; i < len; i++) {
        crc ^= (uint16_t)data[i];
        for (int j = 0; j < 8; j++) {
            if (crc & 1u) crc = (crc >> 1) ^ 0xA001u;
            else           crc >>= 1;
        }
    }
    return crc;
}
