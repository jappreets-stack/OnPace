import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Data

struct StepsEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let streak: Int
    var curve: [Double]? = nil
    var goal = 10_000

    var progress: Double { min(Double(steps) / Double(goal), 1) }
    var hitGoal: Bool { steps >= goal }

    // Pace: assumes you walk evenly between 7am and 10pm (see Pace.swift).
    var pace: Pace { Pace(steps: steps, goal: goal, now: date, curve: curve) }
    var onPace: Bool { pace.onPace }

    var paceText: String {
        if hitGoal { return "🎉 Goal hit" }
        return onPace ? "✅ On pace" : "⏳ \(pace.statusLine)"
    }

    // 6,214 → "6.2K", 850 → "850"
    var compact: String {
        steps < 1000 ? "\(steps)"
            : (Double(steps) / 1000).formatted(.number.precision(.fractionLength(1))) + "K"
    }

    static let sample = StepsEntry(date: .now, steps: 6214, streak: 5)
}

let ringGreen = Color(red: 0.19, green: 0.82, blue: 0.36)

// Reads steps from Apple Health. The watch app asks for permission; this reuses it.
struct StepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (StepsEntry) -> Void) {
        if context.isPreview { completion(.sample); return }
        Task { completion(await Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<StepsEntry>) -> Void) {
        Task {
            let entry = await Self.load()
            // watchOS decides the exact time; asking for 15 minutes keeps it fresh.
            let next = Date.now.addingTimeInterval(15 * 60)
            // If no refresh comes before midnight, start the new day at 0 instead of showing yesterday.
            let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(24 * 3600))
            let newDay = StepsEntry(date: midnight, steps: 0, streak: entry.hitGoal ? entry.streak : 0,
                                    curve: entry.curve, goal: entry.goal)
            completion(Timeline(entries: [entry, newDay], policy: .after(next)))
        }
    }

    nonisolated static func load() async -> StepsEntry {
        let health = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let goal = Shared.goal   // sent from the iPhone (see WatchSync)
        let d = Shared.defaults

        // Fast path (watchOS gives a watch face only a moment to load): when the phone already sent
        // today's streak and your usual day, only today's steps are read. Still straight from Apple Health.
        let stamp = Double(d.string(forKey: Shared.stepsDateKey) ?? "")
        let fromPhoneToday = stamp.map { cal.isDateInToday(Date(timeIntervalSince1970: $0)) } ?? false
        let phoneStreak = Int(d.string(forKey: Shared.streakKey) ?? "")
        let phoneCurve = (d.string(forKey: Shared.curveKey) ?? "").split(separator: ",").compactMap { Double($0) }
        if fromPhoneToday, let phoneStreak {
            let query = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: stepType,
                                           predicate: HKQuery.predicateForSamples(withStart: todayStart, end: .now)),
                options: .cumulativeSum)
            if let result = try? await query.result(for: health) {
                // Health's saved total + steps the motion chip counted since Health's last save (live, never twice).
                let today = Int(result.sumQuantity()?.doubleValue(for: .count()) ?? 0) + (await LiveTopUp.extraSteps(health))
                return StepsEntry(date: .now, steps: today, streak: phoneStreak,
                                  curve: phoneCurve.count == 24 ? phoneCurve : nil, goal: goal)
            }
        }

        let from = cal.date(byAdding: .day, value: -60, to: todayStart)!
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: stepType,
                predicate: HKQuery.predicateForSamples(withStart: from, end: .now)),
            options: .cumulativeSum,
            anchorDate: todayStart,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await query.result(for: health) else {
            return StepsEntry(date: .now, steps: 0, streak: 0)
        }
        var days: [Int] = []
        for offset in (0...60).reversed() {
            let day = cal.date(byAdding: .day, value: -offset, to: todayStart)!
            days.append(Int(collection.statistics(for: day)?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
        }
        // Today's steps: Apple Health on the watch only, so it matches the Health app exactly.
        let today = (days.last ?? 0) + (await LiveTopUp.extraSteps(health))

        // Streak: days in a row at goal. Today only counts once you've hit it.
        var past = days
        if today < goal { past.removeLast() }
        var streak = 0
        for d in past.reversed() {
            if d >= goal { streak += 1 } else { break }
        }
        var curve = await Pace.learnCurve(from: health)
        if fromPhoneToday, phoneCurve.count == 24 { curve = phoneCurve }
        return StepsEntry(date: .now, steps: today, streak: streak, curve: curve, goal: goal)
    }
}

