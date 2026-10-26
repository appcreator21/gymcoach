import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var app
    @State private var server = ""
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var creating = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image("LogoMark")
                        .resizable().scaledToFit()
                        .frame(height: 120)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 24)
                    Text("Surba Fit").font(.system(size: 36, weight: .heavy, design: .rounded))
                    Text("Train with Surba")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 56)

                GlassCard {
                    VStack(spacing: 14) {
                        field("Server address", systemImage: "server.rack", text: $server,
                              prompt: "http://192.168.1.20:3000", keyboard: .URL)
                        field("Email", systemImage: "envelope", text: $email,
                              prompt: "you@example.com", keyboard: .emailAddress)
                        if creating {
                            field("Name", systemImage: "person", text: $name, prompt: "Your name", keyboard: .default)
                        }
                        HStack {
                            Image(systemName: "lock").foregroundStyle(.secondary).frame(width: 22)
                            SecureField("Password", text: $password)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
                            if busy { ProgressView().tint(.white) } else { Text(creating ? "Create account" : "Sign in") }
                        }
                        .buttonStyle(GradientButtonStyle())
                        .disabled(busy || server.isEmpty || email.isEmpty || password.isEmpty)

                        Button(creating ? "I already have an account" : "New here? Create an account") {
                            withAnimation { creating.toggle() }
                        }
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            server = app.serverURL
            email = app.email
        }
    }

    private func field(_ title: String, systemImage: String, text: Binding<String>, prompt: String, keyboard: UIKeyboardType) -> some View {
        HStack {
            Image(systemName: systemImage).foregroundStyle(.secondary).frame(width: 22)
            TextField(title, text: text, prompt: Text(prompt))
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? TextInputAutocapitalization.words : TextInputAutocapitalization.never)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func submit() {
        busy = true
        error = nil
        app.saveServer(server)
        Task {
            do {
                if creating {
                    try await app.register(email: email, password: password, name: name)
                } else {
                    try await app.login(email: email, password: password)
                }
                Haptics.success()
            } catch {
                self.error = error.localizedDescription
                Haptics.warning()
            }
            busy = false
        }
    }
}
