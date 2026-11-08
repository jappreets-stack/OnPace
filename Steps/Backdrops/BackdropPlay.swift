import SwiftUI

// Which backdrop goes with your fun unit.

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
}
