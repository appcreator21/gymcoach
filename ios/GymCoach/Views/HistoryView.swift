import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var app

    private var grouped: [(String, [SessionSummary])] {
        let sessions = app.finishedSessions
        let dict = Dictionary(grouping: sessions) { $0.startedAt.formatted(.dateTime.month(.wide).year()) }
        return dict.map { ($0.key, $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { ($0.1.first?.startedAt ?? .distantPast) > ($1.1.first?.startedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ConsistencyHeatmap(sessions: app.finishedSessions)
                    if app.finishedSessions.isEmpty {
                        GlassCard {
                            Text("No finished workouts yet. Your history will show up here.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(grouped, id: \.0) { month, sessions in
                        SectionTitle(month)
                        VStack(spacing: 10) {
                            ForEach(sessions) { s in
                                NavigationLink { SessionDetailView(summary: s) } label: { SessionRow(summary: s) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .refreshable { await app.refresh() }
            .navigationTitle("History")
        }
    }
}

/// 12 week training heatmap, GitHub style, newest week on the right.
struct ConsistencyHeatmap: View {
    let sessions: [SessionSummary]
    private let weeks = 12

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let counts = Dictionary(grouping: sessions) { cal.startOfDay(for: $0.startedAt) }.mapValues(\.count)

        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Consistency").font(.system(.headline, design: .rounded))
                HStack(spacing: 5) {
                    ForEach(0..<weeks, id: \.self) { w in
                        VStack(spacing: 5) {
                            ForEach(0..<7, id: \.self) { d in
                                let offset = -(weeks - 1 - w) * 7 + d
                                let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? today
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(color(for: counts[day] ?? 0, future: day > today))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
        }
    }

    private func color(for count: Int, future: Bool) -> Color {
        if future { return Color.white.opacity(0.02) }
        switch count {
        case 0: return Color.white.opacity(0.07)
        case 1: return Theme.accent.opacity(0.75)
        default: return Theme.accent2
        }
    }
}

struct SessionDetailView: View {
    @Environment(AppState.self) private var app
    let summary: SessionSummary
    @State private var detail: SessionDetail?
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let detail {
                    let volume = detail.sets.reduce(0) { $0 + $1.volume }
                    HStack(spacing: 12) {
                        StatTile(value: "\(detail.sets.count)", label: "Sets", icon: "list.number")
                        StatTile(value: app.units.formatVolume(volume), label: "Volume", icon: "scalemass.fill", tint: Theme.mint)
                        StatTile(value: summary.duration.map(formatDuration) ?? "-", label: "Time", icon: "clock.fill", tint: Theme.amber)
                    }
                    ForEach(exerciseGroups(detail), id: \.0.id) { exercise, sets in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.name).font(.system(.headline, design: .rounded))
                                ForEach(sets) { s in
                                    HStack {
                                        Text("Set \(s.setNumber)").foregroundStyle(.secondary)
                                        Spacer()
                                        if let sec = s.durationSec {
                                            Text("\(sec / 60) min")
                                        } else {
                                            Text("\(app.units.format(s.weight)) x \(s.reps)")
                                        }
                                    }
                                    .font(.subheadline.monospacedDigit())
                                }
                            }
                        }
                    }
                } else if failed {
                    Text("Could not load this workout.").foregroundStyle(.secondary)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let cached = app.details[summary.id] { detail = cached; return }
            do { detail = try await APIClient.shared.get("/api/sessions/\(summary.id)") } catch { failed = true }
        }
    }

    private func exerciseGroups(_ d: SessionDetail) -> [(Exercise, [SetEntry])] {
        let exercises = (d.workout?.exercises ?? []).sorted { $0.order < $1.order }.map(\.exercise)
        return exercises.compactMap { ex in
            let sets = d.sets.filter { $0.exerciseId == ex.id }.sorted { $0.setNumber < $1.setNumber }
            return sets.isEmpty ? nil : (ex, sets)
        }
    }
}
