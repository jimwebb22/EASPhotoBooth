// EtchASketchFrame.swift — EtchBot
// Reusable SwiftUI view that renders the iconic Etch-a-Sketch frame
// around any content.
//
// Visual design:
//   - Outer frame: rounded rectangle, Etch-a-Sketch red (#D4262A)
//   - Top banner: "EtchBot" in bold rounded system font
//   - Screen area: rounded rect, light grey (#C8C8C8) — content goes here
//   - Bottom: two decorative knobs at lower-left and lower-right

import SwiftUI

/// The Etch-a-Sketch red colour.
public extension Color {
    static let etchRed   = Color(red: 0.831, green: 0.149, blue: 0.165)  // #D4262A
    static let etchGrey  = Color(red: 0.784, green: 0.784, blue: 0.784)  // #C8C8C8
    static let etchDark  = Color(red: 0.200, green: 0.200, blue: 0.200)  // #333333
}

/// A view modifier that wraps content in the Etch-a-Sketch frame.
public struct EtchASketchFrame<Content: View>: View {

    let content: Content
    var title: String = "EtchBot"
    var showKnobs: Bool = true

    public init(title: String = "EtchBot", showKnobs: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showKnobs = showKnobs
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            let frameW = geo.size.width
            let knobSize = frameW * 0.12
            let cornerRadius = frameW * 0.06
            let screenInset = frameW * 0.05
            let bannerHeight = frameW * 0.10
            let bottomBarHeight = showKnobs ? (knobSize + screenInset * 2) : screenInset

            ZStack(alignment: .top) {
                // Outer red frame
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.etchRed)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 4, y: 4)

                VStack(spacing: 0) {
                    // Banner
                    Text(title)
                        .font(.system(size: frameW * 0.07, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(height: bannerHeight)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)

                    // Screen
                    RoundedRectangle(cornerRadius: cornerRadius * 0.6)
                        .fill(Color.etchGrey)
                        .overlay(
                            // Inner shadow for depth
                            RoundedRectangle(cornerRadius: cornerRadius * 0.6)
                                .stroke(Color.black.opacity(0.15), lineWidth: 3)
                                .blur(radius: 2)
                        )
                        .overlay(
                            content
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius * 0.5))
                        )
                        .padding(.horizontal, screenInset)

                    Spacer(minLength: 0)
                        .frame(height: bottomBarHeight)
                }

                // Knobs at bottom
                if showKnobs {
                    VStack {
                        Spacer()
                        HStack {
                            EtchKnob()
                                .frame(width: knobSize, height: knobSize)
                                .padding(.leading, screenInset * 0.8)
                            Spacer()
                            EtchKnob()
                                .frame(width: knobSize, height: knobSize)
                                .padding(.trailing, screenInset * 0.8)
                        }
                        .padding(.bottom, screenInset)
                    }
                }
            }
        }
        .aspectRatio(CGSize(width: 500, height: 420), contentMode: .fit)
    }
}

// MARK: — Knob view

private struct EtchKnob: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.9), Color(white: 0.75)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 30
                    )
                )
                .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
            // Cross-hatch grip marks
            ForEach(0..<8) { i in
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 12)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }
}

// MARK: — Preview

#if DEBUG
struct EtchASketchFrame_Previews: PreviewProvider {
    static var previews: some View {
        EtchASketchFrame(title: "EtchBot") {
            ZStack {
                Color.etchGrey
                Text("Preview")
                    .foregroundColor(.etchDark)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
