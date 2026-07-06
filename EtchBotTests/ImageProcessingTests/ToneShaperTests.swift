// ToneShaperTests.swift — EtchBotTests
// Tests for the pure tone-mapping functions used by ImagePreprocessor.

import XCTest
@testable import EtchBotCore

final class ToneShaperTests: XCTestCase {

    // MARK: — Contrast (mid-gray pivot)

    func testContrastIdentityAtOne() {
        var pixels: [Float] = [0, 0.25, 0.5, 0.75, 1]
        let original = pixels
        ToneShaper.applyContrast(&pixels, multiplier: 1.0)
        XCTAssertEqual(pixels, original)
    }

    func testContrastPivotsOnMidGray() {
        var pixels: [Float] = [0.5]
        ToneShaper.applyContrast(&pixels, multiplier: 2.0)
        XCTAssertEqual(pixels[0], 0.5, accuracy: 1e-5, "Mid-gray must be invariant")
    }

    func testContrastDarkensShadowsAndBrightensHighlights() {
        var pixels: [Float] = [0.3, 0.7]
        ToneShaper.applyContrast(&pixels, multiplier: 1.5)
        XCTAssertLessThan(pixels[0], 0.3, "Shadows must get darker")
        XCTAssertGreaterThan(pixels[1], 0.7, "Highlights must get brighter")
    }

    func testContrastClampsToUnitRange() {
        var pixels: [Float] = [0.05, 0.95]
        ToneShaper.applyContrast(&pixels, multiplier: 2.0)
        XCTAssertEqual(pixels[0], 0)
        XCTAssertEqual(pixels[1], 1)
    }

    func testContrastReductionCompresses() {
        var pixels: [Float] = [0.0, 1.0]
        ToneShaper.applyContrast(&pixels, multiplier: 0.5)
        XCTAssertEqual(pixels[0], 0.25, accuracy: 1e-5)
        XCTAssertEqual(pixels[1], 0.75, accuracy: 1e-5)
    }

    // MARK: — Gamma

    func testGammaIdentityAtOne() {
        var pixels: [Float] = [0, 0.3, 0.6, 1]
        let original = pixels
        ToneShaper.applyGamma(&pixels, gamma: 1.0)
        XCTAssertEqual(pixels, original)
    }

    func testGammaPreservesEndpointsAndSuppressesMidtones() {
        var pixels: [Float] = [0, 0.5, 1]
        ToneShaper.applyGamma(&pixels, gamma: 1.8)
        XCTAssertEqual(pixels[0], 0)
        XCTAssertEqual(pixels[2], 1, accuracy: 1e-5)
        XCTAssertLessThan(pixels[1], 0.5, "gamma > 1 must suppress midtones")
        XCTAssertGreaterThan(pixels[1], 0, "but not to zero")
    }

    func testGammaIsMonotonic() {
        var pixels: [Float] = [0.1, 0.2, 0.4, 0.8]
        ToneShaper.applyGamma(&pixels, gamma: 2.0)
        for i in 1..<pixels.count {
            XCTAssertGreaterThan(pixels[i], pixels[i - 1])
        }
    }

    // MARK: — Background cutoff

    func testCutoffZerosBackground() {
        var pixels: [Float] = [0, 0.04, 0.08]
        ToneShaper.applyBackgroundCutoff(&pixels, cutoff: 0.08)
        XCTAssertEqual(pixels, [0, 0, 0], "Values at or below the cutoff must become exactly zero")
    }

    func testCutoffLeavesForegroundUntouched() {
        var pixels: [Float] = [0.5, 0.9, 1.0]
        ToneShaper.applyBackgroundCutoff(&pixels, cutoff: 0.08, softness: 0.06)
        XCTAssertEqual(pixels, [0.5, 0.9, 1.0], "Values above cutoff + softness must be unchanged")
    }

    func testCutoffRampIsBetweenZeroAndOriginal() {
        var pixels: [Float] = [0.11]  // inside the [0.08, 0.14] ramp
        ToneShaper.applyBackgroundCutoff(&pixels, cutoff: 0.08, softness: 0.06)
        XCTAssertGreaterThan(pixels[0], 0)
        XCTAssertLessThan(pixels[0], 0.11)
    }

    func testCutoffDisabledAtZero() {
        var pixels: [Float] = [0.01, 0.5]
        let original = pixels
        ToneShaper.applyBackgroundCutoff(&pixels, cutoff: 0)
        XCTAssertEqual(pixels, original)
    }
}
