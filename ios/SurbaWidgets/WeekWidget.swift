import SwiftUI
import WidgetKit

/// Weekly goal ring, streak and the seven day strip.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SurbaWeekWidget", provider: SnapshotProvider()) { entry in
            WeekWidgetView(snapshot: entry.snapshot)
                .widgetURL(WidgetTheme.link)
                .containerBackground(for: .widget) { WidgetTheme.background }
        }
        .configurationDisplayName("This week")
        .description("Your weekly workout goal and streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snapshot.weekProgress) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(snapshot.sessionsThisWeek)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .systemMedium:
            HStack(spacing: 18) {
                ring
                VStack(alignment: .leading, spacing: 10) {
                    streak
                    strip
                    if !snapshot.weekVolume.isEmpty {
                        Text("\(snapshot.weekVolume) in 7 days").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            VStack(spacing: 8) {
                ring
                streak
            }
        }
    }

    private var ring: some View {
        ZStack {
            RingView(progress: snapshot.weekProgress, lineWidth: 10)
            VStack(spacing: 0) {
                Text("\(snapshot.sessionsThisWeek)").font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("of \(snapshot.weeklyGoal)").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 84, height: 84)
    }

    private var streak: some View {
        Label("\(snapshot.weekStreak) week streak", systemImage: "flame.fill")
            .font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(WidgetTheme.amber)
    }

    private var strip: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(7, snapshot.trainedDays.count), id: \.self) { i in
                VStack(spacing: 3) {
                    Text(snapshot.dayInitials.indices.contains(i) ? snapshot.dayInitials[i] : "").font(.system(size: 9)).foregroundStyle(.secondary)
                    ZStack {
                        Circle().fill(snapshot.trainedDays[i] ? WidgetTheme.accent : WidgetTheme.field)
                        if i == snapshot.todayIndex { Circle().strokeBorder(Color.white, lineWidth: 1.5) }
                    }
                    .frame(width: 20, height: 20)
                }
            }
        }
    }
}
