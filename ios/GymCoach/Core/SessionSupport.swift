import Foundation

/// One set row in the live workout. `number` is the set number stored on the
/// server; the screen shows the row's position instead.
struct DraftSet: Identifiable {
    let id = UUID()
    var number: Int
    var weight: String
    var reps: String
    var serverId: String?
    var isPR = false
    var isWarmup = false
    var isDropSet = false
    var rir: Int? = nil
    var note = ""
    /// Set while the request is in flight.
    var isSaving = false
    /// Set when the set was saved on this device only and still has to sync.
    var pendingKey: String? = nil

    var isLogged: Bool { serverId != nil }
    var isPending: Bool { pendingKey != nil }
}

/// A set that could not reach the server. Kept on disk so an app restart
/// cannot lose it.
struct PendingSet: Codable, Identifiable {
    var id: String { key }
    let key: String
    let sessionId: String
    let exerciseId: String
    let setNumber: Int
    let weightKg: Double
    let reps: Int
    let durationSec: Int?
    let rir: Int?
    let isWarmup: Bool
    let isDropSet: Bool
    let notes: String?

    var body: [String: Any] {
        var out: [String: Any] = [
            "exerciseId": exerciseId,
            "setNumber": setNumber,
            "weight": weightKg,
            "reps": reps,
            "isWarmup": isWarmup,
            "isDropSet": isDropSet,
        ]
        if let durationSec { out["durationSec"] = durationSec }
        if let rir { out["rir"] = rir }
        if let notes, !notes.isEmpty { out["notes"] = notes }
        return out
    }
}

enum PendingSetStore {
    private static let key = "pendingSets.v1"

    static func all() -> [PendingSet] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingSet].self, from: data)) ?? []
    }

    private static func save(_ sets: [PendingSet]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(sets), forKey: key)
    }

    static func forSession(_ id: String) -> [PendingSet] { all().filter { $0.sessionId == id } }
    static func add(_ set: PendingSet) { save(all().filter { $0.key != set.key } + [set]) }
    static func remove(_ key: String) { save(all().filter { $0.key != key }) }
    static func removeSession(_ id: String) { save(all().filter { $0.sessionId != id }) }
}

/// How the user shaped this one workout on the fly: exercises skipped, added
/// and reordered. Kept per session so it survives leaving the screen.
struct SessionUIState: Codable {
    var hidden: [String] = []
    var extraExerciseIds: [String] = []
    var order: [String] = []
}

enum SessionUIStore {
    private static func key(_ id: String) -> String { "sessionUI.\(id)" }

    static func load(_ id: String) -> SessionUIState {
        guard let data = UserDefaults.standard.data(forKey: key(id)),
              let state = try? JSONDecoder().decode(SessionUIState.self, from: data) else { return SessionUIState() }
        return state
    }

    static func save(_ id: String, _ state: SessionUIState) {
        UserDefaults.standard.set(try? JSONEncoder().encode(state), forKey: key(id))
    }

    static func clear(_ id: String) { UserDefaults.standard.removeObject(forKey: key(id)) }
}

struct Toast: Identifiable {
    let id = UUID()
    let text: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}
