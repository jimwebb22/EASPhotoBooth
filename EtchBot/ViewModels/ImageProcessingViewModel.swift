// ImageProcessingViewModel.swift — EtchBot
// Drives the image-to-drawing pipeline: preprocessing → stippling → TSP → encoding.
// Publishes intermediate results for the editor UI.

import Foundation
import UIKit
import Combine

@MainActor
public final class ImageProcessingViewModel: ObservableObject {

    // MARK: — Published state
    @Published public var sourceImage: UIImage?
    @Published public var previewImage: UIImage?  // Line drawing rendered as UIImage
    @Published public var stipplePoints: [StipplePoint]?
    @Published public var drawingPath: DrawingPath?
    @Published public var settings: DrawingSettings = .defaults
    @Published public var isProcessing: Bool = false
    @Published public var processingProgress: Double = 0
    @Published public var currentPhase: ProcessingPhase = .preprocessing
    @Published public var processingDetail: String = ""
    @Published public var showPhotoPicker: Bool = false
    @Published public var transferError: String?

    // MARK: — Private
    private var debounceTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var calibration: CalibrationData = .defaults

    // MARK: — Source image management

    public func setSourceImage(_ image: UIImage) {
        sourceImage = image
        stipplePoints = nil
        drawingPath = nil
        previewImage = nil
        Task { await processImage() }
    }

    public func updateCalibration(_ calibration: CalibrationData) {
        self.calibration = calibration
    }

    // MARK: — Debounced reprocess (called when settings change)

    public func reprocessDebounced() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await processImage()
        }
    }

    // MARK: — Main processing pipeline

    public func processImage() async {
        guard let source = sourceImage else { return }
        processingTask?.cancel()
        processingTask = Task {
            isProcessing = true
            processingProgress = 0
            stipplePoints = nil
            drawingPath = nil

            do {
                // Step 1: Preprocess (density map + optional edge map)
                currentPhase = .preprocessing
                processingDetail = "Converting to grayscale…"
                processingProgress = 0.05
                let localSettings = settings
                let preprocessed = try await Task.detached(priority: .userInitiated) {
                    try ImagePreprocessor.process(image: source, settings: localSettings)
                }.value

                guard !Task.isCancelled else { return }

                // Step 2 (hybrid style): trace contour chains and remove their
                // coverage from the tonal density so stipples don't double-draw.
                var chains: [[StipplePoint]] = []
                var stippleDensity = preprocessed.densityMap
                if localSettings.renderStyle == .hybrid, let edgeMap = preprocessed.edgeMap {
                    processingDetail = "Tracing contours…"
                    processingProgress = 0.12
                    let (tracedChains, reducedDensity) = await Task.detached(priority: .userInitiated) {
                        () -> ([[StipplePoint]], DensityMap) in
                        let traced = ContourTracer.trace(
                            edgeMap: edgeMap,
                            width: ImagePreprocessor.workingWidth,
                            height: ImagePreprocessor.workingHeight
                        )
                        let reduced = ContourTracer.subtractChains(
                            from: preprocessed.densityMap,
                            chains: traced
                        )
                        return (traced, reduced)
                    }.value
                    chains = tracedChains
                    stippleDensity = reducedDensity
                }

                guard !Task.isCancelled else { return }
                processingProgress = 0.15
                currentPhase = .stippling

                // Step 3: Voronoi stippling (over the chain-reduced density in hybrid)
                let points = await VoronoiStippler.stipple(
                    densityMap: stippleDensity,
                    settings: localSettings
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.processingDetail = "Iteration \(progress.iteration)/\(progress.totalIterations) — displacement: \(String(format: "%.1f", progress.averageDisplacement))px"
                        self.processingProgress = 0.15 + (Double(progress.iteration) / Double(max(1, progress.totalIterations))) * 0.35
                    }
                }

                guard !Task.isCancelled else { return }
                processingProgress = 0.50
                currentPhase = .solvingTSP

                // Step 4: Order everything into a single continuous polyline.
                let orderedPoints: [StipplePoint]
                if localSettings.renderStyle == .hybrid && !chains.isEmpty {
                    // Chains + stipples via the chained-tour solver.
                    processingDetail = "Routing continuous line…"
                    let elements = chains.map { TourElement.chain($0) }
                                 + points.map { TourElement.point($0) }
                    orderedPoints = await Task.detached(priority: .userInitiated) {
                        ChainedTourSolver.solve(elements: elements)
                    }.value
                } else {
                    // Pure stipple TSP.
                    let tour = await TSPSolver.solve(
                        points: points,
                        settings: localSettings
                    ) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.processingDetail = "\(progress.phase.rawValue) (pass \(progress.passNumber))"
                            self.processingProgress = 0.50 + progress.progressFraction * 0.30
                        }
                    }
                    guard !Task.isCancelled else { return }
                    // Drop the tour's longest edge so the worst jump is never drawn.
                    let orderedTour = TSPSolver.breakTourAtLongestEdge(tour: tour, points: points)
                    orderedPoints = orderedTour.map { points[$0] }
                }

                guard !Task.isCancelled else { return }
                stipplePoints = orderedPoints

                processingProgress = 0.80
                currentPhase = .optimizing
                processingDetail = "Optimizing motor path…"

                // Step 4: Path optimization
                let localCalibration = calibration
                let path = await Task.detached(priority: .userInitiated) {
                    PathOptimizer.optimize(
                        tour: Array(0..<orderedPoints.count),
                        points: orderedPoints,
                        densityMapWidth: ImagePreprocessor.workingWidth,
                        densityMapHeight: ImagePreprocessor.workingHeight,
                        calibration: localCalibration
                    )
                }.value

                guard !Task.isCancelled else { return }
                processingProgress = 0.90
                currentPhase = .encoding
                processingDetail = "Encoding for BLE transfer…"

                // Step 5: Encode
                let encodedPath = try DrawingPathEncoder.encode(path)
                drawingPath = encodedPath

                // Step 6: Render preview image
                previewImage = renderPreviewImage(points: orderedPoints)

                processingProgress = 1.0
                isProcessing = false

            } catch {
                processingDetail = "Error: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    // MARK: — Preview rendering

    private func renderPreviewImage(points: [StipplePoint]) -> UIImage? {
        guard points.count >= 2 else { return nil }
        // Render with the same uniform transform PathOptimizer uses to map
        // working-space points onto the drawing area — the preview must show
        // exactly what will be drawn. No bounding-box normalization: that
        // stretched the drawing non-uniformly and hid composition errors.
        let displayScale: CGFloat = 2  // uniform upscale for a crisp preview
        let size = CGSize(
            width: CGFloat(ImagePreprocessor.workingWidth) * displayScale,
            height: CGFloat(ImagePreprocessor.workingHeight) * displayScale
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Background
            UIColor(Color.etchGrey).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            func px(_ p: StipplePoint) -> CGPoint {
                CGPoint(x: CGFloat(p.x) * displayScale, y: CGFloat(p.y) * displayScale)
            }

            UIColor(Color.etchDark).setStroke()
            let path = UIBezierPath()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: px(points[0]))
            for i in 1..<points.count { path.addLine(to: px(points[i])) }
            path.stroke()
        }
    }

    // MARK: — Save to photo library

    public func savePreviewToPhotoLibrary() {
        guard let image = previewImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
