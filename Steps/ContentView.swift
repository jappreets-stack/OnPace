import SwiftUI
import HealthKit
import Combine
import WidgetKit

// MARK: - Data

struct DaySteps: Identifiable {
    let date: Date
    let steps: Int
    var id: Date { date }
}

// Reads steps from Apple Health: today, the last 7 days, and your streak.
@MainActor
final class StepStore: ObservableObject {
    @Published var today = 0
    @Published var todayMeters: Double?   // real distance walked today (Health)
    @Published var week: [DaySteps] = []
    @Published var streak = 0
    @Published var curve: [Double]?   // your usual day, learned from the last 30 days
    @Published var error: String?

    let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var ready = false

    func start(goal: Int) async {
        #if DEBUG
        if UserDefaults.standard.integer(forKey: "demoSteps") > 0 { await refresh(goal: goal); return }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "Health data isn't available on this device."
            return
        }
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType, WalkDistance.type, HKObjectType.workoutType()])
            ready = true
            await refresh(goal: goal)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh(goal: Int) async {
        #if DEBUG
        // Simulator testing: launch with `-demoSteps 6400` to fake today's steps (no Health data there).
        let demo = UserDefaults.standard.integer(forKey: "demoSteps")
        if demo > 0 {
            let cal = Calendar.current
            today = demo
            todayMeters = Double(demo) * 0.72
            week = (0..<7).map { i in
                DaySteps(date: cal.date(byAdding: .day, value: i - 6, to: cal.startOfDay(for: .now))!,
                         steps: i == 6 ? demo : [11_200, 8_400, 12_300, 9_900, 13_600, 10_700][i])
            }
            streak = demo >= goal ? 4 : 3
            return
        }
        #endif
        guard ready else { return }
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let from = cal.date(byAdding: .day, value: -60, to: todayStart)!
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: stepType,
                predicate: HKQuery.predicateForSamples(withStart: from, end: .now)),
            options: .cumulativeSum,
            anchorDate: todayStart,
            intervalComponents: DateComponents(day: 1)
        )
        do {
            let collection = try await query.result(for: health)
            var days: [DaySteps] = []
            for offset in (0...60).reversed() {
                let day = cal.date(byAdding: .day, value: -offset, to: todayStart)!
                let n = collection.statistics(for: day)?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                days.append(DaySteps(date: day, steps: Int(n)))
            }
            today = days.last?.steps ?? 0
            week = Array(days.suffix(7))

            // Streak: days in a row at goal. Today only counts once you've hit it.
            var past = days
            if let last = past.last, last.steps < goal { past.removeLast() }
            var count = 0
            for d in past.reversed() {
                if d.steps >= goal { count += 1 } else { break }
            }
            streak = count
            todayMeters = await WalkDistance.meters(health, from: todayStart)
            // For the home-screen widget: today's steps and the goal, in the shared App Group.
            let shared = Shared.defaults
            shared.set(today, forKey: Shared.stepsKey)
            shared.set(Date.now.timeIntervalSince1970, forKey: Shared.stepsDateKey)
            shared.set(goal, forKey: Shared.goalKey)
            for key in [Shared.avatarKey, Shared.lookKey, Shared.funUnitKey] {   // the medium widget shows your mini-me
                if let v = UserDefaults.standard.string(forKey: key) { shared.set(v, forKey: key) }
            }
            WidgetCenter.shared.reloadAllTimelines()
            curve = await Pace.learnCurve(from: health)
            error = nil
            await importWorkouts()   // finished Apple workouts become sessions (Sessions.swift)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension StepStore {
    // Steps between two times (used for golf rounds).
    func steps(from start: Date, to end: Date = .now) async -> Int {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(
                type: stepType,
                predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum
        )
        let result = try? await query.result(for: health)
        return Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }
}

// MARK: - Themes

enum Theme: String, CaseIterable, Identifiable {
    case system, light, dark   // old "purpleGold" / "golf" saves fall back to Auto
    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    // nil = follow the iPhone's Light/Dark setting
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var background: Color {
        switch self {
        case .system: Color(uiColor: .systemBackground)
        case .light: .white
        case .dark: .black
        }
    }
    var ring: Color { .blue }
    var done: Color { .green }
}

