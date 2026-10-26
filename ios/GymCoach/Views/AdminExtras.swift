import SwiftUI

// MARK: Announcements

struct AdminAnnouncementsView: View {
    @State private var items: [Announcement] = []
    @State private var loading = true
    @State private var showNew = false
    @State private var error: String?

    var body: some View {
        List {
            ForEach(items) { a in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if a.pinned { Image(systemName: "pin.fill").foregroundStyle(Theme.accent) }
                        Text(a.title).font(.headline)
                    }
                    Text(a.body).font(.subheadline).foregroundStyle(.secondary)
                    Text(a.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { Task { await delete(a) } }
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if loading { ProgressView() }
            else if items.isEmpty { Text("No announcements yet").foregroundStyle(.secondary) }
        }
        .navigationTitle("Announcements")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showNew, onDismiss: { Task { await load() } }) { NewAnnouncementSheet() }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { items = try await APIClient.shared.get("/api/admin/announcements") } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func delete(_ a: Announcement) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/admin/announcements/\(a.id)")
            items.removeAll { $0.id == a.id }
        } catch { self.error = error.localizedDescription }
    }
}

struct NewAnnouncementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var pinned = false
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Title", text: $title) }
                Section("Message") { TextEditor(text: $message).frame(minHeight: 120) }
                Section { Toggle("Pin to the top", isOn: $pinned) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("New announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await post() } }
                        .disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func post() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/admin/announcements",
                                               json: ["title": title, "body": message, "pinned": pinned])
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: Templates

struct AdminTemplatesView: View {
    @State private var items: [TemplateSummary] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            ForEach(items) { t in
                NavigationLink { TemplateDetailView(summary: t) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.name).font(.headline)
                        Text("\(t.workoutCount) workouts, \(t.exerciseCount) exercises  -  \(t.phase)")
                            .font(.caption).foregroundStyle(t.valid ? Color.secondary : Color.red)
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) { Task { await delete(t) } } }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if loading { ProgressView() }
            else if items.isEmpty { Text("Generate a program with Surba and save it as a template.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding() }
        }
        .navigationTitle("Templates")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { items = try await APIClient.shared.get("/api/admin/templates") } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func delete(_ t: TemplateSummary) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/admin/templates/\(t.id)")
            items.removeAll { $0.id == t.id }
        } catch { self.error = error.localizedDescription }
    }
}

struct TemplateDetailView: View {
    let summary: TemplateSummary
    @State private var program: DraftProgram?
    @State private var error: String?
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let program {
                    if let description = program.description, !description.isEmpty {
                        Text(description).font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(program.workouts) { w in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(w.name).font(.system(.headline, design: .rounded))
                                ForEach(w.exercises) { e in
                                    HStack {
                                        Text(e.name).font(.subheadline)
                                        Spacer()
                                        Text("\(e.targetSets) x \(e.targetRepsMin)-\(e.targetRepsMax)")
                                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    NavigationLink { AssignTemplateView(client: nil, template: summary) } label: {
                        Text("Assign to a client")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                } else if let error {
                    Text(error).foregroundStyle(.red)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(program?.name ?? summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if program != nil {
                ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } }
            }
        }
        .sheet(isPresented: $editing) {
            if let current = program {
                TemplateEditorView(templateId: summary.id, program: current) { updated in
                    self.program = updated
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let detail: TemplateDetail = try await APIClient.shared.get("/api/admin/templates/\(summary.id)")
            program = detail.program
        } catch { self.error = error.localizedDescription }
    }
}

/// Edits a saved template: details, workouts and every exercise's sets, reps,
/// effort and rest. Saves the whole program back; the server validates it.
struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let templateId: String
    var onSaved: (DraftProgram) -> Void
    @State private var program: DraftProgram
    @State private var saving = false
    @State private var error: String?

    init(templateId: String, program: DraftProgram, onSaved: @escaping (DraftProgram) -> Void) {
        self.templateId = templateId
        self.onSaved = onSaved
        _program = State(initialValue: program)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $program.name)
                    TextField("Phase", text: $program.phase)
                    TextField("Description", text: Binding(
                        get: { program.description ?? "" },
                        set: { program.description = $0.isEmpty ? nil : $0 }), axis: .vertical)
                        .lineLimit(1...4)
                }
                ForEach($program.workouts) { $workout in
                    WorkoutEditorSection(workout: $workout) { removeWorkout(workout.uid) }
                }
                Section {
                    Button {
                        Haptics.tap()
                        program.workouts.append(.init(name: "New workout", dayOfWeek: nil, exercises: [.blank()]))
                    } label: { Label("Add workout", systemImage: "plus.circle") }
                }
                if let error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if saving { ProgressView() } else { Button("Save") { Task { await save() } } }
                }
                ToolbarItem(placement: .bottomBar) { EditButton() }
            }
        }
    }

    private func removeWorkout(_ uid: UUID) {
        Haptics.warning()
        program.workouts.removeAll { $0.uid == uid }
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            let data = try JSONEncoder().encode(program)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            _ = try await APIClient.shared.raw("PATCH", "/api/admin/templates/\(templateId)", json: ["program": json])
            Haptics.success()
            onSaved(program)
            dismiss()
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }
}

