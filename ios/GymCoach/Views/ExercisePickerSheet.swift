import SwiftUI

/// Pick an exercise from the user's catalog, or create one. Used to add or swap
/// an exercise in a live workout and to build a workout in the editor.
struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let excluding: Set<String>
    var title = "Choose exercise"
    var suggestMuscle: String? = nil
    var onPick: (Exercise) -> Void

    @State private var exercises: [Exercise] = []
    @State private var query = ""
    @State private var loading = true
    @State private var showCreate = false
    @State private var error: String?

    private var filtered: [Exercise] {
        exercises.filter { !excluding.contains($0.id) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }

    private var grouped: [(String, [Exercise])] {
        var groups = Dictionary(grouping: filtered, by: \.muscleGroup)
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
        groups.sort { a, b in
            // The muscle being swapped comes first, then alphabetical.
            if a.0 == suggestMuscle { return true }
            if b.0 == suggestMuscle { return false }
            return a.0 < b.0
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showCreate = true } label: { Label("Create a new exercise", systemImage: "plus.circle.fill") }
                }
                ForEach(grouped, id: \.0) { muscle, items in
                    Section(Exercise.pretty(muscle)) {
                        ForEach(items) { ex in
                            Button {
                                onPick(ex)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name).foregroundStyle(.primary)
                                        Text(Exercise.pretty(ex.equipmentType)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .overlay {
                if loading { ProgressView() }
                else if filtered.isEmpty { Text(query.isEmpty ? "No more exercises to add." : "No match.").foregroundStyle(.secondary) }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $showCreate) {
                NewExerciseSheet { created in
                    exercises.append(created)
                    onPick(created)
                    dismiss()
                }
            }
            .task {
                do { exercises = try await APIClient.shared.get("/api/exercises") } catch { self.error = error.localizedDescription }
                loading = false
            }
        }
    }
}

struct NewExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (Exercise) -> Void

    @State private var name = ""
    @State private var muscle = "CHEST"
    @State private var equipment = "BARBELL"
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name", text: $name) }
                Section {
                    Picker("Muscle", selection: $muscle) {
                        ForEach(ExerciseOptions.muscles, id: \.self) { Text(Exercise.pretty($0)).tag($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(ExerciseOptions.equipment, id: \.self) { Text(Exercise.pretty($0)).tag($0) }
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() async {
        busy = true
        defer { busy = false }
        let isCardio = equipment == "CARDIO"
        let body: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces), "muscleGroup": muscle,
            "category": isCardio ? "CARDIO" : "COMPOUND", "equipmentType": equipment,
            "defaultRestSec": 90, "usesBodyweight": equipment == "BODYWEIGHT",
        ]
        do {
            let created: Exercise = try await APIClient.shared.send("POST", "/api/exercises", json: body)
            Haptics.success()
            onCreated(created)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
