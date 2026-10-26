import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let muscleGroup: String
    let category: String
    let defaultRestSec: Int
    let usesBodyweight: Bool
    let equipmentType: String

    var isCardio: Bool { category == "CARDIO" }
    var muscleLabel: String { Exercise.pretty(muscleGroup) }

    static func pretty(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct ProgramExercise: Codable, Identifiable, Hashable {
    let id: String
    let order: Int
    let targetSets: Int
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetRIR: Int
    let restSec: Int
    let notes: String?
    let exercise: Exercise

    var repRange: String {
        targetRepsMin == targetRepsMax ? "\(targetRepsMin)" : "\(targetRepsMin)-\(targetRepsMax)"
    }
}

struct Workout: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let dayOfWeek: Int?
    let order: Int
    let exercises: [ProgramExercise]?
}

struct Program: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let phase: String
    let description: String?
    let isActive: Bool
    let workouts: [Workout]?
}

struct NamedRef: Codable, Hashable { let name: String }
struct CountRef: Codable, Hashable { let sets: Int }

struct SessionSummary: Codable, Identifiable, Hashable {
    let id: String
    let workoutId: String?
    let startedAt: Date
    let finishedAt: Date?
    let notes: String?
    let workout: NamedRef?
    let program: NamedRef?
    let _count: CountRef?

    var title: String { workout?.name ?? "Workout" }
    var setCount: Int { _count?.sets ?? 0 }
    var duration: TimeInterval? { finishedAt.map { $0.timeIntervalSince(startedAt) } }
}

struct SetEntry: Codable, Identifiable, Hashable {
    let id: String
    let exerciseId: String
    let setNumber: Int
    let weight: Double
    let reps: Int
    let rir: Int?
    let isWarmup: Bool
    let durationSec: Int?
    let distanceM: Double?
    let completedAt: Date

    /// Epley estimate of a one-rep max, in kg. Warmups and cardio return nil.
    var e1RM: Double? {
        guard !isWarmup, durationSec == nil, reps > 0, weight > 0 else { return nil }
        return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
    }
    var volume: Double { isWarmup || durationSec != nil ? 0 : weight * Double(reps) }
}

struct SessionDetail: Codable, Identifiable, Hashable {
    let id: String
    let startedAt: Date
    let finishedAt: Date?
    let notes: String?
    let workout: Workout?
    let sets: [SetEntry]
}

struct BodyweightEntry: Codable, Identifiable, Hashable {
    let id: String
    let weightKg: Double
    let measuredAt: Date
    let note: String?
}

struct Profile: Codable, Hashable {
    let email: String
    var displayName: String?
    var bodyweight: Double?
    var bodyweightGoalKg: Double?
    var unit: String
    var goal: String?
    var weeklyFrequency: Int?
    var isAdmin: Bool? = nil

    var firstName: String {
        (displayName ?? email.split(separator: "@").first.map(String.init) ?? "Athlete")
            .split(separator: " ").first.map(String.init) ?? "Athlete"
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let role: String
    var content: String
    var isUser: Bool { role == "USER" }
}

struct ChatHistory: Codable { let messages: [ChatMessage] }

struct StartedSession: Codable {
    let id: String
    let startedAt: Date
}

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: Admin

struct AdminOverview: Codable {
    let users: Int
    let newUsers30d: Int
    let sessionsTotal: Int
    let sessions7d: Int
    let sets7d: Int
    let activeUsers7d: Int
}

struct AdminUser: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String?
    let role: String
    let createdAt: Date
    let goal: String?
    let sessionCount: Int
    let lastSessionAt: Date?
    let activeProgram: String?

    var name: String { displayName ?? email }
    var isAdmin: Bool { role == "ADMIN" }
}

struct AdminProgramRef: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let phase: String
    let isActive: Bool
}

struct AdminSessionRef: Codable, Identifiable, Hashable {
    let id: String
    let startedAt: Date
    let finishedAt: Date?
    let workout: NamedRef?
    let _count: CountRef?
}

struct AdminUserDetail: Codable {
    let id: String
    let email: String
    let displayName: String?
    var role: String
    let createdAt: Date
    let goal: String?
    let weeklyFrequency: Int?
    let bodyweight: Double?
    let coachNote: String?
    let programs: [AdminProgramRef]
    let sessions: [AdminSessionRef]
}

/// Preview of a program drafted by Surba. The full JSON is kept separately
/// and sent back untouched when saving, so no field is lost.
struct DraftProgram: Codable {
    struct DraftExercise: Codable, Identifiable {
        var id: String { name }
        let name: String
        let muscleGroup: String
        let targetSets: Int
        let targetRepsMin: Int
        let targetRepsMax: Int
        let targetRIR: Int
        let restSec: Int
    }
    struct DraftWorkout: Codable, Identifiable {
        var id: String { name }
        let name: String
        let exercises: [DraftExercise]
    }
    let name: String
    let description: String?
    let phase: String
    let workouts: [DraftWorkout]
}
