import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var showNext = false
    @State private var walkthroughClip: VideoClip?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        return "\(part), \(app.profile?.firstName ?? "")"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    announcementCards
                    weekCard
                    WeekStrip()
                    ReadinessCard()
                    tiles
                    upNext
                    ExploreSection()
                    FromSurbaSection()
                    recent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .refreshable {
                Haptics.soft()
                await app.refresh()
            }
            .navigationTitle(greeting)
            .scrollContentBackground(.hidden)
            .fullScreenCover(item: $walkthroughClip) { VideoPlayerScreen(clip: $0) }
            .overlay {
                if app.isLoading && app.program == nil { ProgressView() }
            }
        }
    }

    @ViewBuilder
    private var announcementCards: some View {
        ForEach(app.visibleAnnouncements.prefix(2)) { a in
            GlassCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: a.pinned ? "pin.fill" : "megaphone.fill")
                        .foregroundStyle(Theme.accent).font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.system(.headline, design: .rounded))
                        Text(a.body).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { withAnimation { app.dismiss(a) } } label: {
                        Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
            }
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
        switch app.todayPlan {
        case .workout(let workout, let caption):
            SectionTitle(caption)
            workoutCard(workout)
        case .done(let finished):
            SectionTitle("Today")
            doneCard(finished)
            if showNext, let next = app.peekWorkout {
                SectionTitle(nextTitle(for: next))
                workoutCard(next)
            }
        case .rest(let next):
            SectionTitle("Today")
            restCard(next)
            if showNext, let next {
                SectionTitle(nextTitle(for: next))
                workoutCard(next)
            }
        case .empty:
            SectionTitle("Today")
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No active program").font(.headline)
                    Text(app.loadError ?? "Your coach has not assigned a program yet. Ask Surba to build one.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func nextTitle(for workout: Workout) -> String {
        if let day = workout.dayOfWeek { return "Next: \(Weekday.name(day))" }
        return "Next workout"
    }

    private func doneCard(_ finished: SessionSummary) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(Theme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's workout is done").font(.system(.title3, design: .rounded, weight: .bold))
                        Text("\(finished.title)  -  \(finished.setCount) sets" + (finished.duration.map { "  -  \(formatDuration($0))" } ?? ""))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Text("Rest up. Your next workout unlocks tomorrow.").font(.subheadline).foregroundStyle(.secondary)
                Button(showNext ? "Hide next workout" : "Look at the next workout") {
                    Haptics.select()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showNext.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
        }
    }

    private func restCard(_ next: Workout?) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill").font(.title).foregroundStyle(Theme.accent2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest day").font(.system(.title3, design: .rounded, weight: .bold))
                        if let next, let day = next.dayOfWeek {
                            Text("Next: \(next.name) on \(Weekday.name(day))").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if next != nil {
                    Button(showNext ? "Hide workout" : "Train anyway") {
                        Haptics.select()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showNext.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        let resuming = app.inProgressSession(for: workout.id) != nil
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name).font(.system(.title2, design: .rounded, weight: .bold))
                        Text(app.program?.name ?? "").font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let walkthrough = app.workoutVideo(for: workout.name) {
                        Button { Haptics.select(); walkthroughClip = walkthrough } label: {
                            Image(systemName: "play.fill").font(.footnote.weight(.bold)).frame(width: 32, height: 32)
                                .background(Theme.accent, in: Circle()).foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Watch walkthrough")
                    }
                    if let programId = app.program?.id {
                        NavigationLink {
                            WorkoutEditorView(programId: programId, workoutId: workout.id)
                        } label: {
                            Image(systemName: "pencil").font(.footnote.weight(.bold)).frame(width: 32, height: 32)
                                .background(Theme.field, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit workout")
                    }
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.accent).font(.title2)
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
                    app.requestStart(workout)
                }
                .buttonStyle(PrimaryButtonStyle())
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
                    .hapticTap()
                    .sessionActions(s)
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
