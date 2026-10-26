import ActivityKit
import Foundation

/// Owns the Live Activity of the workout in progress: starts it, keeps it
/// current, ends it, and answers the pause button on the lock screen.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?
    private var lastState: WorkoutActivityAttributes.ContentState?
    /// The open workout screen, when there is one. Weak: the screen owns it.
    weak var model: SessionViewModel?

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Starts the activity for a session, or updates the one already running
    /// (after the app was relaunched, for example).
    func show(sessionId: String, name: String, state: WorkoutActivityAttributes.ContentState) {
        lastState = state
        guard isAvailable else { return }
        if activity == nil {
            activity = Activity<WorkoutActivityAttributes>.activities.first { $0.attributes.sessionId == sessionId }
        }
        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        // Only one workout at a time: end anything left over from another one.
        for other in Activity<WorkoutActivityAttributes>.activities {
            Task { await other.end(nil, dismissalPolicy: .immediate) }
        }
        let attributes = WorkoutActivityAttributes(workoutName: name, sessionId: sessionId)
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
    }

    func end() {
        let current = activity
        activity = nil
        lastState = nil
        model = nil
        Task {
            await current?.end(nil, dismissalPolicy: .immediate)
            // Also clear anything the app no longer knows it started.
            for other in Activity<WorkoutActivityAttributes>.activities {
                await other.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Ends activities whose workout is no longer open (finished or deleted
    /// on another device, or the app was killed mid-workout).
    func reconcile(openSessionIds: Set<String>) {
        let protected = model?.sessionId
        for item in Activity<WorkoutActivityAttributes>.activities
        where !openSessionIds.contains(item.attributes.sessionId) && item.attributes.sessionId != protected {
            if activity?.id == item.id { activity = nil; lastState = nil }
            Task { await item.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// The lock screen pause button. Goes through the open workout screen when
    /// there is one; otherwise talks to the server directly and updates the
    /// activity itself.
    func handlePauseIntent(sessionId: String, pause: Bool) async {
        if let model, model.sessionId == sessionId {
            if pause { await model.pause() } else { await model.resume() }
            return
        }
        do {
            _ = try await APIClient.shared.raw("PUT", "/api/sessions/\(sessionId)", json: [pause ? "pause" : "resume": true])
        } catch {
            return
        }
        guard var state = lastState ?? currentState() else { return }
        let now = Date()
        if pause && !state.isPaused {
            state.activeSecondsAtUpdate += max(0, Int(now.timeIntervalSince(state.updatedAt)))
            state.isPaused = true
            state.restEndsAt = nil
        } else if !pause && state.isPaused {
            state.isPaused = false
        }
        state.updatedAt = now
        lastState = state
        if let activity { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func currentState() -> WorkoutActivityAttributes.ContentState? {
        (activity ?? Activity<WorkoutActivityAttributes>.activities.first)?.content.state
    }
}
