// DrawingPreviewView.swift — EtchBot
// Renders the TSP drawing path as a continuous line on a grey canvas,
// mimicking the Etch-a-Sketch drawing surface.

import SwiftUI

struct DrawingPreviewView: View {

    /// Ordered stipple points representing the drawing path.
    let points: [StipplePoint]
    /// Animated progress (0.0 = no drawing, 1.0 = full drawing shown).
    var progress: Double = 1.0
    var lineColor: Color = Color.etchDark
    var backgroundColor: Color = Color.etchGrey

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundColor
                if points.count >= 2 {
                    DrawingPathShape(points: points, progress: progress)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: — Shape

private struct DrawingPathShape: Shape {

    let points: [StipplePoint]
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard points.count >= 2 else { return Path() }

        // Compute bounds of point set
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        let minX = xs.min()!; let maxX = xs.max()!
        let minY = ys.min()!; let maxY = ys.max()!
        let rangeX = max(maxX - minX, 1)
        let rangeY = max(maxY - minY, 1)

        func transform(_ p: StipplePoint) -> CGPoint {
            CGPoint(
                x: CGFloat((p.x - minX) / rangeX) * rect.width  + rect.minX,
                y: CGFloat((p.y - minY) / rangeY) * rect.height + rect.minY
            )
        }

        let visibleCount = max(2, Int(Double(points.count) * progress))
        var path = Path()
        path.move(to: transform(points[0]))
        for i in 1..<visibleCount {
            path.addLine(to: transform(points[i]))
        }
        return path
    }
}

// MARK: — Preview

#if DEBUG
struct DrawingPreviewView_Previews: PreviewProvider {
    static var samplePoints: [StipplePoint] = (0..<100).map { i in
        let angle = Double(i) / 100.0 * .pi * 10
        let r = Float(i) / 10.0
        return StipplePoint(x: Float(cos(angle)) * r + 50, y: Float(sin(angle)) * r + 50)
    }

    static var previews: some View {
        DrawingPreviewView(points: samplePoints, progress: 1.0)
            .frame(width: 300, height: 192)
            .previewLayout(.sizeThatFits)
    }
}
#endif
