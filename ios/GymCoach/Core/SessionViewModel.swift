import SwiftUI
import UserNotifications

@Observable
@MainActor
final class SessionViewModel {
    let workout: Workout
    let existingSessionId: String?
    unowned let app: AppState
    let timer: RestTimer

    var sessionId: String?
    var clock = SessionClock(startedAt: Date(), finishedAt: nil, pausedAt: nil, pausedSec: 0)
    var drafts: [String: [DraftSet]] = [:]
    var ui = SessionUIState()
    var extras: [ProgramExercise] = []
    var catalog: [String: Exercise] = [:]
    var notes = ""
    var error: String?
    var startFailure: String?
    var toast: Toast?
    var prBanner: String?
    var confettiTick = 0
    var logged: [String: SetEntry] = [:]
    var prNames: [String] = []
    var isStarting = true
    var finalActiveSeconds: Int?

    @ObservationIgnored private let api = APIClient.shared
    @ObservationIgnored private var sessionBest: [String: Double] = [:]
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var unsentClockAction: String?
    private static let pauseReminderId = "surbafit.paused"

    init(workout: Workout, sessionId: String?, app: AppState, timer: RestTimer) {
        self.workout = workout
        self.existingSessionId = sessionId
        self.app = app
        self.timer = timer
    }

    deinit { retryTask?.cancel() }

    // MARK: Derived

    var isPaused: Bool { clock.isPaused }

    var exercises: [ProgramExercise] {
        let planned = (workout.exercises ?? []).sorted { $0.order < $1.order }.filter { !ui.hidden.contains($0.id) }
        let all = planned + extras
        guard !ui.order.isEmpty else { return all }
        var rank: [String: Int] = [:]
        for (i, id) in ui.order.enumerated() where rank[id] == nil { rank[id] = i }
        return all.enumerated()
            .sorted { (rank[$0.element.id] ?? 1000 + $0.offset) < (rank[$1.element.id] ?? 1000 + $1.offset) }
            .map(\.element)
    }

    private var allRows: [DraftSet] { drafts.values.flatMap { $0 } }
    var completedSets: Int { allRows.filter { $0.isLogged || $0.isPending }.count }
    var workingSets: Int { allRows.filter { ($0.isLogged || $0.isPending) && !$0.isWarmup }.count }
    var pendingCount: Int { allRows.filter(\.isPending).count }
    var plannedUnlogged: Int {
        exercises.reduce(0) { total, pe in
            let rows = drafts[pe.id] ?? []
            return total + max(0, pe.targetSets - rows.filter { ($0.isLogged || $0.isPending) && !$0.isWarmup }.count)
        }
    }
    var hasStructuralChanges: Bool { !ui.hidden.isEmpty || !extras.isEmpty }

    func hasLoggedSets(_ pe: ProgramExercise) -> Bool {
        (drafts[pe.id] ?? []).contains { $0.isLogged || $0.isPending }
    }

    // MARK: Start

    func start() async {
        do {
            let id: String
            if let existingSessionId {
                id = existingSessionId
            } else {
                let created: StartedSession = try await api.send("POST", "/api/sessions", json: ["workoutId": workout.id])
                id = created.id
            }
            sessionId = id
            let detail: SessionDetail = try await api.get("/api/sessions/\(id)")
            if detail.finishedAt != nil {
                startFailure = "This workout was already finished."
                isStarting = false
                return
            }
            clock = detail.clock
            notes = detail.notes ?? ""
            await loadCatalog()
            ui = SessionUIStore.load(id)
            for s in detail.sets { logged[s.id] = s }
            restoreExtras(detail.sets)
            buildDrafts(existing: detail.sets)
            mergePending()
            if clock.isPaused { timer.stop() }
            if pendingCount > 0 { startRetryLoop() }
            await flushPending()
        } catch {
            startFailure = error.localizedDescription
        }
        isStarting = false
    }

