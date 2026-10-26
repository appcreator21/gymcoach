import SwiftUI

@Observable
@MainActor
final class CoachModel {
    var messages: [ChatMessage] = []
    var input = ""
    var isStreaming = false
    var error: String?
    var conversationId: String? = UserDefaults.standard.string(forKey: "coachConversationId")

    @ObservationIgnored private let api = APIClient.shared

    func loadHistory() async {
        guard let id = conversationId, messages.isEmpty else { return }
        do {
            let history: ChatHistory = try await api.get("/api/coach/chat/\(id)")
            messages = history.messages
        } catch {
            // The conversation may have been deleted on the server.
            conversationId = nil
            UserDefaults.standard.removeObject(forKey: "coachConversationId")
        }
    }

    func newChat() {
        messages = []
        conversationId = nil
        UserDefaults.standard.removeObject(forKey: "coachConversationId")
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }
        input = ""
        error = nil
        messages.append(ChatMessage(id: UUID().uuidString, role: "USER", content: trimmed))
        let replyId = UUID().uuidString
        messages.append(ChatMessage(id: replyId, role: "ASSISTANT", content: ""))
        isStreaming = true
        Haptics.tap()

        var body: [String: Any] = ["message": trimmed]
        if let conversationId { body["conversationId"] = conversationId }

        do {
            try await api.stream("/api/coach/chat", json: body,
                onHeaders: { [weak self] id in
                    guard let self, let id else { return }
                    Task { @MainActor in
                        self.conversationId = id
                        UserDefaults.standard.set(id, forKey: "coachConversationId")
                    }
                },
                onText: { [weak self] chunk in
                    Task { @MainActor in self?.append(chunk, to: replyId) }
                })
        } catch {
            self.error = error.localizedDescription
            if let idx = messages.firstIndex(where: { $0.id == replyId }), messages[idx].content.isEmpty {
                messages.remove(at: idx)
            }
        }
        isStreaming = false
        Haptics.success()
    }

    private func append(_ chunk: String, to id: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content += chunk
    }
}

struct CoachView: View {
    @State private var model = CoachModel()
    @FocusState private var focused: Bool

    private let suggestions = [
        "How did my last week of training look?",
        "What should I focus on next session?",
        "Am I recovering enough?",
        "Build me a 4 day upper/lower split",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if model.messages.isEmpty { intro }
                            ForEach(model.messages) { m in
                                Bubble(message: m, isStreaming: model.isStreaming && m.id == model.messages.last?.id)
                                    .id(m.id)
                            }
                            if let error = model.error {
                                Text(error).font(.footnote).foregroundStyle(.red)
                            }
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: model.messages.last?.content) { _, _ in
                        if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                inputBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.loadHistory() }
        }
    }

    /// Surba's face and name at the top-left, new chat at the top-right.
    private var header: some View {
        HStack(spacing: 12) {
            CoachAvatar(size: 44, online: true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Surba").font(.system(.title3, design: .rounded, weight: .bold))
                Text("Your coach").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Haptics.select()
                model.newChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .accessibilityLabel("New chat")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var intro: some View {
        VStack(spacing: 14) {
            CoachAvatar(size: 120, online: true)
            Text("Hey, I'm Surba").font(.system(.title2, design: .rounded, weight: .bold))
            Text("Ask me anything. I know your program, your recent sessions and how you're progressing.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            ForEach(suggestions, id: \.self) { s in
                Button { Task { await model.send(s) } } label: {
                    Text(s).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 30)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message Surba", text: $model.input, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Button {
                Task { await model.send(model.input) }
            } label: {
                Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.accent, in: Circle())
            }
            .disabled(model.isStreaming || model.input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

struct Bubble: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 50) } else { CoachAvatar(size: 28) }
            Group {
                if message.content.isEmpty && isStreaming {
                    ProgressView().padding(.vertical, 4)
                } else {
                    Text(rendered)
                }
            }
            .font(.body)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background {
                if message.isUser {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.accent)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                }
            }
            .textSelection(.enabled)
            if !message.isUser { Spacer(minLength: 50) }
        }
    }

    private var rendered: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: message.content, options: options)) ?? AttributedString(message.content)
    }
}

/// Surba's headshot in a circle. Used as the coach's face across the app.
/// With `online` it carries a green presence dot at the bottom-right corner.
struct CoachAvatar: View {
    var size: CGFloat
    var online = false

    private var dot: CGFloat { max(9, size * 0.24) }

    var body: some View {
        Image("SurbaCoach")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: max(1, size / 60)))
            .overlay(alignment: .bottomTrailing) {
                if online { presenceDot }
            }
            .accessibilityLabel(online ? "Surba, online" : "Surba")
    }

    private var presenceDot: some View {
        let green = Color(red: 0.20, green: 0.80, blue: 0.36)
        return ZStack {
            // Slow pulse so he reads as live.
            PhaseAnimator([false, true]) { grow in
                Circle().fill(green.opacity(grow ? 0 : 0.5))
                    .scaleEffect(grow ? 2.1 : 1)
            } animation: { _ in .easeOut(duration: 1.6) }
            Circle().fill(green)
        }
        .frame(width: dot, height: dot)
        .overlay(Circle().strokeBorder(Theme.background, lineWidth: max(2, dot * 0.2)))
        .offset(x: dot / 2 - size * 0.146, y: dot / 2 - size * 0.146)
    }
}
