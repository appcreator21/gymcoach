import Foundation
import WidgetKit

extension AppState {
    /// Publishes what widgets show and tidies up Live Activities. Called after
    /// every refresh.
    func syncSystemSurfaces() {
        WidgetStore.save(isSignedIn ? makeWidgetSnapshot() : .signedOut)
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.reconcile(openSessionIds: Set(openSessions.map(\.id)))
    }

    func makeWidgetSnapshot() -> WidgetSnapshot {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let trained = trainedDays
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let symbols = days.map { $0.formatted(.dateTime.weekday(.narrow)) }
        let todayIndex = days.firstIndex { cal.isDateInToday($0) } ?? 0

        var state: WidgetSnapshot.State = .empty
        var label = "SURBA FIT"
        var headline = "No plan yet"
        var subtitle = "Ask Surba to build one"
        var workout: Workout?

        if let open = activeSession, !isAbandoned(open) {
            state = .inProgress
            label = open.isPaused ? "PAUSED" : "IN PROGRESS"
            headline = open.title
            subtitle = "Tap to resume"
            workout = nil
        } else {
            switch todayPlan {
            case .workout(let w, let title):
                state = .workout
                label = title.uppercased()
                headline = w.name
                workout = w
                subtitle = "\((w.exercises ?? []).count) exercises"
            case .done(let s):
                state = .done
                label = "DONE TODAY"
                headline = s.title
                subtitle = "\(s.setCount) sets logged"
            case .rest(let next):
                state = .rest
                label = "REST DAY"
                headline = next?.name ?? "Recover"
                subtitle = next.map { "Next: \($0.dayOfWeek.map(Weekday.name) ?? "soon")" } ?? "Enjoy the day off"
            case .empty:
                break
            }
        }

        let lines = (workout?.exercises ?? []).sorted { $0.order < $1.order }.prefix(4).map {
            "\($0.exercise.name)  \($0.targetSets) x \($0.repRange)"
        }

        return WidgetSnapshot(
            updatedAt: Date(), firstName: profile?.firstName ?? "", state: state, label: label,
            headline: headline, subtitle: subtitle, exercises: Array(lines),
            exerciseCount: workout?.exercises?.count ?? 0,
            sessionsThisWeek: sessionsThisWeek, weeklyGoal: weeklyGoal, weekStreak: weekStreak,
            trainedDays: days.map { trained.contains(cal.startOfDay(for: $0)) },
            dayInitials: symbols, todayIndex: todayIndex,
            weekVolume: units.formatVolume(totalVolumeLast7Days))
    }

    /// Opens what a widget or a link asks for. Held until the app has loaded.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "surbafit" else { return }
        pendingLink = url
        processPendingLink()
    }

    func processPendingLink() {
        guard isSignedIn, !isBooting, profile?.onboardedAt != nil, let url = pendingLink else { return }
        pendingLink = nil
        if url.host == "workout" {
            if let open = activeSession {
                Task { await resume(open) }
            } else if case .workout(let w, _) = todayPlan {
                requestStart(w)
            }
        }
    }
}
