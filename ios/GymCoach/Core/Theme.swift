import SwiftUI

enum Theme {
    static let accent = Color(red: 0.49, green: 0.36, blue: 1.0)
    static let accent2 = Color(red: 1.0, green: 0.36, blue: 0.64)
    static let mint = Color(red: 0.25, green: 0.88, blue: 0.70)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let bgTop = Color(red: 0.05, green: 0.05, blue: 0.10)
    static let bgBottom = Color(red: 0.09, green: 0.06, blue: 0.16)

    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            Circle().fill(Theme.accent.opacity(0.25)).frame(width: 320).blur(radius: 90).offset(x: -140, y: -300)
            Circle().fill(Theme.accent2.opacity(0.16)).frame(width: 280).blur(radius: 90).offset(x: 160, y: 120)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.45), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
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
                .stroke(Theme.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
