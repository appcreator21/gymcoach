import SwiftUI

struct ProgramListItem: Codable, Identifiable, Hashable {
    struct Counts: Codable, Hashable { let workouts: Int; let sessions: Int }
    let id: String
    let name: String
    let phase: String
    let isActive: Bool
    let _count: Counts?
}

/// Every program the user owns: activate, duplicate, delete, create.
struct ProgramsView: View {
    @Environment(AppState.self) private var app
    @State private var items: [ProgramListItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var showNew = false
    @State private var deleting: ProgramListItem?

    var body: some View {
        List {
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            ForEach(items) { p in
                NavigationLink { ProgramDetailView(programId: p.id, onChange: { Task { await load() } }) } label: { row(p) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { deleting = p }
                        Button("Duplicate") { Task { await duplicate(p) } }.tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button(p.isActive ? "Deactivate" : "Activate") { Task { await setActive(p, !p.isActive) } }
                            .tint(p.isActive ? .gray : .green)
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay {
            if loading { ProgressView() }
            else if items.isEmpty { Text("No programs yet. Tap + or ask Surba to build one.").foregroundStyle(.secondary).padding() }
        }
        .navigationTitle("My programs")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew, onDismiss: { Task { await load() } }) { ProgramInfoSheet(program: nil, onSaved: {}) }
        .alert("Delete \(deleting?.name ?? "program")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) { if let p = deleting { Task { await delete(p) } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage(deleting))
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func deleteMessage(_ p: ProgramListItem?) -> String {
        guard let p else { return "" }
        var text = "Its \(p._count?.workouts ?? 0) workouts and their exercises will be deleted. Workouts you already finished stay in your history."
        if p.isActive { text += " This is your active plan, so Today will be empty until you activate another." }
        return text
    }

    private func row(_ p: ProgramListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.system(.headline, design: .rounded))
                Text("\(p.phase)  -  \(p._count?.workouts ?? 0) workouts").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if p.isActive {
                Text("ACTIVE").font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.mint, in: Capsule())
            }
        }
    }

    private func load() async {
        do {
            let list: [ProgramListItem] = try await APIClient.shared.get("/api/programs")
            items = list
            error = nil
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func setActive(_ p: ProgramListItem, _ active: Bool) async {
        do {
            _ = try await APIClient.shared.raw("POST", "/api/programs/\(p.id)/activate", json: ["active": active])
            Haptics.success()
            await load()
            await app.refresh()
        } catch { self.error = error.localizedDescription }
    }

    private func duplicate(_ p: ProgramListItem) async {
        do {
            _ = try await APIClient.shared.raw("POST", "/api/programs/\(p.id)/duplicate", json: [:])
            Haptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func delete(_ p: ProgramListItem) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/programs/\(p.id)")
            Haptics.success()
            await load()
            await app.refresh()
        } catch { self.error = error.localizedDescription }
    }
}

/// Create a program or edit its name, phase and description.
struct ProgramInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let program: Program?
    var onSaved: () -> Void

    @State private var name = ""
    @State private var phase = "General"
    @State private var details = ""
    @State private var busy = false
    @State private var error: String?
    private let phases = ["Hypertrophy", "Strength", "Cut", "Bulk", "General", "Deload"]

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name", text: $name) }
                Section("Phase") {
                    TextField("Phase", text: $phase)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(phases, id: \.self) { p in Button(p) { phase = p }.buttonStyle(.bordered).controlSize(.small) } }
                    }
                }
                Section("Description") { TextField("Optional", text: $details, axis: .vertical).lineLimit(1...5) }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(program == nil ? "New program" : "Edit program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty || phase.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let program { name = program.name; phase = program.phase; details = program.description ?? "" }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        busy = true
        defer { busy = false }
        var body: [String: Any] = ["name": name, "phase": phase]
        body["description"] = details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSNull() : details
        do {
            if let program { _ = try await APIClient.shared.raw("PUT", "/api/programs/\(program.id)", json: body) }
            else { _ = try await APIClient.shared.raw("POST", "/api/programs", json: body) }
            Haptics.success()
            onSaved()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct ProgramDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let programId: String
    var onChange: () -> Void

    @State private var program: Program?
    @State private var error: String?
    @State private var showInfo = false
    @State private var showNewWorkout = false
    @State private var deleteWorkout: Workout?
    @State private var deleteProgram = false

    private var workouts: [Workout] { (program?.workouts ?? []).sorted { $0.order < $1.order } }

    var body: some View {
        List {
            if let program {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(program.name).font(.system(.title3, design: .rounded, weight: .bold))
                        Text(program.phase).font(.caption).foregroundStyle(Theme.mint)
                        if let d = program.description, !d.isEmpty { Text(d).font(.footnote).foregroundStyle(.secondary) }
                    }
                    Toggle("Active plan", isOn: Binding(get: { program.isActive }, set: { on in Task { await setActive(on) } }))
                    Button("Edit details") { showInfo = true }
                }
                Section("Workouts") {
                    ForEach(workouts) { w in
                        NavigationLink { WorkoutEditorView(programId: programId, workoutId: w.id, onChange: { Task { await load(); onChange() } }) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.name).font(.system(.body, design: .rounded, weight: .semibold))
                                Text("\(w.dayOfWeek.map { Weekday.name($0) + "  -  " } ?? "")\((w.exercises ?? []).count) exercises")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) { deleteWorkout = w }
                            Button("Duplicate") { Task { await duplicate(w) } }.tint(.blue)
                        }
                    }
                    .onMove { from, to in Task { await move(from, to) } }
                    Button { showNewWorkout = true } label: { Label("Add workout", systemImage: "plus") }
                }
                Section {
                    Button("Delete program", role: .destructive) { deleteProgram = true }
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay { if program == nil && error == nil { ProgressView() } }
        .navigationTitle(program?.name ?? "Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .sheet(isPresented: $showInfo, onDismiss: { Task { await load(); onChange() } }) {
            if let program { ProgramInfoSheet(program: program, onSaved: {}) }
        }
        .sheet(isPresented: $showNewWorkout, onDismiss: { Task { await load(); onChange() } }) { NewWorkoutSheet(programId: programId) }
        .alert("Delete \(deleteWorkout?.name ?? "workout")?", isPresented: Binding(get: { deleteWorkout != nil }, set: { if !$0 { deleteWorkout = nil } })) {
            Button("Delete", role: .destructive) { if let w = deleteWorkout { Task { await remove(w) } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The workout and its exercises are removed from this program. Finished workouts stay in your history.")
        }
        .alert("Delete this program?", isPresented: $deleteProgram) {
            Button("Delete", role: .destructive) { Task { await removeProgram() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("All its workouts are deleted. Finished workouts stay in your history.") }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { program = try await APIClient.shared.get("/api/programs/\(programId)"); error = nil } catch { self.error = error.localizedDescription }
    }

    private func setActive(_ on: Bool) async {
        do {
            _ = try await APIClient.shared.raw("POST", "/api/programs/\(programId)/activate", json: ["active": on])
            Haptics.success()
            await load()
            await app.refresh()
            onChange()
        } catch { self.error = error.localizedDescription }
    }

    private func move(_ from: IndexSet, _ to: Int) async {
        var ids = workouts.map(\.id)
        ids.move(fromOffsets: from, toOffset: to)
        do {
            _ = try await APIClient.shared.raw("POST", "/api/programs/\(programId)/reorder", json: ["ids": ids])
            Haptics.select()
            await load()
            await app.reloadProgram()
        } catch { self.error = error.localizedDescription; await load() }
    }

    private func duplicate(_ w: Workout) async {
        do {
            _ = try await APIClient.shared.raw("POST", "/api/workouts/\(w.id)/duplicate", json: [:])
            Haptics.success()
            await load()
            await app.reloadProgram()
        } catch { self.error = error.localizedDescription }
    }

    private func remove(_ w: Workout) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/workouts/\(w.id)")
            Haptics.success()
            await load()
            await app.reloadProgram()
            await app.reloadSessions()
        } catch { self.error = error.localizedDescription }
    }

    private func removeProgram() async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/programs/\(programId)")
            Haptics.success()
            onChange()
            await app.refresh()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct NewWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let programId: String
    @State private var name = ""
    @State private var day: Int? = nil
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name, e.g. Upper A", text: $name) }
                Section("Day") {
                    Picker("Day", selection: $day) {
                        Text("Any day").tag(Int?.none)
                        ForEach(1...7, id: \.self) { Text(Weekday.name($0)).tag(Int?.some($0)) }
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }.disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        busy = true
        defer { busy = false }
        var body: [String: Any] = ["name": name]
        body["dayOfWeek"] = day.map { $0 as Any } ?? NSNull()
        do {
            _ = try await APIClient.shared.raw("POST", "/api/programs/\(programId)/workouts", json: body)
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

/// Edit one workout of a program: name, day, and its exercises.
struct WorkoutEditorView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let programId: String
    let workoutId: String
    var onChange: () -> Void = {}

    @State private var workout: Workout?
    @State private var name = ""
    @State private var error: String?
    @State private var showPicker = false
    @State private var editing: ExerciseEdit?
    @State private var deleting: ProgramExercise?
    @State private var confirmDeleteWorkout = false
    @FocusState private var nameFocused: Bool

    private var exercises: [ProgramExercise] { (workout?.exercises ?? []).sorted { $0.order < $1.order } }

    var body: some View {
        List {
            if let workout {
                Section {
                    TextField("Workout name", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { Task { await saveHeader() } }
                    Picker("Day", selection: Binding(
                        get: { workout.dayOfWeek },
                        set: { day in Task { await saveHeader(day: .some(day)) } })) {
                        Text("Any day").tag(Int?.none)
                        ForEach(1...7, id: \.self) { Text(Weekday.name($0)).tag(Int?.some($0)) }
                    }
                }
                Section("Exercises") {
                    ForEach(exercises) { pe in
                        Button { editing = ExerciseEdit(existing: pe, exercise: pe.exercise) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pe.exercise.name).font(.system(.body, design: .rounded, weight: .semibold)).foregroundStyle(.primary)
                                Text("\(pe.targetSets) x \(pe.repRange)  -  RIR \(pe.targetRIR)  -  rest \(pe.restSec)s")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions { Button("Remove", role: .destructive) { deleting = pe } }
                    }
                    .onMove { from, to in Task { await move(from, to) } }
                    Button { showPicker = true } label: { Label("Add exercise", systemImage: "plus") }
                }
                Section {
                    Button("Duplicate workout") { Task { await duplicate() } }
                    Button("Delete workout", role: .destructive) { confirmDeleteWorkout = true }
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay { if workout == nil && error == nil { ProgressView() } }
        .navigationTitle(workout?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .onChange(of: nameFocused) { _, focused in if !focused { Task { await saveHeader() } } }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet(excluding: Set(exercises.map(\.exercise.id)), title: "Add exercise") { picked in
                editing = ExerciseEdit(existing: nil, exercise: picked)
            }
        }
        .sheet(item: $editing, onDismiss: { Task { await load(); notify() } }) { edit in
            ProgramExerciseEditSheet(workoutId: workoutId, edit: edit)
        }
        .alert("Remove \(deleting?.exercise.name ?? "exercise")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Remove", role: .destructive) { if let pe = deleting { Task { await remove(pe) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It is removed from this workout. Sets you already logged are kept.") }
        .alert("Delete this workout?", isPresented: $confirmDeleteWorkout) {
            Button("Delete", role: .destructive) { Task { await deleteWorkout() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It and its exercises are removed from the program. Finished workouts stay in your history.") }
        .task { await load() }
    }

    private func notify() {
        onChange()
        Task { await app.reloadProgram() }
    }

    private func load() async {
        do {
            let program: Program = try await APIClient.shared.get("/api/programs/\(programId)")
            workout = program.workouts?.first { $0.id == workoutId }
            if let w = workout, !nameFocused { name = w.name }
            if workout == nil { error = "This workout no longer exists." } else { error = nil }
        } catch { self.error = error.localizedDescription }
    }

    private func saveHeader(day: Int?? = nil) async {
        guard let w = workout else { return }
        let newName = name.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { name = w.name; return }
        let newDay: Int? = day ?? w.dayOfWeek
        guard newName != w.name || newDay != w.dayOfWeek else { return }
        var body: [String: Any] = ["name": newName]
        body["dayOfWeek"] = newDay.map { $0 as Any } ?? NSNull()
        do {
            _ = try await APIClient.shared.raw("PUT", "/api/workouts/\(workoutId)", json: body)
            Haptics.success()
            await load()
            notify()
        } catch { self.error = error.localizedDescription }
    }

    private func move(_ from: IndexSet, _ to: Int) async {
        var ids = exercises.map(\.id)
        ids.move(fromOffsets: from, toOffset: to)
        do {
            _ = try await APIClient.shared.raw("POST", "/api/workouts/\(workoutId)/reorder", json: ["ids": ids])
            Haptics.select()
            await load()
            notify()
        } catch { self.error = error.localizedDescription; await load() }
    }

    private func remove(_ pe: ProgramExercise) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/program-exercises/\(pe.id)")
            Haptics.success()
            await load()
            notify()
        } catch { self.error = error.localizedDescription }
    }

    private func duplicate() async {
        do {
            _ = try await APIClient.shared.raw("POST", "/api/workouts/\(workoutId)/duplicate", json: [:])
            Haptics.success()
            notify()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func deleteWorkout() async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/workouts/\(workoutId)")
            Haptics.success()
            notify()
            await app.reloadSessions()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct ExerciseEdit: Identifiable {
    let id = UUID()
    let existing: ProgramExercise?
    let exercise: Exercise
}

/// Targets for one exercise in a workout: sets, reps, effort, rest, notes.
struct ProgramExerciseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    let edit: ExerciseEdit

    @State private var sets = 3
    @State private var repsMin = 8
    @State private var repsMax = 12
    @State private var rir = 2
    @State private var rest = 90
    @State private var notes = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                    Stepper("Min reps: \(repsMin)", value: $repsMin, in: 1...50)
                        .onChange(of: repsMin) { _, v in if repsMax < v { repsMax = v } }
                    Stepper("Max reps: \(repsMax)", value: $repsMax, in: 1...50)
                        .onChange(of: repsMax) { _, v in if repsMin > v { repsMin = v } }
                    Stepper("Reps in reserve: \(rir)", value: $rir, in: 0...5)
                    Stepper("Rest: \(rest) s", value: $rest, in: 15...600, step: 15)
                }
                Section("Notes") { TextField("Cues, tempo, reminders", text: $notes, axis: .vertical).lineLimit(1...4) }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(edit.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(busy) }
            }
            .onAppear {
                if let e = edit.existing {
                    sets = e.targetSets; repsMin = e.targetRepsMin; repsMax = e.targetRepsMax
                    rir = e.targetRIR; rest = e.restSec; notes = e.notes ?? ""
                } else {
                    rest = min(600, max(15, edit.exercise.defaultRestSec))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        busy = true
        defer { busy = false }
        let clean = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var body: [String: Any] = [
            "exerciseId": edit.exercise.id, "targetSets": sets, "targetRepsMin": repsMin,
            "targetRepsMax": max(repsMax, repsMin), "targetRIR": rir, "restSec": rest,
        ]
        body["notes"] = clean.isEmpty ? NSNull() : clean
        do {
            if let existing = edit.existing {
                body["tempo"] = existing.tempo.map { $0 as Any } ?? NSNull()
                _ = try await APIClient.shared.raw("PUT", "/api/program-exercises/\(existing.id)", json: body)
            } else {
                _ = try await APIClient.shared.raw("POST", "/api/workouts/\(workoutId)/program-exercises", json: body)
            }
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
