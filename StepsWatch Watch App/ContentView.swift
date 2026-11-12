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
    private var healthToday = 0        // today's steps exactly as Apple Health has saved them
    private let live = LiveSteps()     // + steps counted since Health's last save (see Walking.swift)

    // App went to the background: stop the live step counter (it restarts on the next refresh).
    func pause() { live.stop() }

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
            live.onChange = { [weak self] extra in
                guard let self else { return }
                self.today = self.healthToday + extra
                if let last = self.week.indices.last {
                    self.week[last] = WatchDay(date: self.week[last].date, steps: self.today)
                }
            }
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
            // Today's steps: Apple Health on the watch, plus only the steps the motion chip counted after
            // Health's last save (so it moves like the Fitness app and settles back to Health's total).
            healthToday = days.last?.steps ?? 0
            await live.follow(health)
            today = healthToday + live.extra
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

struct ContentView: View {
    @StateObject private var store = WatchStepStore()
    @Environment(\.scenePhase) private var scenePhase
    // Sent from the iPhone (see WatchSync), stored in the App Group the complications read too.
    @AppStorage(Shared.goalKey, store: Shared.defaults) private var goal = 10_000
    @AppStorage(Shared.avatarKey, store: Shared.defaults) private var avatar: Avatar = .golfer
    @AppStorage(Shared.lookKey, store: Shared.defaults) private var look: Look = .starter
    @AppStorage(Shared.appStyleKey, store: Shared.defaults) private var appStyle: AppStyle = .minimal
    @AppStorage(Shared.cozyPaletteKey, store: Shared.defaults) private var cozyPalette: CozyPalette = .peach   // redraws on change
    // Watch only: everything in red on black, like the Ultra's Night Mode (picked on the last page).
    // After sunset is the default: apps can't read the Ultra's own Night Mode, so we go by the sun.
    @AppStorage("nightRedMode") private var nightRedMode: NightRedMode = .sunset
    @State private var page = 0   // which page the Crown is on (for the red page dots)
    init() { NightRedMode.keepOldSwitch() }
    private let funUnit = FunUnit.walked
    // The ring color for the phone's style (Cozy pastel uses a gradient, see ringPage).
    private var accent: Color {
        switch appStyle {
        case .minimal: Minimal.accent
        case .cozy: Cozy.accent
        case .retro16: Retro16.gold
        }
    }
    // Sent by the iPhone with every refresh (see PhoneSync): today's steps and sessions.
    @AppStorage(Shared.stepsDateKey, store: Shared.defaults) private var phoneStamp = ""   // changes with every phone refresh
    @AppStorage(Shared.sessionsKey, store: Shared.defaults) private var sessionsJSON = ""
    // The phone's list is only replaced when its app refreshes, so after midnight it can still hold
    // yesterday's sessions: keep only ones that started today.
    private var phoneSessions: [WatchSession] {
        let all = (try? JSONDecoder().decode([WatchSession].self, from: Data(sessionsJSON.utf8))) ?? []
        // Sessions saved by an older iPhone build have no start time, so there's no way to tell their day: skip them.
        // (The phone's background reply can resend an old list with a fresh "today" stamp.)
        return all.filter { $0.start.map { Calendar.current.isDateInToday($0) } ?? false }
    }
    // Workouts you finished today on this watch, read straight from its Health (no need to open the iPhone app).
    @State private var watchWorkouts: [WatchSession] = []
    private var sessions: [WatchSession] {
        let phone = phoneSessions
        let extra = watchWorkouts.filter { w in
            !phone.contains { p in
                p.id == w.id || (p.start.map { $0 < (w.end ?? .now) } ?? false && p.end.map { $0 > (w.start ?? .now) } ?? false)
            }
        }
        return (phone + extra).sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    private var progress: Double { min(Double(store.today) / Double(goal), 1) }
    private var hitGoal: Bool { store.today >= goal }

    // Pace: assumes you walk evenly between 7am and 10pm (see Pace.swift).
    private var pace: Pace { Pace(steps: store.today, goal: goal, curve: store.curve) }
    private var onPace: Bool { pace.onPace }

    // Walks while you walk; otherwise celebrate at goal, stand on pace, slump behind.
    @StateObject private var walking = WalkingDetector()
    private var mood: Mood { .everyday(walking: walking.isWalking, hitGoal: hitGoal, onPace: onPace) }

    // Scroll the Digital Crown to move between pages.
    private var pages: some View {
        TabView(selection: $page) {
            ringPage.id(cozyPalette).tag(0)   // redraw when the phone sends new Cozy colors
            statsPage.tag(1)
            sessionsPage.tag(2)
            weekPage.tag(3)
            colorPage.tag(4)
        }
        .tabViewStyle(.verticalPage)
    }

    var body: some View {
        // Checks once a minute whether the sun has set (Red after sunset).
        TimelineView(.everyMinute) { context in
            // Night red: every color in a shade of red. On with the switch on the last page, after sunset
            // (Red after sunset), or when the phone picks Cozy pastel → Night red.
            let red = nightRedMode == .always || (nightRedMode == .sunset && SunClock.isDark(context.date))
                || (appStyle == .cozy && cozyPalette == .nightRed)
            pages
                // watchOS draws its page dots in white and apps can't recolor them, so while red we hide
                // them and draw our own (the red filter below turns them red). The clock can't be changed.
                .scrollIndicators(red ? .hidden : .automatic)
                .overlay(alignment: .topTrailing) {
                    if red { PageDots(count: 5, current: page) }
                }
                .environment(\.nightRedOn, red)
                .nightRed(red)
        }
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
            } else if phase == .inactive || phase == .background {
                // Leaving the app (wrist down / back to the face): redraw the face with the live number now.
                WidgetCenter.shared.reloadAllTimelines()
                if phase == .background {
                    walking.stop()
                    store.pause()
                }
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
            let retro = appStyle == .retro16
            let color = accent
            let design: Font.Design = retro ? .monospaced : .rounded
            ZStack {
                switch appStyle {
                case .retro16:
                    Retro16BlockRing(progress: progress)
                case .minimal:
                    // Clean minimal: one flat green ring, like the phone.
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: line)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: progress)
                case .cozy:
                    // Cozy pastel: the phone's soft peach → pink → lavender ring.
                    CozyRing(progress: progress, hitGoal: hitGoal, lineWidth: line) { EmptyView() }
                }
                VStack(spacing: 0) {
                    if retro {
                        Retro16Sprite(look: look, avatar: avatar, mood: mood)
                            .frame(width: d * 0.36, height: d * 0.41)
                    } else {
                        CharacterView(avatar: avatar, mood: mood, look: look)
                            .frame(width: d * 0.36, height: d * 0.41)
                    }
                    Text(store.today, format: .number)
                        .font(.system(size: d * (retro ? 0.15 : 0.17), weight: retro ? .heavy : .bold, design: design))
                        .foregroundStyle(retro ? Retro16.goldLight : .white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    // How far you walked today ("4.9 miles walked").
                    Text(funUnit.phrase(store.today, meters: store.todayMeters))
                        .font(.system(size: d * 0.065, weight: .medium, design: design))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: d * 0.78)
                    // Pace: goal hit, on pace, or how far behind + how long to walk.
                    Text(hitGoal ? "🎉 Goal hit"
                         : onPace ? "✅ On pace"
                         : "⏳ \(pace.behindText) · walk \(pace.catchUpMinutes) min")
                        .font(.system(size: d * 0.075, weight: .semibold, design: design))
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

    // Page 3: today's sessions (yours and finished workouts from the Workout app), sent by the iPhone.
    private var sessionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's sessions").font(.headline)
                if sessions.isEmpty {
                    Text("No sessions yet today. Start one on your iPhone, or finish a workout in the Workout app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(sessions, id: \.self) { s in
                    HStack(spacing: 8) {
                        Text(s.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.title).font(.body.weight(.semibold)).lineLimit(1)
                            Text("\(s.steps.formatted()) steps · \(s.distance)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .modifier(RedScrollBar())
        .task { watchWorkouts = await TodaysWorkouts.load() }
        // Read again each time you raise your wrist into the app (a workout may have ended since).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { watchWorkouts = await TodaysWorkouts.load() } }
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
                        // Flag on goal days.
                        Text(hit ? funUnit.goalFlag : " ").font(.system(size: 11))
                        Capsule()
                            .fill(appStyle == .cozy ? (hit ? Cozy.done : Cozy.end) : accent.opacity(hit ? 1 : 0.55))
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

    // Last page: Night red, and your mini-me (set on the iPhone).
    private var colorPage: some View {
        List {
            Section {
                Picker("Night red", selection: $nightRedMode) {
                    ForEach(NightRedMode.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                switch nightRedMode {
                case .off: Text("Night red turns everything red on black, like Ultra Night Mode.")
                case .sunset: Text("Red from about \(SunClock.tonight).")
                case .always: Text("Red all the time.")
                }
            }
            Section("Your mini-me") {
                HStack(spacing: 10) {
                    CharacterView(avatar: avatar, mood: .walk, look: look)
                        .frame(width: 30, height: 42)
                    Text("Change your mini-me, goal and style on your iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .modifier(RedScrollBar())
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

// Today's finished workouts from this watch's own Health, as sessions (same kinds the iPhone adds:
// Golf, Hike, Walk, Run, Strength). The iPhone only adds them when its app is opened; this shows them right away.
enum TodaysWorkouts {
    static func load() async -> [WatchSession] {
        let health = HKHealthStore()
        try? await health.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
        let start = Calendar.current.startOfDay(for: .now)
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: .now))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let workouts = try? await query.result(for: health) else { return [] }
        var list: [WatchSession] = []
        for w in workouts {
            let hours = w.endDate.timeIntervalSince(w.startDate) / 3600
            let (emoji, title): (String, String)
            switch w.workoutActivityType {
            case .golf: (emoji, title) = ("⛳️", hours < 2.5 ? "9 holes" : "18 holes")
            case .hiking: (emoji, title) = ("🥾", "Hike")
            case .walking: (emoji, title) = ("✨", "Walk")
            case .running: (emoji, title) = ("✨", "Run")
            case .traditionalStrengthTraining, .functionalStrengthTraining,
                 .highIntensityIntervalTraining, .crossTraining: (emoji, title) = ("💪", "Workout")
            default: continue
            }
            let stepsQuery = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: HKQuantityType(.stepCount),
                                           predicate: HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate)),
                options: .cumulativeSum)
            let steps = Int((try? await stepsQuery.result(for: health))?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            // Skip workouts that were started and stopped by accident (under 2 minutes, or no steps).
            if w.endDate.timeIntervalSince(w.startDate) < 120 || steps == 0 { continue }
            let meters = await WalkDistance.meters(health, from: w.startDate, to: w.endDate)
            let unit = FunUnit.walked   // real miles or km, golf too (the title says the holes)
            list.append(WatchSession(emoji: emoji, title: title, steps: steps,
                                     distance: unit.phrase(steps, meters: meters),
                                     id: w.uuid, start: w.startDate, end: w.endDate))
        }
        return list
    }
}

// Red after sunset: rough sunset and sunrise for today, worked out from the date and your time zone only
// (no location needed). The time zone's city gives a rough spot on the map, so it also works south of the
// equator and far north. "Dark" starts 15 min after sunset and ends 15 min before sunrise.
enum SunClock {
    // Rough latitude / longitude of the city each time zone is named after.
    private static let cities: [String: (lat: Double, lon: Double)] = [
        "America/Los_Angeles": (34, -118), "America/Denver": (40, -105), "America/Phoenix": (33, -112),
        "America/Chicago": (42, -88), "America/New_York": (41, -74), "America/Anchorage": (61, -150),
        "Pacific/Honolulu": (21, -158), "America/Toronto": (44, -79), "America/Vancouver": (49, -123),
        "America/Edmonton": (53, -113), "America/Winnipeg": (50, -97), "America/Halifax": (45, -64),
        "America/Mexico_City": (19, -99), "America/Bogota": (5, -74), "America/Lima": (-12, -77),
        "America/Santiago": (-33, -71), "America/Sao_Paulo": (-24, -47), "America/Argentina/Buenos_Aires": (-35, -58),
        "Europe/London": (51.5, 0), "Europe/Dublin": (53, -6), "Europe/Lisbon": (39, -9), "Europe/Madrid": (40, -4),
        "Europe/Paris": (49, 2), "Europe/Amsterdam": (52, 5), "Europe/Brussels": (51, 4), "Europe/Berlin": (52.5, 13),
        "Europe/Zurich": (47, 8.5), "Europe/Rome": (42, 12.5), "Europe/Vienna": (48, 16), "Europe/Warsaw": (52, 21),
        "Europe/Stockholm": (59, 18), "Europe/Oslo": (60, 11), "Europe/Copenhagen": (56, 12.5), "Europe/Helsinki": (60, 25),
        "Europe/Athens": (38, 24), "Europe/Istanbul": (41, 29), "Europe/Kyiv": (50, 30.5), "Europe/Moscow": (56, 37.5),
        "Africa/Cairo": (30, 31), "Africa/Lagos": (6.5, 3.5), "Africa/Nairobi": (-1, 37), "Africa/Johannesburg": (-26, 28),
        "Asia/Dubai": (25, 55), "Asia/Riyadh": (25, 47), "Asia/Jerusalem": (32, 35), "Asia/Karachi": (25, 67),
        "Asia/Kolkata": (23, 79), "Asia/Calcutta": (23, 79), "Asia/Dhaka": (24, 90), "Asia/Bangkok": (14, 100.5),
        "Asia/Jakarta": (-6, 107), "Asia/Singapore": (1, 104), "Asia/Kuala_Lumpur": (3, 102), "Asia/Manila": (14.5, 121),
        "Asia/Hong_Kong": (22, 114), "Asia/Shanghai": (31, 121.5), "Asia/Taipei": (25, 121.5), "Asia/Seoul": (37.5, 127),
        "Asia/Tokyo": (36, 140), "Australia/Perth": (-32, 116), "Australia/Adelaide": (-35, 138.5),
        "Australia/Darwin": (-12.5, 131), "Australia/Brisbane": (-27.5, 153), "Australia/Sydney": (-34, 151),
        "Australia/Melbourne": (-38, 145), "Australia/Hobart": (-43, 147), "Pacific/Auckland": (-37, 175),
    ]
    // Time zones not in the list: a typical latitude for that part of the world, in the middle of the zone.
    private static func place(for tz: TimeZone, standardHours: Double) -> (lat: Double, lon: Double) {
        if let c = cities[tz.identifier] { return c }
        let id = tz.identifier
        let lat: Double = id.hasPrefix("Europe/") ? 50 : id.hasPrefix("Australia/") ? -33
            : id.hasPrefix("Africa/") ? 5 : id.hasPrefix("Asia/") ? 28
            : id.hasPrefix("Pacific/") ? -15 : id.hasPrefix("Antarctica/") ? -70 : 37
        return (lat, standardHours * 15)
    }

    // Minutes after local midnight for sunrise and sunset on that day.
    static func times(on date: Date, in tz: TimeZone = .current) -> (rise: Double, set: Double) {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let day = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 172)
        let b = 2 * Double.pi / 365 * (day - 81)
        let declination = 23.44 * Double.pi / 180 * sin(b)
        let equationOfTime = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)   // minutes
        let dst = tz.daylightSavingTimeOffset(for: date) / 60                   // minutes
        let standardHours = (Double(tz.secondsFromGMT(for: date)) / 60 - dst) / 60
        let spot = place(for: tz, standardHours: standardHours)
        let lat = spot.lat * Double.pi / 180
        let cosH = (sin(-0.833 * Double.pi / 180) - sin(lat) * sin(declination)) / (cos(lat) * cos(declination))
        let halfDay = acos(max(-1, min(1, cosH))) * 180 / Double.pi * 4   // minutes from solar noon
        // Solar noon: 12:00 standard time in the middle of the zone, 4 min earlier per degree east of it.
        let noon = 720 - equationOfTime - 4 * (spot.lon - standardHours * 15) + dst
        return (noon - halfDay, noon + halfDay)
    }

    static func isDark(_ date: Date = .now) -> Bool {
        let t = times(on: date)
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minute = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
        return minute >= t.set + 15 || minute < t.rise - 15
    }

    // "7:05 PM to 6:40 AM", for the footer.
    static var tonight: String {
        let t = times(on: .now)
        let midnight = Calendar.current.startOfDay(for: .now)
        let on = midnight.addingTimeInterval((t.set + 15) * 60)
        let off = midnight.addingTimeInterval((t.rise - 15) * 60)
        let f = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(on.formatted(f)) to \(off.formatted(f))"
    }
}

// Night red choice on the last watch page.
enum NightRedMode: String, CaseIterable, Identifiable {
    case off, sunset, always
    var id: Self { self }
    var label: String {
        switch self {
        case .off: "Off"
        case .sunset: "After sunset"
        case .always: "Always"
        }
    }

    // Older builds had an on/off "Night red" switch: if it was on, keep the app red all the time.
    static func keepOldSwitch() {
        let d = UserDefaults.standard
        if d.object(forKey: "nightRedMode") == nil, d.bool(forKey: "nightRed") {
            d.set(NightRedMode.always.rawValue, forKey: "nightRedMode")
        }
    }
}

// True while the watch app is drawn in Night red (set at the top, read by the red scroll bar).
private struct NightRedOnKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var nightRedOn: Bool {
        get { self[NightRedOnKey.self] }
        set { self[NightRedOnKey.self] = newValue }
    }
}

// watchOS hides its white scroll bar with the page dots while red, so long pages draw their own.
struct RedScrollBar: ViewModifier {
    @Environment(\.nightRedOn) private var red
    @State private var info = Info()
    struct Info: Equatable { var offset = 0.0, content = 0.0, visible = 1.0 }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Info.self) { g in
                Info(offset: g.contentOffset.y + g.contentInsets.top, content: g.contentSize.height,
                     visible: g.containerSize.height - g.contentInsets.top - g.contentInsets.bottom)
            } action: { _, new in info = new }
            .overlay(alignment: .trailing) {
                if red && info.content > info.visible + 4 {
                    let track = 34.0
                    let thumb = max(10, track * info.visible / info.content)
                    let progress = min(max(info.offset / (info.content - info.visible), 0), 1)
                    Capsule().fill(Color.white.opacity(0.25))
                        .frame(width: 3, height: track)
                        .overlay(alignment: .top) {
                            Capsule().fill(Color.white).frame(width: 3, height: thumb)
                                .offset(y: (track - thumb) * progress)
                        }
                        .offset(x: -1.5, y: 34)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
    }
}

// Our own page dots, shown in Night red instead of the white system ones.
struct PageDots: View {
    let count: Int
    let current: Int
    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(i == current ? 1 : 0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 10)
        .padding(.trailing, 2)
        .allowsHitTesting(false)
    }
}
