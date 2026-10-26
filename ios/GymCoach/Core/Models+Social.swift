import Foundation

struct Challenge: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let metric: String
    let startsAt: Date
    let endsAt: Date
    let participants: Int
    var joined: Bool?
    var status: String?

    var metricLabel: String {
        switch metric {
        case "WORKOUTS": return "Workouts"
        case "SETS": return "Working sets"
        default: return "Volume"
        }
    }

    var metricIcon: String {
        switch metric {
        case "WORKOUTS": return "figure.strengthtraining.traditional"
        case "SETS": return "list.number"
        default: return "scalemass.fill"
        }
    }
}

struct LeaderboardRow: Codable, Identifiable, Hashable {
    var id: String { "\(rank)-\(name)-\(isMe)" }
    let name: String
    let score: Double
    let rank: Int
    let isMe: Bool
}

struct Leaderboard: Codable {
    let metric: String
    let rows: [LeaderboardRow]
    let myRank: Int?
    let participants: Int
}

struct QuickWorkoutResult: Codable {
    let programId: String
    let workoutId: String
}

struct CoachDebrief: Codable, Identifiable {
    let id: String
    let response: String
    let appliedAt: Date?
    let createdAt: Date
}

/// Choices shared by the plan builder and the quick workout screen. The raw
/// values are what the server expects.
enum PlanStyle: String, CaseIterable, Identifiable {
    case HYPERTROPHY, STRENGTH, POWERLIFTING, BODYWEIGHT, SCULPT, GENERAL
    var id: String { rawValue }
    var title: String {
        switch self {
        case .HYPERTROPHY: return "Build muscle"
        case .STRENGTH: return "Get stronger"
        case .POWERLIFTING: return "Powerlifting"
        case .BODYWEIGHT: return "Bodyweight"
        case .SCULPT: return "Sculpt and lean out"
        case .GENERAL: return "General fitness"
        }
    }
    var detail: String {
        switch self {
        case .HYPERTROPHY: return "Volume and variety for size"
        case .STRENGTH: return "Heavy compounds, longer rests"
        case .POWERLIFTING: return "Squat, bench, deadlift"
        case .BODYWEIGHT: return "Calisthenics progressions"
        case .SCULPT: return "Full body, supersets, conditioning"
        case .GENERAL: return "Balanced strength and cardio"
        }
    }
    var icon: String {
        switch self {
        case .HYPERTROPHY: return "figure.arms.open"
        case .STRENGTH: return "dumbbell.fill"
        case .POWERLIFTING: return "scalemass.fill"
        case .BODYWEIGHT: return "figure.gymnastics"
        case .SCULPT: return "flame.fill"
        case .GENERAL: return "heart.fill"
        }
    }
}

enum EquipmentProfile: String, CaseIterable, Identifiable {
    case FULL_GYM, HOME_DUMBBELLS, HOME_MINIMAL, HOTEL, BODYWEIGHT
    var id: String { rawValue }
    var title: String {
        switch self {
        case .FULL_GYM: return "Full gym"
        case .HOME_DUMBBELLS: return "Home dumbbells"
        case .HOME_MINIMAL: return "Home minimal"
        case .HOTEL: return "Hotel gym"
        case .BODYWEIGHT: return "No equipment"
        }
    }
    var icon: String {
        switch self {
        case .FULL_GYM: return "building.2.fill"
        case .HOME_DUMBBELLS: return "house.fill"
        case .HOME_MINIMAL: return "figure.cooldown"
        case .HOTEL: return "bed.double.fill"
        case .BODYWEIGHT: return "figure.walk"
        }
    }
}
