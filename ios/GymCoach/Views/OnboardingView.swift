import SwiftUI

// MARK: Answers

struct OnboardingAnswers {
    var name = ""
    var goal: String?
    var reasons: Set<String> = []
    var experience: String?
    var daysPerWeek = 4
    var sessionMinutes = 60
    var location: String?
    var focusAreas: Set<String> = []
    var sex: String?
    var age = 28.0
    var heightCm = 172.0
    var weight = 75.0
    var isPounds = false
    var lifestyle: String?
    var sleep: String?
    var injuries = ""
    var noInjuries = false
    var dislikes = ""
    var style = "SUPPORTIVE"

    var json: [String: Any] {
        var out: [String: Any] = [
            "displayName": name.trimmingCharacters(in: .whitespaces),
            "goal": goal ?? "GENERAL_FITNESS",
            "experience": experience ?? "SOME",
            "daysPerWeek": daysPerWeek,
            "sessionMinutes": sessionMinutes,
            "location": location ?? "COMMERCIAL_GYM",
            "focusAreas": Array(focusAreas),
            "unit": isPounds ? "LB" : "KG",
            "coachingStyle": style,
            "age": Int(age),
            "heightCm": Int(heightCm),
            "bodyweightKg": isPounds ? (weight / 2.20462 * 10).rounded() / 10 : weight,
        ]
        if let sex { out["sex"] = sex }
        if !reasons.isEmpty { out["motivation"] = reasons.sorted().joined(separator: ", ") }
        if let lifestyle { out["lifestyle"] = lifestyle }
        if let sleep { out["sleepHours"] = sleep }
        let hurt = injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        if !noInjuries, !hurt.isEmpty { out["injuries"] = hurt }
        let dislike = dislikes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dislike.isEmpty { out["dislikes"] = dislike }
        return out
    }
}

private struct Choice: Identifiable {
    let id: String
    let icon: String
    let title: String
    var detail: String = ""
}

// MARK: Flow

struct OnboardingView: View {
    @Environment(AppState.self) private var app

    private enum Step: Int, CaseIterable {
        case welcome, name, goal, why, experience, schedule, location, focus
        case body, lifestyle, limits, style, building
    }

    @State private var a = OnboardingAnswers()
    @State private var step: Step = .welcome
    @State private var forward = true
    @FocusState private var nameFocused: Bool

    private let goals = [
        Choice(id: "HYPERTROPHY", icon: "figure.strengthtraining.traditional", title: "Build muscle", detail: "Add size and shape"),
        Choice(id: "STRENGTH", icon: "dumbbell.fill", title: "Get stronger", detail: "Lift heavier, move better"),
        Choice(id: "FAT_LOSS", icon: "flame.fill", title: "Lose fat", detail: "Lean out and keep the muscle"),
        Choice(id: "RECOMP", icon: "arrow.triangle.2.circlepath", title: "Lose fat, build muscle", detail: "Change how you look and perform"),
        Choice(id: "GENERAL_FITNESS", icon: "heart.fill", title: "Feel fitter overall", detail: "Energy, health, consistency"),
    ]
    private let reasons = ["Feel more confident", "Be healthier", "Look better", "Get stronger for a sport",
                           "An event is coming up", "Mental health", "Build a routine", "Rehab or return to training"]
    private let experiences = [
        Choice(id: "NEW", icon: "leaf.fill", title: "Brand new", detail: "I have never trained properly"),
        Choice(id: "SOME", icon: "figure.walk", title: "Getting started", detail: "Under a year of lifting"),
        Choice(id: "EXPERIENCED", icon: "figure.strengthtraining.functional", title: "Experienced", detail: "One to three years"),
        Choice(id: "ADVANCED", icon: "bolt.fill", title: "Advanced", detail: "Three years or more"),
    ]
    private let locations = [
        Choice(id: "COMMERCIAL_GYM", icon: "building.2.fill", title: "A commercial gym", detail: "Full equipment"),
        Choice(id: "HOME_GYM", icon: "house.fill", title: "A home gym", detail: "Rack, bench, dumbbells"),
        Choice(id: "MINIMAL", icon: "backpack.fill", title: "Minimal equipment", detail: "Bands, a few dumbbells"),
        Choice(id: "BODYWEIGHT", icon: "figure.core.training", title: "Bodyweight only", detail: "Anywhere, no gear"),
    ]
    private let lifestyles = [
        Choice(id: "DESK", icon: "laptopcomputer", title: "Mostly seated"),
        Choice(id: "MIXED", icon: "figure.walk.motion", title: "A mix"),
        Choice(id: "ON_FEET", icon: "figure.stand", title: "On my feet"),
        Choice(id: "PHYSICAL", icon: "hammer.fill", title: "Physical work"),
    ]
    private let sleeps = [("UNDER_5", "Under 5 h"), ("FIVE_TO_6", "5 to 6 h"), ("SEVEN_TO_8", "7 to 8 h"), ("OVER_8", "8 h +")]
    private let styles = [
        Choice(id: "PUSH_ME", icon: "flame", title: "Push me", detail: "Hold me to it"),
        Choice(id: "SUPPORTIVE", icon: "hands.clap.fill", title: "Supportive", detail: "Encourage me"),
        Choice(id: "DATA_DRIVEN", icon: "chart.xyaxis.line", title: "Show me the numbers", detail: "Explain the why"),
        Choice(id: "RELAXED", icon: "sun.max.fill", title: "Keep it relaxed", detail: "No pressure"),
    ]

