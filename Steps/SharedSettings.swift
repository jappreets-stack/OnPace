import SwiftUI
import HealthKit

// Settings the iPhone shares with the watch and its watch-face complications.
// The iPhone is the boss: it sends goal, mini-me and fun unit to the watch (WatchConnectivity),
// and the watch saves them in an App Group so the complications can read them too.
// Shared by all three targets.
nonisolated enum Shared {
    static let appGroup = "group.com.js.personal.Steps"

    // Keys (the same names the iPhone uses in its own @AppStorage).
    static let goalKey = "goal"
    static let avatarKey = "avatar"
    static let lookKey = "look"
    static let funUnitKey = "funUnit"
    static let placeKey = "distancePlace"   // road / beach / trail, for km and mi
    // The iPhone app saves today's steps here for its home-screen widget (used when Health is locked).
    static let stepsKey = "todaySteps"
    static let stepsDateKey = "todayStepsDate"
    static let syncedKeys = [goalKey, avatarKey, lookKey, funUnitKey, placeKey]

    // On the watch: the App Group storage both the app and the complications read.
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    // Your daily goal as the watch + complications know it (10,000 until the phone sends one).
    static var goal: Int {
        let g = defaults.integer(forKey: goalKey)
        return g > 0 ? g : 10_000
    }
}

// How far you really walked, measured by your iPhone / watch with your own stride
// (Apple Health "Walking + Running Distance"). nil if there's no data or no permission.
nonisolated enum WalkDistance {
    static let type = HKQuantityType(.distanceWalkingRunning)

    static func meters(_ health: HKHealthStore, from start: Date, to end: Date = .now) async -> Double? {
        let query = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type,
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum)
        return (try? await query.result(for: health))?.sumQuantity()?.doubleValue(for: .meter())
    }
}

// Steps turned into something you can picture. Uses the real distance you walked when Apple Health
// has it; golf holes always count steps (a hole is about walking, not a straight line).
nonisolated enum FunUnit: String, CaseIterable, Identifiable {
    case holes, soccerFields, footballFields, courts, tennisCourts, bases, laps, blocks, km, mi
    var id: String { rawValue }

    var name: String {
        switch self {
        case .holes: "Golf holes"
        case .soccerFields: "Soccer fields"
        case .footballFields: "Football fields"
        case .courts: "Basketball courts"
        case .tennisCourts: "Tennis courts"
        case .bases: "Trips around the bases"
        case .laps: "Track laps"
        case .blocks: "City blocks"
        case .km: "Kilometers"
        case .mi: "Miles"
        }
    }

    var stepsPerUnit: Double {
        switch self {
        case .holes: 1300        // walking a hole, tee to green plus the walk to the next tee
        case .soccerFields: 140  // one length of a 105 m field
        case .footballFields: 120 // 100 yards, goal line to goal line
        case .courts: 38         // one 28.65 m basketball court
        case .tennisCourts: 31   // one 23.77 m tennis court
        case .bases: 144         // home → 1st → 2nd → 3rd → home, 109.7 m
        case .laps: 525          // one 400 m lap
        case .blocks: 105        // a ~80 m city block
        case .km: 1320
        case .mi: 2125
        }
    }

    // Real size of one unit. nil for holes (counted in steps).
    var metersPerUnit: Double? {
        switch self {
        case .holes: nil
        case .soccerFields: 105
        case .footballFields: 91.44
        case .courts: 28.65
        case .tennisCourts: 23.77
        case .bases: 109.73
        case .laps: 400
        case .blocks: 80
        case .km: 1000
        case .mi: 1609.344
        }
    }

    var emoji: String {
        switch self {
        case .holes: "⛳️"
        case .soccerFields: "⚽️"
        case .footballFields: "🏈"
        case .courts: "🏀"
        case .tennisCourts: "🎾"
        case .bases: "⚾️"
        case .laps: "🏃"
        case .blocks: "🏙️"
        case .km, .mi: "📏"
        }
    }

    var tileTitle: String {
        switch self {
        case .holes: "Golf"
        case .soccerFields: "Soccer"
        case .footballFields: "Football"
        case .courts: "Hoops"
        case .tennisCourts: "Tennis"
        case .bases: "Baseball"
        case .laps: "Track"
        case .blocks: "City"
        case .km, .mi: "Distance"
        }
    }

    var detail: String {
        switch self {
        case .holes: "holes walked"
        case .soccerFields: "soccer fields"
        case .footballFields: "football fields"
        case .courts: "basketball courts"
        case .tennisCourts: "tennis courts"
        case .bases: "trips around the bases"
        case .laps: "track laps"
        case .blocks: "city blocks"
        case .km: "km walked"
        case .mi: "miles walked"
        }
    }

    // Shown at the end of goal days in the Last 7 days table.
    var goalFlag: String { self == .holes ? "⛳️" : "🏁" }

    // meters = real distance walked (from Health); without it, a step-based estimate.
    func amount(_ steps: Int, meters: Double? = nil) -> String {
        let value: Double
        if let per = metersPerUnit, let meters { value = meters / per }
        else { value = Double(steps) / stepsPerUnit }
        let decimals = [.soccerFields, .footballFields, .courts, .tennisCourts, .blocks].contains(self) ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }

    // "Holes walked" (for a row title on the watch)
    var title: String { detail.prefix(1).uppercased() + detail.dropFirst() }

    // "3.2 km walked" (measured) or "~3.2 holes walked" (estimated from steps)
    func phrase(_ steps: Int, meters: Double? = nil) -> String {
        let measured = metersPerUnit != nil && meters != nil
        return "\(measured ? "" : "~")\(amount(steps, meters: meters)) \(detail)"
    }
}


