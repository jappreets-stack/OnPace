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

    let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private var ready = false
    var liveQuery: HKObserverQuery?

    func start(goal: Int) async {
        #if DEBUG
        // Simulator testing: launch with `-demoSteps 6400` to fake today's steps (no Health data there).
        let demo = UserDefaults.standard.integer(forKey: "demoSteps")
        if demo > 0 {
            let cal = Calendar.current
            today = demo
            todayMeters = Double(demo) * 0.72
            week = (0..<7).map { i in
                WatchDay(date: cal.date(byAdding: .day, value: i - 6, to: cal.startOfDay(for: .now))!,
                         steps: i == 6 ? demo : [11_200, 8_400, 12_300, 9_900, 13_600, 10_700][i])
            }
            streak = 3
            return
        }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "Health data isn't available."
            return
        }
        do {
            try await health.requestAuthorization(toShare: [], read: [stepType, WalkDistance.type])
            ready = true
            startLiveUpdates()
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
            todayMeters = await WalkDistance.meters(health, from: todayStart)
            // Today's steps and distance come only from Apple Health on the watch, so they always match
            // the Health app (and other step apps). Mixing in other counters made it too high.
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
            applyPhone()   // the phone's streak, week and usual day win: it has the full step history
            error = nil
            // Update the watch face complications with the fresh numbers.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension WatchStepStore {
    // Today's steps and distance the iPhone last sent (nil if it's from another day).
    // fresh = sent in the last 30 minutes, so it can be shown exactly as the phone shows it.
    nonisolated static func phoneToday() -> (steps: Int, meters: Double?, fresh: Bool)? {
        let d = Shared.defaults
        guard let stamp = Double(d.string(forKey: Shared.stepsDateKey) ?? ""),
              Calendar.current.isDateInToday(Date(timeIntervalSince1970: stamp)),
              let steps = Int(d.string(forKey: Shared.stepsKey) ?? "") else { return nil }
        let fresh = Date.now.timeIntervalSince1970 - stamp < 30 * 60
        return (steps, Double(d.string(forKey: Shared.metersKey) ?? ""), fresh)
    }

    // The phone has the full step history, so past days, the streak and your usual day (which drives
    // "At this pace") come from it. Today's steps always come from the watch's own Health (see refresh).
    func applyPhone() {
        guard let phone = Self.phoneToday() else { return }
        let d = Shared.defaults
        if let s = Int(d.string(forKey: Shared.streakKey) ?? "") { streak = s }
        let phoneWeek = (d.string(forKey: Shared.weekKey) ?? "").split(separator: ",").compactMap { Int($0) }
        if phoneWeek.count == 7 {
            let start = Calendar.current.startOfDay(for: .now)
            week = phoneWeek.enumerated().map { i, steps in
                let day = Calendar.current.date(byAdding: .day, value: i - 6, to: start)!
                if i == 6 { return WatchDay(date: day, steps: today) }
                let own = week.first { Calendar.current.isDate($0.date, inSameDayAs: day) }?.steps ?? 0
                return WatchDay(date: day, steps: max(own, steps))
            }
        } else if let last = week.indices.last {
            week[last] = WatchDay(date: week[last].date, steps: today)
        }
        let phoneCurve = (d.string(forKey: Shared.curveKey) ?? "").split(separator: ",").compactMap { Double($0) }
        if phoneCurve.count == 24 { curve = phoneCurve }
    }
}

