import SwiftUI

struct ReadinessCheckin: Codable {
    let readiness: Int
    let sleepQuality: Int
    let createdAt: Date
}

/// Daily "how do you feel" check-in. Surba's coach reads it from the server,
/// and the card turns it into a one line suggestion for today.
struct ReadinessCard: View {
    @State private var latest: ReadinessCheckin?
    @State private var loaded = false
    @State private var readiness = 0
    @State private var sleep = 0
    @State private var saving = false
    @State private var error: String?

    private var doneToday: Bool {
        guard let latest else { return false }
        return Calendar.current.isDateInToday(latest.createdAt)
    }

    var body: some View {
        if loaded {
            GlassCard {
                if doneToday, let latest {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill").font(.title2).foregroundStyle(Theme.mint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Checked in today").font(.system(.headline, design: .rounded))
                            Text(advice(latest)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How are you feeling?").font(.system(.headline, design: .rounded))
                        scale("Energy", selection: $readiness)
                        scale("Sleep", selection: $sleep)
                        if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                        Button(saving ? "Saving..." : "Check in") { Task { await save() } }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(readiness == 0 || sleep == 0 || saving)
                    }
                }
            }
        } else {
            Color.clear.frame(height: 0).task { await load() }
        }
    }

    private func scale(_ title: String, selection: Binding<Int>) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            ForEach(1...5, id: \.self) { value in
                Button {
                    selection.wrappedValue = value
                    Haptics.select()
                } label: {
                    Text("\(value)").font(.system(.body, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(selection.wrappedValue == value ? Theme.accent : Theme.field,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(selection.wrappedValue == value ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func advice(_ c: ReadinessCheckin) -> String {
        let score = c.readiness + c.sleepQuality
        if score <= 4 { return "Low energy day. Keep the weights moderate and drop a set if it drags." }
        if score >= 9 { return "You are primed. A good day to push your top sets." }
        return "Solid. Train as planned."
    }

    private func load() async {
        latest = try? await APIClient.shared.get("/api/readiness")
        loaded = true
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/readiness", json: ["readiness": readiness, "sleepQuality": sleep])
            Haptics.success()
            latest = ReadinessCheckin(readiness: readiness, sleepQuality: sleep, createdAt: Date())
        } catch { self.error = error.localizedDescription }
    }
}

/// Seven day strip: filled when a workout was done, ringed for today.
struct WeekStrip: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let trained = app.trainedDays
        HStack {
            ForEach(0..<7, id: \.self) { offset in
                let day = cal.date(byAdding: .day, value: offset, to: start) ?? start
                let isToday = cal.isDateInToday(day)
                let done = trained.contains(cal.startOfDay(for: day))
                VStack(spacing: 6) {
                    Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(.secondary)
                    ZStack {
                        Circle().fill(done ? Theme.accent : Theme.field)
                        if isToday { Circle().strokeBorder(Color.white, lineWidth: 2) }
                        if done { Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.black) }
                    }
                    .frame(width: 34, height: 34)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
