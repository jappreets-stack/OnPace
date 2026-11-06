import SwiftUI
import HealthKit
import Combine
import WatchKit
import WidgetKit

struct WatchDay: Identifiable {
    let date: Date
    let steps: Int
    var id: Date { date }
}

// Reads steps from Apple Health on the watch: today, the last 7 days, and your streak.
final class WatchStepStore: ObservableObject {
    @Published var today = 0
    @Published var todayMeters: Double?   // real distance walked today (Health)
    @Published var week: [WatchDay] = []
    @Published var streak = 0
    @Published var curve: [Double]?   // your usual day, learned from the last 30 days
    @Published var error: String?

    private let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var ready = false

    func start(goal: Int) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "Health data isn't available."
            return
        }
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType, WalkDistance.type])
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
            var days: [WatchDay] = []
            for offset in (0...60).reversed() {
                let day = cal.date(byAdding: .day, value: -offset, to: todayStart)!
                let n = collection.statistics(for: day)?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                days.append(WatchDay(date: day, steps: Int(n)))
            }
            today = days.last?.steps ?? 0
            todayMeters = await WalkDistance.meters(health, from: todayStart)
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
            // Update the watch face complications with the fresh numbers.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// Ring colors you can pick on the last page.
enum RingStyle: String, CaseIterable, Identifiable {
    case icon, purpleGold, classic, ocean, golf
    var id: String { rawValue }

    var name: String {
        switch self {
        case .icon: "App icon green"
        case .purpleGold: "Purple & gold"
        case .classic: "Orange"
        case .ocean: "Blue"
        case .golf: "Golf"
        }
    }
    var ring: Color {
        switch self {
        case .icon: Color(red: 0.19, green: 0.82, blue: 0.36)
        case .purpleGold: Color(red: 0.42, green: 0.22, blue: 0.68)
        case .classic: .orange
        case .ocean: .blue
        case .golf: .white
        }
    }
    // Color once you hit your goal.
    var done: Color {
        switch self {
        case .icon: .mint
        case .purpleGold: Color(red: 0.99, green: 0.73, blue: 0.15)
        case .classic, .ocean: .green
        case .golf: .yellow
        }
    }
}

struct ContentView: View {
    @StateObject private var store = WatchStepStore()
    @Environment(\.scenePhase) private var scenePhase
    // Sent from the iPhone (see WatchSync), stored in the App Group the complications read too.
    @AppStorage(Shared.goalKey, store: Shared.defaults) private var goal = 10_000
    @AppStorage(Shared.avatarKey, store: Shared.defaults) private var avatar: Avatar = .golfer
    @AppStorage(Shared.lookKey, store: Shared.defaults) private var look: Look = .original
    @AppStorage(Shared.funUnitKey, store: Shared.defaults) private var funUnit: FunUnit = .holes
    // Watch only.
    @AppStorage("ringStyle") private var style: RingStyle = .icon

    private var progress: Double { min(Double(store.today) / Double(goal), 1) }
    private var hitGoal: Bool { store.today >= goal }

    // Pace: assumes you walk evenly between 7am and 10pm (see Pace.swift).
    private var pace: Pace { Pace(steps: store.today, goal: goal, curve: store.curve) }
    private var onPace: Bool { pace.onPace }

    // Celebrate at goal, walk on pace, slump behind.
    private var mood: Mood {
        if hitGoal { return .celebrate }
        return onPace ? .walk : .slump
    }

