import SwiftUI

/// Entry points to everything Surba can build or run, shown on Today.
struct ExploreSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Explore")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    card("Quick workout", "Any gear, any time", icon: "bolt.fill") { QuickWorkoutView() }
                    card("Plan with Surba", "Build a full program", icon: "wand.and.stars") { PlanBuilderView() }
                    card("Classes", "HIIT, yoga, mobility", icon: "figure.yoga") { ClassesView() }
                    card("Challenges", "Compete and climb", icon: "flag.checkered") { ChallengesView() }
                    card("Weekly review", "Adjust your plan", icon: "chart.bar.doc.horizontal.fill") { WeeklyReviewView() }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func card<D: View>(_ title: String, _ subtitle: String, icon: String, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink { destination() } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.title2).foregroundStyle(Theme.accent)
                Spacer(minLength: 0)
                Text(title).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(width: 148, height: 118, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { Haptics.select() })
    }
}
