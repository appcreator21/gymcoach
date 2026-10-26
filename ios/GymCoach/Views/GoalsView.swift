import SwiftUI

struct ExerciseGoal: Codable, Identifiable, Hashable {
    struct Ref: Codable, Hashable { let id: String; let name: String }
    let id: String
    let exerciseId: String
    let targetWeight: Double
    let targetReps: Int
    let achievedAt: Date?
    let exercise: Ref

    var targetE1RM: Double { targetReps <= 1 ? targetWeight : targetWeight * (1 + Double(targetReps) / 30) }
}

/// Lift targets such as "100 x 5 on bench". Progress compares your best
/// estimated 1RM with the target's.
struct GoalsView: View {
    @Environment(AppState.self) private var app
    @State private var goals: [ExerciseGoal] = []
    @State private var loading = true
    @State private var showNew = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if goals.isEmpty && !loading {
                    GlassCard { Text("Pick a lift and a target. Surba will show how close you are.").foregroundStyle(.secondary) }
                }
                ForEach(goals) { g in
                    let best = app.bestE1RM(for: g.exerciseId)
                    let progress = g.achievedAt != nil ? 1 : min(best / g.targetE1RM, 1)
                    GlassCard {
                        HStack(spacing: 14) {
                            ZStack {
                                ProgressRing(progress: progress, lineWidth: 7)
                                Image(systemName: g.achievedAt != nil ? "checkmark" : "target")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(g.achievedAt != nil ? Theme.mint : .white)
                            }
                            .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(g.exercise.name).font(.system(.headline, design: .rounded))
                                Text("\(app.units.format(g.targetWeight)) x \(g.targetReps)").font(.subheadline).foregroundStyle(.secondary)
                                Text(g.achievedAt != nil ? "Achieved" : "\(Int(progress * 100))% there")
                                    .font(.caption).foregroundStyle(g.achievedAt != nil ? Theme.mint : .secondary)
                            }
                            Spacer()
                            Button { Task { await delete(g) } } label: {
                                Image(systemName: "trash").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Lift goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .overlay { if loading { ProgressView() } }
        .sheet(isPresented: $showNew, onDismiss: { Task { await load() } }) { NewGoalSheet() }
        .task { await load() }
    }

    private func load() async {
        do { goals = try await APIClient.shared.get("/api/goals"); error = nil } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func delete(_ g: ExerciseGoal) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/goals/\(g.id)")
            goals.removeAll { $0.id == g.id }
            Haptics.tap()
        } catch { self.error = error.localizedDescription }
    }
}

struct NewGoalSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [Exercise] = []
    @State private var exerciseId = ""
    @State private var weight = ""
    @State private var reps = "5"
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Exercise", selection: $exerciseId) {
                    ForEach(exercises) { Text($0.name).tag($0.id) }
                }
                HStack {
                    Text("Weight (\(app.units.label))")
                    Spacer()
                    TextField("0", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                }
                Stepper("Reps: \(reps)", value: Binding(get: { Int(reps) ?? 1 }, set: { reps = String($0) }), in: 1...30)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(busy || weight.isEmpty || exerciseId.isEmpty)
                }
            }
            .task {
                let all: [Exercise] = (try? await APIClient.shared.get("/api/exercises")) ?? []
                exercises = all.filter { !$0.isCardio }
                exerciseId = app.trainedExercises.first?.id ?? exercises.first?.id ?? ""
            }
        }
    }

    private func save() async {
        guard let w = Double(weight.replacingOccurrences(of: ",", with: ".")), w > 0, let r = Int(reps) else {
            error = "Enter a weight."
            return
        }
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/goals",
                                               json: ["exerciseId": exerciseId, "targetWeight": app.units.toKg(w), "targetReps": r])
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
