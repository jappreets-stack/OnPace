import SwiftUI
import HealthKit

// Settings the iPhone shares with the watch and its watch-face complications.
// The iPhone is the boss: it sends goal, mini-me and style to the watch (WatchConnectivity),
// and the watch saves them in an App Group so the complications can read them too.
// Shared by all three targets.
nonisolated enum Shared {
    static let appGroup = "group.com.js.personal.Steps"

    // Keys (the same names the iPhone uses in its own @AppStorage).
    static let goalKey = "goal"
    static let avatarKey = "avatar"
    static let lookKey = "look"
    static let appStyleKey = "appStyle"   // Clean minimal / 16-bit adventure / Original
    // The iPhone app saves today's steps here for its home-screen widget (used when Health is locked).
    static let stepsKey = "todaySteps"
    static let stepsDateKey = "todayStepsDate"
    static let metersKey = "todayMeters"
    static let sessionsKey = "sessionsToday"   // JSON list of today's sessions, for the watch
    // Sent to the watch with every refresh: the phone usually knows more steps than the watch's own
    // copy of Health (steps the iPhone counts reach the watch late).
    static let streakKey = "phoneStreak"
    static let curveKey = "phoneCurve"     // your usual day (24 numbers), so the watch's forecast matches
    static let weekKey = "phoneWeek"       // last 7 days of steps, oldest first, ending today
    static let liveKeys = [stepsKey, stepsDateKey, metersKey, sessionsKey, streakKey, curveKey, weekKey]
    static let syncedKeys = [goalKey, avatarKey, lookKey, appStyleKey]

    // On the watch: the App Group storage both the app and the complications read.
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    // Your daily goal as the watch + complications know it (10,000 until the phone sends one).
    static var goal: Int {
        let g = defaults.integer(forKey: goalKey)
        return g > 0 ? g : 10_000
    }
}

// How far you really walked, measured by your iPhone / watch with your own stride
// (Apple Health "Walking + Running Distance"). nil if there's no data or no permission.
nonisolated enum WalkDistance {
    static let type = HKQuantityType(.distanceWalkingRunning)

    static func meters(_ health: HKHealthStore, from start: Date, to end: Date = .now) async -> Double? {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type,
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum)
        return (try? await query.result(for: health))?.sumQuantity()?.doubleValue(for: .meter())
    }
}

// Steps turned into something you can picture. Uses the real distance you walked when Apple Health
// has it; golf holes always count steps (a hole is about walking, not a straight line).
nonisolated enum FunUnit: String, CaseIterable, Identifiable {
    case holes, soccerFields, footballFields, courts, tennisCourts, bases, laps, blocks, km, mi
    var id: String { rawValue }

    // The line under your step count: the real distance you walked, in miles (US, UK) or km.
    // Golf sessions still count holes.
    static var walked: FunUnit { Locale.current.measurementSystem == .metric ? .km : .mi }

    var name: String {
        switch self {
        case .holes: "Golf holes"
        case .soccerFields: "Soccer fields"
        case .footballFields: "Football fields"
        case .courts: "Basketball courts"
        case .tennisCourts: "Tennis courts"
        case .bases: "Trips around the bases"
        case .laps: "Track laps"
        case .blocks: "City blocks"
        case .km: "Kilometers"
        case .mi: "Miles"
        }
    }

    var stepsPerUnit: Double {
        switch self {
        case .holes: 1300        // walking a hole, tee to green plus the walk to the next tee
        case .soccerFields: 140  // one length of a 105 m field
        case .footballFields: 120 // 100 yards, goal line to goal line
        case .courts: 38         // one 28.65 m basketball court
        case .tennisCourts: 31   // one 23.77 m tennis court
        case .bases: 144         // home → 1st → 2nd → 3rd → home, 109.7 m
        case .laps: 525          // one 400 m lap
        case .blocks: 105        // a ~80 m city block
        case .km: 1320
        case .mi: 2125
        }
    }

    // Real size of one unit. nil for holes (counted in steps).
    var metersPerUnit: Double? {
        switch self {
        case .holes: nil
        case .soccerFields: 105
        case .footballFields: 91.44
        case .courts: 28.65
        case .tennisCourts: 23.77
        case .bases: 109.73
        case .laps: 400
        case .blocks: 80
        case .km: 1000
        case .mi: 1609.344
        }
    }

    var emoji: String {
        switch self {
        case .holes: "⛳️"
        case .soccerFields: "⚽️"
        case .footballFields: "🏈"
        case .courts: "🏀"
        case .tennisCourts: "🎾"
        case .bases: "⚾️"
        case .laps: "🏃"
        case .blocks: "🏙️"
        case .km, .mi: "📏"
        }
    }

    var tileTitle: String {
        switch self {
        case .holes: "Golf"
        case .soccerFields: "Soccer"
        case .footballFields: "Football"
        case .courts: "Hoops"
        case .tennisCourts: "Tennis"
        case .bases: "Baseball"
        case .laps: "Track"
        case .blocks: "City"
        case .km, .mi: "Distance"
        }
    }

    var detail: String {
        switch self {
        case .holes: "holes walked"
        case .soccerFields: "soccer fields"
        case .footballFields: "football fields"
        case .courts: "basketball courts"
        case .tennisCourts: "tennis courts"
        case .bases: "trips around the bases"
        case .laps: "track laps"
        case .blocks: "city blocks"
        case .km: "km walked"
        case .mi: "miles walked"
        }
    }

    // Shown at the end of goal days in the Last 7 days table.
    var goalFlag: String { self == .holes ? "⛳️" : "🏁" }

    // meters = real distance walked (from Health); without it, a step-based estimate.
    func amount(_ steps: Int, meters: Double? = nil) -> String {
        let value: Double
        if let per = metersPerUnit, let meters { value = meters / per }
        else { value = Double(steps) / stepsPerUnit }
        let decimals = [.soccerFields, .footballFields, .courts, .tennisCourts, .blocks].contains(self) ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }

    // "Holes walked" (for a row title on the watch)
    var title: String { detail.prefix(1).uppercased() + detail.dropFirst() }

    // "3.2 km walked" (measured) or "~3.2 holes walked" (estimated from steps)
    func phrase(_ steps: Int, meters: Double? = nil) -> String {
        let measured = metersPerUnit != nil && meters != nil
        return "\(measured ? "" : "~")\(amount(steps, meters: meters)) \(detail)"
    }
}


// Today's sessions sent from the iPhone to the watch. One line per session, ready to show: "⛳️", "9 holes", "5,517 steps", "4.2 holes walked".
nonisolated struct WatchSession: Codable, Hashable {
    let emoji: String
    let title: String
    let steps: Int
    let distance: String
}

// Debug only: a short log of watch-face updates (when Health woke the app, when the face reloaded and
// with how many steps), saved in the App Group so the watch app can show it. Nothing is logged in release builds.
nonisolated enum FaceLog {
    static let key = "faceLog"
    static func add(_ text: String) {
        #if DEBUG
        let d = Shared.defaults
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        d.set(Array(((d.stringArray(forKey: key) ?? []) + ["\(time) \(text)"]).suffix(40)), forKey: key)
        #endif
    }
    static var lines: [String] { Shared.defaults.stringArray(forKey: key) ?? [] }
}
