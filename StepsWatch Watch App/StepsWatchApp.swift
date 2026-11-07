//
//  StepsWatchApp.swift
//  StepsWatch Watch App
//
//  Created by J s on 11/3/26.
//

import SwiftUI
import HealthKit
import WidgetKit

@main
struct StepsWatch_Watch_AppApp: App {
    init() {
        WatchSync.shared.start()          // receives goal + mini-me from the iPhone
        FaceRefresher.shared.start()      // redraws complications when Health gets new steps
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Apple Health wakes the app in the background when the watch saves new steps,
// and we ask watchOS to redraw the complications right away. It only says "redraw":
// the complications still read the number straight from Apple Health, so it stays exact.
// watchOS still decides how often this is allowed.
nonisolated final class FaceRefresher: @unchecked Sendable {
    static let shared = FaceRefresher()
    private let health = HKHealthStore()
    private var started = false

    func start() {
        guard HKHealthStore.isHealthDataAvailable(), !started else { return }
        started = true
        let steps = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: steps, predicate: nil) { _, done, error in
            if error == nil { Self.redrawFaces() }
            done()
        }
        health.execute(query)
        health.enableBackgroundDelivery(for: steps, frequency: .immediate) { _, _ in }
    }

    // At most once every 3 minutes, so we don't use up watchOS's redraw allowance early in the day.
    private static func redrawFaces() {
        let d = UserDefaults.standard
        let last = d.double(forKey: "lastFaceRedraw")
        guard Date.now.timeIntervalSince1970 - last > 3 * 60 else { return }
        d.set(Date.now.timeIntervalSince1970, forKey: "lastFaceRedraw")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
