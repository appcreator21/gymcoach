import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running clock. It counts on its own, so the activity needs no update
/// every second; a paused workout shows a frozen time.
struct ElapsedText: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(formatClock(state.activeSecondsAtUpdate)).monospacedDigit()
        } else {
            Text(state.updatedAt.addingTimeInterval(-Double(state.activeSecondsAtUpdate)), style: .timer).monospacedDigit()
        }
    }
}

struct RestText: View {
    let end: Date

    var body: some View {
        Text(timerInterval: Date.now...max(end, Date.now.addingTimeInterval(1)), countsDown: true).monospacedDigit()
    }
}

struct PauseButton: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        Button(intent: TogglePauseIntent(sessionId: attributes.sessionId, pause: !state.isPaused)) {
            Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 38, height: 38)
                .background(Color.white, in: Circle())
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(white: 0.07))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(WidgetTheme.link)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.circle.fill" : "bolt.fill")
                        .font(.title2).foregroundStyle(context.state.isPaused ? WidgetTheme.amber : WidgetTheme.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.attributes.workoutName).font(.system(.subheadline, design: .rounded, weight: .bold)).lineLimit(1)
                        Text(context.state.currentExercise).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.setsLogged) sets", systemImage: "list.number").font(.caption.weight(.semibold))
                        if let end = context.state.restEndsAt, end > Date() {
                            Label { RestText(end: end) } icon: { Image(systemName: "timer") }
                                .font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.accent)
                        } else if context.state.isPaused {
                            Text("Paused").font(.caption.weight(.bold)).foregroundStyle(WidgetTheme.amber)
                        }
                        Spacer()
                        PauseButton(attributes: context.attributes, state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "bolt.fill")
                    .foregroundStyle(context.state.isPaused ? WidgetTheme.amber : WidgetTheme.accent)
            } compactTrailing: {
                if let end = context.state.restEndsAt, end > Date(), !context.state.isPaused {
                    RestText(end: end).font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.accent).frame(maxWidth: 46)
                } else {
                    ElapsedText(state: context.state).font(.caption.weight(.semibold)).frame(maxWidth: 52)
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "bolt.fill")
                    .foregroundStyle(context.state.isPaused ? WidgetTheme.amber : WidgetTheme.accent)
            }
            .widgetURL(WidgetTheme.link)
            .keylineTint(WidgetTheme.accent)
        }
    }
}

struct LockScreenView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: state.isPaused ? "pause.circle.fill" : "bolt.fill")
                        .foregroundStyle(state.isPaused ? WidgetTheme.amber : WidgetTheme.accent)
                    Text(attributes.workoutName).font(.system(.headline, design: .rounded, weight: .bold)).lineLimit(1)
                    if state.isPaused {
                        Text("PAUSED").font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(WidgetTheme.amber, in: Capsule())
                    }
                }
                Text(state.currentExercise).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 12) {
                    Label("\(state.setsLogged) sets", systemImage: "list.number").font(.caption.weight(.semibold))
                    if let end = state.restEndsAt, end > Date(), !state.isPaused {
                        Label { RestText(end: end) } icon: { Image(systemName: "timer") }
                            .font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.accent)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 8) {
                ElapsedText(state: state)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .frame(maxWidth: 120, alignment: .trailing)
                PauseButton(attributes: attributes, state: state)
            }
        }
        .padding(16)
    }
}
