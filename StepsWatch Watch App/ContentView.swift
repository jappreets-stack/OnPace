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
            // When the iPhone sent numbers recently, they win (see applyPhone below).
            if let phone = Self.phoneToday(), phone.fresh {
                days[days.count - 1] = WatchDay(date: todayStart, steps: phone.steps)
                if let m = phone.meters { todayMeters = m }
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

    // Use the phone's numbers right away when they arrive (no need to wait for the next Health read).
    // The watch's own copy of Health is missing steps the iPhone counted, so for today's steps, the
    // last 7 days, the streak and your usual day (which drives "At this pace"), the phone's version wins.
    func applyPhone() {
        guard let phone = Self.phoneToday() else { return }
        let d = Shared.defaults
        // Fresh: show exactly the phone's numbers. Older: only take them if they're higher.
        if phone.fresh || phone.steps > today { today = phone.steps }
        if let m = phone.meters, phone.fresh || m > (todayMeters ?? 0) { todayMeters = m }
        if let s = Int(d.string(forKey: Shared.streakKey) ?? "") { streak = s }
        let phoneWeek = (d.string(forKey: Shared.weekKey) ?? "").split(separator: ",").compactMap { Int($0) }
        if phoneWeek.count == 7 {
            let start = Calendar.current.startOfDay(for: .now)
            week = phoneWeek.enumerated().map { i, steps in
                let day = Calendar.current.date(byAdding: .day, value: i - 6, to: start)!
                if i == 6 { return WatchDay(date: day, steps: today) }
                let own = week.first { Calendar.current.isDate($0.date, inSameDayAs: day) }?.steps ?? 0
                return WatchDay(date: day, steps: phone.fresh ? steps : max(own, steps))
            }
        } else if let last = week.indices.last {
            week[last] = WatchDay(date: week[last].date, steps: today)
        }
        let phoneCurve = (d.string(forKey: Shared.curveKey) ?? "").split(separator: ",").compactMap { Double($0) }
        if phoneCurve.count == 24 { curve = phoneCurve }
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
    @AppStorage(Shared.funUnitKey, store: Shared.defaults) private var funUnit: FunUnit = .holes
    @AppStorage(Shared.placeKey, store: Shared.defaults) private var place: DistancePlace = .road
    // Watch only.
    @AppStorage("ringStyle") private var style: RingStyle = .icon
    // Tap the ring: your mini-me does the scene's sport move (see WatchPlay below).
    @State private var tapMove: SportMove?
    @State private var tapStart: Date?
    @State private var flight: (play: WatchPlay, start: Date)?
    @State private var cheer: String?
    @State private var dayLine = ""
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
            if !sessions.isEmpty { sessionsPage }
            weekPage
            colorPage
        }
        .tabViewStyle(.verticalPage)
        .task { await store.start(goal: goal) }
        // Re-read steps every time you raise your wrist / open the app.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh(goal: goal) } }
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
                // Scene for your fun unit (soccer field, track, ...), same as the phone's ring.
                UnitScene(unit: funUnit, place: place, horizon: 124, lowMarks: false)
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
                    CharacterView(avatar: avatar, mood: tapMove.map { .move($0) } ?? mood, look: look,
                                  moveStart: tapStart)
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

                // The ball / taxi / flag from a tap, drawn on the scene's 270-point grid.
                if let flight {
                    TimelineView(.animation) { tl in
                        let t = min(max(tl.date.timeIntervalSince(flight.start) / flight.play.duration, 0), 1)
                        let k = d / 270
                        let p = flight.play.point(t)
                        Text(flight.play.ball)
                            .font(.system(size: flight.play.size * k))
                            .rotationEffect(.degrees(flight.play.spins ? t * 540 : 0))
                            .scaleEffect(flight.play.scale(t))
                            .opacity(flight.play.opacity(t))
                            .position(x: p.x * k, y: p.y * k)
                    }
                    .frame(width: d, height: d)
                    .clipShape(Circle().inset(by: line / 2))
                    .allowsHitTesting(false)
                }
                // A short cheer at the top of the ring.
                if let cheer {
                    VStack(spacing: 0) {
                        Text(cheer)
                            .font(.system(size: d * 0.075, weight: .heavy, design: .rounded))
                        Text(dayLine)
                            .font(.system(size: d * 0.05, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.65))
                    }
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white, in: RoundedRectangle(cornerRadius: d * 0.06))
                    .frame(maxWidth: d * 0.7)
                    .position(x: d / 2, y: d * 0.15)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: d, height: d)
            .contentShape(Circle())
            .onTapGesture { tapRing() }
            #if DEBUG
            // Simulator testing: launch with `-autoTap YES` to tap the ring 2 seconds after opening.
            .task {
                guard UserDefaults.standard.bool(forKey: "autoTap") else { return }
                try? await Task.sleep(for: .seconds(2))
                tapRing()
            }
            #endif
            // Center on the physical screen, not the app area (the page dots shift that left).
            .position(x: screen.width / 2 - geo.frame(in: .global).minX,
                      y: screen.height / 2 - geo.frame(in: .global).minY)
        }
        .ignoresSafeArea()
    }

    private var screen: CGRect { WKInterfaceDevice.current().screenBounds }

    // Tap: move → ball flies to the goal in the ring's scene → cheer + wrist tap.
    private func tapRing() {
        guard tapMove == nil else { return }
        let play = WatchPlay.for(funUnit, place: place, goalHit: hitGoal)
        WKInterfaceDevice.current().play(.click)
        Task {
            tapStart = .now
            tapMove = play.move
            try? await Task.sleep(for: .seconds(play.move.duration * play.move.release))
            if !play.ball.isEmpty { flight = (play, .now) }
            try? await Task.sleep(for: .seconds(max(play.move.duration * (1 - play.move.release), play.duration)))
            // A different cheer than last time, plus how today is going.
            let options = play.cheers.filter { $0 != cheer }
            dayLine = hitGoal ? "Goal hit 🎉" : onPace ? "On pace ✅"
                : "\(pace.behind.formatted()) behind · walk \(pace.catchUpMinutes) min"
            withAnimation(.spring(duration: 0.3)) { cheer = options.randomElement() ?? play.cheer }
            WKInterfaceDevice.current().play(.success)
            try? await Task.sleep(for: .seconds(0.4))
            tapMove = nil
            tapStart = nil
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.3)) { cheer = nil; flight = nil }
        }
    }

        // Same order as the phone's Today card: steps left, pace, finish time, streak.
    private var statsPage: some View {
        VStack(spacing: 5) {
            StatRow(icon: "👟", title: hitGoal ? "Goal hit" : "Left to reach goal",
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


// What the mini-me does on the watch ring for each scene, on UnitScene's 270 x 270 grid
// (the watch draws the ground at y = 124). Phone has fuller versions in Backdrops/BackdropPlay.swift.
struct WatchPlay {
    let move: SportMove
    var ball = ""            // emoji that flies; empty = nothing flies
    var size = 22.0
    var from = CGPoint(x: 150, y: 118)
    var to = CGPoint(x: 205, y: 120)
    var peak = 50.0
    var duration = 0.9
    var spins = true
    var drop = 0.0           // falls this far after arriving (through the net / into the cup)
    var pop = false          // grows in place (summit flag)
    var drive = false        // drives in from the right (taxi)
    let cheer: String

    // Several cheers per scene so it isn't the same word every tap.
    var cheers: [String] {
        switch move {
        case .golfSwing: ["In the cup!", "Birdie!", "Tap-in!", "Pure strike!", "Fore… just kidding!"]
        case .kick: ["GOAL!", "Top corner!", "Back of the net!", "What a strike!", "Golazo!"]
        case .fieldGoal: ["It's good!", "Right down the middle!", "Three points!", "Splits the posts!"]
        case .jumpShot: ["Swish!", "Nothing but net!", "Buckets!", "From downtown!", "Cash!"]
        case .serve: ["Ace!", "Service winner!", "Love-15!", "Untouchable!"]
        case .batSwing: ["Home run!", "Gone!", "Outta here!", "Grand slam!"]
        case .sprint: cheer == "Photo finish!" ? ["Photo finish!", "Gold medal!", "New record!"] : ["Zoom!", "Lap done!", "Keep going!"]
        case .hail: ["Taxi!", "Ride's here!", "Hop in!", "Cab!"]
        case .jog: ["Another marker!", "Mile down!", "Cruising!", "Nice pace!"]
        case .throwDisc: ["Nice throw!", "Caught it!", "Long toss!", "Beach legend!"]
        case .plantFlag: ["Summit!", "Top of the world!", "Peak bagged!", "Made it up!"]
        }
    }

    static func `for`(_ unit: FunUnit, place: DistancePlace, goalHit: Bool) -> WatchPlay {
        let h = 124.0
        switch unit {
        case .holes:
            return WatchPlay(move: .golfSwing, ball: "⚪️", size: 9, to: CGPoint(x: 205, y: h + 4), peak: 70,
                             duration: 1.1, spins: false, drop: 6, cheer: "In the cup!")
        case .soccerFields:
            return WatchPlay(move: .kick, ball: "⚽️", to: CGPoint(x: 207, y: h - 17), peak: 30, cheer: "GOAL!")
        case .footballFields:
            return WatchPlay(move: .fieldGoal, ball: "🏈", to: CGPoint(x: 210, y: h - 58), peak: 30, cheer: "It's good!")
        case .courts:
            return WatchPlay(move: .jumpShot, ball: "🏀", size: 18, from: CGPoint(x: 140, y: 70),
                             to: CGPoint(x: 204, y: h - 67), peak: 40, duration: 1.0, drop: 26, cheer: "Swish!")
        case .tennisCourts:
            return WatchPlay(move: .serve, ball: "🎾", size: 14, from: CGPoint(x: 145, y: 64),
                             to: CGPoint(x: 236, y: h - 10), peak: 20, duration: 0.7, cheer: "Ace!")
        case .bases:
            return WatchPlay(move: .batSwing, ball: "⚾️", size: 14, from: CGPoint(x: 155, y: 100),
                             to: CGPoint(x: 250, y: h - 80), peak: 50, duration: 1.0, cheer: "Home run!")
        case .laps:
            return WatchPlay(move: .sprint, cheer: goalHit ? "Photo finish!" : "Zoom!")
        case .blocks:
            return WatchPlay(move: .hail, ball: "🚕", size: 64, to: CGPoint(x: 200, y: h - 14), duration: 1.0,
                             spins: false, drive: true, cheer: "Taxi!")
        case .km, .mi:
            switch place {
            case .road: return WatchPlay(move: .jog, cheer: "Another marker!")
            case .beach:
                return WatchPlay(move: .throwDisc, ball: "🥏", size: 18, from: CGPoint(x: 160, y: 95),
                                 to: CGPoint(x: 220, y: h - 60), peak: 25, duration: 1.0, cheer: "Nice throw!")
            case .trail:
                return WatchPlay(move: .plantFlag, ball: "🚩", size: 22, to: CGPoint(x: 204, y: h - 104),
                                 duration: 0.5, spins: false, pop: true, cheer: "Summit!")
            }
        }
    }

    func point(_ t: Double) -> CGPoint {
        if pop { return to }
        if drive {
            let e = 1 - pow(1 - t, 3)
            return CGPoint(x: to.x + 140 * (1 - e), y: to.y)   // from the right, the way the taxi faces
        }
        let a = drop > 0 ? min(t / 0.75, 1) : t
        let after = drop > 0 ? max(0, (t - 0.75) / 0.25) : 0
        return CGPoint(x: from.x + (to.x - from.x) * a,
                       y: from.y + (to.y - from.y) * a - 4 * peak * a * (1 - a) + drop * after)
    }
    func scale(_ t: Double) -> Double { pop ? t : 1 }
    func opacity(_ t: Double) -> Double { drop > 0 ? 1 - max(0, (t - 0.9) / 0.1) : 1 }
}
