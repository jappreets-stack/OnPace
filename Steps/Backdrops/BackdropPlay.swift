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

    // What the ball does once it gets there.
    enum Finish: Equatable {
        case stop                               // stays put (frisbee caught, flag planted)
        case sink                               // drops into the cup
        case dropThrough(Double)                // falls straight down this far (through the net)
        case carryOn(Double, Double)            // keeps going this far (through the uprights, over the wall)
    }

    struct Play {
        let move: SportMove
        let flier: Flier
        let peak: Double          // how high the arc goes above the straight line (points)
        let flight: Double        // seconds in the air
        let cheer: String         // said when it works
        let miss: String?         // said when it doesn't (sometimes it doesn't — it's funnier)
        var travels = false       // the mini-me runs over to the target and back
        var finish: Finish = .stop
        var endScale = 1.0        // ball size at the target (smaller = farther away)
    }

    var play: Play {
        switch self {
        case .golf: Play(move: .golfSwing, flier: .golfBall, peak: 120, flight: 1.5, cheer: "In the cup!", miss: "Lipped out.",
                         finish: .sink, endScale: 0.8)
        case .soccer: Play(move: .kick, flier: .emoji("⚽️", size: 22), peak: 60, flight: 1.0, cheer: "GOAL!", miss: "Off the post!",
                           finish: .carryOn(8, 4), endScale: 0.7)
        case .football: Play(move: .fieldGoal, flier: .emoji("🏈", size: 22), peak: 60, flight: 1.3, cheer: "It's good!", miss: "Wide right.",
                             finish: .carryOn(4, -40), endScale: 0.55)
        case .basketball: Play(move: .jumpShot, flier: .emoji("🏀", size: 20), peak: 90, flight: 1.3, cheer: "Swish!", miss: "Brick.",
                               finish: .dropThrough(46), endScale: 0.8)
        case .tennis: Play(move: .serve, flier: .emoji("🎾", size: 14), peak: 40, flight: 0.8, cheer: "Ace!", miss: "Fault.",
                           finish: .carryOn(20, -16), endScale: 0.7)
        case .baseball: Play(move: .batSwing, flier: .emoji("⚾️", size: 16), peak: 120, flight: 1.4, cheer: "Home run!", miss: "Foul ball.",
                             finish: .carryOn(30, -30), endScale: 0.5)
        case .track: Play(move: .sprint, flier: .none, peak: 0, flight: 0, cheer: "Photo finish!", miss: nil, travels: true)
        case .city: Play(move: .hail, flier: .taxi, peak: 0, flight: 1.0, cheer: "Taxi!", miss: "It didn't stop.")
        case .road: Play(move: .jog, flier: .none, peak: 0, flight: 0, cheer: "Another marker!", miss: nil, travels: true)
        case .beach: Play(move: .throwDisc, flier: .disc, peak: 60, flight: 1.0, cheer: "Nice throw!", miss: "Into the sea.")
        case .trail: Play(move: .plantFlag, flier: .flag, peak: 0, flight: 0.5, cheer: "Summit!", miss: nil)
        }
    }
}
