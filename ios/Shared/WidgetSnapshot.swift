import Foundation

/// What the home and lock screen widgets show. The app writes it into the App
/// Group after every refresh; the widgets only read it, so they never need to
/// sign in or reach the server.
struct WidgetSnapshot: Codable, Equatable {
    enum State: String, Codable {
        case workout, inProgress, done, rest, empty, signedOut
    }

    var updatedAt: Date
    var firstName: String
    var state: State
    var label: String
    var headline: String
    var subtitle: String
    /// Up to four lines such as "Bench Press  4 x 6-8".
    var exercises: [String]
    var exerciseCount: Int
    var sessionsThisWeek: Int
    var weeklyGoal: Int
    var weekStreak: Int
    /// Seven days starting at the first day of the week.
    var trainedDays: [Bool]
    var dayInitials: [String]
    var todayIndex: Int
    var weekVolume: String

    var weekProgress: Double { weeklyGoal > 0 ? min(1, Double(sessionsThisWeek) / Double(weeklyGoal)) : 0 }

    static let placeholder = WidgetSnapshot(
        updatedAt: Date(), firstName: "Matt", state: .workout, label: "TODAY", headline: "Upper A",
        subtitle: "5 exercises", exercises: ["Bench Press  4 x 6-8", "Row  4 x 8-10", "Overhead Press  3 x 8-10"],
        exerciseCount: 5, sessionsThisWeek: 2, weeklyGoal: 4, weekStreak: 6,
        trainedDays: [true, false, true, false, false, false, false],
        dayInitials: ["M", "T", "W", "T", "F", "S", "S"], todayIndex: 2, weekVolume: "18.4k kg")

    static let signedOut = WidgetSnapshot(
        updatedAt: Date(), firstName: "", state: .signedOut, label: "SURBA FIT", headline: "Sign in",
        subtitle: "Open the app to get started", exercises: [], exerciseCount: 0, sessionsThisWeek: 0,
        weeklyGoal: 0, weekStreak: 0, trainedDays: Array(repeating: false, count: 7),
        dayInitials: ["M", "T", "W", "T", "F", "S", "S"], todayIndex: 0, weekVolume: "")
}

enum WidgetStore {
    static let groupId = "group.com.surbafit.app"
    private static let key = "widgetSnapshot.v1"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: groupId) }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