    private func loadCatalog() async {
        let list: [Exercise] = (try? await api.get("/api/exercises")) ?? []
        catalog = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func lookup(_ exerciseId: String) -> Exercise? { catalog[exerciseId] ?? app.knownExercises[exerciseId] }

    private func makeAdHoc(_ ex: Exercise) -> ProgramExercise {
        ProgramExercise(id: "adhoc-\(ex.id)", order: 1000 + extras.count, targetSets: 3, targetRepsMin: 8,
                        targetRepsMax: 12, targetRIR: 2, restSec: ex.defaultRestSec, notes: nil, exercise: ex)
    }

    /// Exercises added on the fly come back after leaving the screen: from the
    /// saved UI state and from any logged set whose exercise is not in the workout.
    private func restoreExtras(_ sets: [SetEntry]) {
        let plannedIds = Set((workout.exercises ?? []).map(\.exercise.id))
        var wanted: [String] = []
        for id in ui.extraExerciseIds + sets.map(\.exerciseId) where !plannedIds.contains(id) && !wanted.contains(id) {
            wanted.append(id)
        }
        extras = wanted.compactMap { lookup($0) }.map(makeAdHoc)
        ui.extraExerciseIds = extras.map(\.exercise.id)
        // A planned exercise with logged sets can never be hidden.
        let withSets = Set(sets.map(\.exerciseId))
        ui.hidden.removeAll { hiddenId in
            (workout.exercises ?? []).first { $0.id == hiddenId }.map { withSets.contains($0.exercise.id) } ?? false
        }
    }

    private func persistUI() {
        if let sessionId { SessionUIStore.save(sessionId, ui) }
    }

    private func row(from s: SetEntry, cardio: Bool) -> DraftSet {
        DraftSet(
            number: s.setNumber,
            weight: cardio ? "" : app.units.format(s.weight, withUnit: false),
            reps: cardio ? String((s.durationSec ?? 0) / 60) : String(s.reps),
            serverId: s.id,
            isWarmup: s.isWarmup,
            isDropSet: s.isDropSet ?? false,
            rir: s.rir,
            note: s.notes ?? "")
    }

    private func buildDrafts(existing: [SetEntry]) {
        for pe in exercises { drafts[pe.id] = rows(for: pe, existing: existing) }
    }

    private func rows(for pe: ProgramExercise, existing: [SetEntry]) -> [DraftSet] {
        let cardio = pe.exercise.isCardio
        let done = existing.filter { $0.exerciseId == pe.exercise.id }.sorted { $0.setNumber < $1.setNumber }
        let warmups = done.filter(\.isWarmup).count
        let previous = app.lastSets(for: pe.exercise.id, excluding: sessionId)
        let count = max(pe.targetSets + warmups, done.count)
        var out: [DraftSet] = []
        for i in 0..<count {
            if i < done.count {
                out.append(row(from: done[i], cardio: cardio))
            } else if !previous.isEmpty {
                let p = previous[min(max(0, i - warmups), previous.count - 1)]
                out.append(DraftSet(
                    number: i + 1,
                    weight: cardio ? "" : app.units.format(p.weight, withUnit: false),
                    reps: cardio ? String((p.durationSec ?? 1200) / 60) : String(p.reps)))
            } else {
                out.append(DraftSet(number: i + 1, weight: "", reps: cardio ? "20" : ""))
            }
        }
        return out
    }

    private func mergePending() {
        guard let sessionId else { return }
        for p in PendingSetStore.forSession(sessionId) {
            guard let pe = exercises.first(where: { $0.exercise.id == p.exerciseId }) else { continue }
            let cardio = pe.exercise.isCardio
            var rows = drafts[pe.id] ?? []
            var pending = DraftSet(
                number: p.setNumber,
                weight: cardio ? "" : app.units.format(p.weightKg, withUnit: false),
                reps: cardio ? String((p.durationSec ?? 0) / 60) : String(p.reps),
                isWarmup: p.isWarmup, isDropSet: p.isDropSet, rir: p.rir, note: p.notes ?? "")
            pending.pendingKey = p.key
            if let i = rows.firstIndex(where: { $0.number == p.setNumber && !$0.isLogged && !$0.isPending }) {
                rows[i] = pending
            } else {
                rows.append(pending)
            }
            drafts[pe.id] = rows
        }
    }

    func previousLine(for pe: ProgramExercise) -> String? {
        let prev = app.lastSets(for: pe.exercise.id, excluding: sessionId)
        guard !prev.isEmpty, !pe.exercise.isCardio else { return nil }
        return "Last: " + prev.prefix(4).map { "\(app.units.format($0.weight, withUnit: false)) x \($0.reps)" }.joined(separator: ", ")
    }

    // MARK: Rows

    private func mutate(_ peId: String, _ rowId: UUID, _ change: (inout DraftSet) -> Void) {
        guard var rows = drafts[peId], let i = rows.firstIndex(where: { $0.id == rowId }) else { return }
        change(&rows[i])
        drafts[peId] = rows
    }

    func addSet(to pe: ProgramExercise) {
        var rows = drafts[pe.id] ?? []
        let last = rows.last
        rows.append(DraftSet(number: (rows.map(\.number).max() ?? 0) + 1, weight: last?.weight ?? "", reps: last?.reps ?? ""))
        drafts[pe.id] = rows
        Haptics.tap()
    }

    func duplicateRow(_ pe: ProgramExercise, rowId: UUID) {
        guard var rows = drafts[pe.id], let i = rows.firstIndex(where: { $0.id == rowId }) else { return }
        let src = rows[i]
        var copy = DraftSet(number: (rows.map(\.number).max() ?? 0) + 1, weight: src.weight, reps: src.reps)
        copy.isWarmup = src.isWarmup
        copy.isDropSet = src.isDropSet
        copy.rir = src.rir
        rows.insert(copy, at: i + 1)
        drafts[pe.id] = rows
        Haptics.tap()
    }

    func setFlag(_ pe: ProgramExercise, rowId: UUID, warmup: Bool? = nil, drop: Bool? = nil) async {
        guard let r = drafts[pe.id]?.first(where: { $0.id == rowId }) else { return }
        if r.isLogged {
            await saveEdit(pe, rowId: rowId, weight: r.weight, reps: r.reps, rir: r.rir,
                           warmup: warmup ?? r.isWarmup, drop: drop ?? r.isDropSet, note: r.note)
        } else {
            mutate(pe.id, rowId) {
                if let warmup { $0.isWarmup = warmup }
                if let drop { $0.isDropSet = drop }
            }
            Haptics.select()
        }
    }

    // MARK: Logging

    private func uniqueNumber(_ row: DraftSet, in rows: [DraftSet]) -> Int {
        var taken = Set(rows.filter { $0.isLogged || $0.isPending }.map(\.number))
        taken.remove(row.number)
        var n = row.number
        while taken.contains(n) { n += 1 }
        return n
    }

    /// Validates a row and turns it into the request body. Nil (with a message) when invalid.
    private func makePending(_ pe: ProgramExercise, row: DraftSet, rows: [DraftSet]) -> PendingSet? {
        guard let sessionId else { return nil }
        let cardio = pe.exercise.isCardio
        guard let repsValue = Int(row.reps.trimmingCharacters(in: .whitespaces)), repsValue > 0 else {
            warn(cardio ? "Enter the minutes first." : "Enter the reps first.")
            return nil
        }
        let weightValue = Double(row.weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let kg = app.units.toKg(weightValue)
        if !cardio {
            guard repsValue <= 100 else { warn("Reps must be 100 or fewer."); return nil }
            guard weightValue >= 0, kg <= 500 else { warn("Weight must be between 0 and 500 kg."); return nil }
        } else if repsValue > 1440 {
            warn("That is more than a day of cardio.")
            return nil
        }
        return PendingSet(
            key: UUID().uuidString, sessionId: sessionId, exerciseId: pe.exercise.id,
            setNumber: uniqueNumber(row, in: rows),
            weightKg: cardio ? 0 : kg, reps: cardio ? 1 : repsValue,
            durationSec: cardio ? repsValue * 60 : nil,
            rir: row.rir, isWarmup: row.isWarmup, isDropSet: row.isDropSet,
            notes: row.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : row.note)
    }

    func toggle(_ pe: ProgramExercise, index: Int) async {
        guard !isPaused else { warn("Resume your workout to log sets."); return }
        guard let rows = drafts[pe.id], rows.indices.contains(index) else { return }
        let row = rows[index]
        guard !row.isSaving else { return }

        if let serverId = row.serverId { await unlog(pe, rowId: row.id, serverId: serverId); return }
        if let key = row.pendingKey {
            PendingSetStore.remove(key)
            mutate(pe.id, row.id) { $0.pendingKey = nil }
            Haptics.tap()
            return
        }
        guard let pending = makePending(pe, row: row, rows: rows) else { return }

        mutate(pe.id, row.id) { $0.isSaving = true }
        do {
            let created: SetEntry = try await api.send("POST", "/api/sessions/\(pending.sessionId)/sets", json: pending.body)
            applyCreated(created, pe: pe, rowId: row.id)
        } catch let e as APIError {
            if case .network = e {
                queueOffline(pending, pe: pe, rowId: row.id)
            } else {
                mutate(pe.id, row.id) { $0.isSaving = false }
                warn(e.localizedDescription)
            }
        } catch {
            mutate(pe.id, row.id) { $0.isSaving = false }
            warn(error.localizedDescription)
        }
    }

    private func applyCreated(_ created: SetEntry, pe: ProgramExercise, rowId: UUID) {
        logged[created.id] = created
        var isPR = false
        if !created.isWarmup, !pe.exercise.isCardio { isPR = checkPR(pe, entry: created) }
        mutate(pe.id, rowId) {
            $0.serverId = created.id
            $0.isSaving = false
            $0.pendingKey = nil
            $0.isPR = isPR
            $0.number = created.setNumber
        }
        created.isWarmup ? Haptics.tap() : Haptics.thud()
        if Prefs.bool(Prefs.autoRest, default: true), !isPaused {
            timer.start(seconds: created.isWarmup ? min(pe.restSec, 60) : pe.restSec)
        }
    }

    private func unlog(_ pe: ProgramExercise, rowId: UUID, serverId: String) async {
        mutate(pe.id, rowId) { $0.isSaving = true }
        do {
            _ = try await api.raw("DELETE", "/api/sets/\(serverId)")
            logged[serverId] = nil
            mutate(pe.id, rowId) { $0.serverId = nil; $0.isPR = false; $0.isSaving = false }
            Haptics.tap()
        } catch {
            mutate(pe.id, rowId) { $0.isSaving = false }
            warn("Could not remove the set. Check your connection and try again.")
        }
    }

    /// Removes the row itself. A logged set is deleted on the server first, and
    /// can be brought back with Undo.
    func deleteRow(_ pe: ProgramExercise, rowId: UUID) async {
        guard let rows = drafts[pe.id], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        let row = rows[index]
        if let key = row.pendingKey { PendingSetStore.remove(key) }
        if let serverId = row.serverId {
            do {
                _ = try await api.raw("DELETE", "/api/sets/\(serverId)")
            } catch {
                warn("Could not delete the set. Check your connection and try again.")
                return
            }
            logged[serverId] = nil
        }
        drafts[pe.id]?.removeAll { $0.id == rowId }
        Haptics.tap()
        if row.isLogged {
            var restored = row
            restored.serverId = nil
            showToast("Set deleted", actionTitle: "Undo") { [weak self] in
                Task { await self?.restoreRow(pe, row: restored, at: index) }
            }
        }
    }

    private func restoreRow(_ pe: ProgramExercise, row: DraftSet, at index: Int) async {
        var rows = drafts[pe.id] ?? []
        let target = DraftSet(number: row.number, weight: row.weight, reps: row.reps, isWarmup: row.isWarmup,
                              isDropSet: row.isDropSet, rir: row.rir, note: row.note)
        rows.insert(target, at: min(index, rows.count))
        drafts[pe.id] = rows
        await toggle(pe, index: min(index, rows.count - 1))
    }

    // MARK: Editing a logged set

    func saveEdit(_ pe: ProgramExercise, rowId: UUID, weight: String, reps: String, rir: Int?,
                  warmup: Bool, drop: Bool, note: String) async {
        guard let r = drafts[pe.id]?.first(where: { $0.id == rowId }), let serverId = r.serverId else {
            mutate(pe.id, rowId) {
                $0.weight = weight; $0.reps = reps; $0.rir = rir; $0.isWarmup = warmup; $0.isDropSet = drop; $0.note = note
            }
            return
        }
        let cardio = pe.exercise.isCardio
        guard let repsValue = Int(reps.trimmingCharacters(in: .whitespaces)), repsValue > 0 else {
            warn(cardio ? "Enter the minutes." : "Enter the reps."); return
        }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var body: [String: Any] = ["notes": cleanNote.isEmpty ? NSNull() : cleanNote]
        if cardio {
            body["durationSec"] = repsValue * 60
        } else {
            let w = Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
            let kg = app.units.toKg(w)
            guard repsValue <= 100 else { warn("Reps must be 100 or fewer."); return }
            guard w >= 0, kg <= 500 else { warn("Weight must be between 0 and 500 kg."); return }
            body["weight"] = kg
            body["reps"] = repsValue
            body["rir"] = rir.map { $0 as Any } ?? NSNull()
            body["isWarmup"] = warmup
            body["isDropSet"] = drop
        }
        mutate(pe.id, rowId) { $0.isSaving = true }
        do {
            let updated: SetEntry = try await api.send("PATCH", "/api/sets/\(serverId)", json: body)
            logged[serverId] = updated
            mutate(pe.id, rowId) {
                $0.weight = weight; $0.reps = reps; $0.rir = rir; $0.isWarmup = updated.isWarmup
                $0.isDropSet = updated.isDropSet ?? false; $0.note = cleanNote; $0.isSaving = false
            }
            Haptics.success()
        } catch {
            mutate(pe.id, rowId) { $0.isSaving = false }
            warn(error.localizedDescription)
        }
    }

    // MARK: Offline queue

    private func queueOffline(_ p: PendingSet, pe: ProgramExercise, rowId: UUID) {
        PendingSetStore.add(p)
        mutate(pe.id, rowId) { $0.isSaving = false; $0.pendingKey = p.key; $0.number = p.setNumber }
        Haptics.warning()
        showToast("No connection. The set is saved on this phone and will sync.")
        startRetryLoop()
    }

    private func startRetryLoop() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self else { return }
                await self.flushPending()
                if self.pendingCount == 0 && self.unsentClockAction == nil {
                    self.retryTask = nil
                    return
                }
            }
        }
    }

    /// Sends every set (and a pause or resume) that is still waiting.
    func flushPending() async {
        guard let sessionId else { return }
        if let action = unsentClockAction {
            do {
                _ = try await api.raw("PUT", "/api/sessions/\(sessionId)", json: [action: true])
                unsentClockAction = nil
            } catch {}
        }
        for p in PendingSetStore.forSession(sessionId) {
            do {
                let created: SetEntry = try await api.send("POST", "/api/sessions/\(sessionId)/sets", json: p.body)
                PendingSetStore.remove(p.key)
                if let (peId, rowId) = locate(pendingKey: p.key),
                   let pe = exercises.first(where: { $0.id == peId }) {
                    applySynced(created, pe: pe, rowId: rowId)
                }
            } catch let e as APIError {
                if case .network = e { return }
                // The server refused it for good (for example the workout was
                // finished elsewhere): drop it so it cannot loop forever.
                PendingSetStore.remove(p.key)
                if let (peId, rowId) = locate(pendingKey: p.key) {
                    mutate(peId, rowId) { $0.pendingKey = nil }
                }
                warn("A set could not be saved: \(e.localizedDescription)")
            } catch { return }
        }
    }

    private func applySynced(_ created: SetEntry, pe: ProgramExercise, rowId: UUID) {
        logged[created.id] = created
        mutate(pe.id, rowId) { $0.serverId = created.id; $0.pendingKey = nil; $0.number = created.setNumber }
    }

    private func locate(pendingKey: String) -> (String, UUID)? {
        for (peId, rows) in drafts {
            if let r = rows.first(where: { $0.pendingKey == pendingKey }) { return (peId, r.id) }
        }
        return nil
    }

    // MARK: PR

    private func checkPR(_ pe: ProgramExercise, entry: SetEntry) -> Bool {
        guard let e1 = entry.e1RM else { return false }
        let prior = app.bestE1RM(for: pe.exercise.id, excluding: sessionId)
        let best = max(prior, sessionBest[pe.exercise.id] ?? 0)
        sessionBest[pe.exercise.id] = max(best, e1)
        guard prior > 0, e1 > best + 0.01 else { return false }
        let line = "\(pe.exercise.name): \(app.units.format(entry.weight)) x \(entry.reps)"
        prBanner = "New PR on \(line)"
        if !prNames.contains(line) { prNames.append(line) }
        confettiTick += 1
        Haptics.success()
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            prBanner = nil
        }
        return true
    }

    // MARK: Exercises on the fly

    private func currentOrderIds() -> [String] { exercises.map(\.id) }

    func addExercise(_ ex: Exercise) {
        guard !exercises.contains(where: { $0.exercise.id == ex.id }) else { warn("\(ex.name) is already in this workout."); return }
        // A planned exercise that was skipped comes back instead of a copy.
        if let planned = (workout.exercises ?? []).first(where: { $0.exercise.id == ex.id }), ui.hidden.contains(planned.id) {
            ui.hidden.removeAll { $0 == planned.id }
            drafts[planned.id] = rows(for: planned, existing: [])
            persistUI()
            Haptics.success()
            return
        }
        let pe = makeAdHoc(ex)
        extras.append(pe)
        ui.extraExerciseIds.append(ex.id)
        ui.order = currentOrderIds()
        drafts[pe.id] = rows(for: pe, existing: [])
        persistUI()
        Haptics.success()
    }

    func swap(_ pe: ProgramExercise, with ex: Exercise) {
        guard !hasLoggedSets(pe) else { warn("Delete this exercise's logged sets before swapping it."); return }
        guard !exercises.contains(where: { $0.exercise.id == ex.id }) else { warn("\(ex.name) is already in this workout."); return }
        var order = currentOrderIds()
        let position = order.firstIndex(of: pe.id) ?? order.count
        removeFromSession(pe)
        let replacement = makeAdHoc(ex)
        extras.append(replacement)
        ui.extraExerciseIds.append(ex.id)
        order.removeAll { $0 == pe.id }
        order.insert(replacement.id, at: min(position, order.count))
        ui.order = order
        drafts[replacement.id] = rows(for: replacement, existing: [])
        persistUI()
        Haptics.success()
    }

    private func removeFromSession(_ pe: ProgramExercise) {
        if pe.id.hasPrefix("adhoc-") {
            extras.removeAll { $0.id == pe.id }
            ui.extraExerciseIds.removeAll { $0 == pe.exercise.id }
        } else if !ui.hidden.contains(pe.id) {
            ui.hidden.append(pe.id)
        }
        ui.order.removeAll { $0 == pe.id }
        drafts[pe.id] = nil
    }

    /// Removes an exercise from this workout. Logged sets must be deleted
    /// first, which is why `deleteSets` has to be passed explicitly.
    func remove(_ pe: ProgramExercise, deleteSets: Bool) async {
        if hasLoggedSets(pe) {
            guard deleteSets else { return }
            for r in drafts[pe.id] ?? [] {
                if let key = r.pendingKey { PendingSetStore.remove(key) }
                if let serverId = r.serverId {
                    do {
                        _ = try await api.raw("DELETE", "/api/sets/\(serverId)")
                        logged[serverId] = nil
                    } catch {
                        warn("Could not delete all the sets. Check your connection and try again.")
                        return
                    }
                }
            }
        }
        removeFromSession(pe)
        persistUI()
        Haptics.tap()
    }

    func move(_ pe: ProgramExercise, up: Bool) {
        var order = currentOrderIds()
        guard let i = order.firstIndex(of: pe.id) else { return }
        let j = up ? i - 1 : i + 1
        guard order.indices.contains(j) else { return }
        order.swapAt(i, j)
        ui.order = order
        persistUI()
        Haptics.select()
    }

    // MARK: Pause, resume

    func pause() async {
        guard !isPaused, let sessionId else { return }
        let before = clock
        clock = clock.paused(at: Date())
        timer.pause()
        schedulePauseReminder()
        Haptics.rigid()
        await sendClock("pause", sessionId: sessionId, rollback: before)
    }

    func resume() async {
        guard isPaused, let sessionId else { return }
        let before = clock
        clock = clock.resumed(at: Date())
        timer.resume()
        cancelPauseReminder()
        Haptics.rigid()
        await sendClock("resume", sessionId: sessionId, rollback: before)
    }

    private func sendClock(_ action: String, sessionId: String, rollback: SessionClock) async {
        do {
            _ = try await api.raw("PUT", "/api/sessions/\(sessionId)", json: [action: true])
            unsentClockAction = nil
        } catch let e as APIError {
            if case .network = e {
                // Keep the local state and tell the server later.
                unsentClockAction = action
                startRetryLoop()
            } else {
                clock = rollback
                error = e.localizedDescription
            }
        } catch {
            clock = rollback
            self.error = error.localizedDescription
        }
    }

    /// Picks up a pause, resume or finish made on another device.
    func syncFromServer() async {
        guard let sessionId, unsentClockAction == nil else { return }
        guard let detail: SessionDetail = try? await api.get("/api/sessions/\(sessionId)") else { return }
        if detail.finishedAt != nil {
            startFailure = "This workout was finished on another device."
            return
        }
        if detail.clock != clock {
            let wasPaused = clock.isPaused
            clock = detail.clock
            if clock.isPaused && !wasPaused { timer.pause() } else if !clock.isPaused && wasPaused { timer.resume() }
        }
        if detail.notes != nil, notes.isEmpty { notes = detail.notes ?? "" }
    }

    private func schedulePauseReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Your workout is paused"
        content.body = "Tap to resume or finish it."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: SessionViewModel.pauseReminderId, content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)))
    }

    private func cancelPauseReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [SessionViewModel.pauseReminderId])
    }

    // MARK: Notes

    func saveNotes(_ text: String) async {
        guard let sessionId else { return }
        do {
            _ = try await api.raw("PUT", "/api/sessions/\(sessionId)", json: ["notes": text])
            notes = text.trimmingCharacters(in: .whitespacesAndNewlines)
            Haptics.success()
        } catch { warn(error.localizedDescription) }
    }

    // MARK: Finish, discard

    func finish(updateTemplate: Bool) async -> Bool {
        guard let sessionId else { return false }
        await flushPending()
        guard pendingCount == 0 else {
            warn("\(pendingCount) set\(pendingCount == 1 ? " is" : "s are") not synced yet. Connect to the internet and try again.")
            return false
        }
        do {
            if updateTemplate { await saveStructureToWorkout() }
            _ = try await api.raw("PUT", "/api/sessions/\(sessionId)", json: ["finish": true])
            let now = Date()
            var end = clock.isPaused ? clock.resumed(at: now) : clock
            end.finishedAt = now
            finalActiveSeconds = end.activeSeconds(at: now)
            clock = end
            timer.stop()
            cancelPauseReminder()
            retryTask?.cancel()
            SessionUIStore.clear(sessionId)
            if Prefs.bool(Prefs.healthSync, default: false) {
                let active = TimeInterval(finalActiveSeconds ?? 0)
                await HealthKitManager.shared.saveWorkout(start: now.addingTimeInterval(-active), end: now)
            }
            await app.refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func discard() async {
        timer.stop()
        cancelPauseReminder()
        retryTask?.cancel()
        if let sessionId {
            _ = try? await api.raw("DELETE", "/api/sessions/\(sessionId)")
            PendingSetStore.removeSession(sessionId)
            SessionUIStore.clear(sessionId)
        }
        await app.refresh()
    }

    /// Writes this workout's on the fly changes back to the saved workout.
    private func saveStructureToWorkout() async {
        for peId in ui.hidden where (workout.exercises ?? []).contains(where: { $0.id == peId }) {
            _ = try? await api.raw("DELETE", "/api/program-exercises/\(peId)")
        }
        for pe in extras {
            let working = (drafts[pe.id] ?? []).filter { ($0.isLogged || $0.isPending) && !$0.isWarmup }.count
            let body: [String: Any] = [
                "exerciseId": pe.exercise.id,
                "targetSets": min(20, max(1, working > 0 ? working : pe.targetSets)),
                "targetRepsMin": pe.targetRepsMin, "targetRepsMax": pe.targetRepsMax,
                "targetRIR": pe.targetRIR, "restSec": min(600, max(15, pe.restSec)),
            ]
            _ = try? await api.raw("POST", "/api/workouts/\(workout.id)/program-exercises", json: body)
        }
    }

    func makeSummary() -> WorkoutSummary {
        let working = logged.values.filter { !$0.isWarmup }
        return WorkoutSummary(
            title: workout.name,
            duration: TimeInterval(finalActiveSeconds ?? clock.activeSeconds(at: Date())),
            sets: working.count,
            exercises: Set(working.map(\.exerciseId)).count,
            volumeKg: working.reduce(0) { $0 + $1.volume },
            prs: prNames)
    }

    // MARK: Messages

    func warn(_ text: String) {
        Haptics.warning()
        showToast(text)
    }

    func showToast(_ text: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        toastTask?.cancel()
        toast = Toast(text: text, actionTitle: actionTitle, action: action)
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: actionTitle == nil ? 3_500_000_000 : 6_000_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }
}
