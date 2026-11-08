import Foundation
import Combine
import CoreMotion

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
