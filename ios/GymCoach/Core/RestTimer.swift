import Foundation
import Observation
import UserNotifications

/// Rest countdown between sets. Based on an end date, so it stays correct
/// when the app is backgrounded; a local notification fires at zero.
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var total: TimeInterval = 0
    private(set) var remaining: TimeInterval = 0
    private var ticker: Timer?
    private static let notificationId = "surbafit.rest"

    var isRunning: Bool { endDate != nil || isPaused }
    private(set) var isPaused = false
    private var pausedRemaining: TimeInterval = 0
    var progress: Double { total > 0 ? 1 - remaining / total : 0 }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func start(seconds: Int) {
        stop()
        guard seconds > 0 else { return }
        Haptics.soft()
        total = TimeInterval(seconds)
        endDate = Date().addingTimeInterval(total)
        remaining = total

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: total, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: RestTimer.notificationId, content: content, trigger: trigger)
        )

        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func adjust(by seconds: Int) {
        guard let end = endDate else { return }
        Haptics.tap()
        total = max(1, total + TimeInterval(seconds))
        endDate = end.addingTimeInterval(TimeInterval(seconds))
        tick()
    }

    /// Freezes the countdown (the workout was paused). The time left is kept.
    func pause() {
        guard let end = endDate, !isPaused else { return }
        pausedRemaining = max(0, end.timeIntervalSinceNow)
        remaining = pausedRemaining
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isPaused = true
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [RestTimer.notificationId])
    }

    /// Continues from the time that was left when it was paused.
    func resume() {
        guard isPaused else { return }
        isPaused = false
        guard pausedRemaining > 0 else { remaining = 0; return }
        total = max(total, pausedRemaining)
        endDate = Date().addingTimeInterval(pausedRemaining)
        remaining = pausedRemaining
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: RestTimer.notificationId, content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: pausedRemaining, repeats: false)))
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }

    func stop() {
        isPaused = false
        pausedRemaining = 0
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        remaining = 0
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [RestTimer.notificationId])
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            Haptics.success()
            ticker?.invalidate()
            ticker = nil
            endDate = nil
        }
    }
}
