import SwiftUI
import HealthKit
import Combine

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
    @Published var week: [DaySteps] = []
    @Published var streak = 0
    @Published var curve: [Double]?   // your usual day, learned from the last 30 days
    @Published var error: String?

    private let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var ready = false

    func start(goal: Int) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "Health data isn't available on this device."
            return
        }
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType])
            ready = true
            await refresh(goal: goal)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh(goal: Int) async {
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
            curve = await Pace.learnCurve(from: health)
            error = nil
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
    case system, dark, purpleGold, golf
    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: "Auto"
        case .dark: "Dark"
        case .purpleGold: "Purple & gold"
        case .golf: "Golf green"
        }
    }
    // nil = follow the iPhone's Light/Dark setting
    var scheme: ColorScheme? {
        self == .system ? nil : .dark
    }
    var background: Color {
        switch self {
        case .system: Color(uiColor: .systemBackground)
        case .dark: .black
        case .purpleGold: Color(red: 0.16, green: 0.06, blue: 0.27)
        case .golf: Color(red: 0.12, green: 0.38, blue: 0.20)
        }
    }
    var ring: Color {
        switch self {
        case .system, .dark: .blue
        case .purpleGold: Color(red: 0.99, green: 0.73, blue: 0.15)
        case .golf: .white
        }
    }
    var done: Color {
        switch self {
        case .system, .dark: .green
        case .purpleGold: Color(red: 0.99, green: 0.73, blue: 0.15)
        case .golf: .yellow
        }
    }
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var store = StepStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("goal") private var goal = 10_000
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("roundStart") private var roundStart: Double = 0
    @AppStorage("avatar") private var avatar: Avatar = .golfer
    @AppStorage("look") private var look: Look = .original
    @AppStorage("sessionKind") private var sessionKind: SessionKind = .golf
    @AppStorage("funUnit") private var funUnit: FunUnit = .holes
    @State private var showSettings = false

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
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill").font(.title2)
                        }
                    }
                    ring
                    VStack(spacing: 4) {
                        Text(hitGoal ? "Goal hit 🎉" : "\((goal - store.today).formatted()) to go")
                            .font(.title2.weight(.semibold))
                        // At today's speed: when you'll finish.
                        if let forecast = pace.forecastSentence {
                            Text("🏁 \(forecast)")
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    HStack(spacing: 12) {
                        StatTile(title: "Streak", value: "🔥 \(store.streak)",
                                 detail: store.streak == 1 ? "day" : "days")
                        StatTile(title: funUnit.tileTitle, value: "\(funUnit.emoji) \(funUnit.amount(store.today))",
                                 detail: funUnit.detail)
                        StatTile(title: pace.isPersonal ? "Your pace" : "Pace", value: onPace ? "✅" : "⏳",
                                 detail: onPace ? "on pace" : "\(pace.behindText)\nwalk \(pace.catchUpMinutes) min")
                    }
                    .fixedSize(horizontal: false, vertical: true)   // all tiles as tall as the tallest
                    SessionCard(store: store, theme: theme)
                    weekTable
                    if let error = store.error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding()
            }
        }
        .tint(Color.primary)
        .preferredColorScheme(theme.scheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(goal: $goal, theme: $theme, avatar: $avatar, look: $look, funUnit: $funUnit)
        }
        .task { await store.start(goal: goal) }
        // Re-read steps every time you come back to the app.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh(goal: goal) } }
        }
        .onChange(of: goal) { _, newGoal in
            Task { await store.refresh(goal: newGoal) }
        }
    }

    private var ring: some View {
        ZStack {
            // Scene for your fun unit (golf rounds always get the golf course).
            UnitScene(unit: roundStart > 0 && sessionKind == .golf ? .holes : funUnit)
                .clipShape(Circle().inset(by: 10))
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 20)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(hitGoal ? theme.done : theme.ring,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                CharacterView(avatar: avatar, mood: mood, look: look,
                              prop: roundStart > 0 ? sessionKind.prop : nil)
                    .frame(width: 110, height: 125)
                Text(store.today, format: .number)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("of \(goal.formatted()) steps")
                    .font(.footnote)
                    .foregroundStyle(Color.primary.opacity(0.7))
            }
        }
        .frame(width: 270, height: 270)
    }

    // Last 7 days: a summary row, then one line per day (newest first).
    private var weekTable: some View {
        let days = Array(store.week.reversed())
        let daysHit = store.week.filter { $0.steps >= goal }.count
        let average = store.week.isEmpty ? 0 : store.week.map(\.steps).reduce(0, +) / store.week.count
        let best = store.week.max { $0.steps < $1.steps }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 days").font(.headline)

            HStack(spacing: 10) {
                StatTile(title: "Days hit", value: "\(daysHit)/\(store.week.count)",
                         detail: daysHit == store.week.count ? "perfect week 🔥" : "at goal")
                StatTile(title: "Daily avg", value: average.formatted(), detail: "steps")
                StatTile(title: "Best day", value: (best?.steps ?? 0).formatted(),
                         detail: best.map { $0.date.formatted(.dateTime.weekday(.wide)) } ?? "–")
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Day")
                    Text("Steps").gridColumnAlignment(.trailing)
                    Text("vs goal")
                    Text("")
                }
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.6))

                ForEach(days) { day in
                    let hit = day.steps >= goal
                    GridRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Calendar.current.isDateInToday(day.date)
                                 ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.subheadline.weight(.semibold))
                            Text(day.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(Color.primary.opacity(0.6))
                        }
                        Text(day.steps.formatted())
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        // A tiny you: celebrating at the flag on goal days, slumped where you
                        // stopped on missed days (still walking today).
                        MiniBar(fraction: min(Double(day.steps) / Double(goal), 1),
                                color: hit ? theme.done : theme.ring.opacity(0.6),
                                avatar: avatar,
                                look: look,
                                mood: hit ? .celebrate
                                    : Calendar.current.isDateInToday(day.date) ? .walk : .slump)
                        Text(hit ? funUnit.goalFlag : "−\((goal - day.steps).formatted())")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(hit ? Color.primary : Color.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
            Text(title).font(.caption).foregroundStyle(Color.primary.opacity(0.7))
            Text(value).font(.title3.weight(.bold))
            Text(detail).font(.caption2).foregroundStyle(Color.primary.opacity(0.7))
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
                        ForEach(FunUnit.allCases) { Text("\($0.emoji) \($0.name)").tag($0) }
                    }
                } header: {
                    Text("Fun unit")
                } footer: {
                    Text("Turns your steps into something you can picture, like golf holes or soccer fields. Shown on the main screen and in sessions.")
                }
                Section("Look") {
                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview { ContentView() }
