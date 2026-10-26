import SwiftUI

/// Surba's weekly review: an analysis of your week and concrete changes to
/// your plan that you can apply with one tap.
struct WeeklyReviewView: View {
    @Environment(AppState.self) private var app

    @State private var debrief: CoachDebrief?
    @State private var text = ""
    @State private var adjustments: [[String: Any]] = []
    @State private var selected: Set<Int> = []
    @State private var loading = true
    @State private var running = false
    @State private var applying = false
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Weekly review", systemImage: "chart.bar.doc.horizontal.fill")
                            .font(.system(.headline, design: .rounded))
                        Text("Surba reads your sessions, loads and recovery from this week and suggests changes to your plan.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { Task { await run() } } label: {
                            if running { HStack { ProgressView().tint(.black); Text("Reviewing your week...") } }
                            else { Label(debrief == nil ? "Run my review" : "Run a fresh review", systemImage: "sparkles") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(running)
                    }
                }

                if let error { Text(error).font(.footnote).foregroundStyle(.red) }

                if debrief != nil {
                    GlassCard {
                        Text(rendered(text)).font(.callout).textSelection(.enabled)
                    }
                }

                if !adjustments.isEmpty {
                    SectionTitle("Suggested changes")
                    ForEach(Array(adjustments.enumerated()), id: \.offset) { index, adj in
                        Button {
                            if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
                            Haptics.select()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selected.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(selected.contains(index) ? Theme.accent : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(adj["exerciseName"] as? String ?? "Exercise").font(.system(.headline, design: .rounded))
                                    Text(adj["summary"] as? String ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                                    if let why = adj["rationale"] as? String, !why.isEmpty {
                                        Text(why).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    if debrief?.appliedAt != nil {
                        Label("Already applied", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.mint).font(.subheadline)
                    } else {
                        Button { Task { await apply() } } label: {
                            if applying { ProgressView().tint(.black) }
                            else { Text("Apply \(selected.count) change\(selected.count == 1 ? "" : "s") to my plan") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selected.isEmpty || applying)
                    }
                }
                if let message { Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.mint).font(.subheadline) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle("Weekly review")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if loading { ProgressView() } }
        .task { await load() }
    }

    private func rendered(_ s: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
    }

    private func load() async {
        do {
            let list: [CoachDebrief] = try await APIClient.shared.get("/api/coach")
            if let latest = list.first { show(latest) }
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func run() async {
        running = true
        error = nil
        message = nil
        defer { running = false }
        do {
            let fresh: CoachDebrief = try await APIClient.shared.send("POST", "/api/coach")
            show(fresh)
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }

    private func show(_ d: CoachDebrief) {
        debrief = d
        let parsed = Self.extract(d.response)
        text = parsed.text
        adjustments = parsed.adjustments
        selected = Set(parsed.adjustments.indices)
    }

    /// Splits the model's reply into readable text and the <adjustments> JSON.
    static func extract(_ markdown: String) -> (text: String, adjustments: [[String: Any]]) {
        guard let regex = try? NSRegularExpression(pattern: "<adjustments>([\\s\\S]*?)</adjustments>", options: [.caseInsensitive]),
              let match = regex.firstMatch(in: markdown, range: NSRange(markdown.startIndex..., in: markdown)),
              let full = Range(match.range, in: markdown),
              let inner = Range(match.range(at: 1), in: markdown)
        else { return (markdown.trimmingCharacters(in: .whitespacesAndNewlines), []) }
        var cleaned = markdown
        cleaned.removeSubrange(full)
        let json = markdown[inner].trimmingCharacters(in: .whitespacesAndNewlines)
        let list = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [[String: Any]] ?? []
        return (cleaned.trimmingCharacters(in: .whitespacesAndNewlines), list)
    }

    private func apply() async {
        guard let debrief else { return }
        applying = true
        defer { applying = false }
        let chosen = selected.sorted().map { adjustments[$0] }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/coach/\(debrief.id)/apply", json: ["adjustments": chosen])
            message = "Your plan is updated."
            Haptics.success()
            await app.refresh()
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
