import Foundation
import WatchConnectivity
import HealthKit

// Sends your goal, mini-me and fun unit to the watch whenever they change on the iPhone.
// Uses the "application context": the watch always gets the latest copy, even if it was
// asleep or out of range when you changed something.
// @unchecked Sendable: all work happens on the main queue (see the DispatchQueue.main calls).
nonisolated final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
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
        // Today's steps, distance and sessions as the phone sees them.
        for key in Shared.liveKeys {
            if let v = Shared.defaults.object(forKey: key) { context[key] = "\(v)" }
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
    // The watch asks for today's numbers when you open it. This can wake the app in the background.
    // Health can only be read while the iPhone is unlocked (or was recently), otherwise we answer
    // with the last numbers we saved.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        Task {
            let health = HKHealthStore()
            let start = Calendar.current.startOfDay(for: .now)
            let query = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: HKQuantityType(.stepCount),
                                           predicate: HKQuery.predicateForSamples(withStart: start, end: .now)),
                options: .cumulativeSum)
            let d = Shared.defaults
            if let sum = try? await query.result(for: health)?.sumQuantity() {
                d.set(Int(sum.doubleValue(for: .count())), forKey: Shared.stepsKey)
                d.set(Date.now.timeIntervalSince1970, forKey: Shared.stepsDateKey)
                if let m = await WalkDistance.meters(health, from: start) { d.set(m, forKey: Shared.metersKey) }
            }
            var reply: [String: String] = [:]
            for key in Shared.liveKeys {
                if let v = d.object(forKey: key) { reply[key] = "\(v)" }
            }
            replyHandler(reply)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }   // switched watches
}
