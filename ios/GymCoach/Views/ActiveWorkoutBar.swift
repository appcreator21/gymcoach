import SwiftUI

/// "Workout in progress" bar shown above the tab bar while a workout is open
/// and the full screen workout is minimized.
struct ActiveWorkoutBar: View {
    @Environment(AppState.self) private var app
    let session: SessionSummary

    var body: some View {
        Button {
            Haptics.select()
            Task { await app.resume(session) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: session.isPaused ? "pause.circle.fill" : "bolt.fill")
                    .font(.title3).foregroundStyle(session.isPaused ? Theme.amber : Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text((session.isPaused ? "Paused  -  " : "") + formatClock(session.clock.activeSeconds(at: context.date)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("Resume").font(.system(.subheadline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.white, in: Capsule()).foregroundStyle(.black)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Workout in progress: \(session.title). Tap to resume.")
    }
}
