import SwiftUI

struct DraftSet: Identifiable {
    let id = UUID()
    var number: Int
    var weight: String
    var reps: String
    var serverId: String?
    var isPR = false
}

@Observable
@MainActor
final class SessionViewModel {
    let workout: Workout
    unowned let app: AppState
    let timer: RestTimer

    var sessionId: String?
    var startedAt = Date()
    var drafts: [String: [DraftSet]] = [:]
    var error: String?
    var prBanner: String?
    var confettiTick = 0
    var logged: [String: SetEntry] = [:]
    var prNames: [String] = []
    var isStarting = true
    var isBusy = false

    @ObservationIgnored private let api = APIClient.shared
    @ObservationIgnored private var sessionBest: [String: Double] = [:]

    init(workout: Workout, app: AppState, timer: RestTimer) {
        self.workout = workout
        self.app = app
        self.timer = timer
    }

    var exercises: [ProgramExercise] { (workout.exercises ?? []).sorted { $0.order < $1.order } }
    var completedSets: Int { drafts.values.flatMap { $0 }.filter { $0.serverId != nil }.count }

    func start() async {
        do {
            let created: StartedSession = try await api.send("POST", "/api/sessions", json: ["workoutId": workout.id])
            sessionId = created.id
            startedAt = created.startedAt
            let detail: SessionDetail = try await api.get("/api/sessions/\(created.id)")
            for s in detail.sets { logged[s.id] = s }
            buildDrafts(existing: detail.sets)
        } catch {
            self.error = error.localizedDescription
        }
        isStarting = false
    }

    private func buildDrafts(existing: [SetEntry]) {
        let units = app.units
        for pe in exercises {
            let done = existing.filter { $0.exerciseId == pe.exercise.id }.sorted { $0.setNumber < $1.setNumber }
            let previous = app.lastSets(for: pe.exercise.id, excluding: sessionId)
            let count = max(pe.targetSets, done.count)
            var rows: [DraftSet] = []
            for i in 0..<count {
                if i < done.count {
                    let s = done[i]
                    rows.append(DraftSet(
                        number: s.setNumber,
                        weight: pe.exercise.isCardio ? "" : units.format(s.weight, withUnit: false),
                        reps: pe.exercise.isCardio ? String((s.durationSec ?? 0) / 60) : String(s.reps),
                        serverId: s.id))
                } else if !previous.isEmpty {
                    let p = previous[min(i, previous.count - 1)]
                    rows.append(DraftSet(
                        number: i + 1,
                        weight: pe.exercise.isCardio ? "" : units.format(p.weight, withUnit: false),
                        reps: pe.exercise.isCardio ? String((p.durationSec ?? 1200) / 60) : String(p.reps)))
                } else {
                    rows.append(DraftSet(number: i + 1, weight: "", reps: pe.exercise.isCardio ? "20" : ""))
                }
            }
            drafts[pe.id] = rows
        }
    }

    func previousLine(for pe: ProgramExercise) -> String? {
        let prev = app.lastSets(for: pe.exercise.id, excluding: sessionId)
        guard !prev.isEmpty else { return nil }
        if pe.exercise.isCardio { return nil }
        return "Last: " + prev.prefix(4).map { "\(app.units.format($0.weight, withUnit: false)) x \($0.reps)" }.joined(separator: ", ")
    }

    func addSet(to pe: ProgramExercise) {
        var rows = drafts[pe.id] ?? []
        let last = rows.last
        rows.append(DraftSet(number: rows.count + 1, weight: last?.weight ?? "", reps: last?.reps ?? ""))
        drafts[pe.id] = rows
        Haptics.tap()
    }