// MARK: - Main complication (circle ring, corner, inline, rectangle)

struct StepsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StepsComplication", provider: StepsProvider()) { entry in
            StepsComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Steps")
        .description("Steps toward your goal, with streak and pace.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct StepsComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepsEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Small ring with the step count inside.
            Gauge(value: entry.progress) {
                Text("Steps")
            } currentValueLabel: {
                Text(entry.compact)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(ringGreen)

        case .accessoryCorner:
            // Step count in the corner, curved gauge along the edge.
            Text(entry.compact)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(ringGreen)
                .widgetCurvesContent()
                .widgetLabel {
                    Gauge(value: entry.progress) {
                        Text("Steps")
                    }
                    .tint(ringGreen)
                }

        case .accessoryInline:
            // One line near the clock.
            Text("\(entry.steps.formatted()) · \(entry.paceText)")

        default:
            // Rectangle: ring, steps, streak, pace.
            HStack(spacing: 8) {
                Gauge(value: entry.progress) {
                    Text("Steps")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(ringGreen)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.steps.formatted()) steps")
                        .font(.headline)
                        .minimumScaleFactor(0.7)
                    Text("🔥 \(entry.streak) \(entry.streak == 1 ? "day" : "days")")
                        .font(.caption)
                    Text(entry.paceText)
                        .font(.caption)
                        .foregroundStyle(entry.hitGoal || entry.onPace ? ringGreen : .orange)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Number + one line (steps left, or pace)

extension StepsEntry {
    var leftText: String { hitGoal ? "Goal hit" : "\((goal - steps).formatted()) to go" }
    // Plain text (no emoji) so it reads well curved around a corner.
    var paceLine: String { pace.statusLine }
}

// Full step count, with a small line under it (round) or curved along the edge (corner).
struct NumberWithLineView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepsEntry
    let line: String
    let lineColor: Color

    var body: some View {
        if family == .accessoryCorner {
            Text(entry.steps.formatted())
                .font(.system(.body, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
                .widgetCurvesContent()
                .widgetLabel {
                    Text(line).foregroundStyle(lineColor)
                }
        } else if family == .accessoryInline {
            Text("\(entry.steps.formatted()) · \(line)")
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.steps.formatted()) steps")
                    .font(.headline)
                Text(line)
                    .font(.caption)
                    .foregroundStyle(lineColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Text(entry.steps.formatted())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                    // Round slots are tiny: keep only the first part ("784 behind").
                    Text(line.components(separatedBy: " · ").first ?? line)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(lineColor)
                        .minimumScaleFactor(0.6)
                }
                .lineLimit(1)
                .padding(.horizontal, 4)
            }
        }
    }
}

struct StepsNumberComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StepsNumber", provider: StepsProvider()) { entry in
            NumberWithLineView(entry: entry, line: entry.leftText,
                               lineColor: entry.hitGoal ? ringGreen : .secondary)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Steps left")
        .description("Today's steps and how many are left.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct StepsPaceComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StepsPace", provider: StepsProvider()) { entry in
            NumberWithLineView(entry: entry, line: entry.paceLine,
                               lineColor: entry.hitGoal || entry.onPace ? ringGreen : .orange)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Steps pace")
        .description("Today's steps and whether you're on pace.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    StepsComplication()
} timeline: {
    StepsEntry.sample
}