// How much of the scene shows behind the Today screen.
enum SceneStyle: String, CaseIterable, Identifiable {
    case full, calm, plain
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var store = StepStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("goal") private var goal = 10_000
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("sceneStyle") private var sceneStyle: SceneStyle = .calm
    @AppStorage("roundStart") private var roundStart: Double = 0
    @AppStorage("avatar") private var avatar: Avatar = .golfer
    @AppStorage("look") private var look: Look = .starter
    @AppStorage("sessionKind") private var sessionKind: SessionKind = .golf
    @AppStorage("funUnit") private var funUnit: FunUnit = .holes
    @AppStorage("distancePlace") private var place: DistancePlace = .road
    @Environment(\.colorScheme) private var colorScheme
    @State private var miniMeFrame: CGRect = .zero   // where the mini-me is on screen (the scene's ground lines up with its feet)
    @State private var screenSize: CGSize = .zero
    @State private var showSettings = false
    @StateObject private var ringTap = RingTap()   // tap the ring: mini-me talks, plays, runs (RingTap.swift)
    @AppStorage("didSetup") private var didSetup = true

    private var progress: Double { min(Double(store.today) / Double(goal), 1) }
    private var hitGoal: Bool { store.today >= goal }

    // Pace: assumes you walk between 7am and 10pm (see Pace.swift).
    private var pace: Pace { Pace(steps: store.today, goal: goal, curve: store.curve) }
    private var onPace: Bool { pace.onPace }

    // What your character does: swing in a golf round, walk with a prop in other sessions,
    // celebrate at goal, walk on pace, slump behind.
    private var mood: Mood {
        if roundStart > 0 { return sessionKind == .golf ? .swing : .walk }
        if hitGoal { return .celebrate }
        return onPace ? .walk : .slump
    }