    func toggle(_ pe: ProgramExercise, index: Int) async {
        guard let sessionId, var rows = drafts[pe.id], rows.indices.contains(index) else { return }
        var row = rows[index]
        isBusy = true
        defer { isBusy = false }

        if let serverId = row.serverId {
            do {
                _ = try await api.raw("DELETE", "/api/sets/\(serverId)")
                logged[serverId] = nil
                row.serverId = nil
                row.isPR = false
                rows[index] = row
                drafts[pe.id] = rows
                Haptics.tap()
            } catch { self.error = error.localizedDescription }
            return
        }

        let isCardio = pe.exercise.isCardio
        let weightValue = Double(row.weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let repsValue = Int(row.reps.trimmingCharacters(in: .whitespaces)), repsValue > 0 else {
            Haptics.warning()
            error = isCardio ? "Enter the minutes first." : "Enter the reps first."
            return
        }
        let kg = app.units.toKg(weightValue)
        var body: [String: Any] = [
            "exerciseId": pe.exercise.id,
            "setNumber": row.number,
            "weight": isCardio ? 0 : kg,
            "reps": isCardio ? 1 : repsValue,
        ]
        if isCardio { body["durationSec"] = repsValue * 60 }

        do {
            let created: SetEntry = try await api.send("POST", "/api/sessions/\(sessionId)/sets", json: body)
            row.serverId = created.id
            logged[created.id] = created
            if !isCardio { checkPR(pe, entry: created, row: &row) }
            rows[index] = row
            drafts[pe.id] = rows
            Haptics.thud()
            if Prefs.bool(Prefs.autoRest, default: true) { timer.start(seconds: pe.restSec) }
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }

    private func checkPR(_ pe: ProgramExercise, entry: SetEntry, row: inout DraftSet) {
        guard let e1 = entry.e1RM else { return }
        let prior = app.bestE1RM(for: pe.exercise.id, excluding: sessionId)
        let best = max(prior, sessionBest[pe.exercise.id] ?? 0)
        sessionBest[pe.exercise.id] = max(best, e1)
        if prior > 0 && e1 > best + 0.01 {
            row.isPR = true
            prBanner = "New PR on \(pe.exercise.name): \(app.units.format(entry.weight)) x \(entry.reps)"
            if !prNames.contains(prLine(pe, entry)) { prNames.append(prLine(pe, entry)) }
            confettiTick += 1
            Haptics.success()
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                prBanner = nil
            }
        }
    }

    func finish() async -> Bool {
        guard let sessionId else { return false }
        do {
            _ = try await api.raw("PUT", "/api/sessions/\(sessionId)", json: ["finish": true])
            timer.stop()
            if Prefs.bool(Prefs.healthSync, default: false) {
                await HealthKitManager.shared.saveWorkout(start: startedAt, end: Date())
            }
            await app.refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func prLine(_ pe: ProgramExercise, _ entry: SetEntry) -> String {
        "\(pe.exercise.name): \(app.units.format(entry.weight)) x \(entry.reps)"
    }

    func makeSummary() -> WorkoutSummary {
        let sets = Array(logged.values)
        let exerciseIds = Set(sets.map(\.exerciseId))
        return WorkoutSummary(
            title: workout.name,
            duration: Date().timeIntervalSince(startedAt),
            sets: sets.count,
            exercises: exerciseIds.count,
            volumeKg: sets.reduce(0) { $0 + $1.volume },
            prs: prNames)
    }

    func discard() async {
        timer.stop()
        if let sessionId { _ = try? await api.raw("DELETE", "/api/sessions/\(sessionId)") }
        await app.refresh()
    }
}

struct WorkoutSessionView: View {
    @Environment(AppState.self) private var app
    @Environment(RestTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    @State private var model: SessionViewModel?
    @State private var showFinish = false
    @State private var showPlates = false
    @State private var summary: WorkoutSummary?

    var body: some View {
        ZStack {
            AppBackground()
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let m = SessionViewModel(workout: workout, app: app, timer: timer)
            model = m
            timer.requestPermission()
            UIApplication.shared.isIdleTimerDisabled = Prefs.bool(Prefs.keepAwake, default: true)
            await m.start()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
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
                        ForEach(model.exercises) { pe in
                            ExerciseCard(model: model, pe: pe)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, timer.isRunning ? 130 : 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .overlay(alignment: .bottom) {
            if timer.isRunning { RestTimerBar().padding(.horizontal, 16).padding(.bottom, 10).transition(.move(edge: .bottom).combined(with: .opacity)) }
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
        .animation(.spring(response: 0.4), value: timer.isRunning)
        .animation(.spring(response: 0.4), value: model.prBanner)
        .alert("Something went wrong", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.error ?? "") }
        .confirmationDialog("Finish workout?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Finish and save") {
                Task { if await model.finish() { summary = model.makeSummary() } }
            }
            Button("Discard workout", role: .destructive) {
                Task { await model.discard(); dismiss() }
            }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("\(model.completedSets) sets logged")
        }
        .sheet(item: $summary, onDismiss: { dismiss() }) { WorkoutSummaryView(summary: $0) }
        .sheet(isPresented: $showPlates) { PlateCalculatorView().presentationDetents([.medium, .large]) }
    }

    private func header(_ model: SessionViewModel) -> some View {
        HStack {
            Button { Task { dismiss() } } label: {
                Image(systemName: "chevron.down").font(.headline).padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(workout.name).font(.system(.title3, design: .rounded, weight: .bold))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsed(from: model.startedAt, to: context.date))
                        .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { showPlates = true } label: {
                Image(systemName: "circle.grid.2x2.fill").padding(10).background(.ultraThinMaterial, in: Circle())
            }
            Button { showFinish = true } label: {
                Text("Finish").font(.system(.subheadline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func elapsed(from start: Date, to now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

struct ExerciseCard: View {
    @Environment(AppState.self) private var app
    let model: SessionViewModel
    let pe: ProgramExercise
    @State private var showWarmup = false

    var body: some View {
        let rows = model.drafts[pe.id] ?? []
        let isCardio = pe.exercise.isCardio
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pe.exercise.name).font(.system(.headline, design: .rounded))
                        Text(isCardio ? pe.exercise.muscleLabel : "\(pe.targetSets) x \(pe.repRange)  -  RIR \(pe.targetRIR)  -  \(pe.exercise.muscleLabel)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isCardio {
                        Button { showWarmup = true } label: {
                            Image(systemName: "flame").font(.footnote.weight(.semibold))
                                .padding(7).background(Theme.field, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(rows.filter { $0.serverId != nil }.count)/\(rows.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
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
                    SetRow(model: model, pe: pe, index: index, row: row)
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
                        workingWeight: Double((model.drafts[pe.id]?.first?.weight ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0)
                .presentationDetents([.medium])
        }
    }
}

struct SetRow: View {
    let model: SessionViewModel
    let pe: ProgramExercise
    let index: Int
    let row: DraftSet

    var body: some View {
        let done = row.serverId != nil
        let isCardio = pe.exercise.isCardio
        HStack(spacing: 8) {
            Text("\(row.number)").font(.subheadline.monospacedDigit().weight(.bold))
                .frame(width: 34, alignment: .leading)
                .foregroundStyle(done ? Theme.mint : .secondary)
            if isCardio {
                Spacer().frame(maxWidth: .infinity)
            } else {
                numberField("0", text: binding(\.weight), keyboard: .decimalPad)
            }
            numberField("0", text: binding(\.reps), keyboard: .numberPad)
            Button {
                Task { await model.toggle(pe, index: index) }
            } label: {
                Image(systemName: row.isPR ? "trophy.fill" : "checkmark")
                    .font(.headline)
                    .frame(width: 44, height: 40)
                    .foregroundStyle(done ? .white : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(done ? AnyShapeStyle(row.isPR ? Theme.amber : Theme.mint) : AnyShapeStyle(Color.white.opacity(0.08)))
                    )
            }
            .disabled(model.isBusy)
        }
        .opacity(done ? 0.85 : 1)
    }

    private func numberField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded, weight: .semibold).monospacedDigit())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(row.serverId != nil)
    }

    private func binding(_ keyPath: WritableKeyPath<DraftSet, String>) -> Binding<String> {
        Binding(
            get: { model.drafts[pe.id]?[safe: index]?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard model.drafts[pe.id]?.indices.contains(index) == true else { return }
                model.drafts[pe.id]?[index][keyPath: keyPath] = newValue
            })
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
