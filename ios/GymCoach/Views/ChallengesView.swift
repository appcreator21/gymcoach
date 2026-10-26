import SwiftUI

struct ChallengesView: View {
    @State private var items: [Challenge] = []
    @State private var loading = true
    @State private var error: String?

    private func group(_ status: String) -> [Challenge] { items.filter { ($0.status ?? "ACTIVE") == status } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if items.isEmpty && !loading {
                    GlassCard { Text("No challenges right now. New ones show up here when your coach posts them.").foregroundStyle(.secondary) }
                }
                section("Active", group("ACTIVE"))
                section("Upcoming", group("UPCOMING"))
                section("Finished", group("ENDED"))
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if loading { ProgressView() } }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [Challenge]) -> some View {
        if !list.isEmpty {
            SectionTitle(title)
            ForEach(list) { c in
                NavigationLink { ChallengeDetailView(challenge: c, onChange: { Task { await load() } }) } label: {
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: c.metricIcon).font(.title2).foregroundStyle(Theme.accent)
                                .frame(width: 44, height: 44)
                                .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                                Text("\(c.metricLabel)  -  \(c.participants) joined").font(.caption).foregroundStyle(.secondary)
                                Text(dates(c)).font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                            if c.joined == true { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint) }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dates(_ c: Challenge) -> String {
        "\(c.startsAt.formatted(.dateTime.month(.abbreviated).day())) to \(c.endsAt.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func load() async {
        do { items = try await APIClient.shared.get("/api/challenges"); error = nil } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct ChallengeDetailView: View {
    @Environment(AppState.self) private var app
    let challenge: Challenge
    var onChange: () -> Void

    @State private var board: Leaderboard?
    @State private var joined: Bool
    @State private var busy = false
    @State private var error: String?

    init(challenge: Challenge, onChange: @escaping () -> Void) {
        self.challenge = challenge
        self.onChange = onChange
        _joined = State(initialValue: challenge.joined ?? false)
    }

    private var ended: Bool { challenge.status == "ENDED" }

    private func format(_ score: Double) -> String {
        switch challenge.metric {
        case "VOLUME": return app.units.formatVolume(score)
        default: return String(format: "%.0f", score)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(challenge.metricLabel, systemImage: challenge.metricIcon).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                        if let d = challenge.description, !d.isEmpty { Text(d).font(.subheadline).foregroundStyle(.secondary) }
                        Text(ended ? "Ended \(challenge.endsAt.formatted(date: .abbreviated, time: .omitted))"
                                   : "Ends \(challenge.endsAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }

                if !ended {
                    Button { Task { await toggleJoin() } } label: {
                        Label(joined ? "Leave challenge" : "Join challenge", systemImage: joined ? "xmark" : "flag.checkered")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)
                    if !joined {
                        Text("Joining shows your first name and last initial on this leaderboard.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                SectionTitle("Leaderboard")
                if let board {
                    if board.rows.isEmpty {
                        GlassCard { Text("Nobody has joined yet. Be the first.").foregroundStyle(.secondary) }
                    }
                    ForEach(board.rows) { row in
                        GlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                Text("\(row.rank)").font(.system(.title3, design: .rounded, weight: .heavy))
                                    .frame(width: 34)
                                    .foregroundStyle(row.rank == 1 ? Theme.amber : .white)
                                Text(row.name + (row.isMe ? " (you)" : "")).font(.system(.body, design: .rounded, weight: row.isMe ? .bold : .regular))
                                Spacer()
                                Text(format(row.score)).font(.system(.body, design: .rounded, weight: .semibold).monospacedDigit())
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(row.isMe ? Theme.accent : .clear, lineWidth: 1.5))
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBoard() }
        .refreshable { await loadBoard() }
    }

    private func loadBoard() async {
        do { board = try await APIClient.shared.get("/api/challenges/\(challenge.id)/leaderboard"); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func toggleJoin() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.raw(joined ? "DELETE" : "POST", "/api/challenges/\(challenge.id)/join")
            joined.toggle()
            Haptics.success()
            await loadBoard()
            onChange()
        } catch { self.error = error.localizedDescription }
    }
}