// Where you walk when you count km or miles: changes the scene, not the math.
nonisolated enum DistancePlace: String, CaseIterable, Identifiable {
    case road, beach, trail
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .road: "🛣️"
        case .beach: "🏖️"
        case .trail: "🥾"
        }
    }
}

// MARK: - Fun-unit scene (drawn inside the ring, behind your mini-me)

// A soft scene that matches your fun unit: golf green, soccer field, running track, city, road.
// Drawn on a 270 x 270 grid (the ring's size); the ground line sits at your mini-me's feet.
// Shared with the watch, whose ring puts the feet higher (see `horizon`).
struct UnitScene: View {
    let unit: FunUnit
    var place: DistancePlace = .road
    var horizon = 152.0   // where the ground starts on the 270 grid (your mini-me's feet)
    var lowMarks = true   // field lines / road dashes near the bottom (off on the watch, where text sits there)

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 270
            ctx.scaleBy(x: s, y: s)
            let ground = CGRect(x: 0, y: horizon, width: 270, height: 270 - horizon)

            func fill(_ r: CGRect, _ c: Color) { ctx.fill(Path(r), with: .color(c)) }
            func line(_ a: CGPoint, _ b: CGPoint, _ c: Color, _ w: Double, dash: [CGFloat] = []) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, dash: dash))
            }
            let grass = Color(red: 0.30, green: 0.65, blue: 0.30)
            let sky = Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.18)
            fill(CGRect(x: 0, y: 0, width: 270, height: horizon), sky)

            switch unit {
            case .holes:   // fairway, putting green, flag
                fill(ground, grass.opacity(0.30))
                ctx.fill(Path(ellipseIn: CGRect(x: 160, y: horizon - 6, width: 90, height: 24)),
                         with: .color(grass.opacity(0.35)))
                line(CGPoint(x: 205, y: horizon + 6), CGPoint(x: 205, y: horizon - 48), Color.gray.opacity(0.8), 1.5)
                var flag = Path()
                flag.move(to: CGPoint(x: 205, y: horizon - 48))
                flag.addLine(to: CGPoint(x: 224, y: horizon - 42))
                flag.addLine(to: CGPoint(x: 205, y: horizon - 36))
                ctx.fill(flag, with: .color(Color.red.opacity(0.75)))
                ctx.fill(Path(ellipseIn: CGRect(x: 201, y: horizon + 4, width: 8, height: 3)), with: .color(.black.opacity(0.4)))

            case .soccerFields:   // mowed stripes, center circle, goal
                for i in 0..<9 {
                    fill(CGRect(x: Double(i) * 30, y: horizon, width: 30, height: ground.height),
                         grass.opacity(i.isMultiple(of: 2) ? 0.32 : 0.22))
                }
                // halfway line + center circle, low enough to stay under the step count
                if lowMarks {
                    ctx.stroke(Path(ellipseIn: CGRect(x: 85, y: horizon + 84, width: 100, height: 30)),
                               with: .color(.white.opacity(0.7)), lineWidth: 1.5)
                    line(CGPoint(x: 0, y: horizon + 99), CGPoint(x: 270, y: horizon + 99), .white.opacity(0.7), 1.5)
                }
                // goal frame + net
                let goal = CGRect(x: 182, y: horizon - 34, width: 50, height: 34)
                for x in stride(from: goal.minX, through: goal.maxX, by: 7) {
                    line(CGPoint(x: x, y: goal.minY), CGPoint(x: x, y: goal.maxY), .gray.opacity(0.35), 0.7)
                }
                for y in stride(from: goal.minY, through: goal.maxY, by: 7) {
                    line(CGPoint(x: goal.minX, y: y), CGPoint(x: goal.maxX, y: y), .gray.opacity(0.35), 0.7)
                }
                var frame = Path()
                frame.move(to: CGPoint(x: goal.minX, y: goal.maxY))
                frame.addLine(to: CGPoint(x: goal.minX, y: goal.minY))
                frame.addLine(to: CGPoint(x: goal.maxX, y: goal.minY))
                frame.addLine(to: CGPoint(x: goal.maxX, y: goal.maxY))
                ctx.stroke(frame, with: .color(.white), lineWidth: 2.5)
                ctx.stroke(frame, with: .color(.gray.opacity(0.5)), lineWidth: 0.6)

            case .footballFields:   // yard lines, numbers, yellow goalposts
                fill(ground, grass.opacity(0.32))
                for i in 0..<10 {   // yard lines, leaning a little for depth
                    let x = Double(i) * 30 + 6
                    line(CGPoint(x: x, y: horizon), CGPoint(x: x - 14, y: 270), .white.opacity(0.55), 1.3)
                }
                if lowMarks {
                    for (x, n) in [(48.0, "20"), (138.0, "30"), (228.0, "40")] {
                        ctx.draw(Text(n).font(.system(size: 15, weight: .heavy)).foregroundStyle(.white.opacity(0.6)),
                                 at: CGPoint(x: x, y: horizon + 88))
                    }
                }
                let post = Color(red: 0.98, green: 0.80, blue: 0.15)
                line(CGPoint(x: 210, y: horizon + 2), CGPoint(x: 210, y: horizon - 30), post, 3)
                line(CGPoint(x: 188, y: horizon - 30), CGPoint(x: 232, y: horizon - 30), post, 3)
                line(CGPoint(x: 188, y: horizon - 30), CGPoint(x: 188, y: horizon - 82), post, 2.5)
                line(CGPoint(x: 232, y: horizon - 30), CGPoint(x: 232, y: horizon - 82), post, 2.5)

            case .courts:   // hardwood floor, three-point line, hoop
                let wood = Color(red: 0.80, green: 0.55, blue: 0.30)
                fill(ground, wood.opacity(0.45))
                for y in stride(from: horizon + 9, to: 270, by: 9) {   // floor boards
                    line(CGPoint(x: 0, y: y), CGPoint(x: 270, y: y), wood.opacity(0.35), 0.8)
                }
                line(CGPoint(x: 0, y: horizon + 1), CGPoint(x: 270, y: horizon + 1), .white.opacity(0.6), 1.5)
                if lowMarks {
                    ctx.stroke(Path(ellipseIn: CGRect(x: 60, y: horizon + 70, width: 300, height: 80)),
                               with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                }
                // pole, backboard, rim, net
                line(CGPoint(x: 236, y: horizon), CGPoint(x: 236, y: horizon - 70), .gray.opacity(0.8), 4)
                line(CGPoint(x: 236, y: horizon - 70), CGPoint(x: 220, y: horizon - 70), .gray.opacity(0.8), 3)
                let board = CGRect(x: 186, y: horizon - 92, width: 36, height: 26)
                ctx.fill(Path(roundedRect: board, cornerRadius: 2), with: .color(.white.opacity(0.85)))
                ctx.stroke(Path(CGRect(x: 197, y: horizon - 84, width: 14, height: 11)), with: .color(.orange), lineWidth: 1.5)
                let rim = CGRect(x: 192, y: horizon - 69, width: 24, height: 5)
                for i in 0...4 {
                    let x = rim.minX + Double(i) * 6
                    line(CGPoint(x: x, y: rim.midY), CGPoint(x: 198 + Double(i) * 3, y: horizon - 50), .white.opacity(0.7), 0.8)
                }
                ctx.stroke(Path(ellipseIn: rim), with: .color(.orange), lineWidth: 2.5)

            case .laps:   // red running track with lane lines, infield grass up top
                fill(CGRect(x: 0, y: horizon - 18, width: 270, height: 18), grass.opacity(0.25))
                fill(ground, Color(red: 0.85, green: 0.35, blue: 0.25).opacity(0.35))
                for i in 0...5 {
                    let y = horizon + Double(i) * 20
                    line(CGPoint(x: 0, y: y), CGPoint(x: 270, y: y), .white.opacity(i == 0 ? 0.8 : 0.45), 1.2)
                }
                line(CGPoint(x: 205, y: horizon), CGPoint(x: 222, y: 270), .white.opacity(0.6), 2)  // finish line

            case .blocks:   // skyline with windows, sidewalk
                let buildings: [(Double, Double, Double)] = [(0, 40, 70), (38, 34, 105), (70, 30, 55), (98, 36, 90),
                                                             (132, 40, 120), (170, 28, 65), (196, 38, 100), (232, 40, 75)]
                for (x, w, h) in buildings {
                    let r = CGRect(x: x, y: horizon - h, width: w, height: h)
                    fill(r, Color.gray.opacity(0.28))
                    for wy in stride(from: r.minY + 8, to: r.maxY - 6, by: 12) {
                        for wx in stride(from: r.minX + 6, to: r.maxX - 6, by: 10) {
                            fill(CGRect(x: wx, y: wy, width: 4, height: 5), Color.yellow.opacity(0.35))
                        }
                    }
                }
                fill(ground, Color.gray.opacity(0.22))
                for x in stride(from: 0.0, to: 270, by: 30) {   // sidewalk slabs
                    line(CGPoint(x: x, y: horizon), CGPoint(x: x - 12, y: horizon + 22), .gray.opacity(0.35), 1)
                }
                line(CGPoint(x: 0, y: horizon + 22), CGPoint(x: 270, y: horizon + 22), .gray.opacity(0.45), 2)

            case .tennisCourts:   // blue hard court, net
                fill(ground, Color(red: 0.25, green: 0.45, blue: 0.75).opacity(0.45))
                line(CGPoint(x: 0, y: horizon + 2), CGPoint(x: 270, y: horizon + 2), .white.opacity(0.8), 1.5)
                line(CGPoint(x: 150, y: horizon + 30), CGPoint(x: 250, y: horizon + 30), .white.opacity(0.6), 1.2)
                fill(CGRect(x: 160, y: horizon - 22, width: 100, height: 22), .white.opacity(0.10))
                for x in stride(from: 160.0, through: 260, by: 6) {
                    line(CGPoint(x: x, y: horizon - 22), CGPoint(x: x, y: horizon), .white.opacity(0.25), 0.6)
                }
                line(CGPoint(x: 160, y: horizon - 22), CGPoint(x: 260, y: horizon - 22), .white, 2.5)
                line(CGPoint(x: 160, y: horizon - 22), CGPoint(x: 160, y: horizon), .gray, 2)

            case .bases:   // infield dirt, a base, outfield wall
                fill(CGRect(x: 0, y: horizon - 30, width: 270, height: 30), Color(red: 0.20, green: 0.45, blue: 0.25).opacity(0.6))
                fill(CGRect(x: 0, y: horizon - 34, width: 270, height: 4), Color(red: 0.95, green: 0.80, blue: 0.20).opacity(0.7))
                fill(ground, Color(red: 0.75, green: 0.55, blue: 0.35).opacity(0.45))
                ctx.fill(Path(CGRect(x: 196, y: horizon + 4, width: 14, height: 7)), with: .color(.white.opacity(0.9)))

            case .km where place == .beach, .mi where place == .beach:   // sea, sand, sun
                fill(CGRect(x: 0, y: horizon - 34, width: 270, height: 34), Color(red: 0.20, green: 0.55, blue: 0.80).opacity(0.55))
                for i in 0..<5 {
                    let y = horizon - 30 + Double(i) * 7
                    line(CGPoint(x: Double(i) * 23, y: y), CGPoint(x: Double(i) * 23 + 90, y: y), .white.opacity(0.35), 1.2)
                }
                fill(ground, Color(red: 0.93, green: 0.82, blue: 0.60).opacity(0.55))
                ctx.fill(Path(ellipseIn: CGRect(x: 205, y: horizon - 80, width: 26, height: 26)),
                         with: .color(Color(red: 1.0, green: 0.80, blue: 0.30).opacity(0.85)))

            case .km where place == .trail, .mi where place == .trail:   // mountains, pines, trail
                var far = Path()
                far.move(to: CGPoint(x: 0, y: horizon))
                far.addLine(to: CGPoint(x: 70, y: horizon - 60)); far.addLine(to: CGPoint(x: 120, y: horizon - 30))
                far.addLine(to: CGPoint(x: 200, y: horizon - 95)); far.addLine(to: CGPoint(x: 270, y: horizon - 40))
                far.addLine(to: CGPoint(x: 270, y: horizon)); far.closeSubpath()
                ctx.fill(far, with: .color(Color(red: 0.45, green: 0.55, blue: 0.65).opacity(0.55)))
                var snow = Path()
                snow.move(to: CGPoint(x: 186, y: horizon - 78)); snow.addLine(to: CGPoint(x: 200, y: horizon - 95))
                snow.addLine(to: CGPoint(x: 214, y: horizon - 82)); snow.closeSubpath()
                ctx.fill(snow, with: .color(.white.opacity(0.8)))
                fill(ground, Color(red: 0.30, green: 0.50, blue: 0.30).opacity(0.45))
                var trail = Path()
                trail.move(to: CGPoint(x: 110, y: 270)); trail.addQuadCurve(to: CGPoint(x: 150, y: horizon), control: CGPoint(x: 170, y: horizon + 60))
                ctx.stroke(trail, with: .color(Color(red: 0.75, green: 0.62, blue: 0.45).opacity(0.7)), lineWidth: 10)

            case .km, .mi:   // road with dashed center line and a distance sign
                fill(CGRect(x: 0, y: horizon - 10, width: 270, height: 10), grass.opacity(0.25))
                fill(ground, Color.gray.opacity(0.30))
                if lowMarks {
                    line(CGPoint(x: 0, y: horizon + 96), CGPoint(x: 270, y: horizon + 96), .yellow.opacity(0.8), 3, dash: [16, 12])
                }
                line(CGPoint(x: 0, y: horizon + 2), CGPoint(x: 270, y: horizon + 2), .white.opacity(0.7), 1.5)
                line(CGPoint(x: 212, y: horizon - 2), CGPoint(x: 212, y: horizon - 34), .gray.opacity(0.8), 2)
                let sign = CGRect(x: 194, y: horizon - 56, width: 36, height: 22)
                ctx.fill(Path(roundedRect: sign, cornerRadius: 3), with: .color(Color(red: 0.10, green: 0.50, blue: 0.30).opacity(0.85)))
                ctx.draw(Text(unit == .km ? "1 km" : "1 mi").font(.system(size: 10, weight: .bold)).foregroundStyle(.white),
                         at: CGPoint(x: sign.midX, y: sign.midY))
            }
        }
        .accessibilityHidden(true)
    }
}
