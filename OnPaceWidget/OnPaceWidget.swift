import WidgetKit
import SwiftUI
import HealthKit

// iPhone widgets:
// - "Steps": small home-screen ring, plus lock-screen circle, rectangle and one-line versions.
// - "Steps & mini-me": medium home-screen widget with your mini-me, steps, pace and fun unit.

struct OnPaceEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    var meters: Double? = nil
    var curve: [Double]? = nil
    var avatar: Avatar = .golfer
    var look: Look = .starter
    var unit: FunUnit = .walked

    var progress: Double { min(Double(steps) / Double(max(goal, 1)), 1) }
    var hitGoal: Bool { steps >= goal }
    var left: Int { max(goal - steps, 0) }
    var pace: Pace { Pace(steps: steps, goal: goal, now: date, curve: curve) }
    var mood: Mood { hitGoal ? .celebrate : pace.onPace ? .walk : .slump }
    var leftText: String { hitGoal ? "Goal hit 🎉" : "\(left.formatted()) to go" }
    // "622 behind · walk 7 min" / "On pace" / "Goal hit"
    var paceText: String { pace.statusLine }
    // 6,214 → "6.2K"
    var compact: String {
        steps < 1000 ? "\(steps)" : (Double(steps) / 1000).formatted(.number.precision(.fractionLength(1))) + "K"
    }

    static let sample = OnPaceEntry(date: .now, steps: 6_400, goal: 10_000, meters: 4_600, unit: .walked)
}

struct OnPaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> OnPaceEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (OnPaceEntry) -> Void) {
        if context.isPreview { completion(.sample); return }
        Task { completion(await Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<OnPaceEntry>) -> Void) {
        Task {
            let entry = await Self.load()
            // iOS decides the exact time; asking for 15 minutes keeps it fresh. The app also
            // reloads the widgets whenever it refreshes.
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }

    // Today's steps from Apple Health. When the phone is locked Health is off-limits, so we
    // fall back to the last count the app saved in the shared App Group.
    nonisolated static func load() async -> OnPaceEntry {
        let d = Shared.defaults
        let health = HKHealthStore()
        let start = Calendar.current.startOfDay(for: .now)
        let avatar = d.string(forKey: Shared.avatarKey).flatMap(Avatar.init(rawValue:)) ?? .golfer
        let look = d.string(forKey: Shared.lookKey).flatMap(Look.init(rawValue:)) ?? .starter
        let unit = FunUnit.walked

        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: .now)),
            options: .cumulativeSum)
        var steps: Int
        if let sum = try? await query.result(for: health)?.sumQuantity() {
            steps = Int(sum.doubleValue(for: .count()))
        } else {
            let saved = Date(timeIntervalSince1970: d.double(forKey: Shared.stepsDateKey))
            steps = Calendar.current.isDateInToday(saved) ? d.integer(forKey: Shared.stepsKey) : 0
        }
        let meters = await WalkDistance.meters(health, from: start)
        let curve = await Pace.learnCurve(from: health)
        return OnPaceEntry(date: .now, steps: steps, goal: Shared.goal, meters: meters, curve: curve,
                           avatar: avatar, look: look, unit: unit)
    }
}

// MARK: - Views

struct RingView: View {
    let entry: OnPaceEntry
    var width = 12.0
    var body: some View {
        let color: Color = entry.hitGoal ? .green : .blue
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: width)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct OnPaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OnPaceEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Lock screen: small ring with the step count inside.
            Gauge(value: entry.progress) { Text("Steps") } currentValueLabel: { Text(entry.compact) }
                .gaugeStyle(.accessoryCircularCapacity)
                .accessibilityLabel("\(entry.steps.formatted()) steps. \(entry.leftText)")
        case .accessoryRectangular:
            // Lock screen: steps, steps left, pace.
            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.steps.formatted()) steps").font(.headline)
                Text(entry.leftText).font(.caption)
                Text(entry.paceText).font(.caption).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("\(entry.steps.formatted()) steps · \(entry.leftText)")
        default:
            // Home screen, small: ring with steps and steps left.
            ZStack {
                RingView(entry: entry)
                VStack(spacing: 0) {
                    Text(entry.steps, format: .number)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(entry.leftText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(entry.hitGoal ? .green : .secondary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
            }
            .padding(4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.steps.formatted()) steps. \(entry.leftText)")
        }
    }
}

// Home screen, medium: your mini-me in the ring, steps, pace and fun unit.
struct OnPaceMiniMeView: View {
    let entry: OnPaceEntry

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RingView(entry: entry, width: 10)
                CharacterView(avatar: entry.avatar, mood: entry.mood, look: entry.look)
                    .padding(16)
            }
            .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.steps, format: .number)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(entry.leftText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.hitGoal ? .green : .primary)
                if !entry.hitGoal {
                    Text(entry.pace.onPace ? "✅ On pace" : "⏳ \(entry.paceText)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(entry.pace.onPace ? .green : .orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text("📏 \(entry.unit.phrase(entry.steps, meters: entry.meters))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.steps.formatted()) steps. \(entry.leftText). \(entry.paceText).")
    }
}

// MARK: - Widgets

struct OnPaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OnPaceWidget", provider: OnPaceProvider()) { entry in
            OnPaceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Steps")
        .description("Today's steps and how many are left to your goal.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct OnPaceMiniMeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OnPaceMiniMeWidget", provider: OnPaceProvider()) { entry in
            OnPaceMiniMeView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Steps & mini-me")
        .description("Your mini-me, today's steps, and whether you're on pace.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    OnPaceMiniMeWidget()
} timeline: {
    OnPaceEntry.sample
}
