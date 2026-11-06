import WidgetKit
import SwiftUI
import HealthKit

// Home-screen widget (small): a ring, today's steps, and how many are left.

struct OnPaceEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    var progress: Double { min(Double(steps) / Double(max(goal, 1)), 1) }
    var hitGoal: Bool { steps >= goal }

    static let sample = OnPaceEntry(date: .now, steps: 6_400, goal: 10_000)
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
            // reloads it whenever it refreshes.
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }

    // Today's steps from Apple Health. When the phone is locked Health is off-limits, so we
    // fall back to the last count the app saved in the shared App Group.
    nonisolated static func load() async -> OnPaceEntry {
        let goal = Shared.goal
        let start = Calendar.current.startOfDay(for: .now)
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: .now)),
            options: .cumulativeSum)
        if let sum = try? await query.result(for: HKHealthStore())?.sumQuantity() {
            return OnPaceEntry(date: .now, steps: Int(sum.doubleValue(for: .count())), goal: goal)
        }
        let d = Shared.defaults
        let saved = Date(timeIntervalSince1970: d.double(forKey: Shared.stepsDateKey))
        let steps = Calendar.current.isDateInToday(saved) ? d.integer(forKey: Shared.stepsKey) : 0
        return OnPaceEntry(date: .now, steps: steps, goal: goal)
    }
}

struct OnPaceWidgetView: View {
    let entry: OnPaceEntry

    var body: some View {
        let color: Color = entry.hitGoal ? .green : .blue
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(entry.steps, format: .number)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(entry.hitGoal ? "Goal hit 🎉" : "\((entry.goal - entry.steps).formatted()) to go")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.hitGoal ? .green : .secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
        }
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.hitGoal
            ? "\(entry.steps.formatted()) steps. Goal hit."
            : "\(entry.steps.formatted()) steps. \((entry.goal - entry.steps).formatted()) to go.")
    }
}

struct OnPaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OnPaceWidget", provider: OnPaceProvider()) { entry in
            OnPaceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Steps")
        .description("Today's steps and how many are left to your goal.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    OnPaceWidget()
} timeline: {
    OnPaceEntry.sample
    OnPaceEntry(date: .now, steps: 11_527, goal: 10_000)
}