private struct WorkoutEditorSection: View {
    @Binding var workout: DraftProgram.DraftWorkout
    let onDelete: () -> Void

    var body: some View {
        Section {
            TextField("Workout name", text: $workout.name).font(.headline)
            ForEach($workout.exercises) { $exercise in
                ExerciseRowEditor(exercise: $exercise)
            }
            .onDelete(perform: deleteExercises)
            .onMove(perform: moveExercises)
            Button(action: addExercise) { Label("Add exercise", systemImage: "plus") }
            Button("Delete workout", role: .destructive, action: onDelete)
        }
    }

    private func deleteExercises(_ offsets: IndexSet) { workout.exercises.remove(atOffsets: offsets) }
    private func moveExercises(_ from: IndexSet, _ to: Int) { workout.exercises.move(fromOffsets: from, toOffset: to) }
    private func addExercise() {
        Haptics.tap()
        workout.exercises.append(.blank())
    }
}

private struct ExerciseRowEditor: View {
    @Binding var exercise: DraftProgram.DraftExercise

    private static let muscles = [
        "CHEST", "BACK_WIDTH", "BACK_THICKNESS", "SHOULDERS_FRONT", "SHOULDERS_LATERAL", "SHOULDERS_REAR",
        "BICEPS", "TRICEPS", "FOREARMS", "QUADS", "HAMSTRINGS", "GLUTES", "CALVES", "ABS", "LOWER_BACK",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Exercise", text: $exercise.name)
            Picker("Muscle", selection: $exercise.muscleGroup) {
                ForEach(Self.muscles, id: \.self) { Text(Exercise.pretty($0)).tag($0) }
            }
            Stepper("Sets: \(exercise.targetSets)", value: $exercise.targetSets, in: 1...20)
            Stepper("Reps min: \(exercise.targetRepsMin)", value: $exercise.targetRepsMin, in: 1...50)
                .onChange(of: exercise.targetRepsMin) { _, new in
                    if exercise.targetRepsMax < new { exercise.targetRepsMax = new }
                }
            Stepper("Reps max: \(exercise.targetRepsMax)", value: $exercise.targetRepsMax, in: exercise.targetRepsMin...50)
            Stepper("Reps in reserve: \(exercise.targetRIR)", value: $exercise.targetRIR, in: 0...5)
            Stepper("Rest: \(exercise.restSec) s", value: $exercise.restSec, in: 15...600, step: 15)
        }
        .padding(.vertical, 4)
    }
}

