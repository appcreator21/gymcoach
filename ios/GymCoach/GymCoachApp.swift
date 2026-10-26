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
    }
}
