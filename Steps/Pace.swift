import Foundation
import HealthKit

// Shared pace math for the phone, the watch, and the complications.
// With a learned curve, pace follows YOUR usual day (from the last 30 days).
// Without one (not enough history yet), it assumes you walk evenly between 7am and 10pm.
struct Pace {
    let steps: Int
    let goal: Int
    var now: Date = .now
    // 24 numbers: the share of a usual day's steps you've done by the end of each hour.
    var curve: [Double]? = nil

    // About how many steps a minute of normal walking is.
    static let stepsPerMinute = 100.0

    private var dayStart: Date { Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: now)! }
    private var dayEnd: Date { Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: now)! }

    var hitGoal: Bool { steps >= goal }
    var isPersonal: Bool { curve?.count == 24 }

    // How much of a usual day is done by time t (0...1).
    private func dayFraction(at t: Date) -> Double {
        guard let c = curve, c.count == 24 else {
            let f = t.timeIntervalSince(dayStart) / dayEnd.timeIntervalSince(dayStart)
            return min(max(f, 0), 1)
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: t)
        let h = parts.hour ?? 0
        let before = h == 0 ? 0 : c[h - 1]
        return before + (c[h] - before) * Double(parts.minute ?? 0) / 60
    }

    var expectedByNow: Int { Int(Double(goal) * dayFraction(at: now)) }
    var onPace: Bool { steps >= expectedByNow }
    var behind: Int { max(expectedByNow - steps, 0) }

    // Minutes of walking to get back on pace. The "on pace" number keeps rising while you walk
    // (fast in your busy hours), so this counts minute by minute until your steps pass it.
    var catchUpMinutes: Int {
        guard behind > 0 else { return 0 }
        for m in 1...600 {
            let t = now.addingTimeInterval(Double(m) * 60)
            let walked = Double(steps) + Self.stepsPerMinute * Double(m)
            if walked >= Double(goal) * dayFraction(at: t) { return m }
        }
        return walkMinutes(goal - steps)
    }

    // "784 behind"
    var behindText: String { "\(behind.formatted()) behind" }
    // "walk 8 min to catch up"
    var walkText: String { "walk \(catchUpMinutes) min to catch up" }
    // One line: "784 behind · walk 8 min" / "On pace" / "Goal hit"
    var statusLine: String {
        if hitGoal { return "Goal hit" }
        return onPace ? "On pace" : "\(behindText) · walk \(catchUpMinutes) min"
    }

    // When your walking day usually ends: when you've done 98% of a usual day (10pm without a curve).
    private var usualEndOfDay: Date {
        guard isPersonal else { return dayEnd }
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)
        var t = Calendar.current.startOfDay(for: now)
        while t < midnight {
            if dayFraction(at: t) >= 0.98 { return t }
            t.addTimeInterval(5 * 60)
        }
        return midnight
    }

    // At today's speed: when you'll reach the goal, or how short you'll be by the end of your day.
    private enum Outlook { case reachGoal(Date), short(Int, Date) }
    private var outlook: Outlook? {
        guard !hitGoal, steps > 0 else { return nil }
        let end = usualEndOfDay
        guard now < end else { return nil }
        let total: Double
        if isPersonal {
            // Today so far, scaled up by how much of your usual day is done.
            let done = dayFraction(at: now)
            guard done >= 0.1 else { return nil }
            total = Double(steps) / done
            if total >= Double(goal) {
                var t = now
                while t < end {
                    if dayFraction(at: t) * total >= Double(goal) { return .reachGoal(t) }
                    t.addTimeInterval(5 * 60)
                }
            }
        } else {
            // Flat 7am–10pm: steps per hour since 7am.
            let hours = now.timeIntervalSince(dayStart) / 3600
            guard hours >= 0.5 else { return nil }
            let perHour = Double(steps) / hours
            let finish = now.addingTimeInterval(Double(goal - steps) / perHour * 3600)
            if finish <= end { return .reachGoal(finish) }
            total = Double(steps) + perHour * end.timeIntervalSince(now) / 3600
        }
        return .short(max(goal - Int(total), 1), end)
    }

    private func clock(_ t: Date) -> String { t.formatted(date: .omitted, time: .shortened) }
    private func walkMinutes(_ n: Int) -> Int { Int((Double(n) / Self.stepsPerMinute).rounded(.up)) }

    // Full sentence for the phone. Always ends with a time.
    var forecastSentence: String? {
        switch outlook {
        case .reachGoal(let t):
            "At this pace you'll reach \(goal.formatted()) by \(clock(t))"
        case .short(let n, let t):
            "At this pace you'll be \(n.formatted()) short by \(clock(t))\(isPersonal ? ", your usual end of day" : ""). Walk \(walkMinutes(n)) more min to reach \(goal.formatted())."
        case nil: nil
        }
    }
    // For the phone's row: a time on the right, what happens then underneath.
    var forecastRow: (value: String, detail: String)? {
        switch outlook {
        case .reachGoal(let t): (clock(t), "you'll reach \(goal.formatted()) steps")
        case .short(let n, let t): (clock(t), "\(n.formatted()) short by then · walk \(walkMinutes(n)) more min")
        case nil: nil
        }
    }
    // Short version for the watch, shown under the title "At this pace".
    var forecastShort: String? {
        switch outlook {
        case .reachGoal(let t): "Goal by \(clock(t))"
        case .short(let n, let t): "\(n.formatted()) short by \(clock(t))"
        case nil: nil
        }
    }

    // Learns your usual day from the last 30 days of hourly steps.
    // nil until there are at least 7 days with real walking (2,000+ steps).
    nonisolated static func learnCurve(from health: HKHealthStore) async -> [Double]? {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let from = cal.date(byAdding: .day, value: -30, to: todayStart)!
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: HKQuantityType(.stepCount),
                predicate: HKQuery.predicateForSamples(withStart: from, end: todayStart)),
            options: .cumulativeSum,
            anchorDate: todayStart,
            intervalComponents: DateComponents(hour: 1)
        )
        guard let collection = try? await query.result(for: health) else { return nil }

        var sums = [Double](repeating: 0, count: 24)
        var days = 0
        for d in 0..<30 {
            let day = cal.date(byAdding: .day, value: d, to: from)!
            let hourly = (0..<24).map { h in
                collection.statistics(for: cal.date(byAdding: .hour, value: h, to: day)!)?
                    .sumQuantity()?.doubleValue(for: .count()) ?? 0
            }
            let total = hourly.reduce(0, +)
            guard total >= 2000 else { continue }
            var soFar = 0.0
            for h in 0..<24 {
                soFar += hourly[h]
                sums[h] += soFar / total
            }
            days += 1
        }
        guard days >= 7 else { return nil }
        return sums.map { $0 / Double(days) }
    }
}
