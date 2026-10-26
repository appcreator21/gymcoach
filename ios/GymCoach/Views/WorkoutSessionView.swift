import SwiftUI

struct WorkoutSessionView: View {
    @Environment(AppState.self) private var app
    @Environment(RestTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let workout: Workout
    var sessionId: String? = nil

    @State private var model: SessionViewModel?
    @State private var showFinish = false
    @State private var showDiscard = false
    @State private var showTemplatePrompt = false
    @State private var showPlates = false
    @State private var showNotes = false
    @State private var showAddExercise = false
    @State private var swapTarget: ProgramExercise?
    @State private var summary: WorkoutSummary?
    @State private var finishing = false

    var body: some View {
        ZStack {
            AppBackground()
            if let model {
                if let failure = model.startFailure {
                    failureView(failure)
                } else {
                    content(model)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let m = SessionViewModel(workout: workout, sessionId: sessionId, app: app, timer: timer)
            model = m
            timer.requestPermission()
            await m.start()
            updateIdleTimer()
            await app.reloadSessions()
        }
        .onChange(of: model?.isPaused) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let model else { return }
            Task { await model.syncFromServer(); await model.flushPending() }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await app.reloadSessions() }
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = Prefs.bool(Prefs.keepAwake, default: true) && !(model?.isPaused ?? false)
    }

    private func failureView(_ text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(Theme.amber)
            Text(text).multilineTextAlignment(.center).padding(.horizontal, 30)
            Button("Close") { Task { await app.refresh(); dismiss() } }
                .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 60)
        }
    }

