import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    // Connection
    // The hosted Surba Fit backend. Users never type a server address.
    static let defaultServerURL = "https://surbafit.matthuber21.workers.dev"
    var serverURL: String = AppState.defaultServerURL
    var email: String = UserDefaults.standard.string(forKey: "email") ?? ""
    var isSignedIn = false
    var isBooting = true

    // Data
    var profile: Profile?
    var program: Program?
    var sessions: [SessionSummary] = []
    var details: [String: SessionDetail] = [:]
    var bodyweight: [BodyweightEntry] = []
    var announcements: [Announcement] = []
    var dismissedAnnouncements: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "dismissedAnnouncements") ?? [])
    var isLoading = false
    var loadError: String?

    @ObservationIgnored private let api = APIClient.shared

    var units: Units { Units(isPounds: profile?.unit == "LB") }

    init() {
        api.reauthenticate = { [weak self] in await self?.silentLogin() ?? false }
        applyServerURL()
    }

    // MARK: Auth

    private func applyServerURL() {
        var text = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && !text.contains("://") { text = "https://" + text }
        api.baseURL = URL(string: text)
    }

    func bootstrap() async {
        defer { isBooting = false }
        guard api.baseURL != nil else { return }
        do {
            profile = try await api.get("/api/profile")
            isSignedIn = true
            await refresh()
        } catch {
            isSignedIn = false
        }
    }

    func login(email: String, password: String) async throws {
        _ = try await api.raw("POST", "/api/auth/login", json: ["email": email, "password": password], retry: false)
        remember(email: email, password: password)
        await refresh()
        isSignedIn = true
    }

    func register(email: String, password: String, name: String) async throws {
        var body: [String: Any] = ["email": email, "password": password]
        if !name.isEmpty { body["displayName"] = name }
        _ = try await api.raw("POST", "/api/auth/register", json: body, retry: false)
        remember(email: email, password: password)
        await refresh()
        isSignedIn = true
    }

    /// Sends the intake answers; the server seeds the client's memory file.
    func submitOnboarding(_ answers: [String: Any]) async throws {
        _ = try await api.raw("POST", "/api/onboarding", json: answers)
    }

    /// Reloads the profile, which flips the app from onboarding to the main tabs
    /// right away; the rest of the data loads in the background.
    func completeOnboarding() async {
        if let fresh: Profile = try? await api.get("/api/profile") { profile = fresh }
        Task { await refresh() }
    }

    func loadMemory() async -> String {
        struct MemoryResponse: Decodable { let memory: String }
        let response: MemoryResponse? = try? await api.get("/api/memory")
        return response?.memory ?? ""
    }

    private func remember(email: String, password: String) {
        self.email = email
        UserDefaults.standard.set(email, forKey: "email")
        Keychain.set(password, for: email)
    }

    private func silentLogin() async -> Bool {
        guard !email.isEmpty, let password = Keychain.get(email) else { return false }
        do {
            _ = try await api.raw("POST", "/api/auth/login", json: ["email": email, "password": password], retry: false)
            return true
        } catch {
            return false
        }
    }

    func logout() async {
        _ = try? await api.raw("POST", "/api/auth/logout", retry: false)
        if !email.isEmpty { Keychain.delete(email) }
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        isSignedIn = false
        profile = nil
        program = nil
        sessions = []
        details = [:]
        bodyweight = []
    }

    // MARK: Loading

    func refresh() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            async let profileTask: Profile = api.get("/api/profile")
            async let sessionsTask: [SessionSummary] = api.get("/api/sessions")
            async let bodyweightTask: [BodyweightEntry] = api.get("/api/bodyweight")
            async let programsTask: [Program] = api.get("/api/programs?active=true")

            profile = try await profileTask
            sessions = try await sessionsTask
            bodyweight = (try? await bodyweightTask) ?? []
            if let active = try await programsTask.first {
                program = try await api.get("/api/programs/\(active.id)")
            } else {
                program = nil
            }
            announcements = (try? await api.get("/api/announcements")) ?? []
            await loadDetails()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Fetches the sets of the most recent finished sessions; they drive
    /// previous-performance prefill, PR detection and every chart.
    func loadDetails() async {
        let wanted = sessions.filter { $0.finishedAt != nil && details[$0.id] == nil }.prefix(30).map(\.id)
        guard !wanted.isEmpty else { return }
        let client = api
        // A few at a time: the server handles bursts of parallel requests badly.
        for chunk in stride(from: 0, to: wanted.count, by: 4).map({ Array(wanted[$0..<min($0 + 4, wanted.count)]) }) {
            let fetched = await withTaskGroup(of: SessionDetail?.self) { group -> [SessionDetail] in
                for id in chunk {
                    group.addTask { try? await client.get("/api/sessions/\(id)") }
                }
                var out: [SessionDetail] = []
                for await item in group { if let item { out.append(item) } }
                return out
            }
            for d in fetched { details[d.id] = d }
        }
    }

    var visibleAnnouncements: [Announcement] {
        announcements.filter { !dismissedAnnouncements.contains($0.id) }
    }

    func dismiss(_ announcement: Announcement) {
        dismissedAnnouncements.insert(announcement.id)
        UserDefaults.standard.set(Array(dismissedAnnouncements), forKey: "dismissedAnnouncements")
    }

    // MARK: Derived stats

    var finishedSessions: [SessionSummary] { sessions.filter { $0.finishedAt != nil } }

    private var calendar: Calendar { Calendar.current }

    var sessionsThisWeek: Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return finishedSessions.filter { interval.contains($0.startedAt) }.count
    }

    var weeklyGoal: Int { max(1, profile?.weeklyFrequency ?? program?.workouts?.count ?? 3) }

    /// Consecutive weeks (ending this week or last week) with at least one workout.
    var weekStreak: Int {
        var streak = 0
        var cursor = Date()
        var first = true
        while let interval = calendar.dateInterval(of: .weekOfYear, for: cursor) {
            let has = finishedSessions.contains { interval.contains($0.startedAt) }
            if has { streak += 1 } else if !first { break }
            first = false
            guard let prev = calendar.date(byAdding: .day, value: -7, to: interval.start) else { break }
            cursor = prev
        }
        return streak
    }

    var totalVolumeLast7Days: Double {
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        return details.values.filter { $0.startedAt >= cutoff }.flatMap(\.sets).reduce(0) { $0 + $1.volume }
    }

    /// The workout after the one performed last, cycling through the program.
    var nextWorkout: Workout? {
        guard let workouts = program?.workouts?.sorted(by: { $0.order < $1.order }), !workouts.isEmpty else { return nil }
        if let last = finishedSessions.first(where: { s in workouts.contains { $0.id == s.workoutId } }),
           let idx = workouts.firstIndex(where: { $0.id == last.workoutId }) {
            return workouts[(idx + 1) % workouts.count]
        }
        return workouts.first
    }

    // MARK: Today

    enum TodayPlan {
        /// A workout to do now. The string is the section title.
        case workout(Workout, String)
        /// Today's workout is finished.
        case done(SessionSummary)
        /// A scheduled program with nothing on today. Carries the next workout.
        case rest(Workout?)
        case empty
    }

    private var programWorkouts: [Workout] {
        (program?.workouts ?? []).sorted { $0.order < $1.order }
    }

    /// True when the coach gave workouts specific weekdays.
    var isScheduled: Bool { programWorkouts.contains { $0.dayOfWeek != nil } }

    var sessionFinishedToday: SessionSummary? {
        finishedSessions.first { Calendar.current.isDateInToday($0.startedAt) }
    }

    /// The next scheduled workout after today (wraps around the week).
    var nextScheduledWorkout: Workout? {
        let today = Weekday.iso(of: Date())
        return programWorkouts
            .filter { $0.dayOfWeek != nil }
            .min { a, b in
                func gap(_ d: Int?) -> Int { let g = ((d ?? 0) - today + 7) % 7; return g == 0 ? 7 : g }
                return gap(a.dayOfWeek) < gap(b.dayOfWeek)
            }
    }

    /// What the Today tab should show.
    var todayPlan: TodayPlan {
        let workouts = programWorkouts
        guard !workouts.isEmpty else { return .empty }
        if let open = sessions.first(where: { s in s.finishedAt == nil && workouts.contains { $0.id == s.workoutId } }),
           let w = workouts.first(where: { $0.id == open.workoutId }) {
            return .workout(w, "In progress")
        }
        if let done = sessionFinishedToday { return .done(done) }
        if isScheduled {
            let today = Weekday.iso(of: Date())
            if let w = workouts.first(where: { $0.dayOfWeek == today }) { return .workout(w, "Today") }
            return .rest(nextScheduledWorkout)
        }
        if let w = nextWorkout { return .workout(w, "Up next") }
        return .empty
    }

    /// The workout after today's, shown only when the user asks to look ahead.
    var peekWorkout: Workout? { isScheduled ? nextScheduledWorkout : nextWorkout }

    func inProgressSession(for workoutId: String) -> SessionSummary? {
        sessions.first { $0.workoutId == workoutId && $0.finishedAt == nil }
    }

    /// Sets from the latest finished session that included this exercise.
    func lastSets(for exerciseId: String, excluding sessionId: String? = nil) -> [SetEntry] {
        let ordered = details.values.filter { $0.id != sessionId }.sorted { $0.startedAt > $1.startedAt }
        for d in ordered {
            let sets = d.sets.filter { $0.exerciseId == exerciseId && !$0.isWarmup }.sorted { $0.setNumber < $1.setNumber }
            if !sets.isEmpty { return sets }
        }
        return []
    }

    func bestE1RM(for exerciseId: String, excluding sessionId: String? = nil) -> Double {
        details.values.filter { $0.id != sessionId }
            .flatMap(\.sets)
            .filter { $0.exerciseId == exerciseId }
            .compactMap(\.e1RM).max() ?? 0
    }

    /// (date, best e1RM in kg) per finished session for one exercise.
    func e1RMSeries(for exerciseId: String) -> [(Date, Double)] {
        details.values.sorted { $0.startedAt < $1.startedAt }.compactMap { d in
            let best = d.sets.filter { $0.exerciseId == exerciseId }.compactMap(\.e1RM).max()
            return best.map { (d.startedAt, $0) }
        }
    }

    /// Exercises that appear in loaded history, most frequently trained first.
    var trainedExercises: [Exercise] {
        var counts: [String: (Exercise, Int)] = [:]
        for d in details.values {
            for pe in d.workout?.exercises ?? [] {
                let hasSets = d.sets.contains { $0.exerciseId == pe.exercise.id }
                guard hasSets, !pe.exercise.isCardio else { continue }
                counts[pe.exercise.id, default: (pe.exercise, 0)].1 += 1
            }
        }
        return counts.values.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// Volume per week for the last 8 weeks, oldest first.
    func weeklyVolume() -> [(Date, Double)] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0..<8).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -7 * offset, to: thisWeek.start) else { return nil }
            let end = start.addingTimeInterval(7 * 86400)
            let total = details.values.filter { $0.startedAt >= start && $0.startedAt < end }
                .flatMap(\.sets).reduce(0) { $0 + $1.volume }
            return (start, total)
        }
    }

    func logBodyweight(valueInDisplayUnit: Double) async throws {
        let kg = units.toKg(valueInDisplayUnit)
        let entry: BodyweightEntry = try await api.send("POST", "/api/bodyweight", json: ["weightKg": kg])
        bodyweight.insert(entry, at: 0)
        profile?.bodyweight = kg
    }

    func updateUnit(pounds: Bool) async {
        _ = try? await api.raw("PATCH", "/api/profile", json: ["unit": pounds ? "LB" : "KG"])
        profile?.unit = pounds ? "LB" : "KG"
    }
}
