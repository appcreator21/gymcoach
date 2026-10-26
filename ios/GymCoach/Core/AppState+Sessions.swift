import Foundation

/// What the full screen workout cover is opened with. `sessionId` attaches to
/// an existing session instead of starting one.
struct SessionLaunch: Identifiable {
    let id = UUID()
    let workout: Workout
    var sessionId: String? = nil
}

/// The user tried to start a workout while a different one is still open.
struct StartConflict: Identifiable {
    let id = UUID()
    let open: SessionSummary
    let wanted: Workout
}

extension AppState {
    /// Unfinished sessions, newest first.
    var openSessions: [SessionSummary] {
        sessions.filter(\.isOpen).sorted { $0.startedAt > $1.startedAt }
    }

    /// The workout to show in the "in progress" bar.
    var activeSession: SessionSummary? { openSessions.first }

    /// A light refresh of just the session list (open workouts, their clocks).
    func reloadSessions() async {
        if let fresh: [SessionSummary] = try? await APIClient.shared.get("/api/sessions") { sessions = fresh }
    }

    /// Opened long ago and never used: almost certainly forgotten.
    func isAbandoned(_ s: SessionSummary) -> Bool {
        s.isOpen && s.setCount == 0 && Date().timeIntervalSince(s.startedAt) > 12 * 3600
    }

    /// The one entry point for starting a workout. Resumes the open session of
    /// the same workout, asks what to do about a different open one, and
    /// quietly cleans up a forgotten empty one.
    func requestStart(_ workout: Workout) {
        Haptics.thud()
        if let other = openSessions.first(where: { $0.workoutId != workout.id }) {
            if isAbandoned(other) {
                Task {
                    await discardSession(other)
                    sessionLaunch = SessionLaunch(workout: workout)
                }
            } else {
                startConflict = StartConflict(open: other, wanted: workout)
            }
            return
        }
        sessionLaunch = SessionLaunch(workout: workout, sessionId: inProgressSession(for: workout.id)?.id)
    }

    enum ConflictChoice { case resumeOpen, finishOpenThenStart, discardOpenThenStart }

    func resolve(_ conflict: StartConflict, _ choice: ConflictChoice) {
        switch choice {
        case .resumeOpen:
            Task { await resume(conflict.open) }
        case .finishOpenThenStart:
            Task {
                _ = try? await APIClient.shared.raw("PUT", "/api/sessions/\(conflict.open.id)", json: ["finish": true])
                await refresh()
                sessionLaunch = SessionLaunch(workout: conflict.wanted)
            }
        case .discardOpenThenStart:
            Task {
                await discardSession(conflict.open)
                sessionLaunch = SessionLaunch(workout: conflict.wanted)
            }
        }
    }

    /// Reopens the full screen workout for an open session.
    func resume(_ s: SessionSummary) async {
        do {
            let detail: SessionDetail = try await APIClient.shared.get("/api/sessions/\(s.id)")
            if let workout = detail.workout {
                sessionLaunch = SessionLaunch(workout: workout, sessionId: s.id)
            } else {
                // The program workout it came from was deleted: it cannot be shown.
                orphanSession = s
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func discardSession(_ s: SessionSummary) async {
        _ = try? await APIClient.shared.raw("DELETE", "/api/sessions/\(s.id)")
        details[s.id] = nil
        sessions.removeAll { $0.id == s.id }
        await refresh()
    }

    func finishSession(_ s: SessionSummary) async {
        _ = try? await APIClient.shared.raw("PUT", "/api/sessions/\(s.id)", json: ["finish": true])
        await refresh()
    }

    /// Deletes a finished workout from history. Throws so the caller can show why.
    func deleteSession(_ s: SessionSummary) async throws {
        _ = try await APIClient.shared.raw("DELETE", "/api/sessions/\(s.id)")
        details[s.id] = nil
        sessions.removeAll { $0.id == s.id }
        Haptics.success()
        await refresh()
    }

    /// Reopens a finished workout so its sets can be edited, then opens it.
    func reopen(_ s: SessionSummary) async throws {
        _ = try await APIClient.shared.raw("PUT", "/api/sessions/\(s.id)", json: ["reopen": true])
        details[s.id] = nil
        await refresh()
        guard let updated = sessions.first(where: { $0.id == s.id }) else { return }
        await resume(updated)
    }

    func updateNotes(_ s: SessionSummary, notes: String) async throws {
        _ = try await APIClient.shared.raw("PUT", "/api/sessions/\(s.id)", json: ["notes": notes])
        await refresh()
    }
}
