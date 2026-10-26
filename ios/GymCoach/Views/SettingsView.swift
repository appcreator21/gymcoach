import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var showWeight = false
    @AppStorage(Prefs.keepAwake) private var keepAwake = true
    @AppStorage(Prefs.autoRest) private var autoRest = true
    @AppStorage(Prefs.healthSync) private var healthSync = false
    @AppStorage(Prefs.voiceCues) private var voiceCues = true
    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var healthMessage: String?

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
                    Picker("Unit system", selection: Binding(
                        get: { app.units.isPounds },
                        set: { v in
                            Haptics.select()
                            Task { await app.updateUnit(pounds: v) }
                        })) {
                        Text("Metric (kg, cm)").tag(false)
                        Text("Imperial (lb, in)").tag(true)
                    }
                    Button("Log bodyweight") { showWeight = true }
                }
                Section("Workouts") {
                    Toggle("Keep screen awake", isOn: $keepAwake)
                    Toggle("Voice cues in classes", isOn: $voiceCues)
                    Toggle("Start rest timer after each set", isOn: $autoRest)
                }
                Section {
                    Toggle("Haptics", isOn: $haptics)
                    if haptics {
                        Button("Try a haptic") { Haptics.success() }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("If you feel nothing, check Settings > Sounds & Haptics > System Haptics on your iPhone.")
                }
                Section("Apple Health") {
                    Toggle("Save workouts to Health", isOn: Binding(
                        get: { healthSync },
                        set: { on in
                            if on {
                                Task {
                                    let ok = await HealthKitManager.shared.requestAccess()
                                    healthSync = ok
                                    healthMessage = ok ? nil : "Health access is not available. Check Settings > Health."
                                }
                            } else { healthSync = false }
                        }))
                    Button("Import latest weight from Health") {
                        Task {
                            guard await HealthKitManager.shared.requestAccess(),
                                  let kg = await HealthKitManager.shared.latestBodyweightKg() else {
                                healthMessage = "No weight found in Health."
                                return
                            }
                            do {
                                try await app.logBodyweight(valueInDisplayUnit: app.units.display(kg))
                                healthMessage = "Imported \(app.units.format(kg))."
                            } catch { healthMessage = error.localizedDescription }
                        }
                    }
                    if let healthMessage { Text(healthMessage).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("Progress") {
                    NavigationLink("Achievements") { AchievementsView() }.hapticTap()
                    NavigationLink("Personal records") { RecordsView() }.hapticTap()
                    NavigationLink("Lift goals") { GoalsView() }.hapticTap()
                    NavigationLink("Measurements") { MeasurementsView() }.hapticTap()
                }
                if app.profile?.isAdmin == true {
                    Section("Admin") {
                        NavigationLink {
                            AdminView(embedded: true)
                        } label: {
                            Label("Admin portal", systemImage: "shield.lefthalf.filled")
                        }
                    }
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
            .onChange(of: keepAwake) { _, _ in Haptics.select() }
            .onChange(of: autoRest) { _, _ in Haptics.select() }
            .onChange(of: healthSync) { _, _ in Haptics.select() }
            .onChange(of: haptics) { _, on in if on { Haptics.success() } }
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