    private var canContinue: Bool {
        switch step {
        case .name: return !a.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .goal: return a.goal != nil
        case .experience: return a.experience != nil
        case .location: return a.location != nil
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome && step != .building { header }
            ZStack {
                page
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .safeAreaInset(edge: .bottom) {
            if step != .building { footer }
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 14) {
            Button { go(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 36, height: 36)
                    .background(Theme.card, in: Circle())
            }
            .foregroundStyle(.white)
            GeometryReader { geo in
                let total = Double(Step.building.rawValue - 1)
                let progress = Double(step.rawValue - 1) / total
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.card)
                    Capsule().fill(Theme.accent)
                        .frame(width: max(8, geo.size.width * progress))
                        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: step)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
        .transition(.opacity)
    }

    private var footer: some View {
        Button(action: { go(1) }) {
            Text(step == .welcome ? "Let's go" : step == .style ? "Build my plan" : "Continue")
                .transaction { $0.animation = nil }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canContinue)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.background)
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        forward = delta > 0
        nameFocused = false
        Haptics.tap()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = next }
    }

    // MARK: Pages

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome: WelcomePage()
        case .name:
            QuestionPage("First things first", "What should I call you?") {
                TextField("Your first name", text: $a.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .submitLabel(.continue)
                    .onSubmit { if canContinue { go(1) } }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.accent).frame(height: 2) }
                    .task { try? await Task.sleep(for: .milliseconds(450)); nameFocused = true }
            }
        case .goal:
            QuestionPage("Hi \(a.firstName)", "What are we training for?") {
                ChoiceList(items: goals, selection: $a.goal)
            }
        case .why:
            QuestionPage("What is behind it?", "Pick any that fit. This is how I keep you motivated.") {
                ChipCloud(items: reasons, selection: $a.reasons)
            }
        case .experience:
            QuestionPage("Your experience", "Be honest, it just helps me set the starting point.") {
                ChoiceList(items: experiences, selection: $a.experience)
            }
        case .schedule:
            QuestionPage("Your week", "How often can you realistically train?") {
                DayPicker(days: $a.daysPerWeek)
                Text("How long per session?").font(.headline).padding(.top, 28)
                MinutesPicker(minutes: $a.sessionMinutes)
            }
        case .location:
            QuestionPage("Where do you train?", "I will only program what you can actually do.") {
                ChoiceList(items: locations, selection: $a.location)
            }
        case .focus:
            QuestionPage("Any priorities?", "Pick the areas you want extra attention on, or skip.") {
                ChipCloud(items: ["Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"], selection: $a.focusAreas)
            }
        case .body:
            QuestionPage("About you", "This keeps your loads and targets accurate.") {
                BodyForm(a: $a)
            }
        case .lifestyle:
            QuestionPage("Outside the gym", "Recovery matters as much as training.") {
                Text("Your typical day").font(.headline)
                ChoiceGrid(items: lifestyles, selection: $a.lifestyle)
                Text("Sleep most nights").font(.headline).padding(.top, 24)
                ChipRow(items: sleeps, selection: $a.sleep)
            }
        case .limits:
            QuestionPage("Anything to work around?", "Injuries, pain or exercises you hate.") {
                TextEditor(text: $a.injuries)
                    .scrollContentBackground(.hidden)
                    .frame(height: 110)
                    .padding(10)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if a.injuries.isEmpty {
                            Text("e.g. left shoulder pinches on overhead press")
                                .foregroundStyle(.tertiary).padding(.horizontal, 15).padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                    .disabled(a.noInjuries)
                    .opacity(a.noInjuries ? 0.4 : 1)
                Toggle("No injuries right now", isOn: $a.noInjuries)
                    .onChange(of: a.noInjuries) { _, _ in Haptics.select() }
                    .tint(Theme.accent)
                TextField("Exercises you dislike (optional)", text: $a.dislikes)
                    .padding(14)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        case .style:
            QuestionPage("How should I coach you?", "I will adapt as I get to know you.") {
                ChoiceList(items: styles, selection: Binding(get: { a.style }, set: { a.style = $0 ?? a.style }))
            }
        case .building:
            BuildingPage(answers: a)
        }
    }
}