extension WatchStepStore {
    // While the app is open, re-read Health whenever the watch saves new steps, so the number
    // keeps climbing as you walk (no need to leave and come back).
    func startLiveUpdates() {
        guard liveQuery == nil else { return }
        let query = HKObserverQuery(sampleType: HKQuantityType(.stepCount), predicate: nil) { [weak self] _, done, _ in
            Task { @MainActor in
                if let self { await self.refresh(goal: Shared.goal) }
            }
            done()
        }
        liveQuery = query
        health.execute(query)
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
    @AppStorage(Shared.lookKey, store: Shared.defaults) private var look: Look = .starter
    private let funUnit = FunUnit.walked
    // Watch only.
    @AppStorage("ringStyle") private var style: RingStyle = .icon
    // Sent by the iPhone with every refresh (see PhoneSync): today's steps and sessions.
    @AppStorage(Shared.stepsDateKey, store: Shared.defaults) private var phoneStamp = ""   // changes with every phone refresh
    @AppStorage(Shared.sessionsKey, store: Shared.defaults) private var sessionsJSON = ""
    private var sessions: [WatchSession] {
        (try? JSONDecoder().decode([WatchSession].self, from: Data(sessionsJSON.utf8))) ?? []
    }

    private var progress: Double { min(Double(store.today) / Double(goal), 1) }
    private var hitGoal: Bool { store.today >= goal }

    // Pace: assumes you walk evenly between 7am and 10pm (see Pace.swift).
    private var pace: Pace { Pace(steps: store.today, goal: goal, curve: store.curve) }
    private var onPace: Bool { pace.onPace }

    // Walks while you walk; otherwise celebrate at goal, stand on pace, slump behind.
    @StateObject private var walking = WalkingDetector()
    private var mood: Mood { .everyday(walking: walking.isWalking, hitGoal: hitGoal, onPace: onPace) }

    var body: some View {
        // Scroll the Digital Crown to move between pages.
        TabView {
            ringPage
            statsPage
            if !sessions.isEmpty { sessionsPage }
            weekPage
            colorPage
            #if DEBUG
            faceLogPage
            #endif
        }
        .tabViewStyle(.verticalPage)
        .task {
            await store.start(goal: goal)
            WatchSync.shared.askPhone()
            walking.start()
        }
        // Re-read steps every time you raise your wrist / open the app.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.refresh(goal: goal) }
                WatchSync.shared.askPhone()   // the phone replies in the background with its latest count
                walking.start()
            } else if phase == .background {
                walking.stop()
            }
        }
        // The phone's latest steps show up right away.
        .onChange(of: phoneStamp) { _, _ in store.applyPhone() }
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
                        .frame(width: d * 0.36, height: d * 0.41)
                    Text(store.today, format: .number)
                        .font(.system(size: d * 0.17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    // How far you walked today, in your fun unit ("4.9 miles walked").
                    Text(funUnit.phrase(store.today, meters: store.todayMeters))
                        .font(.system(size: d * 0.065, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: d * 0.78)
                    // Pace: goal hit, on pace, or how far behind + how long to walk.
                    Text(hitGoal ? "🎉 Goal hit"
                         : onPace ? "✅ On pace"
                         : "⏳ \(pace.behindText) · walk \(pace.catchUpMinutes) min")
                        .font(.system(size: d * 0.075, weight: .semibold, design: .rounded))
                        .foregroundStyle(hitGoal || onPace ? color : .orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: d * 0.68)   // stays inside the ring near its bottom
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

    // Same order as the phone's Today card: steps left, pace, finish time, streak.
    private var statsPage: some View {
        VStack(spacing: 5) {
            StatRow(icon: "👟", title: hitGoal ? "Goal hit" : "Left to goal",
                    value: hitGoal ? "+\((store.today - goal).formatted())" : (goal - store.today).formatted())
            StatRow(icon: onPace ? "✅" : "⏳",
                    title: (pace.isPersonal ? "Your pace" : "Pace") + (onPace ? "" : " · \(pace.behindText)"),
                    value: hitGoal ? "Goal hit" : onPace ? "On pace" : "Walk \(pace.catchUpMinutes) min")
            StatRow(icon: "🏁", title: "At this pace",
                    value: pace.forecastShort ?? (hitGoal ? "Goal hit 🎉" : "Too early to tell"))
            StatRow(icon: "🔥", title: "Streak",
                    value: "\(store.streak) \(store.streak == 1 ? "day" : "days")")
        }
        .padding(.horizontal, 4)
    }

    #if DEBUG
    // Debug only: when the watch face last updated, newest first.
    private var faceLogPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                Text("Face updates").font(.headline)
                ForEach(Array(FaceLog.lines.reversed().enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    #endif

    // Page 3: last 7 days as little bars, ✅ on goal days.
    // Today's sessions (yours and finished workouts from the Workout app), sent by the iPhone.
    private var sessionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's sessions").font(.headline)
                ForEach(sessions, id: \.self) { s in
                    HStack(spacing: 8) {
                        Text(s.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.title).font(.body.weight(.semibold)).lineLimit(1)
                            Text("\(s.steps.formatted()) steps · \(s.distance)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

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