    var body: some View {
        TabView {
            Tab("Today", systemImage: "figure.walk") { today }
            Tab("History", systemImage: "calendar") { history }
        }
        .tint(Color.primary)
        .preferredColorScheme(theme.scheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(goal: $goal, theme: $theme, avatar: $avatar, look: $look, funUnit: $funUnit)
        }
        // First-time setup (Onboarding.swift). Health access is asked there, not here.
        .fullScreenCover(isPresented: Binding(get: { !didSetup }, set: { didSetup = !$0 })) {
            Onboarding(store: store, theme: theme)
        }
        .task { if didSetup { await store.start(goal: goal) } }
        .onChange(of: didSetup) { _, done in
            if done { Task { await store.start(goal: goal) } }
        }
        // Re-read steps every time you come back to the app.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh(goal: goal) } }
        }
        .onChange(of: goal) { _, newGoal in
            Task { await store.refresh(goal: newGoal) }
        }
    }

    // Today: the ring, what's left, whether you're on pace, and sessions. Nothing else.
    private var today: some View {
        ZStack {
            // The scene for your fun unit fills the whole screen; its ground lines up with your mini-me's feet.
            BackdropView(backdrop: backdrop, horizon: horizonY, signText: funUnit == .km ? "1 km" : "1 mi",
                         tapeBroken: ringTap.tapeBroken, animated: sceneStyle == .full)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
                // Calm: the same scene, softly blurred and faded so the ring and numbers lead.
                .blur(radius: sceneStyle == .calm ? 7 : 0)
                .overlay { theme.background.opacity(sceneStyle == .calm ? 0.35 : 0).ignoresSafeArea() }
                // Plain: just the theme color.
                .overlay { if sceneStyle == .plain { theme.background.ignoresSafeArea() } }
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill").font(.title2)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Settings")
                    }
                    ring
                    if store.week.isEmpty == false && store.week.allSatisfy({ $0.steps == 0 }) {
                        NoStepsHelp()
                    }
                    // One card of plain rows: label on the left, number on the right.
                    VStack(spacing: 0) {
                        InfoRow(icon: "👟", label: hitGoal ? "Goal hit 🎉" : "Left to reach goal",
                                value: hitGoal ? "+\((store.today - goal).formatted())"
                                               : (goal - store.today).formatted())
                        if !hitGoal {
                            Divider().padding(.leading, 52)
                            InfoRow(icon: onPace ? "✅" : "⏳", label: onPace ? "On pace" : "Behind pace",
                                    detail: onPace ? nil : "walk \(pace.catchUpMinutes) min to catch up",
                                    value: onPace ? "" : pace.behind.formatted(),
                                    valueColor: .orange)
                        }
                        if let f = pace.forecastRow {
                            Divider().padding(.leading, 52)
                            InfoRow(icon: "🏁", label: "At this pace", detail: f.detail, value: f.value)
                        }
                        Divider().padding(.leading, 52)
                        InfoRow(icon: "🔥", label: "Streak", value: "\(store.streak) \(store.streak == 1 ? "day" : "days")")
                    }
                    .padding(.horizontal)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                    SessionCard(store: store, theme: theme)
                    if let error = store.error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            // The ball / disc / taxi / flag from a tap, flying through the scene.
            FlightLayer(flight: ringTap.flight)
                .ignoresSafeArea()
        }
    }

    // History: the last 7 days, then every saved session.
    private var history: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        weekTable
                        SessionHistory(theme: theme)
                    }
                    .padding()
                }
            }
            .navigationTitle("History")
        }
    }

    // The scene behind everything: golf rounds always get the golf course.
    private var backdrop: Backdrop {
        roundStart > 0 && sessionKind == .golf ? .golf : Backdrop(unit: funUnit, place: place)
    }

    // Where the scene's ground starts: your mini-me's feet (feet sit at about 96% of its frame's height).
    private var horizonY: Double { miniMeFrame == .zero ? 330 : miniMeFrame.minY + miniMeFrame.height * 0.957 }

    private var quipContext: QuipContext {
        QuipContext(steps: store.today, goal: goal, behind: pace.behind, catchUpMinutes: pace.catchUpMinutes,
                    onPace: onPace, streak: store.streak,
                    distance: funUnit.phrase(store.today, meters: store.todayMeters),
                    session: roundStart > 0 ? (sessionKind == .golf ? "round" : sessionKind.name.lowercased()) : nil,
                    golfRound: roundStart > 0 && sessionKind == .golf)
    }

    // Tap: the mini-me does its sport move toward the scene's target, then says something.
    private func tapRing() {
        let f = BackdropFrame(size: screenSize, horizon: horizonY, center: screenSize.width / 2,
                              dark: colorScheme == .dark, t: 0)
        let grid = SportMove.releasePoint(backdrop.play.move)    // on the 100 x 140 character grid
        let s = min(miniMeFrame.width / 100, miniMeFrame.height / 140)
        let release = CGPoint(x: miniMeFrame.minX + (miniMeFrame.width - 100 * s) / 2 + grid.x * s,
                              y: miniMeFrame.minY + (miniMeFrame.height - 140 * s) / 2 + grid.y * s)
        ringTap.tap(quipContext, backdrop: backdrop, release: release, target: backdrop.target(f),
                    miniMeX: miniMeFrame.midX)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.ultraThinMaterial, lineWidth: 20)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(hitGoal ? theme.done : theme.ring,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 4) {
                CharacterView(avatar: avatar,
                              mood: ringTap.move.map { .move($0) } ?? (ringTap.grumpy ? .slump : mood),
                              look: look,
                              prop: roundStart > 0 ? sessionKind.prop : nil,
                              moveStart: ringTap.moveStart)
                    .frame(width: 110, height: 125)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { miniMeFrame = $0 }
                    .scaleEffect(x: ringTap.grumpy ? -1 : 1)        // grumpy: turns away
                    .offset(x: ringTap.travel)                       // sprinting / jogging over to the target
                // Today's steps and distance, on a frosted chip so they read over any scene.
                VStack(spacing: 0) {
                    Text(store.today, format: .number)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    // How far you walked today, in your fun unit ("4.9 miles walked").
                    Text(funUnit.phrase(store.today, meters: store.todayMeters))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 140)       // stays well inside the ring
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
            }
        }
        .frame(width: 270, height: 270)
        // The speech bubble sits just above the ring, its tail pointing down at your mini-me.
        .overlay(alignment: .top) {
            if let line = ringTap.bubble {
                SpeechBubble(text: line)
                    .alignmentGuide(.top) { $0[.bottom] - 4 }
                    .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Circle())
        .onTapGesture { tapRing() }
        #if DEBUG
        // Simulator testing: launch with `-autoTap YES` to tap the ring once, 2 seconds after opening.
        .task {
            guard UserDefaults.standard.bool(forKey: "autoTap") else { return }
            try? await Task.sleep(for: .seconds(2))
            tapRing()
        }
        #endif
        .sensoryFeedback(.impact(weight: .light), trigger: ringTap.taps)
        // VoiceOver reads the ring as one thing: steps, goal, distance, and what a tap does.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.today.formatted()) of \(goal.formatted()) steps. \(funUnit.phrase(store.today, meters: store.todayMeters)).")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Your mini-me does a sport move")
    }

    // Last 7 days: a summary row, then one line per day (newest first).
    private var weekTable: some View {
        let days = Array(store.week.reversed())
        let daysHit = store.week.filter { $0.steps >= goal }.count
        let average = store.week.isEmpty ? 0 : store.week.map(\.steps).reduce(0, +) / store.week.count

        return VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 days").font(.title2.weight(.bold))

            HStack(spacing: 0) {
                BigNumber(value: average.formatted(), label: "Daily average", color: theme.ring)
                Divider().frame(height: 60)
                BigNumber(value: "\(daysHit) of \(store.week.count)", label: "Days at goal", color: theme.done)
            }
            .padding(.vertical, 8)

            // One row per day: date, a bar with a tiny you on it, and the steps.
            ForEach(days) { day in
                let hit = day.steps >= goal
                let isToday = Calendar.current.isDateInToday(day.date)
                Divider()
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.body.weight(.semibold))
                        Text(day.date, format: .dateTime.month(.abbreviated).day())
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.6))
                    }
                    .frame(width: 64, alignment: .leading)
                    MiniBar(fraction: min(Double(day.steps) / Double(goal), 1),
                            color: hit ? theme.done : theme.ring.opacity(0.6),
                            avatar: avatar, look: look,
                            mood: hit ? .celebrate : isToday ? .walk : .slump)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(day.steps.formatted())
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Text(hit ? "\(funUnit.goalFlag) goal" : "\((goal - day.steps).formatted()) short")
                            .font(.subheadline)
                            .foregroundStyle(hit ? Color.primary.opacity(0.6) : Color.orange)
                    }
                    .frame(width: 92, alignment: .trailing)
                }
                // VoiceOver: "Wednesday, 10,319 steps, goal hit" instead of reading each piece.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide))), "
                                    + "\(day.steps.formatted()) steps, "
                                    + (hit ? "goal hit" : "\((goal - day.steps).formatted()) short"))
            }
        }
        .padding()
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
    }
}

