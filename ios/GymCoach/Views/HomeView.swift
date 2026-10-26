import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var activeWorkout: Workout?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return "\(part), \(app.profile?.firstName ?? "")"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    weekCard
                    tiles
                    upNext
                    recent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .refreshable { await app.refresh() }
            .navigationTitle(greeting)
            .scrollContentBackground(.hidden)
            .overlay {
                if app.isLoading && app.program == nil { ProgressView() }
            }
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            WorkoutSessionView(workout: workout)
        }
    }

    private var weekCard: some View {
        GlassCard {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: Double(app.sessionsThisWeek) / Double(app.weeklyGoal), lineWidth: 11)
                    VStack(spacing: 0) {
                        Text("\(app.sessionsThisWeek)").font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text("of \(app.weeklyGoal)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text("This week").font(.system(.headline, design: .rounded))
                    Text(app.sessionsThisWeek >= app.weeklyGoal ? "Weekly goal crushed" : "\(app.weeklyGoal - app.sessionsThisWeek) to go")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label("\(app.weekStreak) week streak", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.amber)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var tiles: some View {
        HStack(spacing: 12) {
            StatTile(value: app.units.formatVolume(app.totalVolumeLast7Days), label: "Volume, 7 days", icon: "scalemass.fill", tint: Theme.mint)
            StatTile(
                value: app.profile?.bodyweight.map { app.units.format($0) } ?? "-",
                label: "Bodyweight", icon: "figure.stand", tint: Theme.accent2)
        }
    }

    @ViewBuilder
    private var upNext: some View {
        SectionTitle("Up next")
        if let workout = app.nextWorkout {
            let resuming = app.inProgressSession(for: workout.id) != nil
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name).font(.system(.title2, design: .rounded, weight: .bold))
                            Text(app.program?.name ?? "").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "bolt.fill").foregroundStyle(Theme.gradient).font(.title2)
                    }
                    ForEach((workout.exercises ?? []).prefix(5)) { pe in
                        HStack {
                            Circle().fill(Theme.accent.opacity(0.7)).frame(width: 6, height: 6)
                            Text(pe.exercise.name).font(.subheadline)
                            Spacer()
                            Text("\(pe.targetSets) x \(pe.repRange)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    if (workout.exercises ?? []).count > 5 {
                        Text("+\((workout.exercises ?? []).count - 5) more").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button(resuming ? "Resume workout" : "Start workout") {
                        Haptics.thud()
                        activeWorkout = workout
                    }
                    .buttonStyle(GradientButtonStyle())
                }
            }
        } else {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No active program").font(.headline)
                    Text(app.loadError ?? "Create or activate a program on the Surba Fit website, or ask Surba to build one.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var recent: some View {
        if !app.finishedSessions.isEmpty {
            SectionTitle("Recent")
            VStack(spacing: 10) {
                ForEach(app.finishedSessions.prefix(3)) { s in
                    NavigationLink {
                        SessionDetailView(summary: s)
                    } label: {
                        SessionRow(summary: s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SessionRow: View {
    @Environment(AppState.self) private var app
    let summary: SessionSummary

    var body: some View {
        GlassCard(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.title).font(.system(.headline, design: .rounded))
                    Text(summary.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(summary.setCount) sets").font(.subheadline.weight(.semibold))
                    if let d = summary.duration {
                        Text(formatDuration(d)).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
    }
}
