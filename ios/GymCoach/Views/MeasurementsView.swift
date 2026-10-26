import SwiftUI
import Charts

struct BodyMeasurement: Codable, Identifiable, Hashable {
    let id: String
    let site: String
    let valueCm: Double
    let measuredAt: Date
}

enum MeasurementSites {
    static let all = ["WAIST", "HIPS", "CHEST", "SHOULDERS", "NECK", "ARM_LEFT", "ARM_RIGHT",
                      "FOREARM_LEFT", "FOREARM_RIGHT", "THIGH_LEFT", "THIGH_RIGHT", "CALF_LEFT", "CALF_RIGHT"]
}

/// Tape measure tracking. Stored in cm; shown in inches when the profile uses pounds.
struct MeasurementsView: View {
    @Environment(AppState.self) private var app
    @State private var entries: [BodyMeasurement] = []
    @State private var site = "WAIST"
    @State private var showLog = false
    @State private var loading = true
    @State private var error: String?

    private var inches: Bool { app.units.isPounds }
    private func shown(_ cm: Double) -> Double { inches ? cm / 2.54 : cm }
    private var unitLabel: String { inches ? "in" : "cm" }
    private var forSite: [BodyMeasurement] { entries.filter { $0.site == site }.sorted { $0.measuredAt < $1.measuredAt } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Site", selection: $site) {
                    ForEach(MeasurementSites.all, id: \.self) { Text(Exercise.pretty($0)).tag($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: site) { _, _ in Haptics.select() }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        if let last = forSite.last {
                            Text("\(String(format: "%.1f", shown(last.valueCm))) \(unitLabel)")
                                .font(.system(.title, design: .rounded, weight: .heavy))
                            if let first = forSite.first, forSite.count > 1 {
                                let delta = shown(last.valueCm - first.valueCm)
                                Text("\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta)) \(unitLabel) since \(first.measuredAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        if forSite.count >= 2 {
                            Chart(forSite) { m in
                                LineMark(x: .value("Date", m.measuredAt), y: .value("Size", shown(m.valueCm)))
                                    .foregroundStyle(Theme.accent2)
                                PointMark(x: .value("Date", m.measuredAt), y: .value("Size", shown(m.valueCm)))
                                    .foregroundStyle(Theme.accent2)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 170)
                        } else {
                            Text(forSite.isEmpty ? "No \(Exercise.pretty(site).lowercased()) measurements yet." : "Log it again to see a trend.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Button { showLog = true } label: { Label("Log measurement", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())

                if let error { Text(error).font(.footnote).foregroundStyle(.red) }

                if !forSite.isEmpty {
                    SectionTitle("History")
                    ForEach(forSite.reversed()) { m in
                        GlassCard(padding: 14) {
                            HStack {
                                Text(m.measuredAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(String(format: "%.1f", shown(m.valueCm))) \(unitLabel)").font(.headline.monospacedDigit())
                                Button { Task { await delete(m) } } label: {
                                    Image(systemName: "trash").font(.footnote).foregroundStyle(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if loading { ProgressView() } }
        .sheet(isPresented: $showLog, onDismiss: { Task { await load() } }) {
            LogMeasurementSheet(site: site, inches: inches).presentationDetents([.height(300)])
        }
        .task { await load() }
    }

    private func load() async {
        do { entries = try await APIClient.shared.get("/api/measurements"); error = nil } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func delete(_ m: BodyMeasurement) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/measurements/\(m.id)")
            entries.removeAll { $0.id == m.id }
            Haptics.tap()
        } catch { self.error = error.localizedDescription }
    }
}

struct LogMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let site: String
    let inches: Bool
    @State private var value = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Log \(Exercise.pretty(site).lowercased())").font(.system(.title3, design: .rounded, weight: .bold))
            HStack {
                TextField("0.0", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(inches ? "in" : "cm").font(.title3).foregroundStyle(.secondary)
            }
            .padding()
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            Button("Save") { Task { await save() } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy || value.isEmpty)
        }
        .padding(20)
        .background(Theme.background)
    }

    private func save() async {
        guard let v = Double(value.replacingOccurrences(of: ",", with: ".")), v > 0 else { error = "Enter a number."; return }
        busy = true
        defer { busy = false }
        do {
            _ = try await APIClient.shared.raw("POST", "/api/measurements",
                                               json: ["site": site, "valueCm": inches ? v * 2.54 : v])
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