// Shown when Apple Health has no steps at all this week: new phone, or Health access turned off.
struct NoStepsHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No steps from Apple Health yet").font(.headline)
            Text("Just installed OnPace? Walk a little and they'll show up. Still 0? Open the Settings app → Health → Data Access & Devices → OnPace, and turn everything on.")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

// A label on the left and a number on the right (main screen card).
struct InfoRow: View {
    let icon: String
    let label: String
    var detail: String? = nil
    let value: String
    var valueColor: Color = .primary
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Very large text: number goes under the label so nothing wraps mid-word.
        let stacked = typeSize.isAccessibilitySize
        HStack(alignment: stacked ? .top : .center, spacing: 14) {
            Text(icon).font(.title2).frame(width: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.title3)
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(Color.primary.opacity(0.6))
                }
                if stacked && !value.isEmpty { valueText }
            }
            if !stacked {
                Spacer(minLength: 8)
                valueText
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value)
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// A big colored number with a small label under it (history header).
struct BigNumber: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.subheadline).foregroundStyle(Color.primary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// A segmented progress bar for each day in the table: 10 blocks, each 10% of the goal,
// with an optional tiny character standing where the filled part ends.
struct MiniBar: View {
    let fraction: Double
    let color: Color
    var avatar: Avatar? = nil
    var look: Look? = nil
    var mood: Mood = .walk

    private let blocks = 10
    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { g in
            let blockWidth = (g.size.width - gap * CGFloat(blocks - 1)) / CGFloat(blocks)
            let filled = fraction * Double(blocks)              // e.g. 6.4 blocks
            let full = Int(filled)
            let partial = filled - Double(full)
            // Where the filled part ends, counting the gaps between blocks.
            let end = CGFloat(full) * (blockWidth + gap) + CGFloat(partial) * blockWidth
            ZStack(alignment: .leading) {
                HStack(spacing: gap) {
                    ForEach(0..<blocks, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.12))
                            .overlay(alignment: .leading) {
                                // Full blocks fill all the way; the last one fills partly.
                                let share = i < full ? 1 : (i == full ? partial : 0)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color)
                                    .frame(width: blockWidth * CGFloat(share))
                            }
                            .frame(width: blockWidth, height: 8)
                    }
                }
                if let avatar {
                    CharacterView(avatar: avatar, mood: mood, look: look)
                        .frame(width: 24, height: 34)
                        .position(x: min(max(end, 12), g.size.width - 12),
                                  y: g.size.height / 2 - 13)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: avatar == nil ? 8 : 40)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(Color.primary.opacity(0.7))
            Text(value).font(.title.weight(.bold))
            Text(detail).font(.subheadline).foregroundStyle(Color.primary.opacity(0.7))
                .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Settings (tap the gear)

struct SettingsView: View {
    @Binding var goal: Int
    @Binding var theme: Theme
    @Binding var avatar: Avatar
    @Binding var look: Look
    @Binding var funUnit: FunUnit
    @AppStorage("distancePlace") private var place: DistancePlace = .road
    @AppStorage("importWorkouts") private var importWorkouts = true
    @AppStorage("didSetup") private var didSetup = true
    @AppStorage("sceneStyle") private var sceneStyle: SceneStyle = .calm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goal") {
                    Stepper("\(goal.formatted()) steps", value: $goal, in: 2_000...30_000, step: 500)
                }
                Section("Character") {
                    NavigationLink {
                        CharacterBuilder(avatar: $avatar, look: $look)
                    } label: {
                        HStack(spacing: 12) {
                            CharacterView(avatar: avatar, mood: .walk, look: look)
                                .frame(width: 40, height: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Build your mini-me")
                                Text("Outfit, skin tone, hair, beard, glasses, colors")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Picker("Show steps as", selection: $funUnit) {
                        ForEach(FunUnit.allCases) { unit in
                            // Make it obvious that km / miles come with a choice of scene.
                            Text("\(unit.emoji) \(unit.name)" + (unit == .km || unit == .mi ? " (road, beach or trail)" : ""))
                                .tag(unit)
                        }
                    }
                    if funUnit == .km || funUnit == .mi {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Walk along a")
                                .font(.subheadline)
                            Picker("Walk along a", selection: $place) {
                                ForEach(DistancePlace.allCases) { Text("\($0.emoji) \($0.name)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                } header: {
                    Text("Fun unit")
                } footer: {
                    Text("Turns your steps into something you can picture, and picks the scene behind your mini-me. Kilometers and Miles let you walk a road, a beach or a mountain trail.")
                }
                Section {
                    Toggle("Add workouts automatically", isOn: $importWorkouts)
                } header: {
                    Text("Apple Workout app")
                } footer: {
                    Text("When you end a Golf, Hike, Walk, Run or Strength workout in Apple's Workout app, it shows up here as a session with its steps.")
                }
                Section {
                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Background", selection: $sceneStyle) {
                        ForEach(SceneStyle.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Look")
                } footer: {
                    Text("Background: Full shows the whole scene, Calm softens it, Plain hides it.")
                }
                Section {
                    Button("Show setup again") {
                        dismiss()
                        // Wait for Settings to close before setup covers the screen.
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            didSetup = false
                        }
                    }
                } footer: {
                    Text("Walks you through goal, mini-me and fun unit again. Your steps and sessions stay.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview { ContentView() }
