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
    static let liveKeys = [stepsKey, stepsDateKey, metersKey, sessionsKey, streakKey, curveKey, weekKey]
    static let syncedKeys = [goalKey, avatarKey, lookKey, appStyleKey, cozyPaletteKey]

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
