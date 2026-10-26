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
            if app.isBooting {
                ProgressView().controlSize(.large)
            } else if app.isSignedIn {
                MainTabs()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabs: View {
    @Environment(AppState.self) private var app

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Today", systemImage: "flame.fill") }
            HistoryView().tabItem { Label("History", systemImage: "calendar") }
            ProgressTab().tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            CoachView().tabItem { Label("Surba", systemImage: "sparkles") }
            SettingsView().tabItem { Label("You", systemImage: "person.crop.circle") }
            if app.profile?.isAdmin == true {
                AdminView().tabItem { Label("Admin", systemImage: "shield.lefthalf.filled") }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
