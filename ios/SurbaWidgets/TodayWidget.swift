import SwiftUI
import WidgetKit

/// Today's workout: what is next, and a tap to start or resume it.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SurbaTodayWidget", provider: SnapshotProvider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .widgetURL(WidgetTheme.link)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("Today's workout")
        .description("See what you are training today and jump straight in.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    private var tint: Color {
        switch snapshot.state {
        case .inProgress: return WidgetTheme.mint
        case .done: return WidgetTheme.mint
        case .rest: return WidgetTheme.amber
        default: return WidgetTheme.accent
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(snapshot.label.capitalized): \(snapshot.headline)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(snapshot.headline).font(.headline).lineLimit(1)
                Text(snapshot.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                summary
                VStack(alignment: .leading, spacing: 6) {
                    if snapshot.exercises.isEmpty {
                        Spacer(minLength: 0)
                        Text(snapshot.state == .done ? "Nice work today." : "Open Surba Fit for more.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    } else {
                        ForEach(snapshot.exercises, id: \.self) { line in
                            HStack(spacing: 6) {
                                Circle().fill(WidgetTheme.accent.opacity(0.8)).frame(width: 5, height: 5)
                                Text(line).font(.caption).lineLimit(1)
                            }
                        }
                        if snapshot.exerciseCount > snapshot.exercises.count {
                            Text("+\(snapshot.exerciseCount - snapshot.exercises.count) more")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            summary
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.label).font(.caption2.weight(.heavy)).foregroundStyle(tint)
            Text(snapshot.headline).font(.system(.title3, design: .rounded, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8)
            Text(snapshot.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            if snapshot.state == .workout || snapshot.state == .inProgress {
                Text(snapshot.state == .inProgress ? "Resume" : "Start")
                    .font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 6).background(Color.white, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
