import SwiftUI
import Charts

struct ProgressTab: View {
    @Environment(AppState.self) private var app
    @State private var selectedId: String?
    @State private var showWeightSheet = false

    private var selectedExercise: Exercise? {
        app.trainedExercises.first { $0.id == selectedId } ?? app.trainedExercises.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    volumeCard
                    strengthCard
                    bodyweightCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .refreshable { await app.refresh() }
            .navigationTitle("Progress")
            .sheet(isPresented: $showWeightSheet) {
                LogBodyweightSheet().presentationDetents([.height(280)])
            }
        }
    }

    private var volumeCard: some View {
        let points = app.weeklyVolume().map { ChartPoint(date: $0.0, value: app.units.display($0.1)) }
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly volume").font(.system(.headline, design: .rounded))
                if points.allSatisfy({ $0.value == 0 }) {
                    emptyText("Finish a workout to see your volume.")
                } else {
                    Chart(points) { p in
                        BarMark(x: .value("Week", p.date, unit: .weekOfYear), y: .value("Volume", p.value))
                            .foregroundStyle(Theme.gradient)
                            .cornerRadius(6)
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .frame(height: 170)
                }
            }
        }
    }

    private var strengthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Estimated 1RM").font(.system(.headline, design: .rounded))
                    Spacer()
                    if !app.trainedExercises.isEmpty {
                        Menu {
                            ForEach(app.trainedExercises) { ex in
                                Button(ex.name) { selectedId = ex.id }
                            }
                        } label: {
                            Label(selectedExercise?.name ?? "Pick", systemImage: "chevron.up.chevron.down")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                if let ex = selectedExercise {
                    let points = app.e1RMSeries(for: ex.id).map { ChartPoint(date: $0.0, value: app.units.display($0.1)) }
                    if points.count < 2 {
                        emptyText("Log this lift in at least two workouts to see a trend.")
                    } else {
                        let best = points.map(\.value).max() ?? 0
                        Text("Best \(String(format: "%.0f", best)) \(app.units.label)")
                            .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Theme.mint)
                        Chart(points) { p in
                            LineMark(x: .value("Date", p.date), y: .value("e1RM", p.value))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.mint)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            AreaMark(x: .value("Date", p.date), y: .value("e1RM", p.value))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(colors: [Theme.mint.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                            PointMark(x: .value("Date", p.date), y: .value("e1RM", p.value))
                                .foregroundStyle(Theme.mint)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 190)
                    }
                } else {
                    emptyText("Your lifts will show up here once you have finished workouts.")
                }
            }
        }
    }

    private var bodyweightCard: some View {
        let points = app.bodyweight.sorted { $0.measuredAt < $1.measuredAt }
            .map { ChartPoint(date: $0.measuredAt, value: app.units.display($0.weightKg)) }
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bodyweight").font(.system(.headline, design: .rounded))
                    Spacer()
                    Button { showWeightSheet = true } label: {
                        Label("Log", systemImage: "plus").font(.footnote.weight(.semibold))
                    }
                }
                if points.count < 2 {
                    emptyText("Log your weight a few times to see the trend.")
                } else {
                    if let last = points.last {
                        Text("\(String(format: "%.1f", last.value)) \(app.units.label)")
                            .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Theme.accent2)
                    }
                    Chart {
                        ForEach(points) { p in
                            LineMark(x: .value("Date", p.date), y: .value("Weight", p.value))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.accent2)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        }
                        if let goal = app.profile?.bodyweightGoalKg {
                            RuleMark(y: .value("Goal", app.units.display(goal)))
                                .foregroundStyle(Theme.amber)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 170)
                }
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
    }
}

struct LogBodyweightSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Log bodyweight").font(.system(.title3, design: .rounded, weight: .bold))
            HStack {
                TextField("0.0", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(app.units.label).font(.title3).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            Button("Save") {
                guard let v = Double(value.replacingOccurrences(of: ",", with: ".")) else { error = "Enter a number."; return }
                busy = true
                Task {
                    do { try await app.logBodyweight(valueInDisplayUnit: v); Haptics.success(); dismiss() }
                    catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(busy || value.isEmpty)
        }
        .padding(20)
    }
}
