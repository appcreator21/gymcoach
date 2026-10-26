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
                                    .sessionActions(s)
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
    @Environment(\.dismiss) private var dismiss
    let summary: SessionSummary
    @State private var detail: SessionDetail?
    @State private var failed = false
    @State private var actions = SessionActionState()

    private var current: SessionSummary { app.sessions.first { $0.id == summary.id } ?? summary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let detail {
                    let working = detail.sets.filter { !$0.isWarmup }
                    HStack(spacing: 12) {
                        StatTile(value: "\(working.count)", label: "Sets", icon: "list.number")
                        StatTile(value: app.units.formatVolume(working.reduce(0) { $0 + $1.volume }), label: "Volume", icon: "scalemass.fill", tint: Theme.mint)
                        StatTile(value: current.duration.map(formatDuration) ?? "-", label: "Time", icon: "clock.fill", tint: Theme.amber)
                    }
                    if let note = detail.notes, !note.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Notes", systemImage: "note.text").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(note).font(.subheadline)
                            }
                        }
                    }
                    if detail.sets.isEmpty {
                        GlassCard { Text("No sets were logged in this workout.").foregroundStyle(.secondary) }
                    }
                    ForEach(exerciseGroups(detail), id: \.0.id) { exercise, sets in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.name).font(.system(.headline, design: .rounded))
                                ForEach(sets) { s in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(s.isWarmup ? "Warm-up" : "Set \(s.setNumber)\(s.isDropSet == true ? "  (drop)" : "")")
                                                .foregroundStyle(s.isWarmup ? Theme.amber : .secondary)
                                            Spacer()
                                            if let sec = s.durationSec {
                                                Text("\(sec / 60) min")
                                            } else {
                                                Text("\(app.units.format(s.weight)) x \(s.reps)" + (s.rir.map { "  @\($0) RIR" } ?? ""))
                                            }
                                        }
                                        .font(.subheadline.monospacedDigit())
                                        if let n = s.notes, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
                                    }
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
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu { SessionActionButtons(summary: current, state: $actions) } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sessionActionDialogs(current, state: $actions, onDeleted: { dismiss() })
        .task { await load() }
        .onChange(of: app.sessions.first { $0.id == summary.id }?.finishedAt) { _, _ in Task { await load(force: true) } }
    }

    private func load(force: Bool = false) async {
        if !force, let cached = app.details[summary.id] { detail = cached; return }
        do {
            let fresh: SessionDetail = try await APIClient.shared.get("/api/sessions/\(summary.id)")
            detail = fresh
            failed = false
        } catch { failed = detail == nil }
    }

    /// Planned exercises first, then anything added during the workout.
    private func exerciseGroups(_ d: SessionDetail) -> [(Exercise, [SetEntry])] {
        let planned = (d.workout?.exercises ?? []).sorted { $0.order < $1.order }.map(\.exercise)
        var out: [(Exercise, [SetEntry])] = []
        var seen = Set<String>()
        func sets(for id: String) -> [SetEntry] { d.sets.filter { $0.exerciseId == id }.sorted { $0.setNumber < $1.setNumber } }
        for ex in planned where !sets(for: ex.id).isEmpty && seen.insert(ex.id).inserted { out.append((ex, sets(for: ex.id))) }
        let known = app.knownExercises
        for id in d.sets.map(\.exerciseId) where seen.insert(id).inserted {
            let ex = known[id] ?? Exercise(id: id, name: "Exercise", muscleGroup: "OTHER", category: "COMPOUND",
                                           defaultRestSec: 90, usesBodyweight: false, equipmentType: "OTHER")
            out.append((ex, sets(for: id)))
        }
        return out
    }
}
