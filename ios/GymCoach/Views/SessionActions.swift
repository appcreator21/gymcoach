import SwiftUI

/// Shared state for the history actions: edit, notes, delete.
struct SessionActionState {
    var confirmDelete = false
    var editNotes = false
    var error: String?
    var busy = false
}

/// The buttons shown in a context menu or toolbar menu for a finished workout.
struct SessionActionButtons: View {
    @Environment(AppState.self) private var app
    let summary: SessionSummary
    @Binding var state: SessionActionState

    var body: some View {
        Button {
            Task { await edit() }
        } label: { Label("Edit workout", systemImage: "pencil") }
            .disabled(summary.workoutId == nil)
        Button { state.editNotes = true } label: { Label("Edit notes", systemImage: "note.text") }
        Divider()
        Button(role: .destructive) { state.confirmDelete = true } label: { Label("Delete workout", systemImage: "trash") }
    }

    private func edit() async {
        do { try await app.reopen(summary) } catch { state.error = error.localizedDescription }
    }
}

private struct SessionActionDialogs: ViewModifier {
    @Environment(AppState.self) private var app
    let summary: SessionSummary
    @Binding var state: SessionActionState
    var onDeleted: (() -> Void)?
    @State private var notes = ""

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Delete this workout?", isPresented: $state.confirmDelete, titleVisibility: .visible) {
                Button("Delete workout", role: .destructive) {
                    Task {
                        do { try await app.deleteSession(summary); onDeleted?() }
                        catch { state.error = error.localizedDescription }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(summary.title) and its \(summary.setCount) set\(summary.setCount == 1 ? "" : "s") will be removed from your history and stats. This cannot be undone.")
            }
            .alert("Workout notes", isPresented: $state.editNotes) {
                TextField("Notes", text: $notes, axis: .vertical)
                Button("Save") {
                    Task {
                        do { try await app.updateNotes(summary, notes: notes) } catch { state.error = error.localizedDescription }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: state.editNotes) { _, on in
                if on { notes = summary.notes ?? app.details[summary.id]?.notes ?? "" }
            }
            .alert("Something went wrong", isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(state.error ?? "") }
    }
}

extension View {
    /// Long press menu for a workout row in a list.
    func sessionActions(_ summary: SessionSummary) -> some View {
        modifier(SessionRowActions(summary: summary))
    }

    func sessionActionDialogs(_ summary: SessionSummary, state: Binding<SessionActionState>, onDeleted: (() -> Void)? = nil) -> some View {
        modifier(SessionActionDialogs(summary: summary, state: state, onDeleted: onDeleted))
    }
}

private struct SessionRowActions: ViewModifier {
    let summary: SessionSummary
    @State private var state = SessionActionState()

    func body(content: Content) -> some View {
        content
            .contextMenu { SessionActionButtons(summary: summary, state: $state) }
            .sessionActionDialogs(summary, state: $state)
    }
}
