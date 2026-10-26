import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var showWeight = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.accent)
                            Text(String(app.profile?.firstName.prefix(1) ?? "G").uppercased())
                                .font(.system(.title2, design: .rounded, weight: .heavy))
                        }
                        .frame(width: 54, height: 54)
                        VStack(alignment: .leading) {
                            Text(app.profile?.displayName ?? app.profile?.firstName ?? "").font(.headline)
                            Text(app.profile?.email ?? "").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Preferences") {
                    Picker("Units", selection: Binding(
                        get: { app.units.isPounds },
                        set: { v in Task { await app.updateUnit(pounds: v) } })) {
                        Text("Kilograms").tag(false)
                        Text("Pounds").tag(true)
                    }
                    Button("Log bodyweight") { showWeight = true }
                }
                Section("Surba") {
                    NavigationLink("What Surba knows about you") { MemoryView() }
                }
                Section("Data") {
                    Button("Refresh data") { Task { await app.refresh() } }
                }
                Section {
                    Button("Sign out", role: .destructive) { Task { await app.logout() } }
                }
                Section {
                    Text("Surba Fit. Train with Surba.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("You")
            .sheet(isPresented: $showWeight) { LogBodyweightSheet().presentationDetents([.height(280)]) }
        }
    }
}

struct MemoryView: View {
    @Environment(AppState.self) private var app
    @State private var memory: String?

    var body: some View {
        ScrollView {
            if let memory {
                Text(memory.isEmpty ? "Surba has not learned anything about you yet." : memory)
                    .font(.system(.callout, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .textSelection(.enabled)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(Theme.background)
        .navigationTitle("Your memory file")
        .navigationBarTitleDisplayMode(.inline)
        .task { memory = await app.loadMemory() }
    }
}
