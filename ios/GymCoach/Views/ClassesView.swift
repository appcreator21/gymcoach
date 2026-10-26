import SwiftUI
import HealthKit

struct ClassesView: View {
    @State private var kind: ClassKind?
    @State private var selected: GuidedClass?

    private var visible: [GuidedClass] {
        ClassLibrary.all.filter { kind == nil || $0.kind == kind }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", icon: nil, on: kind == nil) { kind = nil }
                        ForEach(ClassKind.allCases) { k in
                            chip(k.rawValue, icon: k.icon, on: kind == k) { kind = k }
                        }
                    }
                }
                ForEach(visible) { c in
                    Button { selected = c; Haptics.select() } label: {
                        GlassCard {
                            HStack(spacing: 14) {
                                Image(systemName: c.kind.icon).font(.title2).foregroundStyle(Theme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                                    Text(c.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    Text("\(c.minutes) min  -  \(c.level)").font(.caption.weight(.semibold)).foregroundStyle(Theme.mint)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selected) { ClassPlayerView(guided: $0) }
    }

    private func chip(_ title: String, icon: String?, on: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.select() } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(on ? Color.white : Theme.card, in: Capsule())
            .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}

/// The interval player: one step at a time, countdown ring, haptics at each
/// change, spoken cues, and a three second count-in at the end of every step.
struct ClassPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let guided: GuidedClass

    @State private var index = 0
    @State private var remaining = 0.0
    @State private var paused = true
    @State private var started = false
    @State private var finished = false
    @State private var startedAt = Date()
    @State private var lastWhole = -1
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var step: ClassStep { guided.steps[min(index, guided.steps.count - 1)] }
    private var next: ClassStep? { index + 1 < guided.steps.count ? guided.steps[index + 1] : nil }
    private var secondsLeftTotal: Int {
        Int(remaining.rounded(.up)) + guided.steps.dropFirst(index + 1).reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if finished { done } else { player }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true; remaining = Double(guided.steps[0].seconds) }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; VoiceCoach.shared.stop() }
        .onReceive(tick) { _ in advance() }
    }

    private var player: some View {
        VStack(spacing: 24) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).padding(12).background(Theme.card, in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(guided.title).font(.system(.headline, design: .rounded))
                    Text("Step \(index + 1) of \(guided.steps.count)  -  \(formatClock(secondsLeftTotal)) left")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(1 - remaining / Double(max(step.seconds, 1))))
                    .stroke(step.isRest ? Theme.accent2 : Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(step.isRest ? "REST" : guided.kind.rawValue.uppercased())
                        .font(.caption.weight(.heavy)).foregroundStyle(step.isRest ? Theme.accent2 : Theme.accent)
                    Text("\(Int(remaining.rounded(.up)))")
                        .font(.system(size: 88, weight: .heavy, design: .rounded).monospacedDigit())
                }
            }
            .frame(width: 280, height: 280)
            VStack(spacing: 8) {
                Text(step.name).font(.system(.title, design: .rounded, weight: .heavy)).multilineTextAlignment(.center)
                Text(step.cue).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            if let next, !step.isRest {
                Label("Next: \(next.name)", systemImage: "forward.fill").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 14) {
                Button { skip(-1) } label: { Image(systemName: "backward.fill").frame(width: 56, height: 56).background(Theme.card, in: Circle()) }
                Button { toggle() } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill").font(.title2).foregroundStyle(.black)
                        .frame(width: 76, height: 76).background(Color.white, in: Circle())
                }
                Button { skip(1) } label: { Image(systemName: "forward.fill").frame(width: 56, height: 56).background(Theme.card, in: Circle()) }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var done: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 72)).foregroundStyle(Theme.mint)
            Text("Class complete").font(.system(.title, design: .rounded, weight: .heavy))
            Text("\(guided.title)  -  \(formatDuration(Date().timeIntervalSince(startedAt)))").foregroundStyle(.secondary)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 40).padding(.top, 10)
        }
    }

    private func toggle() {
        if !started {
            started = true
            startedAt = Date()
            announce(step, first: true)
        }
        paused.toggle()
        Haptics.rigid()
    }

    private func skip(_ direction: Int) {
        let target = index + direction
        guard target >= 0, target < guided.steps.count else { return }
        index = target
        remaining = Double(guided.steps[target].seconds)
        lastWhole = -1
        Haptics.select()
        if started { announce(guided.steps[target], first: false) }
    }

    private func advance() {
        guard started, !paused, !finished else { return }
        remaining -= 0.1
        let whole = Int(remaining.rounded(.up))
        if whole != lastWhole {
            lastWhole = whole
            if whole <= 3 && whole >= 1 {
                Haptics.soft()
                if whole == 3 { VoiceCoach.shared.speak("three, two, one") }
            }
        }
        if remaining <= 0 {
            if index + 1 < guided.steps.count {
                index += 1
                remaining = Double(guided.steps[index].seconds)
                lastWhole = -1
                Haptics.thud()
                announce(guided.steps[index], first: false)
            } else {
                finish()
            }
        }
    }

    private func announce(_ s: ClassStep, first: Bool) {
        if s.isRest {
            VoiceCoach.shared.speak("Rest. \(s.cue)")
        } else {
            VoiceCoach.shared.speak(first ? "Let's go. \(s.name)" : "\(s.name). Go")
        }
    }

    private func finish() {
        finished = true
        Haptics.success()
        VoiceCoach.shared.speak("Great work. Class complete.")
        ClassLog.record(guided)
        if Prefs.bool(Prefs.healthSync, default: false) {
            let activity: HKWorkoutActivityType = {
                switch guided.kind {
                case .hiit: return .highIntensityIntervalTraining
                case .cardio: return .mixedCardio
                case .core: return .coreTraining
                case .yoga: return .yoga
                case .mobility: return .flexibility
                }
            }()
            let start = startedAt
            Task { await HealthKitManager.shared.saveWorkout(start: start, end: Date(), activity: activity) }
        }
    }

    private func formatClock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}

/// Completed classes, kept on the device.
enum ClassLog {
    private static let key = "classLog"

    static func record(_ c: GuidedClass) {
        var log = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        log.append(["id": c.id, "title": c.title, "date": Date().timeIntervalSince1970])
        UserDefaults.standard.set(Array(log.suffix(200)), forKey: key)
    }

    static var thisWeek: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        let log = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        return log.filter { week.contains(Date(timeIntervalSince1970: $0["date"] as? Double ?? 0)) }.count
    }
}