private extension OnboardingAnswers {
    var firstName: String {
        name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? "there"
    }
}

// MARK: Page chrome

private struct QuestionPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @State private var shown = false

    init(_ title: String, _ subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.system(size: 32, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(Rise(appeared: shown, delay: 0))
                Text(subtitle).font(.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(Rise(appeared: shown, delay: 0.05))
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(.top, 14)
                    .modifier(Rise(appeared: shown, delay: 0.1))
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onAppear { shown = true }
    }
}

// MARK: Welcome

private struct WelcomePage: View {
    @State private var shown = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                PhaseAnimator([false, true]) { pulse in
                    Circle().stroke(Theme.accent.opacity(pulse ? 0 : 0.5), lineWidth: 2)
                        .frame(width: pulse ? 230 : 120, height: pulse ? 230 : 120)
                } animation: { _ in .easeOut(duration: 1.8) }
                Image("LogoMark").resizable().scaledToFit().frame(height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .scaleEffect(shown ? 1 : 0.6)
            }
            .frame(height: 230)
            Text("I'm Surba.")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .modifier(Rise(appeared: shown, delay: 0.15))
            Text("Your coach. A few quick questions and I will build everything around you, then keep learning as you train.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .modifier(Rise(appeared: shown, delay: 0.25))
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) { shown = true }
            Task { try? await Task.sleep(for: .milliseconds(250)); Haptics.soft() }
        }
    }
}

// MARK: Choices

private struct ChoiceList: View {
    let items: [Choice]
    @Binding var selection: String?
    @State private var shown = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let selected = selection == item.id
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selection = item.id }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.title3).frame(width: 30)
                            .foregroundStyle(selected ? Theme.accent : .secondary)
                            .symbolEffect(.bounce, value: selected)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.headline)
                            if !item.detail.isEmpty {
                                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Theme.accent : Color.white.opacity(0.2))
                            .font(.title3)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2)
                    )
                    .scaleEffect(selected ? 1.02 : 1)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 24)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.12 + Double(index) * 0.06), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}

