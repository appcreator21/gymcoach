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

    /// Header for the weight column when logging.
    var weightColumnTitle: String {
        usesBodyweight || equipmentType == "BODYWEIGHT" ? "ADDED" : "WEIGHT"
    }

    /// One line that says what number to enter as the weight.
    var weightHint: String {
        if usesBodyweight || equipmentType == "BODYWEIGHT" {
            return "Enter only the EXTRA weight you add (belt, vest, dumbbell). Leave 0 for just your bodyweight."
        }
        switch equipmentType {
        case "BARBELL": return "Enter the TOTAL weight on the bar: the plates plus the bar itself. Not your bodyweight."
        case "DUMBBELL": return "Enter the weight of ONE dumbbell, not the pair. Not your bodyweight."
        case "MACHINE": return "Enter the weight set on the machine (stack or plates). Not your bodyweight."
        case "CABLE": return "Enter the weight set on the cable stack. Not your bodyweight."
        default: return "Enter the weight you lifted. Not your bodyweight."
        }
    }
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

/// Weekdays are stored as 1 = Monday ... 7 = Sunday.
enum Weekday {
    static let full = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static func name(_ iso: Int) -> String { full[((iso - 1) % 7 + 7) % 7] }
    static func short(_ iso: Int) -> String { String(name(iso).prefix(3)) }
    static func iso(of date: Date) -> Int { (Calendar.current.component(.weekday, from: date) + 5) % 7 + 1 }
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
    var onboardedAt: String? = nil

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
/// A generated or saved program. Round-trips every field the server stores, so
/// editing a template in the app never drops data (the server validates on save).
struct DraftProgram: Codable {
    struct DraftExercise: Codable, Identifiable {
        var uid = UUID()
        var id: UUID { uid }
        var name: String
        var muscleGroup: String
        var category: String
        var equipmentType: String?
        var targetSets: Int
        var targetRepsMin: Int
        var targetRepsMax: Int
        var targetRIR: Int
        var restSec: Int
        var autoregulationMode: String?
        var fatigueRate: Double?
        var loadAdjustmentPct: Double?
        var supersetGroup: Int?
        var tempo: String?
        var notes: String?

        private enum CodingKeys: String, CodingKey {
            case name, muscleGroup, category, equipmentType, targetSets, targetRepsMin, targetRepsMax
            case targetRIR, restSec, autoregulationMode, fatigueRate, loadAdjustmentPct
            case supersetGroup, tempo, notes
        }

        static func blank() -> DraftExercise {
            DraftExercise(name: "", muscleGroup: "CHEST", category: "COMPOUND", equipmentType: nil,
                          targetSets: 3, targetRepsMin: 8, targetRepsMax: 12, targetRIR: 2, restSec: 90)
        }
    }
    struct DraftWorkout: Codable, Identifiable {
        var uid = UUID()
        var id: UUID { uid }
        var name: String
        var dayOfWeek: Int?
        var exercises: [DraftExercise]

        private enum CodingKeys: String, CodingKey { case name, dayOfWeek, exercises }
    }
    var name: String
    var description: String?
    var phase: String
    var workouts: [DraftWorkout]
}

struct Announcement: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let pinned: Bool
    let createdAt: Date
}

struct TemplateSummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let phase: String
    let createdAt: Date
    let workoutCount: Int
    let exerciseCount: Int
    let valid: Bool
}

struct TemplateDetail: Codable {
    let id: String
    let program: DraftProgram
}

struct AdminExercise: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var muscleGroup: String
    var category: String
    var defaultRestSec: Int
    var notes: String?
    var usesBodyweight: Bool
    var equipmentType: String
    let _count: ExerciseUsage?

    var usageCount: Int { (_count?.programExercises ?? 0) + (_count?.sets ?? 0) }
}

struct ExerciseUsage: Codable, Hashable {
    let programExercises: Int
    let sets: Int
}

enum ExerciseOptions {
    static let muscles = ["CHEST", "BACK_WIDTH", "BACK_THICKNESS", "SHOULDERS_FRONT", "SHOULDERS_LATERAL",
                          "SHOULDERS_REAR", "BICEPS", "TRICEPS", "FOREARMS", "QUADS", "HAMSTRINGS",
                          "GLUTES", "CALVES", "ABS", "LOWER_BACK", "OTHER"]
    static let categories = ["COMPOUND", "ISOLATION", "CARDIO"]
    static let equipment = ["BARBELL", "DUMBBELL", "MACHINE", "CABLE", "BODYWEIGHT", "CARDIO", "OTHER"]
}

struct AdminProgramWorkout: Codable, Identifiable, Hashable {
    struct Count: Codable, Hashable { let exercises: Int }
    let id: String
    let name: String
    var dayOfWeek: Int?
    let order: Int
    let _count: Count?
}

struct AdminProgramDetail: Codable {
    let id: String
    let name: String
    let phase: String
    let isActive: Bool
    var workouts: [AdminProgramWorkout]
}
