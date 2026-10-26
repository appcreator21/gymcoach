import SwiftUI

/// A suggested ramp up to the working weight. Guidance only: nothing is logged.
struct WarmupSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let workingWeight: Double

    var body: some View {
        let units = app.units
        let bar = units.isPounds ? 45.0 : 20.0
        let sets = WarmupPlan.sets(working: workingWeight, step: units.step, bar: bar)
        NavigationStack {
            List {
                Section("Ramp to \(String(format: "%g", workingWeight)) \(units.label)") {
                    if sets.isEmpty {
                        Text("Your working weight is close to the bar. One or two light reps with the bar is enough.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Warm-up \(index + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(String(format: "%g", set.weight)) \(units.label) x \(set.reps)")
                                .font(.system(.body, design: .rounded, weight: .semibold).monospacedDigit())
                        }
                    }
                }
                Section { Text("Rest 30 to 60 seconds between warm-up sets.").font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
