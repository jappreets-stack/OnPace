//
//  StepsApp.swift
//  Steps
//
//  Created by J s on 11/2/26.
//

import SwiftUI

@main
struct StepsApp: App {
    init() {
        PhoneSync.shared.start()   // keeps the watch's goal + mini-me in step with the phone

        // First-time setup is for new people. Anyone who already has a goal, a mini-me or
        // sessions saved was using OnPace before setup existed, so they skip it.
        let d = UserDefaults.standard
        if d.object(forKey: "didSetup") == nil {
            let returning = ["goal", "look", "avatar", "rounds", "funUnit"].contains { d.object(forKey: $0) != nil }
            d.set(returning, forKey: "didSetup")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
