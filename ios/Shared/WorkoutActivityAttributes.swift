import ActivityKit
import Foundation

/// The Live Activity for a workout in progress. The app and the widget
/// extension both compile this file.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
        /// Training seconds at the moment this state was written. The running
        /// clock is derived from it, so no update is needed every second.
        var activeSecondsAtUpdate: Int
        var updatedAt: Date
        var setsLogged: Int
        var currentExercise: String
        /// When the rest countdown ends, if one is running.
        var restEndsAt: Date?
    }

    var workoutName: String
    var sessionId: String
}

func formatClock(_ seconds: Int) -> String {
    String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
}
