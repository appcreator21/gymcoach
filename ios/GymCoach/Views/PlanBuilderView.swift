import SwiftUI

/// Self-serve AI plan builder: pick a style, schedule and equipment, and Surba
/// drafts a full program. Saving makes it the active plan.
struct PlanBuilderView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var style: PlanStyle = .HYPERTROPHY
    @State private var days = 4
    @State private var minutes = 60
    @State private var equipment: EquipmentProfile = .FULL_GYM
    @State private var focus: Set<String> = []
    @State private var notes = ""
    @State private var generating = false
    @State private var saving = false
    @State private var rawProgram: [String: Any]?
    @State private var preview: DraftProgram?
    @State private var saved = false
    @State private var error: String?

    private let areas = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]
    private let lengths = [30, 45, 60, 75, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle("Goal")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(PlanStyle.allCases) { s in
                        Button { style = s; Haptics.select() } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: s.icon).font(.title3)
                                Text(s.title).font(.system(.subheadline, design: .rounded, weight: .bold))
                                Text(s.detail).font(.caption2).foregroundStyle(style == s ? Color.black.opacity(0.7) : .secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(style == s ? Color.white : Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(style == s ? Color.black : Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionTitle("Schedule")
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("\(days) days per week", value: $days, in: 1...7)
                        Picker("Session length", selection: $minutes) {
                            ForEach(lengths, id: \.self) { Text("\($0) min").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                SectionTitle("Equipment")
                VStack(spacing: 8) {
                    ForEach(EquipmentProfile.allCases) { e in
                        Button { equipment = e; Haptics.select() } label: {
                            HStack {
                                Image(systemName: e.icon).frame(width: 28)
                                Text(e.title).font(.system(.body, design: .rounded, weight: .semibold))
                                Spacer()
                                if equipment == e { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                            }
                            .padding(14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionTitle("Extra focus")
                FlowChips(options: areas, selection: $focus)

                TextField("Anything else? Injuries, favorite lifts, dislikes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button { Task { await generate() } } label: {
                    if generating { HStack { ProgressView().tint(.black); Text("Surba is designing your plan...") } }
                    else { Label(preview == nil ? "Build my plan" : "Rebuild", systemImage: "wand.and.stars") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(generating)

                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                if let preview { previewSection(preview) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle("Plan with Surba")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if let f = app.profile?.weeklyFrequency { days = f } }
    }

    @ViewBuilder
    private func previewSection(_ p: DraftProgram) -> some View {
        Divider().overlay(Color.white.opacity(0.1))
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(p.name).font(.system(.title3, design: .rounded, weight: .bold))
                Text(p.phase).font(.caption).foregroundStyle(Theme.mint)
                if let d = p.description, !d.isEmpty { Text(d).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        ForEach(p.workouts) { w in
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(w.name).font(.system(.headline, design: .rounded))
                    ForEach(w.exercises) { e in
                        HStack {
                            Text(e.name).font(.subheadline)
                            Spacer()
                            Text("\(e.targetSets) x \(e.targetRepsMin == e.targetRepsMax ? "\(e.targetRepsMin)" : "\(e.targetRepsMin)-\(e.targetRepsMax)")")
                                .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Button { Task { await save() } } label: {
            if saving { ProgressView().tint(.black) }
            else { Label(saved ? "Plan started" : "Start this plan", systemImage: saved ? "checkmark.circle.fill" : "play.fill") }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(saving || saved)
        if saved {
            Button("Back to Today") { dismiss() }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
        }
    }

    private func generate() async {
        generating = true
        saved = false
        error = nil
        defer { generating = false }
        var body: [String: Any] = [
            "style": style.rawValue, "daysPerWeek": days, "sessionMinutes": minutes,
            "equipment": equipment.rawValue, "focusAreas": Array(focus),
        ]
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body["notes"] = trimmed }
        do {
            let data = try await APIClient.shared.raw("POST", "/api/plans/generate", json: body)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let program = obj["program"] as? [String: Any] else {
                error = "Unexpected response from Surba."
                return
            }
            preview = try JSONDecoder().decode(DraftProgram.self, from: JSONSerialization.data(withJSONObject: program))
            rawProgram = program
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }

    private func save() async {
        guard let program = rawProgram else { return }
        saving = true
        defer { saving = false }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/programs/from-template", json: program)
            await app.refresh()
            saved = true
            Haptics.success()
        } catch { self.error = error.localizedDescription }
    }
}

/// Wrapping multi-select chips.
struct FlowChips: View {
    let options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = selection.contains(option)
                Button {
                    if on { selection.remove(option) } else { selection.insert(option) }
                    Haptics.select()
                } label: {
                    Text(option).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(on ? Color.white : Theme.card, in: Capsule())
                        .foregroundStyle(on ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
