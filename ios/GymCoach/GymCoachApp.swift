import SwiftUI

@main
struct GymCoachApp: App {
    @State private var app = AppState()
    @State private var restTimer = RestTimer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(restTimer)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { await app.bootstrap() }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            AppBackground()
            if app.isBooting || (app.isSignedIn && app.profile == nil) {
                ProgressView().controlSize(.large)
            } else if app.isSignedIn, app.profile?.onboardedAt == nil {
                OnboardingView().transition(.opacity)
            } else if app.isSignedIn {
                MainTabs().transition(.opacity)
            } else {
                LoginView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: app.isSignedIn)
        .animation(.easeInOut(duration: 0.45), value: app.profile?.onboardedAt)
    }
}

struct MainTabs: View {
    @Environment(AppState.self) private var app
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("Today", systemImage: "flame.fill") }.tag(0)
            HistoryView().tabItem { Label("History", systemImage: "calendar") }.tag(1)
            ProgressTab().tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }.tag(2)
            CoachView().tabItem { Label("Surba", systemImage: "sparkles") }.tag(3)
            SettingsView().tabItem { Label("You", systemImage: "person.crop.circle") }.tag(4)
        }
        // Lets every scroll view in the tabs scroll a little past the tab bar.
        .contentMargins(.bottom, 56, for: .scrollContent)
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: tab) { _, _ in Haptics.select() }
        .overlay(alignment: .bottom) {
            if let open = app.activeSession, app.sessionLaunch == nil, !app.isAbandoned(open) {
                ActiveWorkoutBar(session: open)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: app.activeSession?.id)
        .fullScreenCover(item: Binding(get: { app.sessionLaunch }, set: { app.sessionLaunch = $0 })) { launch in
            WorkoutSessionView(workout: launch.workout, sessionId: launch.sessionId)
        }
        .confirmationDialog(
            "A workout is already open",
            isPresented: Binding(get: { app.startConflict != nil }, set: { if !$0 { app.startConflict = nil } }),
            titleVisibility: .visible,
            presenting: app.startConflict
        ) { conflict in
            Button("Resume \(conflict.open.title)") { app.resolve(conflict, .resumeOpen) }
            Button("Finish it and start \(conflict.wanted.name)") { app.resolve(conflict, .finishOpenThenStart) }
            Button("Discard it and start \(conflict.wanted.name)", role: .destructive) { app.resolve(conflict, .discardOpenThenStart) }
            Button("Cancel", role: .cancel) {}
        } message: { conflict in
            Text("\(conflict.open.title) is still in progress with \(conflict.open.setCount) set\(conflict.open.setCount == 1 ? "" : "s") logged.")
        }
        .confirmationDialog(
            "This workout cannot be reopened",
            isPresented: Binding(get: { app.orphanSession != nil }, set: { if !$0 { app.orphanSession = nil } }),
            titleVisibility: .visible,
            presenting: app.orphanSession
        ) { orphan in
            Button("Finish and keep its sets") { Task { await app.finishSession(orphan) } }
            Button("Discard it", role: .destructive) { Task { await app.discardSession(orphan) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The workout it came from was deleted from your program.")
        }
    }
}
