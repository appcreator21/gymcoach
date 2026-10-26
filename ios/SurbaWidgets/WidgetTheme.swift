import SwiftUI

enum WidgetTheme {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.13)
    static let mint = Color(red: 0.25, green: 0.88, blue: 0.70)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let background = Color(white: 0.06)
    static let field = Color(white: 0.16)
    static let link = URL(string: "surbafit://workout")!
}

/// A thin progress ring.
struct RingView: View {
    var progress: Double
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(WidgetTheme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
