import SwiftUI

struct AdminView: View {
    @State private var overview: AdminOverview?
    @State private var error: String?
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button { showBuilder = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "wand.and.stars").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create a workout with Surba").font(.system(.headline, design: .rounded))
                                Text("Describe a goal, review, assign to a client")
                                    .font(.caption).opacity(0.85)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let o = overview {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatTile(value: "\(o.users)", label: "Clients", icon: "person.2.fill")
                            StatTile(value: "\(o.activeUsers7d)", label: "Active this week", icon: "bolt.fill", tint: Theme.mint)
                            StatTile(value: "\(o.sessions7d)", label: "Workouts, 7 days", icon: "figure.strengthtraining.traditional", tint: Theme.accent2)
                            StatTile(value: "\(o.newUsers30d)", label: "New, 30 days", icon: "person.badge.plus", tint: Theme.amber)
                        }
                    } else if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }

                    adminLink("Clients", icon: "person.3.fill") { AdminUsersView() }
                    adminLink("Templates", icon: "square.stack.3d.up.fill") { AdminTemplatesView() }
                    adminLink("Announcements", icon: "megaphone.fill") { AdminAnnouncementsView() }
                    adminLink("My exercise library", icon: "dumbbell.fill") { ExerciseLibraryView(userId: nil, title: "My exercises") }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .navigationTitle("Admin")
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showBuilder) { ProgramBuilderView(client: nil) }
        }
    }

    private func adminLink<D: View>(_ title: String, icon: String, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink { destination() } label: {
            GlassCard {
                HStack {
                    Label(title, systemImage: icon).font(.system(.headline, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            overview = try await APIClient.shared.get("/api/admin/overview")
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct AdminUsersView: View {
    @State private var users: [AdminUser] = []
    @State private var query = ""
    @State private var loading = true

    var body: some View {
        List {
            ForEach(users) { u in
                NavigationLink { AdminUserDetailView(user: u) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.accent)
                            Text(String(u.name.prefix(1)).uppercased()).font(.headline)
                        }
                        .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(u.name).font(.headline)
                                if u.isAdmin {
                                    Text("ADMIN").font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Theme.accent, in: Capsule())
                                }
                            }
                            Text(u.activeProgram ?? "No active program").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(u.sessionCount)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay { if loading { ProgressView() } else if users.isEmpty { Text("No clients found").foregroundStyle(.secondary) } }
        .navigationTitle("Clients")
        .searchable(text: $query)
        .onSubmit(of: .search) { Task { await load() } }
        .onChange(of: query) { _, new in if new.isEmpty { Task { await load() } } }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        do { users = try await APIClient.shared.get("/api/admin/users?q=\(q)") } catch { users = [] }
        loading = false
    }
}

struct AdminUserDetailView: View {
    @Environment(AppState.self) private var app
    let user: AdminUser
    @State private var detail: AdminUserDetail?
    @State private var showBuilder = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.name).font(.system(.title2, design: .rounded, weight: .bold))
                        Text(user.email).font(.footnote).foregroundStyle(.secondary)
                        if let goal = detail?.goal ?? user.goal {
                            Label(Exercise.pretty(goal), systemImage: "target").font(.subheadline).foregroundStyle(Theme.mint)
                        }
                        if let note = detail?.coachNote, !note.isEmpty {
                            Text("Note to Surba: \(note)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                Button { showBuilder = true } label: {
                    Label("Build a program for \(user.name)", systemImage: "wand.and.stars")
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: 12) {
                    NavigationLink { AssignTemplateView(client: user) } label: {
                        Label("Assign template", systemImage: "square.stack.3d.up")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    NavigationLink { ExerciseLibraryView(userId: user.id, title: "\(user.name)'s exercises") } label: {
                        Label("Exercises", systemImage: "dumbbell")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .buttonStyle(.plain)

                if let detail {
                    SectionTitle("Programs")
                    ForEach(detail.programs) { p in
                        GlassCard(padding: 14) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.name).font(.headline)
                                    Text(p.phase).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if p.isActive { Text("Active").font(.caption.weight(.bold)).foregroundStyle(Theme.mint) }
                            }
                        }
                    }
                    SectionTitle("Recent workouts")
                    ForEach(detail.sessions) { s in
                        GlassCard(padding: 14) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(s.workout?.name ?? "Workout").font(.headline)
                                    Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(s._count?.sets ?? 0) sets").font(.footnote)
                            }
                        }
                    }
                    if detail.sessions.isEmpty { Text("No workouts yet.").foregroundStyle(.secondary) }

                    if detail.email != app.profile?.email {
                        Button(detail.role == "ADMIN" ? "Remove admin access" : "Make admin") {
                            Task { await toggleRole(detail) }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(detail.role == "ADMIN" ? .red : Theme.accent)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Client")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showBuilder, onDismiss: { Task { await load() } }) { ProgramBuilderView(client: user) }
    }

    private func load() async {
        do { detail = try await APIClient.shared.get("/api/admin/users/\(user.id)") } catch { self.error = error.localizedDescription }
    }

    private func toggleRole(_ d: AdminUserDetail) async {
        let next = d.role == "ADMIN" ? "USER" : "ADMIN"
        do {
            _ = try await APIClient.shared.raw("PATCH", "/api/admin/users/\(d.id)", json: ["role": next])
            Haptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }
}

struct ProgramBuilderView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let client: AdminUser?

    @State private var clients: [AdminUser] = []
    @State private var selectedId: String = ""
    @State private var prompt = ""
    @State private var rawProgram: [String: Any]?
    @State private var preview: DraftProgram?
    @State private var name = ""
    @State private var activate = true
    @State private var generating = false
    @State private var saving = false
    @State private var saved = false
    @State private var templateSaved = false
    @State private var error: String?

    private let ideas = [
        "4 day upper/lower split for hypertrophy, 60 minutes per session",
        "3 day full body strength focus, barbell based",
        "5 day push pull legs with extra arms and shoulders",
        "Beginner 3 day plan with machines and dumbbells only",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if client == nil { clientPicker }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("What should Surba build?", systemImage: "sparkles").font(.system(.headline, design: .rounded))
                            TextEditor(text: $prompt)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 110)
                                .padding(8)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(ideas, id: \.self) { idea in
                                        Button(idea) { prompt = idea }
                                            .font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                                            .padding(10).frame(width: 190, alignment: .leading)
                                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                            .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Button { Task { await generate() } } label: {
                        if generating { HStack { ProgressView().tint(.white); Text("Surba is designing...") } }
                        else { Label(preview == nil ? "Generate" : "Generate again", systemImage: "wand.and.stars") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(generating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 || targetId.isEmpty)

                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }

                    if let preview { previewSection(preview) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .navigationTitle("Create with Surba")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task {
                if let client { selectedId = client.id }
                else if clients.isEmpty { await loadClients() }
            }
        }
    }

    private var targetId: String { client?.id ?? selectedId }

    private var clientPicker: some View {
        GlassCard {
            HStack {
                Label("For", systemImage: "person.fill")
                Spacer()
                Picker("Client", selection: $selectedId) {
                    ForEach(clients) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private func previewSection(_ p: DraftProgram) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Program name", text: $name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(p.phase).font(.caption).foregroundStyle(Theme.mint)
                if let d = p.description, !d.isEmpty { Text(d).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        ForEach(p.workouts) { w in
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(w.name).font(.system(.headline, design: .rounded))
                    ForEach(w.exercises) { e in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.name).font(.subheadline)
                                Text(Exercise.pretty(e.muscleGroup)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(e.targetSets) x \(e.targetRepsMin == e.targetRepsMax ? "\(e.targetRepsMin)" : "\(e.targetRepsMin)-\(e.targetRepsMax)")")
                                .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Toggle("Make it their active program", isOn: $activate).tint(Theme.accent)
        Button { Task { await save() } } label: {
            if saving { ProgressView().tint(.white) }
            else { Label(saved ? "Saved" : "Save to client", systemImage: saved ? "checkmark.circle.fill" : "tray.and.arrow.down.fill") }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(saving || saved)
        Button { Task { await saveTemplate() } } label: {
            Label(templateSaved ? "Saved as template" : "Save as reusable template", systemImage: "square.stack.3d.up")
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(templateSaved)
    }

    private func saveTemplate() async {
        guard var program = rawProgram else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { program["name"] = trimmed }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/admin/templates", json: ["program": program])
            templateSaved = true
            Haptics.success()
        } catch { self.error = error.localizedDescription }
    }

    private func loadClients() async {
        do {
            clients = try await APIClient.shared.get("/api/admin/users")
            if selectedId.isEmpty { selectedId = clients.first?.id ?? "" }
        } catch { self.error = error.localizedDescription }
    }

    private func generate() async {
        generating = true
        error = nil
        saved = false
        templateSaved = false
        defer { generating = false }
        do {
            let data = try await APIClient.shared.raw(
                "POST", "/api/admin/programs/generate",
                json: ["goal": prompt.trimmingCharacters(in: .whitespacesAndNewlines), "userId": targetId])
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let program = obj["program"] as? [String: Any] else {
                error = "Unexpected response from Surba."
                return
            }
            let programData = try JSONSerialization.data(withJSONObject: program)
            preview = try JSONDecoder().decode(DraftProgram.self, from: programData)
            rawProgram = program
            name = preview?.name ?? ""
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }

    private func save() async {
        guard var program = rawProgram else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { program["name"] = trimmed }
        saving = true
        defer { saving = false }
        do {
            _ = try await APIClient.shared.raw(
                "POST", "/api/admin/programs/build",
                json: ["userId": targetId, "program": program, "activate": activate])
            saved = true
            Haptics.success()
            await app.refresh()
        } catch { self.error = error.localizedDescription }
    }
}
