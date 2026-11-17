import SwiftUI
import HealthKit
import CoreMotion

// Settings the iPhone shares with the watch and its watch-face complications.
// The iPhone is the boss: it sends goal, mini-me and style to the watch (WatchConnectivity),
// and the watch saves them in an App Group so the complications can read them too.
// Shared by all three targets.
nonisolated enum Shared {
    static let appGroup = "group.com.jappreets.onpace"

    // Keys (the same names the iPhone uses in its own @AppStorage).
    static let goalKey = "goal"
    static let avatarKey = "avatar"
    static let lookKey = "look"
    static let appStyleKey = "appStyle"   // Clean minimal / Cozy pastel / 16-bit adventure
    static let cozyPaletteKey = "cozyPalette"   // Cozy pastel colors
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
    // When the phone last counted the streak, and the streak without that day (see PhoneStreak).
    static let streakDateKey = "phoneStreakDate"
    static let streakBaseKey = "phoneStreakBase"
    static let liveKeys = [stepsKey, stepsDateKey, metersKey, sessionsKey, streakKey, curveKey, weekKey,
                           streakDateKey, streakBaseKey]
    static let syncedKeys = [goalKey, avatarKey, lookKey, appStyleKey, cozyPaletteKey]

    // On the watch: the App Group storage both the app and the complications read.
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    // Your daily goal as the watch + complications know it (10,000 until the phone sends one).
    static var goal: Int {
        let g = defaults.integer(forKey: goalKey)
        return g > 0 ? g : 10_000
    }
}

// Your streak on the watch when the iPhone app hasn't been opened today.
// The phone has the full step history, so its last count is kept, and only the days since then
// are counted from the watch's own Apple Health. (Counting every day on the watch came out too low:
// it misses steps the phone counted alone.)
nonisolated enum PhoneStreak {
    struct Saved {
        var day: Date        // start of the day the phone last counted
        var base: Int        // the streak before that day
        var streak: Int      // the streak the phone showed that day
        var daySteps: Int    // that day's steps as the phone knew them
    }

    // The phone's last count (nil until a phone with this version has sent one).
    static func saved() -> Saved? {
        let d = Shared.defaults
        guard let stamp = Double(d.string(forKey: Shared.streakDateKey) ?? ""),
              let base = Int(d.string(forKey: Shared.streakBaseKey) ?? ""),
              let streak = Int(d.string(forKey: Shared.streakKey) ?? "") else { return nil }
        let week = (d.string(forKey: Shared.weekKey) ?? "").split(separator: ",").compactMap { Int($0) }
        return Saved(day: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: stamp)),
                     base: base, streak: streak, daySteps: week.last ?? 0)
    }

    // The streak right now. today = today's steps on the watch; watchSteps = the watch's steps for
    // a past day (nil if unknown). Returns nil when it can't tell, so the caller counts on its own.
    static func current(_ saved: Saved, goal: Int, today: Int, todayStart: Date,
                        watchSteps: (Date) -> Int?) -> Int? {
        let hitToday = today >= goal ? 1 : 0
        if saved.day == todayStart { return max(saved.streak, saved.base + hitToday) }
        guard saved.day < todayStart else { return nil }
        var streak = saved.base
        var day = saved.day
        while day < todayStart {
            guard let own = watchSteps(day) else { return nil }
            let steps = day == saved.day ? max(own, saved.daySteps) : own
            streak = steps >= goal ? streak + 1 : 0
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        return streak + hitToday
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

// The line under your step count: the real distance you walked, in miles (US, UK) or km.
// Uses the distance Apple Health measured; without it, an estimate from steps.
nonisolated enum FunUnit: String, CaseIterable, Identifiable {
    case km, mi
    var id: String { rawValue }

    static var walked: FunUnit { Locale.current.measurementSystem == .metric ? .km : .mi }

    var stepsPerUnit: Double { self == .km ? 1320 : 2125 }
    var metersPerUnit: Double { self == .km ? 1000 : 1609.344 }
    var detail: String { self == .km ? "km walked" : "miles walked" }

    // Shown at the end of goal days in the Last 7 days table.
    var goalFlag: String { "🏁" }

    // meters = real distance walked (from Health); without it, a step-based estimate.
    func amount(_ steps: Int, meters: Double? = nil) -> String {
        let value = meters.map { $0 / metersPerUnit } ?? Double(steps) / stepsPerUnit
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    // "3.2 km walked" (measured) or "~3.2 km walked" (estimated from steps)
    func phrase(_ steps: Int, meters: Double? = nil) -> String {
        "\(meters == nil ? "~" : "")\(amount(steps, meters: meters)) \(detail)"
    }
}

// Today's sessions sent from the iPhone to the watch. One line per session, ready to show: "⛳️", "9 holes", "5,517 steps", "3.1 miles walked".
nonisolated struct WatchSession: Codable, Hashable {
    let emoji: String
    let title: String
    let steps: Int
    let distance: String
    var id: UUID? = nil      // same as the Apple workout's id, so the watch never lists a workout twice
    var start: Date? = nil
    var end: Date? = nil
}

// Apple Health saves steps in batches; the motion chip has every step right away. These helpers find Health's
// newest saved step sample and count the motion-chip steps after it, so a number can be live without ever
// counting a step twice. Used by the apps (LiveSteps, Walking.swift) and the watch faces.
nonisolated enum LiveTopUp {
    // When Health's newest saved step sample today ends (nil if nothing saved yet today).
    static func lastSavedEnd(_ health: HKHealthStore, since start: Date) async -> Date? {
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.stepCount),
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1)
        return try? await query.result(for: health).first?.endDate
    }

    // One-off: motion-chip steps since Health's last save (0 if motion isn't available or allowed).
    // Never waits more than 2 seconds: a watch face that doesn't finish loading keeps showing old numbers.
    static func extraSteps(_ health: HKHealthStore) async -> Int {
        guard CMPedometer.isStepCountingAvailable(),
              CMPedometer.authorizationStatus() == .authorized else { return 0 }
        let dayStart = Calendar.current.startOfDay(for: .now)
        let from = min(await lastSavedEnd(health, since: dayStart) ?? dayStart, .now)
        let pedometer = CMPedometer()
        let answer = AnswerOnce()
        return await withCheckedContinuation { done in
            answer.set(done)
            pedometer.queryPedometerData(from: from, to: .now) { data, _ in
                _ = pedometer   // keep the pedometer alive until it answers
                answer.finish(data?.numberOfSteps.intValue ?? 0)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { answer.finish(0) }
        }
    }
}

// Resumes a waiting call exactly once: with the pedometer's answer, or 0 if the time limit hits first.
nonisolated final class AnswerOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done: CheckedContinuation<Int, Never>?
    func set(_ continuation: CheckedContinuation<Int, Never>) { lock.lock(); done = continuation; lock.unlock() }
    func finish(_ value: Int) {
        lock.lock(); let d = done; done = nil; lock.unlock()
        d?.resume(returning: value)
    }
}
