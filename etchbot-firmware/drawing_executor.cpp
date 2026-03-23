// drawing_executor.cpp — EtchBot Firmware

#include "drawing_executor.h"
#include "path_storage.h"
#include "motor_controller.h"
#include <Arduino.h>

DrawingExecutor drawingExecutor;

// ─────────────────────────────────────────────────────────────────────────────
// prepare()
// ─────────────────────────────────────────────────────────────────────────────

void DrawingExecutor::prepare() {
    _payload    = pathStorage.payloadPtr();
    _totalMoves = pathStorage.header().moveCount;
    _moveIdx    = 0;
    _running    = true;
    _paused     = false;
    _complete   = false;
    _lastNotifyMs    = millis();
    _movesSinceNotify = 0;

    DBG_PRINTF("[EXEC] Drawing prepared: %u moves\n", _totalMoves);

    // Notify iOS: drawing has started
    bleService.notifyStatus(STATE_DRAWING, 0, _totalMoves);
}

// ─────────────────────────────────────────────────────────────────────────────
// tick() — called from main loop
// ─────────────────────────────────────────────────────────────────────────────

bool DrawingExecutor::tick(uint16_t movesPerTick) {
    if (!_running || _paused || _complete) return !_complete;

    const uint16_t endIdx = min((uint16_t)(_moveIdx + movesPerTick), _totalMoves);

    while (_moveIdx < endIdx) {
        StepDir  dir;
        uint16_t runLen;
        decodeMove(_moveIdx, dir, runLen);

        // Variable speed: long straight segments can run faster without quality loss
        uint16_t rpm = speedForRunLength(runLen);
        motors.setSpeedRPM(rpm);
        motors.move(dir, runLen);

        _moveIdx++;
        _movesSinceNotify++;
    }

    maybeNotifyStatus();

    if (_moveIdx >= _totalMoves) {
        _complete = true;
        _running  = false;
        motors.release();
        bleService.notifyStatus(STATE_COMPLETE, _moveIdx, _totalMoves);
        DBG_PRINTLN("[EXEC] Drawing complete");
        return false;
    }

    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pause / Resume / Cancel
// ─────────────────────────────────────────────────────────────────────────────

void DrawingExecutor::pause() {
    if (!_running || _paused) return;
    _paused = true;
    bleService.notifyStatus(STATE_PAUSED, _moveIdx, _totalMoves);
    DBG_PRINTF("[EXEC] Paused at move %u / %u\n", _moveIdx, _totalMoves);
}

void DrawingExecutor::resume() {
    if (!_paused) return;
    _paused = false;
    bleService.notifyStatus(STATE_DRAWING, _moveIdx, _totalMoves);
    DBG_PRINTF("[EXEC] Resumed at move %u / %u\n", _moveIdx, _totalMoves);
}

void DrawingExecutor::cancel() {
    _running  = false;
    _paused   = false;
    _complete = false;
    _moveIdx  = 0;
    motors.release();
    bleService.notifyStatus(STATE_IDLE, 0, 0);
    DBG_PRINTLN("[EXEC] Cancelled");
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

uint16_t DrawingExecutor::speedForRunLength(uint16_t runLen) const {
    // Long straight segments can be drawn faster without visible quality loss.
    // Short segments near detail areas stay at the default speed.
    if (runLen > 200) return SPEED_MAX_RPM;       // 200 RPM for long traversals
    if (runLen > 50)  return 150;                  // 150 RPM for medium segments
    return SPEED_DRAW_DEFAULT_RPM;                 // 100 RPM for detail work
}

void DrawingExecutor::decodeMove(uint16_t index, StepDir& dir, uint16_t& runLen) const {
    // Each move is 2 bytes at payload offset index*2:
    //   Byte 0: [7:5] direction (3 bits) | [4:0] runLength high 5 bits
    //   Byte 1: runLength low 8 bits
    const uint8_t b0 = _payload[index * 2];
    const uint8_t b1 = _payload[index * 2 + 1];
    dir    = (StepDir)((b0 >> 5) & 0x07);
    runLen = ((uint16_t)(b0 & 0x1F) << 8) | b1;
    if (runLen == 0) runLen = 1;  // guard against malformed data
}

void DrawingExecutor::maybeNotifyStatus() {
    bool byCount = (_movesSinceNotify >= STATUS_NOTIFY_MOVE_INTERVAL);
    bool byTime  = ((millis() - _lastNotifyMs) >= STATUS_NOTIFY_MS_INTERVAL);

    if (byCount || byTime) {
        bleService.notifyStatus(STATE_DRAWING, _moveIdx, _totalMoves);
        _movesSinceNotify = 0;
        _lastNotifyMs     = millis();
    }
}
