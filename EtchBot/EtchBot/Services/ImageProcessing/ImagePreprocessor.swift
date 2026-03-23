// ImagePreprocessor.swift — EtchBot
// Converts a UIImage into a normalized DensityMap suitable for Voronoi stippling.
//
// Pipeline:
//   1. Downscale to working resolution (500 × 320 max)
//   2. Convert to 8-bit grayscale via vImage
//   3. Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
//   4. Invert: dark pixels → high density (more dots)
//   5. Optionally blend with Canny edge map
//   6. Output normalized DensityMap (Float32, 0 = no dot, 1 = max dot density)
//
// Performance target: <200ms on iPhone 12+

#if canImport(UIKit)
import UIKit
import Accelerate

nonisolated public enum ImagePreprocessorError: Error {
    case invalidImage
    case conversionFailed(String)
}

nonisolated public final class ImagePreprocessor: Sendable {

    // MARK: — Constants
    /// Working resolution — matches Etch-a-Sketch proportions (1000:640 ≈ 25:16).
    /// Higher resolution preserves more tonal detail for stippling at 8000+ points.
    public static let workingWidth = 1000
    public static let workingHeight = 640

    // MARK: — Public entry point

    /// Convert a UIImage into a DensityMap.
    /// - Parameters:
    ///   - image: Source image (any size).
    ///   - settings: Drawing settings (contrast, edge emphasis, etc.).
    /// - Returns: DensityMap at working resolution.
    public static func process(
        image: UIImage,
        settings: DrawingSettings
    ) throws -> DensityMap {
        // 1. Resize to working resolution (aspect-fill then crop)
        guard let resized = resizedImage(image, to: CGSize(width: workingWidth, height: workingHeight)) else {
            throw ImagePreprocessorError.conversionFailed("Resize failed")
        }

        // 2. Convert to grayscale float pixels
        var grayPixels = try toGrayscaleFloat(image: resized)

        // 3. Apply contrast boost
        if settings.contrastMultiplier != 1.0 {
            let factor = Float(settings.contrastMultiplier)
            applyContrastBoost(pixels: &grayPixels, factor: factor)
        }

        // 4. Apply CLAHE
        applyCLAHE(pixels: &grayPixels, width: workingWidth, height: workingHeight)

        // 5. Invert: 0 = white → 0 density; 1 = black → 1 density
        //    Input grayPixels: 0=black, 1=white → invert to get density
        var densityPixels = grayPixels.map { 1.0 - $0 }

        // 5b. Suppress blurry/out-of-focus background regions
        suppressBackground(pixels: &densityPixels, width: workingWidth, height: workingHeight)

        // 6. Blend with edge map if enabled
        if settings.edgeEmphasisEnabled {
            let edgeMap = try EdgeDetector.multiScaleCanny(
                pixels: grayPixels,      // pass original (not inverted) for edge detection
                width: workingWidth,
                height: workingHeight
            )
            let w = Float(settings.edgeWeight)
            for i in 0..<densityPixels.count {
                // Adaptive blending: edges always add density, never reduce it.
                // In edge regions, boost density to concentrate stipple points on structure.
                let edgeBoost = edgeMap[i] * w * 2.0  // edges contribute strongly
                densityPixels[i] = max(densityPixels[i], edgeBoost).clamped(to: 0...1)
            }
        }

        // 7. Clamp to [0, 1]
        densityPixels = densityPixels.map { $0.clamped(to: 0...1) }

        return DensityMap(width: workingWidth, height: workingHeight, pixels: densityPixels)
    }

    // MARK: — Private: Resize

    private static func resizedImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        // Aspect-fill: scale uniformly so that both dimensions are >= size, then crop centre.
        guard let cgImage = image.cgImage else { return nil }
        let srcW = CGFloat(cgImage.width)
        let srcH = CGFloat(cgImage.height)
        let scale = max(size.width / srcW, size.height / srcH)
        let scaledW = srcW * scale
        let scaledH = srcH * scale
        let offsetX = (scaledW - size.width) / 2
        let offsetY = (scaledH - size.height) / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(x: -offsetX, y: -offsetY, width: scaledW, height: scaledH))
        }
    }

    // MARK: — Private: Grayscale conversion via vImage

    private static func toGrayscaleFloat(image: UIImage) throws -> [Float] {
        guard let cgImage = image.cgImage else {
            throw ImagePreprocessorError.invalidImage
        }
        let width = cgImage.width
        let height = cgImage.height
        let pixelCount = width * height

        // Create an RGBA 8-bit buffer from cgImage
        var srcFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )!
        var rgbaBuffer = vImage_Buffer()
        let initError = vImageBuffer_InitWithCGImage(&rgbaBuffer, &srcFormat, nil, cgImage, vImage_Flags(kvImageNoFlags))
        guard initError == kvImageNoError else {
            throw ImagePreprocessorError.conversionFailed("vImage RGBA init: \(initError)")
        }
        defer { rgbaBuffer.data.deallocate() }

        // Convert RGBA → grayscale (8bpp)
        var grayBuffer = try createBuffer(width: width, height: height, bytesPerPixel: 1)
        defer { grayBuffer.data.deallocate() }

        // vImageMatrixMultiply_ARGB8888ToPlanar8: R*0.2126 + G*0.7152 + B*0.0722
        let divisor: Int32 = 0x1000
        let coefficients: [Int16] = [
            Int16(0.2126 * Float(divisor)),   // R
            Int16(0.7152 * Float(divisor)),   // G
            Int16(0.0722 * Float(divisor)),   // B
            0                                  // A
        ]
        // Use a pre-bias of 0, post-bias of 0
        let convError = vImageMatrixMultiply_ARGB8888ToPlanar8(
            &rgbaBuffer, &grayBuffer,
            coefficients, divisor,
            nil, 0,
            vImage_Flags(kvImageNoFlags)
        )
        guard convError == kvImageNoError else {
            throw ImagePreprocessorError.conversionFailed("vImage grayscale convert: \(convError)")
        }

        // Convert UInt8 gray → Float in [0, 1]
        var floats = [Float](repeating: 0, count: pixelCount)
        floats.withUnsafeMutableBufferPointer { buffer in
            var floatBuffer = vImage_Buffer(
                data: buffer.baseAddress!,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width * MemoryLayout<Float>.size
            )
            _ = vImageConvert_Planar8toPlanarF(&grayBuffer, &floatBuffer, 1.0, 0.0, vImage_Flags(kvImageNoFlags))
        }
        return floats
    }

    private static func createBuffer(width: Int, height: Int, bytesPerPixel: Int) throws -> vImage_Buffer {
        let rowBytes = width * bytesPerPixel
        guard let data = malloc(height * rowBytes) else {
            throw ImagePreprocessorError.conversionFailed("malloc failed")
        }
        return vImage_Buffer(
            data: data,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: rowBytes
        )
    }

    // MARK: — Private: Contrast boost (sigmoid curve)

    /// Apply a sigmoid contrast curve that preserves the full tonal range.
    /// Unlike linear multiplication, this doesn't clip highlights/shadows.
    /// Steepness scales with the contrast multiplier setting.
    private static func applyContrastBoost(pixels: inout [Float], factor: Float) {
        let steepness = 5.0 * factor  // factor 1.0 → gentle, 2.0 → strong, 3.0 → very strong
        let midpoint: Float = 0.5
        for i in 0..<pixels.count {
            let x = pixels[i]
            pixels[i] = 1.0 / (1.0 + exp(-steepness * (x - midpoint)))
        }
    }

    // MARK: — Private: Background suppression

    /// Suppress low-variance (blurry/out-of-focus) regions by reducing their density.
    /// This concentrates stipple points on sharp foreground subjects.
    private static func suppressBackground(
        pixels: inout [Float],
        width: Int,
        height: Int,
        tileSize: Int = 16,
        varianceThreshold: Float = 0.01,
        suppressionFactor: Float = 0.3
    ) {
        let tilesX = (width + tileSize - 1) / tileSize
        let tilesY = (height + tileSize - 1) / tileSize

        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let x0 = tx * tileSize
                let y0 = ty * tileSize
                let x1 = min(x0 + tileSize, width)
                let y1 = min(y0 + tileSize, height)

                // Compute local mean and variance
                var sum: Float = 0
                var sumSq: Float = 0
                var count: Float = 0
                for y in y0..<y1 {
                    for x in x0..<x1 {
                        let v = pixels[y * width + x]
                        sum += v
                        sumSq += v * v
                        count += 1
                    }
                }
                let mean = sum / count
                let variance = (sumSq / count) - (mean * mean)

                // Suppress low-variance tiles
                if variance < varianceThreshold {
                    for y in y0..<y1 {
                        for x in x0..<x1 {
                            pixels[y * width + x] *= suppressionFactor
                        }
                    }
                }
            }
        }
    }

    // MARK: — Private: CLAHE

    /// Contrast Limited Adaptive Histogram Equalization.
    /// Divides image into a grid of tiles, equalizes each tile's histogram,
    /// clips contrast above `clipLimit`, then bilinearly interpolates tile boundaries.
    private static func applyCLAHE(
        pixels: inout [Float],
        width: Int,
        height: Int,
        tileRows: Int = 8,
        tileCols: Int = 8,
        clipLimit: Float = 3.0,
        histBins: Int = 256
    ) {
        let tileH = height / tileRows
        let tileW = width / tileCols
        guard tileH > 0, tileW > 0 else { return }

        // Build LUT for each tile
        var luts = [[[Float]]](
            repeating: [[Float]](repeating: [Float](repeating: 0, count: histBins), count: tileCols),
            count: tileRows
        )

        for row in 0..<tileRows {
            for col in 0..<tileCols {
                let x0 = col * tileW
                let y0 = row * tileH
                let x1 = col == tileCols - 1 ? width : x0 + tileW
                let y1 = row == tileRows - 1 ? height : y0 + tileH

                // Compute histogram
                var hist = [Float](repeating: 0, count: histBins)
                var count = 0
                for y in y0..<y1 {
                    for x in x0..<x1 {
                        let bin = Int(pixels[y * width + x] * Float(histBins - 1))
                        hist[min(bin, histBins - 1)] += 1
                        count += 1
                    }
                }

                // Clip histogram
                let clipCount = clipLimit * (Float(count) / Float(histBins))
                var excess: Float = 0
                for i in 0..<histBins {
                    if hist[i] > clipCount {
                        excess += hist[i] - clipCount
                        hist[i] = clipCount
                    }
                }
                // Redistribute excess uniformly
                let add = excess / Float(histBins)
                for i in 0..<histBins { hist[i] += add }

                // Build CDF → LUT
                var cdf: Float = 0
                var lut = [Float](repeating: 0, count: histBins)
                for i in 0..<histBins {
                    cdf += hist[i]
                    lut[i] = (cdf / Float(count)).clamped(to: 0...1)
                }
                luts[row][col] = lut
            }
        }

        // Bilinear interpolation across tile boundaries
        for y in 0..<height {
            for x in 0..<width {
                let v = pixels[y * width + x]
                let bin = min(Int(v * Float(histBins - 1)), histBins - 1)

                // Tile coordinates (floating point)
                let tileX = (Float(x) / Float(width)) * Float(tileCols) - 0.5
                let tileY = (Float(y) / Float(height)) * Float(tileRows) - 0.5
                let tx = tileX - floor(tileX)
                let ty = tileY - floor(tileY)
                let c0 = max(0, min(tileCols - 1, Int(tileX)))
                let r0 = max(0, min(tileRows - 1, Int(tileY)))
                let c1 = min(tileCols - 1, c0 + 1)
                let r1 = min(tileRows - 1, r0 + 1)

                let v00 = luts[r0][c0][bin]
                let v10 = luts[r0][c1][bin]
                let v01 = luts[r1][c0][bin]
                let v11 = luts[r1][c1][bin]
                let interpolated = (1 - tx) * (1 - ty) * v00
                                 + tx * (1 - ty) * v10
                                 + (1 - tx) * ty * v01
                                 + tx * ty * v11
                pixels[y * width + x] = interpolated
            }
        }
    }
}
#endif
