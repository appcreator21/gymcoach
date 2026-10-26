import SwiftUI

/// Working sets per muscle this week against the 10 to 20 set band.
struct MuscleVolumeCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let rows = app.weeklySetsByMuscle()
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sets per muscle").font(.system(.headline, design: .rounded))
                    Spacer()
                    Text("this week").font(.caption).foregroundStyle(.secondary)
                }
                if rows.isEmpty {
                    Text("Log some sets this week to see your balance.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(rows.prefix(10)) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(Exercise.pretty(row.muscle)).font(.subheadline)
                                Spacer()
                                Text("\(row.sets)").font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                            bar(row.sets)
                        }
                    }
                    Text("Aim for \(VolumeBand.mev) to \(VolumeBand.mrv) hard sets per muscle each week.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func bar(_ sets: Int) -> some View {
        GeometryReader { geo in
            let scale = Double(VolumeBand.mrv + 6)
            let width = min(Double(sets) / scale, 1) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.field)
                Capsule().fill(color(sets)).frame(width: max(width, 6))
                Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1.5)
                    .offset(x: Double(VolumeBand.mev) / scale * geo.size.width)
                Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1.5)
                    .offset(x: Double(VolumeBand.mrv) / scale * geo.size.width)
            }
        }
        .frame(height: 8)
    }

    private func color(_ sets: Int) -> Color {
        if sets < VolumeBand.mev { return Theme.accent2 }
        if sets <= VolumeBand.mrv { return Theme.mint }
        return Theme.accent
    }
}
