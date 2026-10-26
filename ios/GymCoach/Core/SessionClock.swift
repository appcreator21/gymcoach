import Foundation

/// The clock of a workout: elapsed time minus every pause. Mirrors
/// lib/session-clock.ts on the server, so every device shows the same time.
struct SessionClock: Hashable {
    var startedAt: Date
    var finishedAt: Date?
    var pausedAt: Date?
    var pausedSec: Int

    var isPaused: Bool { pausedAt != nil && finishedAt == nil }

    func activeSeconds(at now: Date) -> Int {
        let end = finishedAt ?? now
        let elapsed = max(0, Int(end.timeIntervalSince(startedAt)))
        let ongoing = (pausedAt != nil && finishedAt == nil) ? max(0, Int(now.timeIntervalSince(pausedAt ?? now))) : 0
        return max(0, elapsed - pausedSec - ongoing)
    }

    /// The clock after pausing now.
    func paused(at now: Date) -> SessionClock {
        guard finishedAt == nil, pausedAt == nil else { return self }
        var copy = self
        copy.pausedAt = now
        return copy
    }

    /// The clock after resuming now: the pause is added to the paused total.
    func resumed(at now: Date) -> SessionClock {
        guard finishedAt == nil, let start = pausedAt else { return self }
        var copy = self
        copy.pausedSec += max(0, Int(now.timeIntervalSince(start)))
        copy.pausedAt = nil
        return copy
    }
}
