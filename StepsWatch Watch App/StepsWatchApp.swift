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
        #if DEBUG
        // Simulator testing: `-appStyle retro16`, `-look <json>` (the phone normally sends these).
        if let style = UserDefaults.standard.string(forKey: "appStyle") { Shared.defaults.set(style, forKey: Shared.appStyleKey) }
        if let look = UserDefaults.standard.string(forKey: "look") { Shared.defaults.set(look, forKey: Shared.lookKey) }
        if let p = UserDefaults.standard.string(forKey: "cozyPalette") { Shared.defaults.set(p, forKey: Shared.cozyPaletteKey) }
        #endif
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
            if error == nil { WidgetCenter.shared.reloadAllTimelines() }
            done()
        }
        health.execute(query)
        health.enableBackgroundDelivery(for: steps, frequency: .immediate) { _, _ in }
    }
}
