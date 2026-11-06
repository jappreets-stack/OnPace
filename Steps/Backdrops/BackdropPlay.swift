import SwiftUI

// Which backdrop goes with your fun unit, and what your mini-me does in it when you tap.

extension Backdrop {
    init(unit: FunUnit, place: DistancePlace) {
        switch unit {
        case .holes: self = .golf
        case .soccerFields: self = .soccer
        case .footballFields: self = .football
        case .courts: self = .basketball
        case .tennisCourts: self = .tennis
        case .bases: self = .baseball
        case .laps: self = .track
        case .blocks: self = .city
        case .km, .mi:
            switch place {
            case .road: self = .road
            case .beach: self = .beach
            case .trail: self = .trail
            }
        }
    }

    // What flies (or drives, or pops up) after the move.
    enum Flier: Equatable {
        case emoji(String, size: Double)
        case golfBall
        case disc
        case taxi        // drives in from the left and stops at the target
        case flag        // pops up at the target (summit)
        case none        // the mini-me itself runs to the target
    }

    struct Play {
        let move: SportMove
        let flier: Flier
        let peak: Double          // how high the arc goes above the straight line (points)
        let flight: Double        // seconds in the air
        let cheer: String         // said when it works
        let miss: String?         // said when it doesn't (sometimes it doesn't — it's funnier)
        var travels = false       // the mini-me runs over to the target and back
    }

    var play: Play {
        switch self {
        case .golf: Play(move: .golfSwing, flier: .golfBall, peak: 140, flight: 1.1, cheer: "In the cup!", miss: "Lipped out.")
        case .soccer: Play(move: .kick, flier: .emoji("⚽️", size: 22), peak: 90, flight: 0.8, cheer: "GOAL!", miss: "Off the post!")
        case .football: Play(move: .fieldGoal, flier: .emoji("🏈", size: 22), peak: 160, flight: 1.0, cheer: "It's good!", miss: "Wide right.")
        case .basketball: Play(move: .jumpShot, flier: .emoji("🏀", size: 20), peak: 120, flight: 0.9, cheer: "Swish!", miss: "Brick.")
        case .tennis: Play(move: .serve, flier: .emoji("🎾", size: 14), peak: 40, flight: 0.6, cheer: "Ace!", miss: "Fault.")
        case .baseball: Play(move: .batSwing, flier: .emoji("⚾️", size: 16), peak: 160, flight: 1.2, cheer: "Home run!", miss: "Foul ball.")
        case .track: Play(move: .sprint, flier: .none, peak: 0, flight: 0, cheer: "Photo finish!", miss: nil, travels: true)
        case .city: Play(move: .hail, flier: .taxi, peak: 0, flight: 1.0, cheer: "Taxi!", miss: "It didn't stop.")
        case .road: Play(move: .jog, flier: .none, peak: 0, flight: 0, cheer: "Another marker!", miss: nil, travels: true)
        case .beach: Play(move: .throwDisc, flier: .disc, peak: 60, flight: 1.0, cheer: "Nice throw!", miss: "Into the sea.")
        case .trail: Play(move: .plantFlag, flier: .flag, peak: 0, flight: 0.5, cheer: "Summit!", miss: nil)
        }
    }
}
