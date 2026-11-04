import Foundation

// Shared pace math for the phone, the watch, and the complications.
// Assumes you walk evenly between 7am and 10pm.
struct Pace {
    let steps: Int
    let goal: Int
    var now: Date = .now

    // About how many steps a minute of normal walking is.
    static let stepsPerMinute = 100.0

    private var dayStart: Date { Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: now)! }
    private var dayEnd: Date { Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: now)! }

    var hitGoal: Bool { steps >= goal }

    var expectedByNow: Int {
        let fraction = now.timeIntervalSince(dayStart) / dayEnd.timeIntervalSince(dayStart)
        return Int(Double(goal) * min(max(fraction, 0), 1))
    }
    var onPace: Bool { steps >= expectedByNow }
    var behind: Int { max(expectedByNow - steps, 0) }

    // Minutes of walking to get back on pace.
    var catchUpMinutes: Int { Int((Double(behind) / Self.stepsPerMinute).rounded(.up)) }

    // "784 behind"
    var behindText: String { "\(behind.formatted()) behind" }
    // "walk 8 min to catch up"
    var walkText: String { "walk \(catchUpMinutes) min to catch up" }
    // One line: "784 behind · walk 8 min" / "On pace" / "Goal hit"
    var statusLine: String {
        if hitGoal { return "Goal hit" }
        return onPace ? "On pace" : "\(behindText) · walk \(catchUpMinutes) min"
    }

    // At today's speed (steps per hour since 7am). nil when it's too early to tell.
    private enum Outlook { case reachGoal(Date), total(Int) }
    private var outlook: Outlook? {
        guard !hitGoal, steps > 0, now < dayEnd else { return nil }
        let hours = now.timeIntervalSince(dayStart) / 3600
        guard hours >= 0.5 else { return nil }
        let perHour = Double(steps) / hours
        let finish = now.addingTimeInterval(Double(goal - steps) / perHour * 3600)
        if finish <= dayEnd { return .reachGoal(finish) }
        return .total(steps + Int(perHour * dayEnd.timeIntervalSince(now) / 3600))
    }

    // Full sentence for the phone.
    var forecastSentence: String? {
        switch outlook {
        case .reachGoal(let t): "At this pace you'll reach \(goal.formatted()) by \(t.formatted(date: .omitted, time: .shortened))"
        case .total(let n): "At this pace you'll have about \(n.formatted()) steps by 10pm"
        case nil: nil
        }
    }
    // Short version for the watch, shown under the title "At this pace".
    var forecastShort: String? {
        switch outlook {
        case .reachGoal(let t): "Goal by \(t.formatted(date: .omitted, time: .shortened))"
        case .total(let n): "About \(n.formatted()) by 10pm"
        case nil: nil
        }
    }
}
