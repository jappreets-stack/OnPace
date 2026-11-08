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
            curve = await Pace.learnCurve(from: health)
            // For the home-screen widget: today's steps and the goal, in the shared App Group.
            let shared = Shared.defaults
            shared.set(today, forKey: Shared.stepsKey)
            shared.set(Date.now.timeIntervalSince1970, forKey: Shared.stepsDateKey)
            if let todayMeters { shared.set(todayMeters, forKey: Shared.metersKey) }
            // The watch shows the same streak, week and forecast as the phone.
            shared.set(streak, forKey: Shared.streakKey)
            shared.set(week.map { "\($0.steps)" }.joined(separator: ","), forKey: Shared.weekKey)
            shared.set(curve.map { $0.map { "\($0)" }.joined(separator: ",") } ?? "", forKey: Shared.curveKey)
            shared.set(goal, forKey: Shared.goalKey)
            for key in [Shared.avatarKey, Shared.lookKey] {   // the medium widget shows your mini-me
                if let v = UserDefaults.standard.string(forKey: key) { shared.set(v, forKey: key) }
            }
            WidgetCenter.shared.reloadAllTimelines()
            error = nil
            await importWorkouts()   // finished Apple workouts become sessions (Sessions.swift)
            shareTodaysSessions()    // and the watch shows today's sessions too
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

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var store = StepStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("goal") private var goal = 10_000
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("roundStart") private var roundStart: Double = 0
    @AppStorage("avatar") private var avatar: Avatar = .golfer
    @AppStorage("look") private var look: Look = .starter
    @AppStorage("sessionKind") private var sessionKind: SessionKind = .golf
    private let funUnit = FunUnit.walked
    @State private var showSettings = false
    @AppStorage("didSetup") private var didSetup = true
    @AppStorage("appStyle") private var appStyle: AppStyle = .minimal
    @State private var tab = "today"
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var retroNumberSize: CGFloat = 60

    private var progress: Double { min(Double(store.today) / Double(goal), 1) }
    private var hitGoal: Bool { store.today >= goal }

    // Pace: assumes you walk between 7am and 10pm (see Pace.swift).
    private var pace: Pace { Pace(steps: store.today, goal: goal, curve: store.curve) }
    private var onPace: Bool { pace.onPace }

    // What your character does: swing in a golf round, walk with a prop in other sessions,
    // walk while you walk, celebrate at goal, stand on pace, slump behind.
    private var mood: Mood {
        if roundStart > 0 { return sessionKind == .golf ? .swing : .walk }
        return .everyday(walking: walking.isWalking, hitGoal: hitGoal, onPace: onPace)
    }
    @StateObject private var walking = WalkingDetector()   // walks while you walk (Walking.swift)

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "figure.walk", value: "today") {
                switch appStyle {
                case .original: today
                case .minimal: minimalToday
                case .retro16: retroToday
                }
            }
            Tab("History", systemImage: "calendar", value: "history") { history }
        }
        #if DEBUG
        // Simulator testing: launch with `-startTab history` to open on the History tab.
        .onAppear { if let t = UserDefaults.standard.string(forKey: "startTab") { tab = t } }
        #endif
        .tint(Color.primary)
        .preferredColorScheme(theme.scheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(goal: $goal, theme: $theme, avatar: $avatar, look: $look)
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
            if phase == .active {
                Task { await store.refresh(goal: goal) }
                if didSetup { walking.start() }
            } else if phase == .background {
                walking.stop()
            }
        }
        .onChange(of: goal) { _, newGoal in
            Task { await store.refresh(goal: newGoal) }
        }
    }

    // Today: the ring, what's left, whether you're on pace, and sessions. Nothing else.
    private var today: some View {
        ZStack {
            theme.background.ignoresSafeArea()
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
                    infoRows(symbols: false)
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
        }
    }

    // Left to goal, pace, forecast, streak. Original uses emoji; Clean minimal and 16-bit use SF Symbols.
    private func infoRows(symbols: Bool, tint: Color = Minimal.accent) -> some View {
        return VStack(spacing: 0) {
            InfoRow(icon: "👟", label: hitGoal ? "Goal hit 🎉" : "Left to goal",
                    value: hitGoal ? "+\((store.today - goal).formatted())"
                                   : (goal - store.today).formatted(),
                    symbol: symbols ? (hitGoal ? "checkmark.circle.fill" : "figure.walk") : nil, symbolTint: tint)
            if !hitGoal {
                Divider().padding(.leading, 52)
                InfoRow(icon: onPace ? "✅" : "⏳", label: onPace ? "On pace" : "Behind pace",
                        detail: onPace ? nil : "walk \(pace.catchUpMinutes) min to catch up",
                        value: onPace ? "" : pace.behind.formatted(),
                        valueColor: .orange,
                        symbol: symbols ? "gauge.with.dots.needle.67percent" : nil,
                        symbolTint: onPace ? tint : .orange)
            }
            if let f = pace.forecastRow {
                Divider().padding(.leading, 52)
                InfoRow(icon: "🏁", label: "At this pace", detail: f.detail, value: f.value,
                        symbol: symbols ? "flag.checkered" : nil, symbolTint: tint)
            }
            Divider().padding(.leading, 52)
            InfoRow(icon: "🔥", label: "Streak", value: "\(store.streak) \(store.streak == 1 ? "day" : "days")",
                    symbol: symbols ? "flame.fill" : nil, symbolTint: .orange)
        }
    }

    // Clean minimal Today: no scene, grouped background, a thick ring and one card of rows.
    private var minimalToday: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .accessibilityLabel("Settings")
                }
                minimalRing
                if store.week.isEmpty == false && store.week.allSatisfy({ $0.steps == 0 }) {
                    NoStepsHelp()
                }
                infoRows(symbols: true)
                    .minimalCard()
                SessionCard(store: store, theme: theme)
                if let error = store.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Minimal.background.ignoresSafeArea())
    }

    // 16-bit adventure Today: a pixel world with a gold block ring, the big number, then blue menu panels.
    private var retroToday: some View {
        let night = colorScheme == .dark
        let ink = Retro16.text(night: night)
        return ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Retro16GearButton { showSettings = true }
                }
                .padding(.bottom, -8)
                ringLabel(
                    VStack(spacing: 10) {
                        Retro16SceneWindow(look: look, avatar: avatar, mood: mood, progress: progress)
                        VStack(spacing: 2) {
                            Text(store.today, format: .number)
                                .font(.system(size: min(retroNumberSize, 84), weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(ink)
                                .shadow(color: Retro16.textShadow(night: night), radius: 0, x: 2, y: 2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("of \(goal.formatted()) steps")
                                .font(.headline)
                                .foregroundStyle(ink.opacity(0.8))
                            Text(funUnit.phrase(store.today, meters: store.todayMeters))
                                .font(.subheadline)
                                .foregroundStyle(ink.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .multilineTextAlignment(.center)
                    }
                )
                if store.week.isEmpty == false && store.week.allSatisfy({ $0.steps == 0 }) {
                    NoStepsHelp()
                }
                infoRows(symbols: true, tint: Retro16.gold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .retro16Panel()
                SessionCard(store: store, theme: theme)
                if let error = store.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Retro16.page(night: night).ignoresSafeArea())
    }

    private var minimalRing: some View {
        ringLabel(
            MinimalRing(progress: progress) {
                VStack(spacing: 2) {
                    miniMe(width: 72, height: 100)
                    Text(store.today, format: .number)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("of \(goal.formatted()) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(funUnit.phrase(store.today, meters: store.todayMeters))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: 170)       // stays inside the ring
            }
            .frame(width: 270, height: 270)
        )
    }

    // History: the last 7 days, then every saved session.
    private var history: some View {
        NavigationStack {
            ZStack {
                Group {
                    switch appStyle {
                    case .original: theme.background
                    case .minimal: Minimal.background
                    case .retro16: Retro16.page(night: colorScheme == .dark)
                    }
                }
                .ignoresSafeArea()
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

    private var ring: some View {
        ringLabel(ZStack {
            Circle()
                .stroke(.ultraThinMaterial, lineWidth: 20)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(hitGoal ? theme.done : theme.ring,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 4) {
                miniMe(width: 110, height: 125)
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
        )
    }

    // Your mini-me inside the ring.
    private func miniMe(width: CGFloat, height: CGFloat) -> some View {
        CharacterView(avatar: avatar, mood: mood, look: look,
                      prop: roundStart > 0 ? sessionKind.prop : nil)
            .frame(width: width, height: height)
    }

    // VoiceOver reads the ring as one thing: steps, goal, distance. Shared by every style.
    private func ringLabel(_ ring: some View) -> some View {
        ring
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(store.today.formatted()) of \(goal.formatted()) steps. \(funUnit.phrase(store.today, meters: store.todayMeters)).")
    }

    // Last 7 days, in each style's card.
    @ViewBuilder private var weekTable: some View {
        switch appStyle {
        case .original:
            weekContent.padding().background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        case .minimal:
            weekContent.padding().background(Minimal.card, in: RoundedRectangle(cornerRadius: 22))
        case .retro16:
            weekContent.padding(20).retro16Panel()
        }
    }

    // A summary row, then one line per day (newest first).
    private var weekContent: some View {
        let days = Array(store.week.reversed())
        let daysHit = store.week.filter { $0.steps >= goal }.count
        let average = store.week.isEmpty ? 0 : store.week.map(\.steps).reduce(0, +) / store.week.count

        return VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 days").font(.title2.weight(.bold))

            HStack(spacing: 0) {
                BigNumber(value: average.formatted(), label: "Daily average", color: appStyle == .original ? theme.ring : .primary)
                Divider().frame(height: 60)
                BigNumber(value: "\(daysHit) of \(store.week.count)", label: "Days at goal",
                          color: appStyle == .retro16 ? Retro16.gold : appStyle == .minimal ? Minimal.accent : theme.done)
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
                    if appStyle == .retro16 {
                        Retro16DayBar(fraction: min(Double(day.steps) / Double(goal), 1), look: look, avatar: avatar,
                                      mood: hit ? .celebrate : isToday ? .walk : .slump)
                    } else {
                        MiniBar(fraction: min(Double(day.steps) / Double(goal), 1),
                                color: appStyle == .minimal ? Minimal.accent.opacity(hit ? 1 : 0.55)
                                                        : (hit ? theme.done : theme.ring.opacity(0.6)),
                                avatar: avatar, look: look,
                                mood: hit ? .celebrate : isToday ? .walk : .slump)
                    }
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
    var symbol: String? = nil          // SF Symbol instead of the emoji (Clean minimal)
    var symbolTint: Color = .secondary
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Very large text: number goes under the label so nothing wraps mid-word.
        let stacked = typeSize.isAccessibilitySize
        HStack(alignment: stacked ? .top : .center, spacing: 14) {
            Group {
                if let symbol {
                    Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(symbolTint)
                } else {
                    Text(icon).font(.title2)
                }
            }
            .frame(width: 38)
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
    @AppStorage("importWorkouts") private var importWorkouts = true
    @AppStorage("didSetup") private var didSetup = true
    @AppStorage("appStyle") private var appStyle: AppStyle = .minimal
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
                    Toggle("Add workouts automatically", isOn: $importWorkouts)
                } header: {
                    Text("Apple Workout app")
                } footer: {
                    Text("When you end a Golf, Hike, Walk, Run or Strength workout in Apple's Workout app, it shows up here as a session with its steps.")
                }
                Section {
                    Picker("Style", selection: $appStyle) {
                        ForEach(AppStyle.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Look")
                } footer: {
                    switch appStyle {
                    case .original:
                        Text("Style changes how the whole app looks. Original has emoji icons and a blue ring.")
                    case .minimal:
                        Text("Style changes how the whole app looks. Clean minimal is simple and calm, with no scene behind your mini-me.")
                    case .retro16:
                        Text("Style changes how the whole app looks. 16-bit adventure draws everything like an old video game: your mini-me in pixels, a castle world, and a ring of gold blocks.")
                    }
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
