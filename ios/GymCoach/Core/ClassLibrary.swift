import Foundation

/// One timed step of a guided class: a move to do, or a rest.
struct ClassStep: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let seconds: Int
    let isRest: Bool
    let cue: String
}

enum ClassKind: String, CaseIterable, Identifiable {
    case hiit = "HIIT"
    case cardio = "Cardio"
    case core = "Core"
    case yoga = "Yoga"
    case mobility = "Mobility"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hiit: return "bolt.heart.fill"
        case .cardio: return "figure.run"
        case .core: return "figure.core.training"
        case .yoga: return "figure.yoga"
        case .mobility: return "figure.flexibility"
        }
    }
}

struct GuidedClass: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: ClassKind
    let level: String
    let blurb: String
    let steps: [ClassStep]

    var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }
    var minutes: Int { Int((Double(totalSeconds) / 60).rounded()) }
    var moveCount: Int { steps.filter { !$0.isRest }.count }
}

/// The built-in class catalog. Everything is no-equipment so it works at home,
/// in a hotel, or as a finisher after lifting.
enum ClassLibrary {
    static let all: [GuidedClass] = [
        fullBodyBurn, tabata, lowImpact, boxing, jumpRope, coreCrusher, morningFlow, eveningStretch, hipsAndSpine, shoulderUnlock,
    ]

    /// Work and rest intervals over a list of moves, repeated for `rounds`.
    private static func circuit(
        _ moves: [(String, String)], work: Int, rest: Int, rounds: Int, warmup: [ClassStep] = [], cooldown: [ClassStep] = []
    ) -> [ClassStep] {
        var steps = warmup
        for round in 1...rounds {
            for (index, move) in moves.enumerated() {
                steps.append(ClassStep(name: move.0, seconds: work, isRest: false, cue: move.1))
                let isLast = round == rounds && index == moves.count - 1
                if !isLast && rest > 0 {
                    let next = index + 1 < moves.count ? moves[index + 1].0 : moves[0].0
                    steps.append(ClassStep(name: "Rest", seconds: rest, isRest: true, cue: "Next: \(next)"))
                }
            }
        }
        return steps + cooldown
    }

    private static func holds(_ poses: [(String, Int, String)]) -> [ClassStep] {
        poses.map { ClassStep(name: $0.0, seconds: $0.1, isRest: false, cue: $0.2) }
    }

    private static let warmupSteps = [
        ClassStep(name: "Easy jog in place", seconds: 30, isRest: false, cue: "Loosen up and breathe"),
        ClassStep(name: "Arm circles and hip circles", seconds: 30, isRest: false, cue: "Big slow circles"),
    ]

    private static let cooldownSteps = [
        ClassStep(name: "Walk it out", seconds: 30, isRest: false, cue: "Slow your breathing"),
        ClassStep(name: "Standing quad and hamstring stretch", seconds: 30, isRest: false, cue: "Hold, do not bounce"),
    ]

    static let fullBodyBurn = GuidedClass(
        id: "full-body-burn", title: "Full Body Burn", kind: .hiit, level: "Intermediate",
        blurb: "Eight moves, three rounds, 40 seconds on and 20 off. Leave nothing behind.",
        steps: circuit([
            ("Jumping jacks", "Land soft, arms fully overhead"),
            ("Squat jumps", "Sit back, explode up"),
            ("Mountain climbers", "Hips low, drive the knees"),
            ("Push-ups", "Chest to the floor, body in one line"),
            ("Reverse lunges", "Alternate legs, stay tall"),
            ("Burpees", "Smooth and steady, pace yourself"),
            ("High knees", "Knees to hip height"),
            ("Plank shoulder taps", "Do not let the hips rock"),
        ], work: 40, rest: 20, rounds: 3, warmup: warmupSteps, cooldown: cooldownSteps))

    static let tabata = GuidedClass(
        id: "tabata-16", title: "Tabata 16", kind: .hiit, level: "Hard",
        blurb: "Four moves, four rounds: 20 seconds all out, 10 seconds off.",
        steps: circuit([("Squat jumps", "All out"), ("Mountain climbers", "Fast feet"),
                        ("Burpees", "Max effort"), ("High knees", "Drive hard")],
                       work: 20, rest: 10, rounds: 4, warmup: warmupSteps, cooldown: cooldownSteps))

    static let lowImpact = GuidedClass(
        id: "low-impact-hiit", title: "Low Impact HIIT", kind: .hiit, level: "Beginner",
        blurb: "All the heart rate, none of the jumping. Quiet enough for an apartment.",
        steps: circuit([
            ("Fast feet squats", "Quick tempo, stay low"),
            ("Standing knee drives", "Elbow to opposite knee"),
            ("Step back lunges", "Controlled, no impact"),
            ("Incline push-ups", "Hands on a sofa or table"),
            ("Skater steps", "Glide side to side"),
            ("Plank hold", "Squeeze everything"),
        ], work: 40, rest: 20, rounds: 3, warmup: warmupSteps, cooldown: cooldownSteps))

