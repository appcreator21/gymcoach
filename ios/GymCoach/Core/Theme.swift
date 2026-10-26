import SwiftUI

enum Theme {
    // One flat accent. No gradients anywhere in the app.
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.13)
    static let accent2 = Color(red: 0.40, green: 0.68, blue: 1.0)
    static let mint = Color(red: 0.25, green: 0.88, blue: 0.70)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let background = Color(white: 0.04)
    static let card = Color(white: 0.11)
    static let field = Color(white: 0.14)
}

struct AppBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Flat white button with a light haptic on press. The one primary action style.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(isEnabled ? 1 : 0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.soft() }
            }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var icon: String
    var tint: Color = Theme.accent

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint).font(.title3)
                Text(value).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.white)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
    }
}

extension Date {
    var shortDay: String { formatted(.dateTime.weekday(.abbreviated).day()) }
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600, m = (total % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m) min"
}
