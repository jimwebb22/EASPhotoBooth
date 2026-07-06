// ToneShaper.swift — EtchBot
// Pure tone-mapping functions applied to grayscale/density pixel buffers.
// Platform-independent (no UIKit) so the SPM test suite can exercise them;
// ImagePreprocessor composes these into its pipeline.

import Foundation

public enum ToneShaper {

    /// Contrast adjustment as a linear stretch pivoted on mid-gray:
    /// v' = (v - 0.5) * multiplier + 0.5, clamped to [0, 1].
    /// Unlike a plain multiply (which just brightens toward white), this
    /// darkens shadows and brightens highlights symmetrically.
    public static func applyContrast(_ pixels: inout [Float], multiplier: Float) {
        guard multiplier != 1.0 else { return }
        for i in 0..<pixels.count {
            pixels[i] = ((pixels[i] - 0.5) * multiplier + 0.5).clamped(to: 0...1)
        }
    }

    /// Gamma shaping on a density buffer (0 = no dot, 1 = max density).
    /// gamma > 1 suppresses weak densities and increases midtone/shadow
    /// separation — perceived tone from stippling is nonlinear in dot
    /// spacing, so linear density reads muddy.
    public static func applyGamma(_ pixels: inout [Float], gamma: Float) {
        guard gamma != 1.0, gamma > 0 else { return }
        for i in 0..<pixels.count {
            let v = pixels[i]
            pixels[i] = v <= 0 ? 0 : pow(v, gamma)
        }
    }

    /// Background cutoff: density at or below `cutoff` becomes exactly 0 so
    /// no stipple points ever land in blank regions; a smoothstep ramp over
    /// `softness` above the cutoff avoids a visible hard band.
    public static func applyBackgroundCutoff(
        _ pixels: inout [Float],
        cutoff: Float,
        softness: Float = 0.06
    ) {
        guard cutoff > 0 else { return }
        let ramp = max(softness, 1e-4)
        for i in 0..<pixels.count {
            let v = pixels[i]
            if v <= cutoff {
                pixels[i] = 0
            } else if v < cutoff + ramp {
                let t = (v - cutoff) / ramp
                pixels[i] = v * t * t * (3 - 2 * t)  // smoothstep
            }
        }
    }
}
