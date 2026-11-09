import Foundation
import Combine
import CoreMotion
import HealthKit

// Is the person walking right now? Only used to animate the mini-me (it walks when you walk).
// It never touches the step count: steps always come from Apple Health.
// Shared by the iPhone and the watch app.
final class WalkingDetector: ObservableObject {
    @Published private(set) var isWalking = false
    private let motion = CMMotionActivityManager()
    private var running = false

    func start() {
        #if DEBUG
        // Simulator testing: `-demoWalking YES` pretends you're walking.
        if UserDefaults.standard.bool(forKey: "demoWalking") { isWalking = true; return }
        #endif
        guard CMMotionActivityManager.isActivityAvailable(), !running else { return }
        running = true
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            // Walking or running, unless iOS is unsure. Stops when you stop or sit down.
            let moving = (activity.walking || activity.running) && activity.confidence != .low
            if moving != self.isWalking { self.isWalking = moving }
        }
    }

    func stop() {
        guard running else { return }
        motion.stopActivityUpdates()
        running = false
        isWalking = false
    }
}

extension Mood {
    // What the mini-me does when no session is running: walks while you walk,
    // celebrates at goal, stands happy when on pace, slumps when behind.
    static func everyday(walking: Bool, hitGoal: Bool, onPace: Bool) -> Mood {
        if walking { return .walk }
        if hitGoal { return .celebrate }
        return onPace ? .stand : .slump
    }
}

// Apple Health saves steps in batches every few minutes, while the motion chip counts every step right away
// (that's why the Fitness app ticks up live). LiveSteps adds only the steps the motion chip counted AFTER
// Health's last saved step sample: the number moves while you walk, never counts a step twice, and goes back
// to Health's exact total each time Health saves (the window then starts again from the new save).
// Shared by the iPhone and the watch app. Only runs while the app is open.
final class LiveSteps {
    private let pedometer = CMPedometer()
    private var since: Date?
    private(set) var extra = 0
    var onChange: ((Int) -> Void)?

    // Call after every Health read. Restarts counting from Health's newest saved step sample.
    func follow(_ health: HKHealthStore) async {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let dayStart = Calendar.current.startOfDay(for: .now)
        let saved = await LiveTopUp.lastSavedEnd(health, since: dayStart) ?? dayStart
        let from = min(saved, .now)
        guard from != since else { return }
        since = from
        pedometer.stopUpdates()
        set(0)
        pedometer.startUpdates(from: from) { [weak self] data, _ in
            let steps = data?.numberOfSteps.intValue ?? 0
            DispatchQueue.main.async { self?.set(steps) }
        }
    }

    func stop() {
        pedometer.stopUpdates()
        since = nil
        set(0)
    }

    private func set(_ steps: Int) {
        guard steps != extra else { return }
        extra = steps
        onChange?(steps)
    }
}