    static let boxing = GuidedClass(
        id: "boxing-cardio", title: "Shadow Boxing Cardio", kind: .cardio, level: "Intermediate",
        blurb: "Three minute rounds of punches, footwork and defense, with a minute off between.",
        steps: circuit([
            ("Jab cross", "Rotate the hips, hands back to your chin"),
            ("Hook and uppercut combos", "Bend the knees, stay loose"),
            ("Slip, bob and weave", "Keep your eyes forward"),
            ("Power punches", "Everything you have"),
        ], work: 45, rest: 15, rounds: 3, warmup: warmupSteps, cooldown: cooldownSteps))

    static let jumpRope = GuidedClass(
        id: "jump-rope", title: "Jump Rope Intervals", kind: .cardio, level: "Intermediate",
        blurb: "Rope or no rope. Alternating easy and fast intervals build a big engine.",
        steps: circuit([
            ("Steady jump", "Light on the toes"),
            ("Fast jump", "Speed up, wrists only"),
        ], work: 60, rest: 0, rounds: 6, warmup: warmupSteps, cooldown: cooldownSteps))

    static let coreCrusher = GuidedClass(
        id: "core-crusher", title: "Core Crusher", kind: .core, level: "Intermediate",
        blurb: "Ten minutes of abs, obliques and low back. Slow reps, tight everything.",
        steps: circuit([
            ("Dead bugs", "Low back glued to the floor"),
            ("Bicycle crunches", "Shoulder to opposite knee"),
            ("Side plank, left", "Hips high"),
            ("Side plank, right", "Hips high"),
            ("Leg raises", "Lower slowly, no swinging"),
            ("Superman holds", "Lift chest and legs together"),
        ], work: 40, rest: 15, rounds: 2))

    static let morningFlow = GuidedClass(
        id: "morning-flow", title: "Morning Flow", kind: .yoga, level: "All levels",
        blurb: "A gentle twelve minute flow to wake up the spine, hips and shoulders.",
        steps: holds([
            ("Child's pose", 45, "Breathe into your back"),
            ("Cat and cow", 60, "Move with your breath"),
            ("Downward dog", 60, "Press the floor away, pedal the feet"),
            ("Low lunge, left", 45, "Sink the hips, chest tall"),
            ("Low lunge, right", 45, "Sink the hips, chest tall"),
            ("Forward fold", 45, "Soft knees, let the head hang"),
            ("Chair pose", 40, "Weight in the heels"),
            ("Warrior II, left", 40, "Front knee over the ankle"),
            ("Warrior II, right", 40, "Front knee over the ankle"),
            ("Seated twist", 60, "Long spine, then rotate"),
            ("Happy baby", 45, "Rock gently"),
            ("Final rest", 60, "Let everything go"),
        ]))

    static let eveningStretch = GuidedClass(
        id: "evening-stretch", title: "Evening Wind Down", kind: .yoga, level: "All levels",
        blurb: "Long, slow holds to unwind after a day of training.",
        steps: holds([
            ("Butterfly stretch", 60, "Fold forward from the hips"),
            ("Pigeon pose, left", 75, "Square the hips"),
            ("Pigeon pose, right", 75, "Square the hips"),
            ("Supine twist, left", 60, "Shoulders heavy"),
            ("Supine twist, right", 60, "Shoulders heavy"),
            ("Hamstring stretch, left", 60, "Strap or towel around the foot"),
            ("Hamstring stretch, right", 60, "Strap or towel around the foot"),
            ("Legs up the wall", 120, "Slow belly breaths"),
        ]))

    static let hipsAndSpine = GuidedClass(
        id: "hips-spine", title: "Hips and Spine Reset", kind: .mobility, level: "All levels",
        blurb: "Ten minutes for stiff hips and a desk-bound back. Great before squats and deadlifts.",
        steps: holds([
            ("90/90 hip switches", 60, "Sit tall, rotate smoothly"),
            ("World's greatest stretch, left", 45, "Elbow to the instep, reach up"),
            ("World's greatest stretch, right", 45, "Elbow to the instep, reach up"),
            ("Deep squat hold", 60, "Heels down, elbows push the knees out"),
            ("Thread the needle, left", 40, "Melt the shoulder to the floor"),
            ("Thread the needle, right", 40, "Melt the shoulder to the floor"),
            ("Cat cow", 60, "Slow and full range"),
            ("Couch stretch, left", 50, "Squeeze the glute"),
            ("Couch stretch, right", 50, "Squeeze the glute"),
        ]))

    static let shoulderUnlock = GuidedClass(
        id: "shoulder-unlock", title: "Shoulder Unlock", kind: .mobility, level: "All levels",
        blurb: "Open up tight shoulders and upper back before pressing and pulling.",
        steps: holds([
            ("Arm circles", 40, "Start small, grow big"),
            ("Wall slides", 50, "Keep the ribs down"),
            ("Doorway chest stretch", 50, "Elbows at shoulder height"),
            ("Thoracic rotations, left", 40, "Hand behind the head, open the chest"),
            ("Thoracic rotations, right", 40, "Hand behind the head, open the chest"),
            ("Band-free pull aparts", 45, "Squeeze the shoulder blades"),
            ("Child's pose reach", 50, "Walk the hands out, sink the chest"),
        ]))
}