/// Assigns a template to a client. Opened from a client (pick the template)
/// or from a template (pick the client).
struct AssignTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    let client: AdminUser?
    var template: TemplateSummary?

    @State private var templates: [TemplateSummary] = []
    @State private var clients: [AdminUser] = []
    @State private var templateId = ""
    @State private var clientId = ""
    @State private var activate = true
    @State private var busy = false
    @State private var done = false
    @State private var error: String?

    var body: some View {
        Form {
            if template == nil {
                Picker("Template", selection: $templateId) {
                    ForEach(templates.filter(\.valid)) { Text($0.name).tag($0.id) }
                }
            } else {
                LabeledContent("Template", value: template?.name ?? "")
            }
            if client == nil {
                Picker("Client", selection: $clientId) {
                    ForEach(clients) { Text($0.name).tag($0.id) }
                }
            } else {
                LabeledContent("Client", value: client?.name ?? "")
            }
            Toggle("Make it their active program", isOn: $activate)
            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            Section {
                Button(done ? "Assigned" : "Assign") { Task { await assign() } }
                    .disabled(busy || done || templateId.isEmpty || clientId.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Assign template")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let template { templateId = template.id }
            if let client { clientId = client.id }
            if template == nil {
                templates = (try? await APIClient.shared.get("/api/admin/templates")) ?? []
                templateId = templates.first(where: \.valid)?.id ?? ""
            }
            if client == nil {
                clients = (try? await APIClient.shared.get("/api/admin/users")) ?? []
                clientId = clients.first?.id ?? ""
            }
        }
    }

    private func assign() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/admin/templates/\(templateId)/assign",
                                               json: ["userId": clientId, "activate": activate])
            done = true
            Haptics.success()
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: Exercise library

struct ExerciseLibraryView: View {
    /// nil means the signed-in admin's own catalog.
    let userId: String?
    let title: String

    @Environment(AppState.self) private var app
    @State private var exercises: [AdminExercise] = []
    @State private var resolvedId: String?
    @State private var loading = true
    @State private var editing: AdminExercise?
    @State private var showNew = false
    @State private var query = ""
    @State private var error: String?

    private var filtered: [AdminExercise] {
        query.isEmpty ? exercises : exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var grouped: [(String, [AdminExercise])] {
        Dictionary(grouping: filtered, by: \.muscleGroup)
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.0) { muscle, items in
                Section(Exercise.pretty(muscle)) {
                    ForEach(items) { ex in
                        Button { editing = ex } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name).font(.body).foregroundStyle(.primary)
                                    Text("\(Exercise.pretty(ex.equipmentType))  -  \(Exercise.pretty(ex.category))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if ex.usageCount > 0 {
                                    Text("\(ex.usageCount)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .swipeActions { Button("Delete", role: .destructive) { Task { await delete(ex) } } }
                    }
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .overlay { if loading { ProgressView() } }
        .navigationTitle(title)
        .searchable(text: $query)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing, onDismiss: { Task { await load() } }) { ex in
            ExerciseEditorSheet(userId: resolvedId ?? "", exercise: ex)
        }
        .sheet(isPresented: $showNew, onDismiss: { Task { await load() } }) {
            ExerciseEditorSheet(userId: resolvedId ?? "", exercise: nil)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            if resolvedId == nil {
                if let userId { resolvedId = userId }
                else {
                    let users: [AdminUser] = try await APIClient.shared.get("/api/admin/users?q=\(app.profile?.email ?? "")")
                    resolvedId = users.first(where: { $0.email == app.profile?.email })?.id
                }
            }
            guard let id = resolvedId else { error = "Could not find your account."; loading = false; return }
            exercises = try await APIClient.shared.get("/api/admin/users/\(id)/exercises")
            error = nil
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func delete(_ ex: AdminExercise) async {
        guard let id = resolvedId else { return }
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/admin/users/\(id)/exercises/\(ex.id)")
            exercises.removeAll { $0.id == ex.id }
            error = nil
        } catch { self.error = error.localizedDescription; Haptics.warning() }
    }
}

struct ExerciseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let exercise: AdminExercise?

    @State private var name = ""
    @State private var muscle = "CHEST"
    @State private var category = "COMPOUND"
    @State private var equipment = "BARBELL"
    @State private var rest = 90
    @State private var bodyweight = false
    @State private var notes = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name", text: $name) }
                Section {
                    Picker("Muscle", selection: $muscle) { ForEach(ExerciseOptions.muscles, id: \.self) { Text(Exercise.pretty($0)).tag($0) } }
                    Picker("Type", selection: $category) { ForEach(ExerciseOptions.categories, id: \.self) { Text(Exercise.pretty($0)).tag($0) } }
                    Picker("Equipment", selection: $equipment) { ForEach(ExerciseOptions.equipment, id: \.self) { Text(Exercise.pretty($0)).tag($0) } }
                    Stepper("Rest: \(rest)s", value: $rest, in: 15...600, step: 15)
                    Toggle("Uses bodyweight", isOn: $bodyweight)
                }
                Section("Notes") { TextEditor(text: $notes).frame(minHeight: 80) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(exercise == nil ? "New exercise" : "Edit exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty || userId.isEmpty)
                }
            }
            .onAppear {
                guard let e = exercise else { return }
                name = e.name; muscle = e.muscleGroup; category = e.category; equipment = e.equipmentType
                rest = e.defaultRestSec; bodyweight = e.usesBodyweight; notes = e.notes ?? ""
            }
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        let body: [String: Any] = [
            "name": name, "muscleGroup": muscle, "category": category, "equipmentType": equipment,
            "defaultRestSec": rest, "usesBodyweight": bodyweight,
            "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSNull() : notes,
        ]
        do {
            if let exercise {
                _ = try await APIClient.shared.raw("PUT", "/api/admin/users/\(userId)/exercises/\(exercise.id)", json: body)
            } else {
                _ = try await APIClient.shared.raw("POST", "/api/admin/users/\(userId)/exercises", json: body)
            }
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
