import SwiftUI

/// "I have 30 minutes and a hotel gym": Surba builds one workout on the spot.
struct QuickWorkoutView: View {
    @Environment(AppState.self) private var app

    @State private var equipment: EquipmentProfile = .FULL_GYM
    @State private var minutes = 30
    @State private var focus = "FULL_BODY"
    @State private var intensity = "NORMAL"
    @State private var building = false
    @State private var workout: Workout?
    @State private var running: Workout?
    @State private var error: String?

    private let focuses: [(String, String)] = [
        ("FULL_BODY", "Full body"), ("UPPER", "Upper"), ("LOWER", "Lower"), ("PUSH", "Push"), ("PULL", "Pull"),
        ("LEGS", "Legs"), ("CORE", "Core"), ("ARMS_SHOULDERS", "Arms"), ("GLUTES", "Glutes"),
    ]
    private let lengths = [15, 20, 30, 45, 60]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle("Where are you training?")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EquipmentProfile.allCases) { e in
                            Button { equipment = e; Haptics.select() } label: {
                                Label(e.title, systemImage: e.icon).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(equipment == e ? Color.white : Theme.card, in: Capsule())
                                    .foregroundStyle(equipment == e ? Color.black : Color.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionTitle("How long?")
                Picker("Minutes", selection: $minutes) {
                    ForEach(lengths, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)

                SectionTitle("What do you want to hit?")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(focuses, id: \.0) { value, title in
                        Button { focus = value; Haptics.select() } label: {
                            Text(title).font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(focus == value ? Color.white : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(focus == value ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionTitle("Intensity")
                Picker("Intensity", selection: $intensity) {
                    Text("Easy").tag("LIGHT"); Text("Normal").tag("NORMAL"); Text("Hard").tag("HARD")
                }
                .pickerStyle(.segmented)

                Button { Task { await build() } } label: {
                    if building { HStack { ProgressView().tint(.black); Text("Building your workout...") } }
                    else { Label(workout == nil ? "Build my workout" : "Build another", systemImage: "bolt.fill") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(building)

                if let error { Text(error).font(.footnote).foregroundStyle(.red) }

                if let workout {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(workout.name).font(.system(.title3, design: .rounded, weight: .bold))
                            ForEach(workout.exercises ?? []) { pe in
                                HStack {
                                    Text(pe.exercise.name).font(.subheadline)
                                    Spacer()
                                    Text("\(pe.targetSets) x \(pe.repRange)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button { running = workout; Haptics.thud() } label: { Label("Start workout", systemImage: "play.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle("Quick workout")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $running, onDismiss: { workout = nil }) { WorkoutSessionView(workout: $0) }
    }

    private func build() async {
        building = true
        error = nil
        workout = nil
        defer { building = false }
        do {
            let result: QuickWorkoutResult = try await APIClient.shared.send("POST", "/api/workouts/quick", json: [
                "equipment": equipment.rawValue, "minutes": minutes, "focus": focus, "intensity": intensity,
            ])
            let program: Program = try await APIClient.shared.get("/api/programs/\(result.programId)")
            workout = program.workouts?.first { $0.id == result.workoutId }
            if workout == nil { error = "The workout was saved but could not be loaded." }
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }
}