    var body: some View {
        // Scroll the Digital Crown to move between pages.
        TabView {
            ringPage
            statsPage
            weekPage
            colorPage
        }
        .tabViewStyle(.verticalPage)
        .task { await store.start(goal: goal) }
        // Re-read steps every time you raise your wrist / open the app.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh(goal: goal) } }
        }
        // A new goal from the phone changes the streak and bars.
        .onChange(of: goal) { _, newGoal in Task { await store.refresh(goal: newGoal) } }
    }

    // Page 1: big ring, your character, and today's steps.
    private var ringPage: some View {
        GeometryReader { geo in
            // Centered on the whole screen. 77% of the width is the most that still clears
            // the clock (top right) and page dots (right), measured on the Ultra 2.
            let d = min(screen.width * 0.77, screen.height - 88)
            let line = d * 0.08
            let color = hitGoal ? style.done : style.ring
            ZStack {
                // Scene for your fun unit (soccer field, track, ...), same as the phone's ring.
                UnitScene(unit: funUnit, horizon: 124, lowMarks: false)
                    .clipShape(Circle().inset(by: line / 2))
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: line)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AngularGradient(colors: [color.opacity(0.55), color],
                                            center: .center,
                                            startAngle: .degrees(0),
                                            endAngle: .degrees(360 * max(progress, 0.01))),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .animation(.easeOut(duration: 0.6), value: progress)
                VStack(spacing: 0) {
                    CharacterView(avatar: avatar, mood: mood, look: look)
                        .frame(width: d * 0.38, height: d * 0.44)
                    Text(store.today, format: .number)
                        .font(.system(size: d * 0.17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    // Pace: goal hit, on pace, or how far behind + how long to walk.
                    Text(hitGoal ? "🎉 Goal hit"
                         : onPace ? "✅ On pace"
                         : "⏳ \(pace.behindText)")
                        .font(.system(size: d * 0.075, weight: .semibold, design: .rounded))
                        .foregroundStyle(hitGoal || onPace ? color : .orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !hitGoal && !onPace {
                        Text(pace.walkText)
                            .font(.system(size: d * 0.06, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    if let error = store.error {
                        Text(error).font(.caption2).foregroundStyle(.red).lineLimit(2)
                    }
                }
                // Sit a little high so the pace lines clear the bottom of the ring.
                .offset(y: -d * 0.06)
            }
            .frame(width: d, height: d)
            // Center on the physical screen, not the app area (the page dots shift that left).
            .position(x: screen.width / 2 - geo.frame(in: .global).minX,
                      y: screen.height / 2 - geo.frame(in: .global).minY)
        }
        .ignoresSafeArea()
    }

    private var screen: CGRect { WKInterfaceDevice.current().screenBounds }

    // Page 2: streak, pace, finish forecast, fun unit (holes walked, soccer fields, ...).
    private var statsPage: some View {
        VStack(spacing: 5) {
            StatRow(icon: "🔥", title: "Streak",
                    value: "\(store.streak) \(store.streak == 1 ? "day" : "days")")
            StatRow(icon: onPace ? "✅" : "⏳",
                    title: (pace.isPersonal ? "Your pace" : "Pace") + (onPace ? "" : " · \(pace.behindText)"),
                    value: hitGoal ? "Goal hit" : onPace ? "On pace" : "Walk \(pace.catchUpMinutes) min")
            StatRow(icon: "🏁", title: "At this pace",
                    value: pace.forecastShort ?? (hitGoal ? "Goal hit 🎉" : "Too early to tell"))
            StatRow(icon: funUnit.emoji, title: funUnit.title, value: funUnit.amount(store.today, meters: store.todayMeters))
        }
        .padding(.horizontal, 4)
    }

    // Page 3: last 7 days as little bars, ✅ on goal days.
    private var weekPage: some View {
        let daysHit = store.week.filter { $0.steps >= goal }.count
        let average = store.week.isEmpty ? 0 : store.week.map(\.steps).reduce(0, +) / store.week.count
        return VStack(spacing: 6) {
            Text("Last 7 days").font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(store.week) { day in
                    let hit = day.steps >= goal
                    VStack(spacing: 3) {
                        // Flag in the hole on goal days.
                        Text(hit ? funUnit.goalFlag : " ").font(.system(size: 11))
                        Capsule()
                            .fill(hit ? style.done : style.ring.opacity(0.6))
                            .frame(width: 14,
                                   height: max(6, 70 * min(Double(day.steps) / Double(goal), 1)))
                        Text(Calendar.current.isDateInToday(day.date)
                             ? "T" : String(day.date.formatted(.dateTime.weekday(.narrow))))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 100, alignment: .bottom)
            Text("\(daysHit)/\(store.week.count) at goal · avg \(average.formatted())")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // Page 4: your mini-me (set on the iPhone) and the ring color (watch only).
    private var colorPage: some View {
        List {
            Section("Your mini-me") {
                HStack(spacing: 10) {
                    CharacterView(avatar: avatar, mood: .walk, look: look)
                        .frame(width: 30, height: 42)
                    Text("Change your mini-me, goal and fun unit on your iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Ring color") {
                ForEach(RingStyle.allCases) { option in
                    Button {
                        style = option
                    } label: {
                        HStack {
                            Circle().fill(option.ring).frame(width: 14, height: 14)
                            Circle().fill(option.done).frame(width: 14, height: 14)
                            Text(option.name)
                            Spacer()
                            if option == style { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }
    }
}

// One line on the stats page.
struct StatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
