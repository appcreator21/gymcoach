import Foundation

struct PersonalRecord: Identifiable {
    let id: String
    let exercise: Exercise
    let bestE1RM: Double
    let bestSet: SetEntry
    let heaviest: SetEntry
}

struct MuscleVolume: Identifiable {
    var id: String { muscle }
    let muscle: String
    let sets: Int
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let progress: Double
    var unlocked: Bool { progress >= 1 }
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let title: String
    let duration: TimeInterval
    let sets: Int
    let exercises: Int
    let volumeKg: Double
    let prs: [String]
}

/// Weekly working-set landmarks (same defaults as the web app's volume card).
enum VolumeBand {
    static let mev = 10
    static let mrv = 20
}

extension AppState {
    /// Every exercise seen in the active program or in loaded history.
    var knownExercises: [String: Exercise] {
        var out: [String: Exercise] = [:]
        let workouts = (program?.workouts ?? []) + details.values.compactMap(\.workout)
        for workout in workouts {
            for pe in workout.exercises ?? [] { out[pe.exercise.id] = pe.exercise }
        }
        return out
    }

    func personalRecords() -> [PersonalRecord] {
        let catalog = knownExercises
        let sets = details.values.flatMap(\.sets)
        let grouped = Dictionary(grouping: sets.filter { !$0.isWarmup && $0.durationSec == nil && $0.weight > 0 }, by: \.exerciseId)
        var records: [PersonalRecord] = []
        for (exerciseId, list) in grouped {
            guard let exercise = catalog[exerciseId],
                  let best = list.max(by: { ($0.e1RM ?? 0) < ($1.e1RM ?? 0) }),
                  let e1 = best.e1RM,
                  let heaviest = list.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) })
            else { continue }
            records.append(PersonalRecord(id: exerciseId, exercise: exercise, bestE1RM: e1, bestSet: best, heaviest: heaviest))
        }
        return records.sorted { $0.bestSet.completedAt > $1.bestSet.completedAt }
    }

    /// Working sets per muscle group in the current calendar week.
    func weeklySetsByMuscle() -> [MuscleVolume] {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        let catalog = knownExercises
        var counts: [String: Int] = [:]
        for d in details.values where week.contains(d.startedAt) {
            for s in d.sets where !s.isWarmup && s.durationSec == nil {
                guard let muscle = catalog[s.exerciseId]?.muscleGroup else { continue }
                counts[muscle, default: 0] += 1
            }
        }
        return counts.map { MuscleVolume(muscle: $0.key, sets: $0.value) }.sorted { $0.sets > $1.sets }
    }

    /// Start-of-day dates of every finished workout.
    var trainedDays: Set<Date> {
        let cal = Calendar.current
        return Set(finishedSessions.map { cal.startOfDay(for: $0.startedAt) })
    }

    var lifetimeVolumeKg: Double {
        details.values.flatMap(\.sets).reduce(0) { $0 + $1.volume }
    }

    /// How many times a session beat the best e1RM of every earlier session.
    var lifetimePRCount: Int {
        var best: [String: Double] = [:]
        var count = 0
        for d in details.values.sorted(by: { $0.startedAt < $1.startedAt }) {
            var sessionBest: [String: Double] = [:]
            for s in d.sets {
                guard let e1 = s.e1RM else { continue }
                sessionBest[s.exerciseId] = max(sessionBest[s.exerciseId] ?? 0, e1)
            }
            for (exerciseId, e1) in sessionBest {
                if let prior = best[exerciseId], e1 > prior + 0.01 { count += 1 }
                best[exerciseId] = max(best[exerciseId] ?? 0, e1)
            }
        }
        return count
    }

    func achievements() -> [Achievement] {
        let workouts = finishedSessions.count
        let streak = weekStreak
        let volume = lifetimeVolumeKg
        let prs = lifetimePRCount
        func ratio(_ value: Double, _ goal: Double) -> Double { min(value / goal, 1) }
        return [
            Achievement(id: "first", title: "First rep", detail: "Finish your first workout", icon: "figure.strengthtraining.traditional", progress: ratio(Double(workouts), 1)),
            Achievement(id: "ten", title: "Getting serious", detail: "Finish 10 workouts", icon: "10.circle.fill", progress: ratio(Double(workouts), 10)),
            Achievement(id: "twentyfive", title: "Regular", detail: "Finish 25 workouts", icon: "25.circle.fill", progress: ratio(Double(workouts), 25)),
            Achievement(id: "fifty", title: "Lifer", detail: "Finish 50 workouts", icon: "50.circle.fill", progress: ratio(Double(workouts), 50)),
            Achievement(id: "streak4", title: "One month strong", detail: "Train 4 weeks in a row", icon: "flame.fill", progress: ratio(Double(streak), 4)),
            Achievement(id: "streak8", title: "Two months strong", detail: "Train 8 weeks in a row", icon: "flame.circle.fill", progress: ratio(Double(streak), 8)),
            Achievement(id: "week", title: "Week complete", detail: "Hit your weekly goal", icon: "checkmark.seal.fill", progress: ratio(Double(sessionsThisWeek), Double(weeklyGoal))),
            Achievement(id: "pr1", title: "New heights", detail: "Set your first PR", icon: "trophy.fill", progress: ratio(Double(prs), 1)),
            Achievement(id: "pr10", title: "Record breaker", detail: "Set 10 PRs", icon: "medal.fill", progress: ratio(Double(prs), 10)),
            Achievement(id: "vol10k", title: "10 tonnes moved", detail: "Lift 10,000 kg in total", icon: "scalemass.fill", progress: ratio(volume, 10_000)),
            Achievement(id: "vol50k", title: "50 tonnes moved", detail: "Lift 50,000 kg in total", icon: "scalemass", progress: ratio(volume, 50_000)),
        ]
    }
}

enum WarmupPlan {
    /// A short ramp to the working weight, in the display unit. Weights are
    /// rounded to the plate step and never fall below the empty bar.
    static func sets(working: Double, step: Double, bar: Double) -> [(weight: Double, reps: Int)] {
        guard working > bar else { return [] }
        let ramp: [(Double, Int)] = [(0.4, 10), (0.6, 5), (0.75, 3), (0.9, 1)]
        var out: [(Double, Int)] = []
        for (fraction, reps) in ramp {
            let raw = working * fraction
            let rounded = max(bar, (raw / step).rounded() * step)
            if rounded >= working { continue }
            if let last = out.last, last.0 == rounded { continue }
            out.append((rounded, reps))
        }
        return out
    }
}
