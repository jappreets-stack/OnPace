import Foundation
import WatchConnectivity
import WidgetKit

// Receives your goal, mini-me and fun unit from the iPhone and saves them in the App Group,
// where both this app and the watch-face complications read them.
nonisolated final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Ask the iPhone for its latest steps (it answers in the background, even if its app is closed).
    func askPhone() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["request": "today"], replyHandler: { [weak self] reply in self?.apply(reply) },
                            errorHandler: nil)
    }

    private func apply(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        DispatchQueue.main.async {
            let d = Shared.defaults
            for key in Shared.syncedKeys + Shared.liveKeys {
                guard let text = context[key] as? String else { continue }
                if key == Shared.goalKey, let goal = Int(text) {
                    if d.integer(forKey: key) != goal { d.set(goal, forKey: key) }
                } else if d.string(forKey: key) != text {
                    d.set(text, forKey: key)
                }
            }
            WidgetCenter.shared.reloadAllTimelines()   // complications pick up the new goal
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)   // the latest copy, if it came while we were closed
    }
    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }
}
