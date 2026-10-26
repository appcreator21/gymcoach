import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var app
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var creating = false
    @State private var busy = false
    @State private var error: String?
    @State private var appeared = false
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Image("LogoMark")
                    .resizable().scaledToFit()
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .padding(.top, 72)
                    .modifier(Rise(appeared: appeared, delay: 0))

                Text(creating ? "Create your account" : "Welcome back")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.top, 28)
                    .contentTransition(.interpolate)
                    .modifier(Rise(appeared: appeared, delay: 0.06))

                Text(creating ? "Takes a minute. Then Surba gets to know you." : "Sign in to keep training with Surba.")
                    .font(.body).foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .modifier(Rise(appeared: appeared, delay: 0.1))

                VStack(spacing: 12) {
                    if creating {
                        row("person", "Name", text: $name, field: .name, content: .name)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    row("envelope", "Email", text: $email, field: .email, content: .emailAddress)
                    secureRow
                }
                .padding(.top, 32)
                .modifier(Rise(appeared: appeared, delay: 0.16))

                if let error {
                    Text(error)
                        .font(.footnote).foregroundStyle(.red)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Button(action: submit) {
                    if busy { ProgressView().tint(.black) } else { Text(creating ? "Create account" : "Sign in") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || email.isEmpty || password.isEmpty)
                .padding(.top, 24)
                .modifier(Rise(appeared: appeared, delay: 0.22))

                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        creating.toggle()
                        error = nil
                    }
                } label: {
                    Text(creating ? "I already have an account" : "New here? Create an account")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .modifier(Rise(appeared: appeared, delay: 0.28))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            email = app.email
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func row(_ icon: String, _ title: String, text: Binding<String>, field: Field, content: UITextContentType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            TextField(title, text: text)
                .textContentType(content)
                .keyboardType(field == .email ? .emailAddress : .default)
                .textInputAutocapitalization(field == .name ? .words : .never)
                .autocorrectionDisabled()
                .focused($focus, equals: field)
                .submitLabel(.next)
                .onSubmit { focus = field == .name ? .email : .password }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var secureRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock").foregroundStyle(.secondary).frame(width: 22)
            SecureField("Password", text: $password)
                .textContentType(creating ? .newPassword : .password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func submit() {
        guard !busy, !email.isEmpty, !password.isEmpty else { return }
        busy = true
        error = nil
        focus = nil
        Task {
            do {
                if creating {
                    try await app.register(email: email, password: password, name: name)
                } else {
                    try await app.login(email: email, password: password)
                }
                Haptics.success()
            } catch {
                withAnimation { self.error = error.localizedDescription }
                Haptics.warning()
            }
            busy = false
        }
    }
}

/// Fade-and-rise entrance, staggered by `delay`.
struct Rise: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay), value: appeared)
    }
}
