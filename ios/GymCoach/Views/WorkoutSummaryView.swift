import SwiftUI

/// Shown when a workout is finished: the numbers, any PRs, and a share card.
struct WorkoutSummaryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutSummary
    @State private var shareImage: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64)).foregroundStyle(Theme.mint)
                    .padding(.top, 36)
                Text("Workout complete").font(.system(.title, design: .rounded, weight: .heavy))
                Text(summary.title).font(.headline).foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(value: formatDuration(summary.duration), label: "Time", icon: "clock.fill", tint: Theme.amber)
                    StatTile(value: "\(summary.sets)", label: "Sets", icon: "list.number")
                    StatTile(value: app.units.formatVolume(summary.volumeKg), label: "Volume", icon: "scalemass.fill", tint: Theme.mint)
                    StatTile(value: "\(summary.exercises)", label: "Exercises", icon: "dumbbell.fill", tint: Theme.accent2)
                }

                if !summary.prs.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(summary.prs.count) new PR\(summary.prs.count == 1 ? "" : "s")", systemImage: "trophy.fill")
                                .font(.system(.headline, design: .rounded)).foregroundStyle(Theme.amber)
                            ForEach(summary.prs, id: \.self) { Text($0).font(.subheadline) }
                        }
                    }
                }

                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("My Surba Fit workout", image: shareImage)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .task {
            let renderer = ImageRenderer(content: WorkoutShareCard(summary: summary, units: app.units))
            renderer.scale = 3
            if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
            await Haptics.crescendo(steps: 5)
        }
    }
}

/// The image people share. Fixed size and colors so it renders the same everywhere.
struct WorkoutShareCard: View {
    let summary: WorkoutSummary
    let units: Units

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image("LogoMark").resizable().scaledToFit().frame(height: 44)
                Text("Surba Fit").font(.system(.title3, design: .rounded, weight: .heavy))
                Spacer()
            }
            Text(summary.title).font(.system(size: 30, weight: .heavy, design: .rounded))
            Text(Date().formatted(date: .long, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                stat(formatDuration(summary.duration), "time")
                stat("\(summary.sets)", "sets")
                stat(units.formatVolume(summary.volumeKg), "volume")
            }
            if !summary.prs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(summary.prs.count) new PR\(summary.prs.count == 1 ? "" : "s")", systemImage: "trophy.fill")
                        .font(.headline).foregroundStyle(Theme.amber)
                    ForEach(summary.prs.prefix(3), id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 360, height: 420, alignment: .topLeading)
        .background(Color(white: 0.07))
        .foregroundStyle(.white)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
