import Foundation
import WatchConnectivity

// Sends your goal, mini-me and fun unit to the watch whenever they change on the iPhone.
// Uses the "application context": the watch always gets the latest copy, even if it was
// asleep or out of range when you changed something.
nonisolated final class PhoneSync: NSObject, WCSessionDelegate {
    static let shared = PhoneSync()
    private var lastSent: [String: String] = [:]

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        // Any settings change on the phone → send (only if a synced value actually changed).
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.send() }
    }

    func send() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let d = UserDefaults.standard
        var context: [String: String] = [:]
        for key in Shared.syncedKeys {
            if let v = d.object(forKey: key) { context[key] = "\(v)" }
        }
        guard context != lastSent else { return }
        do {
            try session.updateApplicationContext(context)
            lastSent = context
        } catch {
            print("Watch sync failed: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.send() }
    }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.lastSent = [:]; self.send() }   // e.g. watch app just installed
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }   // switched watches
}
