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
                            Circle().fill(Theme.gradient)
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
                Section("Server") {
                    LabeledContent("Address", value: app.serverURL)
                    Button("Refresh data") { Task { await app.refresh() } }
                }
                Section {
                    Button("Sign out", role: .destructive) { Task { await app.logout() } }
                }
                Section {
                    Text("GymCoach for iOS. Your data stays on your own server.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("You")
            .sheet(isPresented: $showWeight) { LogBodyweightSheet().presentationDetents([.height(280)]) }
        }
    }
}
