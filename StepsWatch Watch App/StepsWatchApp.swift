//
//  StepsWatchApp.swift
//  StepsWatch Watch App
//
//  Created by J s on 11/3/26.
//

import SwiftUI

@main
struct StepsWatch_Watch_AppApp: App {
    init() { WatchSync.shared.start() }   // receives goal + mini-me from the iPhone

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
