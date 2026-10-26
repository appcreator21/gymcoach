import SwiftUI

struct RecordsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let records = app.personalRecords()
        ScrollView {
            VStack(spacing: 10) {
                if records.isEmpty {
                    GlassCard { Text("Finish a few workouts and your best lifts will show up here.").foregroundStyle(.secondary) }
                }
                ForEach(records) { r in
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: "trophy.fill").font(.title2).foregroundStyle(Theme.amber)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.exercise.name).font(.system(.headline, design: .rounded))
                                Text("Best set \(app.units.format(r.bestSet.weight)) x \(r.bestSet.reps)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("Heaviest \(app.units.format(r.heaviest.weight)) x \(r.heaviest.reps)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(app.units.format(r.bestE1RM)).font(.system(.title3, design: .rounded, weight: .bold))
                                Text("est. 1RM").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Personal records")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let items = app.achievements()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(items.filter(\.unlocked).count) of \(items.count) unlocked")
                    .font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(items) { a in
                        GlassCard(padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: a.icon).font(.title)
                                    .foregroundStyle(a.unlocked ? Theme.amber : Color.white.opacity(0.25))
                                Text(a.title).font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(a.unlocked ? .white : .secondary)
                                Text(a.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                if !a.unlocked {
                                    ProgressView(value: a.progress).tint(Theme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
