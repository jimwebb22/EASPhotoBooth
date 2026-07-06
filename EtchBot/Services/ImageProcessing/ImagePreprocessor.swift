// ImagePreprocessor.swift — EtchBot
// Converts a UIImage into a normalized DensityMap suitable for Voronoi stippling.
//
// Pipeline:
//   1. Downscale to working resolution (500 × 343, matches drawing-area aspect)
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

public enum ImagePreprocessorError: Error {
    case invalidImage
    case conversionFailed(String)
}

/// Output of the preprocessing stage.
public struct PreprocessedImage: Sendable {
    /// Tonal density map (with edge blend applied when style is .stipple
    /// and edge emphasis is on).
    public let densityMap: DensityMap
    /// Raw (undilated) Canny edge map at working resolution, for contour
    /// tracing. Present when the render style or edge emphasis needs it.
    public let edgeMap: [Float]?
}

public final class ImagePreprocessor: Sendable {

    // MARK: — Constants
    /// Working resolution — defined by WorkingCanvas (platform-independent),
    /// which matches the physical drawing-area aspect ratio.
    public static let workingWidth = WorkingCanvas.width
    public static let workingHeight = WorkingCanvas.height

    // MARK: — Public entry point

    /// Convert a UIImage into a PreprocessedImage (density map + edge map).
    /// - Parameters:
    ///   - image: Source image (any size).
    ///   - settings: Drawing settings (contrast, edge emphasis, style, etc.).
    /// - Returns: PreprocessedImage at working resolution.
    public static func process(
        image: UIImage,
        settings: DrawingSettings
    ) throws -> PreprocessedImage {
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

        // 6. Edge map: the hybrid style traces it into contour chains;
        //    the stipple style blends it into the density.
        var edgeMap: [Float]? = nil
        if settings.renderStyle == .hybrid || settings.edgeEmphasisEnabled {
            edgeMap = try EdgeDetector.canny(
                pixels: grayPixels,      // pass original (not inverted) for edge detection
                width: workingWidth,
                height: workingHeight
            )
        }

        // 7. Blend edges into density — stipple style only. The hybrid style
        //    draws contours explicitly, so blending would double-emphasize.
        //    Dilate 1px first so the thin Canny lines survive stippling.
        if settings.renderStyle == .stipple, settings.edgeEmphasisEnabled, let edges = edgeMap {
            let dilated = dilate3x3(edges, width: workingWidth, height: workingHeight)
            let w = Float(settings.edgeWeight)
            let t = 1.0 - w
            for i in 0..<densityPixels.count {
                densityPixels[i] = (densityPixels[i] * t + dilated[i] * w).clamped(to: 0...1)
            }
        }

        // 8. Clamp to [0, 1]
        densityPixels = densityPixels.map { $0.clamped(to: 0...1) }

        return PreprocessedImage(
            densityMap: DensityMap(width: workingWidth, height: workingHeight, pixels: densityPixels),
            edgeMap: edgeMap
        )
    }

    // MARK: — Private: 3×3 dilation

    /// Morphological dilation with a 3×3 kernel (max of 8-neighborhood).
    private static func dilate3x3(_ pixels: [Float], width: Int, height: Int) -> [Float] {
        var result = pixels
        for y in 0..<height {
            for x in 0..<width {
                var maxVal = pixels[y * width + x]
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let v = pixels[ny * width + nx]
                        if v > maxVal { maxVal = v }
                    }
                }
                result[y * width + x] = maxVal
            }
        }
        return result
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

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
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
        let rawPtr = grayBuffer.data.bindMemory(to: UInt8.self, capacity: pixelCount)
        var floats = [Float](repeating: 0, count: pixelCount)
        var floatBuffer = vImage_Buffer(data: &floats, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * MemoryLayout<Float>.size)
        let _ = vImageConvert_Planar8toPlanarF(&grayBuffer, &floatBuffer, 1.0, 0.0, vImage_Flags(kvImageNoFlags))
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

    // MARK: — Private: Contrast boost

    /// Multiply each pixel value by `factor`, clamping result to [0, 1].
    private static func applyContrastBoost(pixels: inout [Float], factor: Float) {
        let n = vDSP_Length(pixels.count)
        var f = factor
        vDSP_vsmul(pixels, 1, &f, &pixels, 1, n)
        var lo: Float = 0; var hi: Float = 1
        vDSP_vclip(pixels, 1, &lo, &hi, &pixels, 1, n)
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
