//
//  StepsApp.swift
//  Steps
//
//  Created by J s on 11/2/26.
//

import SwiftUI

@main
struct StepsApp: App {
    init() { PhoneSync.shared.start() }   // keeps the watch's goal + mini-me in step with the phone

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