    @ViewBuilder
    private func content(_ model: SessionViewModel) -> some View {
        VStack(spacing: 0) {
            header(model)
            if model.isStarting {
                Spacer(); ProgressView(); Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if model.pendingCount > 0 {
                            Label("\(model.pendingCount) set\(model.pendingCount == 1 ? "" : "s") waiting to sync", systemImage: "icloud.and.arrow.up")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.amber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if model.exercises.isEmpty {
                            GlassCard {
                                Text("This workout has no exercises. Add one to get going.").foregroundStyle(.secondary)
                            }
                        }
                        ForEach(model.exercises) { pe in
                            ExerciseCard(model: model, pe: pe, onSwap: { swapTarget = $0 })
                        }
                        Button { showAddExercise = true } label: {
                            Label("Add exercise", systemImage: "plus")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, timer.isRunning ? 140 : 50)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let toast = model.toast { ToastView(toast: toast).transition(.move(edge: .bottom).combined(with: .opacity)) }
                if timer.isRunning && !model.isPaused {
                    RestTimerBar().transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)
        }
        .overlay(alignment: .top) {
            if let banner = model.prBanner {
                Label(banner, systemImage: "trophy.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .shadow(radius: 12)
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay { ConfettiView(trigger: model.confettiTick).allowsHitTesting(false) }
        .overlay {
            if model.isPaused && !model.isStarting {
                PausedOverlay(model: model, onFinish: { showFinish = true }, onDiscard: { showDiscard = true })
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4), value: timer.isRunning)
        .animation(.spring(response: 0.4), value: model.prBanner)
        .animation(.spring(response: 0.35), value: model.toast?.id)
        .animation(.easeInOut(duration: 0.25), value: model.isPaused)
        .alert("Something went wrong", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.error ?? "") }
        .confirmationDialog("Finish workout?", isPresented: $showFinish, titleVisibility: .visible) {
            if model.workingSets > 0 {
                Button("Finish and save") { beginFinish(model) }
            }
            Button("Discard workout", role: .destructive) { showDiscard = true }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text(finishMessage(model))
        }
        .confirmationDialog("Update this workout?", isPresented: $showTemplatePrompt, titleVisibility: .visible) {
            Button("Update the saved workout") { performFinish(model, updateTemplate: true) }
            Button("Only for today") { performFinish(model, updateTemplate: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You added or removed exercises. Save those changes to the workout in your program so next time matches?")
        }
        .alert("Discard this workout?", isPresented: $showDiscard) {
            Button("Discard", role: .destructive) { Task { await model.discard(); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.completedSets > 0 ? "The \(model.completedSets) logged set\(model.completedSets == 1 ? "" : "s") will be deleted. This cannot be undone." : "Nothing has been logged yet.")
        }
        .sheet(item: $summary, onDismiss: { dismiss() }) { WorkoutSummaryView(summary: $0) }
        .sheet(isPresented: $showPlates) { PlateCalculatorView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showNotes) { WorkoutNotesSheet(model: model) }
        .sheet(isPresented: $showAddExercise) {
            ExercisePickerSheet(excluding: Set(model.exercises.map(\.exercise.id)), title: "Add exercise") { model.addExercise($0) }
        }
        .sheet(item: $swapTarget) { target in
            ExercisePickerSheet(excluding: Set(model.exercises.map(\.exercise.id)), title: "Swap \(target.exercise.name)",
                                suggestMuscle: target.exercise.muscleGroup) { model.swap(target, with: $0) }
        }
    }

    private func finishMessage(_ model: SessionViewModel) -> String {
        if model.workingSets == 0 { return "No sets are logged yet, so there is nothing to save." }
        var text = "\(model.workingSets) working set\(model.workingSets == 1 ? "" : "s") logged."
        if model.plannedUnlogged > 0 { text += " \(model.plannedUnlogged) planned set\(model.plannedUnlogged == 1 ? " was" : "s were") not logged." }
        return text
    }

    private func beginFinish(_ model: SessionViewModel) {
        if model.hasStructuralChanges { showTemplatePrompt = true } else { performFinish(model, updateTemplate: false) }
    }

    private func performFinish(_ model: SessionViewModel, updateTemplate: Bool) {
        guard !finishing else { return }
        finishing = true
        Task {
            if await model.finish(updateTemplate: updateTemplate) { summary = model.makeSummary() }
            finishing = false
        }
    }

    private func header(_ model: SessionViewModel) -> some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").font(.headline).padding(10)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Minimize workout")
            VStack(alignment: .leading, spacing: 0) {
                Text(workout.name).font(.system(.title3, design: .rounded, weight: .bold)).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 6) {
                        Text(formatClock(model.clock.activeSeconds(at: context.date)))
                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        if model.isPaused {
                            Text("PAUSED").font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.amber, in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            Button { Task { model.isPaused ? await model.resume() : await model.pause() } } label: {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill").font(.headline).padding(10)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityLabel(model.isPaused ? "Resume workout" : "Pause workout")
            Menu {
                Button { showAddExercise = true } label: { Label("Add exercise", systemImage: "plus") }
                Button { showNotes = true } label: { Label("Workout notes", systemImage: "note.text") }
                Button { showPlates = true } label: { Label("Plate calculator", systemImage: "circle.grid.2x2") }
                Divider()
                Button(role: .destructive) { showDiscard = true } label: { Label("Discard workout", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.headline).padding(10).background(Theme.card, in: Circle())
            }
            .accessibilityLabel("More")
            Button { showFinish = true } label: {
                Text("Finish").font(.system(.subheadline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
            }
            .foregroundStyle(.white)
            .disabled(finishing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.text).font(.subheadline).foregroundStyle(.white)
            if let title = toast.actionTitle, let action = toast.action {
                Spacer(minLength: 4)
                Button(title) { action() }.font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}

/// Covers the workout while it is paused. Nothing underneath can be tapped.
struct PausedOverlay: View {
    let model: SessionViewModel
    var onFinish: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "pause.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.amber)
                Text("Workout paused").font(.system(.title2, design: .rounded, weight: .heavy))
                Text(formatClock(model.clock.activeSeconds(at: Date())))
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                Text("The clock and your rest timer are stopped.").font(.footnote).foregroundStyle(.secondary)
                Button { Task { await model.resume() } } label: { Label("Resume", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
                Button("Finish workout", action: onFinish).font(.headline).foregroundStyle(.white)
                Button("Discard workout", role: .destructive, action: onDiscard).font(.subheadline)
            }
            .padding(30)
        }
    }
}

struct WorkoutNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: SessionViewModel
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(16)
                .background(Theme.background)
                .navigationTitle("Workout notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await model.saveNotes(text); dismiss() } }
                    }
                }
                .onAppear { text = model.notes }
        }
        .presentationDetents([.medium])
    }
}

struct ExerciseCard: View {
    @Environment(AppState.self) private var app
    let model: SessionViewModel
    let pe: ProgramExercise
    var onSwap: (ProgramExercise) -> Void
    @State private var showWarmup = false
    @State private var showRemove = false
    @State private var editing: DraftSet?

    var body: some View {
        let rows = model.drafts[pe.id] ?? []
        let isCardio = pe.exercise.isCardio
        let hasSets = model.hasLoggedSets(pe)
        let order = model.exercises.map(\.id)
        let position = order.firstIndex(of: pe.id) ?? 0
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pe.exercise.name).font(.system(.headline, design: .rounded))
                        Text(isCardio ? pe.exercise.muscleLabel : "\(pe.targetSets) x \(pe.repRange)  -  RIR \(pe.targetRIR)  -  \(pe.exercise.muscleLabel)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(rows.filter { ($0.isLogged || $0.isPending) && !$0.isWarmup }.count)/\(max(pe.targetSets, 1))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    Menu {
                        if !isCardio { Button { showWarmup = true } label: { Label("Warm-up ramp", systemImage: "flame") } }
                        Button { onSwap(pe) } label: { Label("Swap exercise", systemImage: "arrow.triangle.2.circlepath") }
                            .disabled(hasSets)
                        Button { model.move(pe, up: true) } label: { Label("Move up", systemImage: "arrow.up") }
                            .disabled(position == 0)
                        Button { model.move(pe, up: false) } label: { Label("Move down", systemImage: "arrow.down") }
                            .disabled(position >= order.count - 1)
                        Divider()
                        Button(role: .destructive) { showRemove = true } label: { Label("Remove from workout", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").font(.footnote.weight(.bold)).frame(width: 30, height: 30)
                            .background(Theme.field, in: Circle())
                    }
                    .accessibilityLabel("Exercise options")
                }
                if let line = model.previousLine(for: pe) {
                    Text(line).font(.caption).foregroundStyle(Theme.mint)
                }
                if let notes = pe.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                }
                if !isCardio {
                    Label(pe.exercise.weightHint, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .labelStyle(HintLabelStyle())
                }

                HStack {
                    Text("SET").frame(width: 34, alignment: .leading)
                    Text(isCardio ? "" : "\(pe.exercise.weightColumnTitle) (\(app.units.label.uppercased()))").frame(maxWidth: .infinity)
                    Text(isCardio ? "MINUTES" : "REPS").frame(maxWidth: .infinity)
                    Spacer().frame(width: 44)
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    SetRow(model: model, pe: pe, index: index, row: row, onEdit: { editing = $0 })
                }

                Button {
                    model.addSet(to: pe)
                } label: {
                    Label("Add set", systemImage: "plus").font(.footnote.weight(.semibold))
                }
                .padding(.top, 2)
            }
        }
        .sheet(isPresented: $showWarmup) {
            WarmupSheet(exercise: pe.exercise,
                        workingWeight: Double((rows.first { !$0.isWarmup }?.weight ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0)
                .presentationDetents([.medium])
        }
        .sheet(item: $editing) { row in SetEditSheet(model: model, pe: pe, rowId: row.id) }
        .confirmationDialog("Remove \(pe.exercise.name)?", isPresented: $showRemove, titleVisibility: .visible) {
            if hasSets {
                Button("Delete its sets and remove", role: .destructive) { Task { await model.remove(pe, deleteSets: true) } }
            } else {
                Button("Remove from this workout", role: .destructive) { Task { await model.remove(pe, deleteSets: false) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(hasSets ? "This exercise has logged sets. They will be deleted." : "It only changes today's workout unless you save the change when you finish.")
        }
    }
}

struct SetRow: View {
    let model: SessionViewModel
    let pe: ProgramExercise
    let index: Int
    let row: DraftSet
    var onEdit: (DraftSet) -> Void

    var body: some View {
        let done = row.isLogged
        let isCardio = pe.exercise.isCardio
        let locked = done || row.isPending
        HStack(spacing: 8) {
            Button {
                if row.isPending { model.showToast("Waiting to sync. You can edit it once it is saved.") } else { onEdit(row) }
            } label: {
                Text(row.isWarmup ? "W" : row.isDropSet ? "D" : "\(index + 1)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .frame(width: 34, alignment: .leading)
                    .foregroundStyle(row.isWarmup || row.isDropSet ? Theme.amber : (done ? Theme.mint : .secondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set \(index + 1). Edit details")
            if isCardio {
                Spacer().frame(maxWidth: .infinity)
            } else {
                numberField("0", text: binding(\.weight), keyboard: .decimalPad, locked: locked)
            }
            numberField("0", text: binding(\.reps), keyboard: .numberPad, locked: locked)
            Button {
                Task { await model.toggle(pe, index: index) }
            } label: {
                ZStack {
                    if row.isSaving {
                        ProgressView().tint(.white)
                    } else if row.isPending {
                        Image(systemName: "icloud.and.arrow.up").font(.headline)
                    } else {
                        Image(systemName: row.isPR ? "trophy.fill" : "checkmark").font(.headline)
                    }
                }
                .frame(width: 44, height: 40)
                .foregroundStyle(done || row.isPending ? .white : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(done ? AnyShapeStyle(row.isPR ? Theme.amber : Theme.mint)
                              : row.isPending ? AnyShapeStyle(Theme.amber.opacity(0.7)) : AnyShapeStyle(Color.white.opacity(0.08)))
                )
            }
            .disabled(row.isSaving)
            .accessibilityLabel(done ? "Set logged. Tap to unlog" : "Log set")
        }
        .opacity(done ? 0.85 : 1)
        .contextMenu {
            Button { if !row.isPending { onEdit(row) } } label: { Label("Edit details", systemImage: "pencil") }
            Button { Task { await model.setFlag(pe, rowId: row.id, warmup: !row.isWarmup) } } label: {
                Label(row.isWarmup ? "Mark as working set" : "Mark as warm-up", systemImage: "flame")
            }
            Button { Task { await model.setFlag(pe, rowId: row.id, drop: !row.isDropSet) } } label: {
                Label(row.isDropSet ? "Not a drop set" : "Mark as drop set", systemImage: "arrow.down.right")
            }
            Button { model.duplicateRow(pe, rowId: row.id) } label: { Label("Duplicate set", systemImage: "plus.square.on.square") }
            Divider()
            Button(role: .destructive) { Task { await model.deleteRow(pe, rowId: row.id) } } label: { Label("Delete set", systemImage: "trash") }
        }
    }

    private func numberField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, locked: Bool) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded, weight: .semibold).monospacedDigit())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(locked)
    }

    private func binding(_ keyPath: WritableKeyPath<DraftSet, String>) -> Binding<String> {
        Binding(
            get: { model.drafts[pe.id]?.first(where: { $0.id == row.id })?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard let i = model.drafts[pe.id]?.firstIndex(where: { $0.id == row.id }) else { return }
                model.drafts[pe.id]?[i][keyPath: keyPath] = newValue
            })
    }
}

/// Edits one set: values, effort, warm-up and drop-set flags, and a note.
struct SetEditSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let model: SessionViewModel
    let pe: ProgramExercise
    let rowId: UUID

    @State private var weight = ""
    @State private var reps = ""
    @State private var rir: Int?
    @State private var warmup = false
    @State private var drop = false
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        let cardio = pe.exercise.isCardio
        NavigationStack {
            Form {
                Section {
                    if !cardio {
                        HStack {
                            Text("\(pe.exercise.weightColumnTitle.capitalized) (\(app.units.label))")
                            Spacer()
                            TextField("0", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                        }
                    }
                    HStack {
                        Text(cardio ? "Minutes" : "Reps")
                        Spacer()
                        TextField("0", text: $reps).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
                    }
                }
                if !cardio {
                    Section("Reps in reserve") {
                        Picker("RIR", selection: $rir) {
                            Text("-").tag(Int?.none)
                            ForEach(0...5, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section {
                        Toggle("Warm-up set", isOn: $warmup)
                        Toggle("Drop set", isOn: $drop)
                    } footer: {
                        Text("Warm-up sets do not count toward volume, records or goals.")
                    }
                }
                Section("Note") {
                    TextField("How did it feel?", text: $note, axis: .vertical).lineLimit(1...4)
                }
                Section {
                    Button("Delete set", role: .destructive) {
                        Task { await model.deleteRow(pe, rowId: rowId); dismiss() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(pe.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await model.saveEdit(pe, rowId: rowId, weight: weight, reps: reps, rir: rir,
                                                 warmup: warmup, drop: drop, note: note)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                guard !loaded, let r = model.drafts[pe.id]?.first(where: { $0.id == rowId }) else { return }
                weight = r.weight; reps = r.reps; rir = r.rir; warmup = r.isWarmup; drop = r.isDropSet; note = r.note
                loaded = true
            }
        }
        .presentationDetents([.large])
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: timer.progress, lineWidth: 5)
                Image(systemName: "timer").font(.footnote)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("Rest").font(.caption).foregroundStyle(.secondary)
                Text(clock(timer.remaining)).font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
            }
            Spacer()
            Button("-15") { timer.adjust(by: -15) }.buttonStyle(.bordered)
            Button("+15") { timer.adjust(by: 15) }.buttonStyle(.bordered)
            Button { timer.stop() } label: { Image(systemName: "forward.fill") }.buttonStyle(.borderedProminent)
        }
        .font(.subheadline.weight(.semibold))
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct ConfettiView: View {
    let trigger: Int
    @State private var burst = false
    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let dy: CGFloat
        let size: CGFloat
        let color: Color
        let spin: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.6)
                        .rotationEffect(.degrees(burst ? p.spin : 0))
                        .position(x: geo.size.width / 2 + (burst ? p.x : 0), y: burst ? geo.size.height * 0.3 + p.dy : geo.size.height * 0.3)
                        .opacity(burst ? 0 : 1)
                }
            }
        }
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        let colors: [Color] = [Theme.accent, Theme.accent2, Theme.mint, Theme.amber, .white]
        pieces = (0..<44).map { _ in
            Piece(x: .random(in: -170...170), dy: .random(in: 120...420), size: .random(in: 5...9),
                  color: colors.randomElement() ?? .white, spin: .random(in: -540...540))
        }
        burst = false
        withAnimation(.easeOut(duration: 1.6)) { burst = true }
    }
}

struct PlateCalculatorView: View {
    @Environment(AppState.self) private var app
    @State private var target = ""
    @State private var bar = ""

    private var plates: [Double] {
        app.units.isPounds ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    var body: some View {
        let barValue = Double(bar) ?? (app.units.isPounds ? 45 : 20)
        let targetValue = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
        let result = PlateMath.perSide(target: targetValue, bar: barValue, plates: plates)

        NavigationStack {
            Form {
                Section("Target weight (\(app.units.label))") {
                    TextField("e.g. 100", text: $target).keyboardType(.decimalPad)
                }
                Section("Bar (\(app.units.label))") {
                    TextField(app.units.isPounds ? "45" : "20", text: $bar).keyboardType(.decimalPad)
                }
                Section("Load each side") {
                    if targetValue <= barValue {
                        Text("Just the bar").foregroundStyle(.secondary)
                    } else {
                        ForEach(result.plates, id: \.0) { plate, count in
                            HStack {
                                Text(plate == plate.rounded() ? "\(Int(plate))" : String(plate))
                                    .font(.headline)
                                Spacer()
                                Text("x \(count)").foregroundStyle(.secondary)
                            }
                        }
                        if result.remainder > 0.01 {
                            Text("Closest loadable is \(String(format: "%.2f", targetValue - result.remainder)) \(app.units.label)")
                                .font(.footnote).foregroundStyle(Theme.amber)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Plate calculator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Icon at the top-left of a wrapping line of text.
struct HintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}