private struct ChoiceGrid: View {
    let items: [Choice]
    @Binding var selection: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items) { item in
                let selected = selection == item.id
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selection = item.id }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: item.icon).font(.title2)
                            .foregroundStyle(selected ? Theme.accent : .secondary)
                            .symbolEffect(.bounce, value: selected)
                        Text(item.title).font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2)
                    )
                    .scaleEffect(selected ? 1.03 : 1)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
    }
}

private struct ChipCloud: View {
    let items: [String]
    @Binding var selection: Set<String>

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.self) { item in
                let selected = selection.contains(item)
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                        if selected { selection.remove(item) } else { selection.insert(item) }
                    }
                } label: {
                    Text(item).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .foregroundStyle(selected ? Color.black : Color.white)
                        .background(selected ? Theme.accent : Theme.card, in: Capsule())
                        .scaleEffect(selected ? 1.06 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ChipRow: View {
    let items: [(String, String)]
    @Binding var selection: String?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { id, label in
                let selected = selection == id
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { selection = id }
                } label: {
                    Text(label).font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(selected ? Color.black : Color.white)
                        .background(selected ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DayPicker: View {
    @Binding var days: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(days)").font(.system(size: 64, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text(days == 1 ? "day a week" : "days a week").font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { n in
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { days = n }
                    } label: {
                        Text("\(n)").font(.headline)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .foregroundStyle(n <= days ? Color.black : Color.white)
                            .background(n <= days ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MinutesPicker: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach([30, 45, 60, 75, 90], id: \.self) { m in
                let selected = minutes == m
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { minutes = m }
                } label: {
                    Text("\(m)").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .foregroundStyle(selected ? Color.black : Color.white)
                        .background(selected ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        Text("minutes").font(.footnote).foregroundStyle(.secondary)
    }
}

// MARK: Body

private struct BodyForm: View {
    @Binding var a: OnboardingAnswers

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                ForEach([("MALE", "Male"), ("FEMALE", "Female"), ("OTHER", "Other")], id: \.0) { id, label in
                    let selected = a.sex == id
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { a.sex = selected ? nil : id }
                    } label: {
                        Text(label).font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .foregroundStyle(selected ? Color.black : Color.white)
                            .background(selected ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            DetentSlider(title: "Age", value: $a.age, range: 13...80, step: 1, display: "\(Int(a.age))", unit: "years")
            VStack(alignment: .leading, spacing: 10) {
                Picker("Unit", selection: Binding(get: { a.isPounds }, set: { toPounds in
                    guard toPounds != a.isPounds else { return }
                    a.weight = toPounds ? (a.weight * 2.20462).rounded() : (a.weight / 2.20462).rounded()
                    a.isPounds = toPounds
                })) {
                    Text("Metric  (kg, cm)").tag(false)
                    Text("Imperial  (lb, in)").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: a.isPounds) { _, _ in Haptics.select() }
                if a.isPounds {
                    DetentSlider(title: "Height",
                                 value: Binding(get: { (a.heightCm / 2.54).rounded() }, set: { a.heightCm = $0 * 2.54 }),
                                 range: 55...85, step: 1,
                                 display: "\(Int((a.heightCm / 2.54).rounded()) / 12)'\(Int((a.heightCm / 2.54).rounded()) % 12)\"", unit: "")
                } else {
                    DetentSlider(title: "Height", value: $a.heightCm, range: 140...215, step: 1, display: "\(Int(a.heightCm))", unit: "cm")
                }
                DetentSlider(title: "Weight", value: $a.weight,
                             range: a.isPounds ? 90...350 : 40...160, step: 1,
                             display: "\(Int(a.weight))", unit: a.isPounds ? "lb" : "kg")
            }
        }
    }
}

/// Big number plus a slider that clicks on every detent.
private struct DetentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(display).font(.system(size: 44, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: value))
                    .animation(.snappy, value: value)
                Text(unit).font(.title3).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step).tint(Theme.accent)
                .onChange(of: value) { _, _ in Haptics.select() }
        }
    }
}

// MARK: Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 320, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(bounds.width, subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

// MARK: Finale

private struct BuildingPage: View {
    @Environment(AppState.self) private var app
    let answers: OnboardingAnswers

    @State private var done = 0
    @State private var finished = false
    @State private var error: String?
    @State private var opening = false
    @State private var confetti = false

    private var tasks: [String] {
        [
            "Reading your answers",
            "Matching your \(answers.daysPerWeek)-day week",
            "Setting your \(answers.goalTitle.lowercased()) focus",
            "Writing your personal memory file",
        ]
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 22) {
                Spacer()
                if finished {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 54)).foregroundStyle(Theme.accent)
                        .symbolEffect(.bounce, value: finished)
                        .transition(.scale.combined(with: .opacity))
                    Text("You're in, \(answers.firstName).")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Text("I know your goals, your schedule and what to work around. I will keep learning from every session and chat.")
                        .font(.title3).foregroundStyle(.secondary)
                        .transition(.opacity)
                } else {
                    Text("Building your profile").font(.system(size: 32, weight: .heavy, design: .rounded))
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(tasks.enumerated()), id: \.offset) { index, text in
                            HStack(spacing: 12) {
                                ZStack {
                                    if index < done {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                                            .transition(.scale.combined(with: .opacity))
                                    } else if index == done {
                                        ProgressView()
                                    } else {
                                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 2).frame(width: 18, height: 18)
                                    }
                                }
                                .frame(width: 24)
                                Text(text).font(.body)
                                    .foregroundStyle(index <= done ? Color.white : Color.secondary)
                            }
                        }
                    }
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                    Button("Try again") { Task { await run() } }.buttonStyle(PrimaryButtonStyle())
                }
                Spacer()
                if finished {
                    Button {
                        guard !opening else { return }
                        opening = true
                        Haptics.thud()
                        Task { await app.completeOnboarding() }
                    } label: {
                        if opening { ProgressView().tint(.black) } else { Text("Meet Surba") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if confetti { ConfettiBurst().allowsHitTesting(false).ignoresSafeArea() }
        }
        .task { await run() }
    }

    private func run() async {
        error = nil
        done = 0
        let upload = Task { try await app.submitOnboarding(answers.json) }
        for index in 0..<tasks.count {
            try? await Task.sleep(for: .milliseconds(index == 0 ? 500 : 750))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { done = index + 1 }
            Haptics.tap()
        }
        do {
            try await upload.value
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { finished = true }
        confetti = true
        await Haptics.crescendo()
    }
}

private extension OnboardingAnswers {
    var goalTitle: String {
        switch goal {
        case "HYPERTROPHY": return "Muscle"
        case "STRENGTH": return "Strength"
        case "FAT_LOSS": return "Fat loss"
        case "RECOMP": return "Recomp"
        default: return "Fitness"
        }
    }
}

// MARK: Confetti

private struct ConfettiBurst: View {
    private struct Piece {
        let angle: Double, speed: Double, size: CGFloat, spin: Double, color: Color
    }

    @State private var start = Date()
    private let pieces: [Piece] = (0..<90).map { _ in
        let colors: [Color] = [Theme.accent, .white, Theme.mint, Theme.amber, Theme.accent2]
        return Piece(angle: .random(in: -.pi * 0.95 ... -.pi * 0.05), speed: .random(in: 260...620),
                     size: .random(in: 5...10), spin: .random(in: -8...8), color: colors.randomElement() ?? .white)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < 3.2 else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.62)
                for piece in pieces {
                    let x = origin.x + cos(piece.angle) * piece.speed * t
                    let y = origin.y + sin(piece.angle) * piece.speed * t + 520 * t * t
                    let alpha = max(0, 1 - t / 3.2)
                    var layer = context
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(piece.spin * t))
                    layer.opacity = alpha
                    layer.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                               with: .color(piece.color))
                }
            }
        }
        .onAppear { start = Date() }
    }
}
