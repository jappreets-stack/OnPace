import SwiftUI

// What the character is doing.
enum Mood { case slump, walk, celebrate, swing }

// Which character you picked in Settings.
enum Avatar: String, CaseIterable, Identifiable {
    case golfer, baller, ripped
    var id: String { rawValue }

    var name: String {
        switch self {
        case .golfer: "Golfer"
        case .baller: "Baller"
        case .ripped: "Ripped me"
        }
    }
}

struct CharacterView: View {
    let avatar: Avatar
    let mood: Mood

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // Everyone is drawn on a 100 x 140 grid, scaled to fit.
                let s = min(size.width / 100, size.height / 140)
                ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 140 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                switch avatar {
                case .golfer: Golfer.draw(&ctx, mood: mood, t: t)
                case .baller: Baller.draw(&ctx, mood: mood, t: t)
                case .ripped: Ripped.draw(&ctx, mood: mood, t: t)
                }
            }
        }
    }
}

// MARK: - Shared drawing helpers

enum Pen {
    static let skin = Color(red: 0.78, green: 0.56, blue: 0.40)
    static let hair = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let turban = Color(red: 0.12, green: 0.22, blue: 0.50)
    static let turbanFold = Color(red: 0.24, green: 0.36, blue: 0.66)
    static let purple = Color(red: 0.36, green: 0.16, blue: 0.56)
    static let gold = Color(red: 0.99, green: 0.73, blue: 0.15)
    static let lips = Color(red: 0.95, green: 0.6, blue: 0.6)

    // A point `length` away from `from`. Angle: 0 = straight down, + = toward screen right.
    static func reach(_ from: CGPoint, _ deg: Double, _ length: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: from.x + sin(a) * length, y: from.y + cos(a) * length)
    }

    static func line(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: Double) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    static func dot(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: Double, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    static func shadow(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(ellipseIn: CGRect(x: 28, y: 131, width: 44, height: 7)), with: .color(.black.opacity(0.3)))
    }

    static func shoe(_ ctx: inout GraphicsContext, _ foot: CGPoint, _ color: Color = .white) {
        ctx.fill(Path(roundedRect: CGRect(x: foot.x - 6, y: foot.y - 2, width: 12, height: 6), cornerRadius: 3),
                 with: .color(color))
    }

    static func mouth(_ ctx: inout GraphicsContext, y: Double, smile: Bool) {
        var m = Path()
        m.move(to: CGPoint(x: 46, y: y))
        m.addQuadCurve(to: CGPoint(x: 54, y: y), control: CGPoint(x: 50, y: smile ? y + 4 : y - 3.5))
        ctx.stroke(m, with: .color(lips), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }

    // Your head: turban + full beard, with or without sunglasses.
    static func sikhHead(_ base: GraphicsContext, tilt: Double, drop: Double, smile: Bool, sunglasses: Bool,
                         turbanColor: Color = Pen.turban, foldColor: Color = Pen.turbanFold) {
        var head = base
        head.translateBy(x: 50, y: 50 + drop)
        head.rotate(by: .degrees(tilt))
        head.translateBy(x: -50, y: -50)

        head.fill(Path(CGRect(x: 46, y: 44, width: 8, height: 9)), with: .color(skin))            // neck
        head.fill(Path(ellipseIn: CGRect(x: 37, y: 22, width: 26, height: 28)), with: .color(skin)) // face

        var beard = Path()
        beard.move(to: CGPoint(x: 37.5, y: 36))
        beard.addQuadCurve(to: CGPoint(x: 50, y: 58), control: CGPoint(x: 38, y: 56))
        beard.addQuadCurve(to: CGPoint(x: 62.5, y: 36), control: CGPoint(x: 62, y: 56))
        beard.addQuadCurve(to: CGPoint(x: 37.5, y: 36), control: CGPoint(x: 50, y: 44))
        head.fill(beard, with: .color(hair))
        mouth(&head, y: 46, smile: smile)

        if sunglasses {
            head.fill(Path(roundedRect: CGRect(x: 40, y: 31, width: 9, height: 6), cornerRadius: 2.5), with: .color(.black))
            head.fill(Path(roundedRect: CGRect(x: 51, y: 31, width: 9, height: 6), cornerRadius: 2.5), with: .color(.black))
            line(&head, CGPoint(x: 49, y: 33), CGPoint(x: 51, y: 33), .black, 1.5)
            line(&head, CGPoint(x: 42, y: 32.5), CGPoint(x: 44.5, y: 32.5), .white.opacity(0.7), 1)
        } else {
            dot(&head, CGPoint(x: 45, y: 34), 1.7, hair)
            dot(&head, CGPoint(x: 55, y: 34), 1.7, hair)
            line(&head, CGPoint(x: 42.5, y: 31), CGPoint(x: 47.5, y: 30.5), hair, 1.4)   // eyebrows
            line(&head, CGPoint(x: 52.5, y: 30.5), CGPoint(x: 57.5, y: 31), hair, 1.4)
        }

        var wrap = Path()
        wrap.move(to: CGPoint(x: 36, y: 31))
        wrap.addQuadCurve(to: CGPoint(x: 50, y: 12), control: CGPoint(x: 34, y: 14))
        wrap.addQuadCurve(to: CGPoint(x: 64, y: 31), control: CGPoint(x: 66, y: 14))
        wrap.addQuadCurve(to: CGPoint(x: 36, y: 31), control: CGPoint(x: 50, y: 25))
        head.fill(wrap, with: .color(turbanColor))
        var folds = Path()
        folds.move(to: CGPoint(x: 39, y: 26))
        folds.addQuadCurve(to: CGPoint(x: 58, y: 16), control: CGPoint(x: 46, y: 18))
        folds.move(to: CGPoint(x: 61, y: 27))
        folds.addQuadCurve(to: CGPoint(x: 43, y: 16), control: CGPoint(x: 55, y: 18))
        head.stroke(folds, with: .color(foldColor), lineWidth: 1.5)
    }
}

// MARK: - Golfer (purple-and-gold polo, sunglasses, swings in a round)

enum Golfer {
    static let pants = Color(red: 0.86, green: 0.83, blue: 0.75)

    static func arm(_ ctx: inout GraphicsContext, shoulder: CGPoint, hand: CGPoint) {
        let mid = CGPoint(x: (shoulder.x + hand.x) / 2, y: (shoulder.y + hand.y) / 2)
        Pen.line(&ctx, mid, hand, Pen.skin, 6)
        Pen.line(&ctx, shoulder, mid, Pen.purple, 9)   // polo sleeve
        Pen.dot(&ctx, hand, 3.5, Pen.skin)
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double) {
        Pen.shadow(&ctx)

        var bob = 0.0, spread = 5.0, liftL = 0.0, liftR = 0.0
        var armL = -8.0, armR = 8.0
        var headTilt = 0.0, headDrop = 0.0, smile = true
        var club: Double? = nil   // swing angle; both hands on the club

        switch mood {
        case .walk:
            let w = sin(t * 6)
            bob = -abs(w) * 2
            liftL = max(0, w) * 7
            liftR = max(0, -w) * 7
            armL = -10 - 12 * w
            armR = 10 - 12 * w
        case .slump:
            bob = 2
            headTilt = 10 + 3 * sin(t * 1.5)
            headDrop = 3
            armL = -3
            armR = 3
            smile = false
        case .celebrate:
            let j = abs(sin(t * 5))
            bob = -8 * j
            spread = 10
            liftL = 3 * j
            liftR = 3 * j
            armL = -30
            armR = 168 + 12 * sin(t * 10)   // fist pump
        case .swing:
            spread = 10
            let p = t.truncatingRemainder(dividingBy: 2.6) / 2.6
            if p < 0.4 { club = -125 * (p / 0.4) }                          // backswing
            else if p < 0.55 { club = -125 + 265 * ((p - 0.4) / 0.15) }     // downswing
            else if p < 0.85 { club = 140 }                                 // hold the finish
            else { club = 140 * (1 - (p - 0.85) / 0.15) }                   // reset
        }

        var body = ctx
        body.translateBy(x: 0, y: bob)

        for (hipX, angle, lift) in [(45.0, -spread, liftL), (55.0, spread, liftR)] {
            let hip = CGPoint(x: hipX, y: 90)
            let foot = Pen.reach(hip, angle, 38 - lift)
            Pen.line(&body, hip, foot, pants, 9)
            Pen.shoe(&body, foot)
        }

        body.fill(Path(roundedRect: CGRect(x: 35, y: 52, width: 30, height: 40), cornerRadius: 9),
                  with: .color(Pen.purple))
        var collar = Path()
        collar.move(to: CGPoint(x: 43, y: 52))
        collar.addLine(to: CGPoint(x: 50, y: 61))
        collar.addLine(to: CGPoint(x: 57, y: 52))
        body.stroke(collar, with: .color(Pen.gold),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        body.fill(Path(CGRect(x: 35, y: 86, width: 30, height: 4)), with: .color(.black.opacity(0.6)))

        let sL = CGPoint(x: 38, y: 57), sR = CGPoint(x: 62, y: 57)
        if let a = club {
            let hands = Pen.reach(CGPoint(x: 50, y: 60), a, 26)
            let clubHead = Pen.reach(hands, a, 32)
            Pen.line(&body, hands, clubHead, Color(white: 0.85), 2)
            body.fill(Path(ellipseIn: CGRect(x: clubHead.x - 3.5, y: clubHead.y - 2.5, width: 7, height: 5)),
                      with: .color(Color(white: 0.7)))
            arm(&body, shoulder: sL, hand: hands)
            arm(&body, shoulder: sR, hand: hands)
        } else {
            arm(&body, shoulder: sL, hand: Pen.reach(sL, armL, 28))
            arm(&body, shoulder: sR, hand: Pen.reach(sR, armR, 28))
        }

        Pen.sikhHead(body, tilt: headTilt, drop: headDrop, smile: smile, sunglasses: true)
    }
}

// MARK: - Baller (gold "J" jersey, dribbles, dunks, spins the ball)

enum Baller {
    static let skin = Pen.skin
    static let ballColor = Color(red: 0.93, green: 0.48, blue: 0.15)

    static func ball(_ ctx: inout GraphicsContext, _ c: CGPoint, spin: Double) {
        Pen.dot(&ctx, c, 7, ballColor)
        var b = ctx
        b.translateBy(x: c.x, y: c.y)
        b.rotate(by: .radians(spin))
        var seams = Path()
        seams.move(to: CGPoint(x: -7, y: 0)); seams.addLine(to: CGPoint(x: 7, y: 0))
        seams.move(to: CGPoint(x: 0, y: -7)); seams.addLine(to: CGPoint(x: 0, y: 7))
        b.stroke(seams, with: .color(.black.opacity(0.55)), lineWidth: 1)
        b.stroke(Path(ellipseIn: CGRect(x: -7, y: -7, width: 14, height: 14)),
                 with: .color(.black.opacity(0.55)), lineWidth: 1)
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double) {
        Pen.shadow(&ctx)

        var bob = 0.0, spread = 6.0
        var armL = -12.0, armR = 12.0
        var headTilt = 0.0, headDrop = 0.0, smile = true
        var ballAt = CGPoint(x: 75, y: 127)
        var ballInBody = false   // true when the ball moves with his jump
        var spin = 0.0

        switch mood {
        case .walk:   // dribbling
            let b = abs(sin(t * 3.5))
            let handY = 80 + 5 * (1 - b)
            armR = 22
            ballAt = CGPoint(x: 72, y: 127 - b * (127 - (handY + 8)))
            spin = t * 3
        case .slump:  // ball parked, head down
            bob = 2
            headTilt = 10 + 3 * sin(t * 1.5)
            headDrop = 3
            armL = -3
            armR = 3
            smile = false
        case .celebrate:   // dunk jump
            bob = -12 * abs(sin(t * 4))
            spread = 12
            armL = -150
            armR = 160
            ballInBody = true
            spin = t * 2
        case .swing:   // spinning the ball on a finger
            armL = -20
            armR = 165
            ballInBody = true
            spin = t * 9
        }

        var body = ctx
        body.translateBy(x: 0, y: bob)

        // Legs, high-tops, shorts
        for (hipX, angle) in [(45.0, -spread), (55.0, spread)] {
            let hip = CGPoint(x: hipX, y: 92)
            let foot = Pen.reach(hip, angle, 36)
            Pen.line(&body, hip, foot, skin, 8)
            Pen.shoe(&body, foot, Pen.gold)
        }
        body.fill(Path(roundedRect: CGRect(x: 35, y: 84, width: 30, height: 22), cornerRadius: 5),
                  with: .color(Pen.purple))
        Pen.line(&body, CGPoint(x: 36, y: 86), CGPoint(x: 36, y: 104), Pen.gold, 1.5)
        Pen.line(&body, CGPoint(x: 64, y: 86), CGPoint(x: 64, y: 104), Pen.gold, 1.5)

        // Gold jersey with a "J"
        body.fill(Path(roundedRect: CGRect(x: 37, y: 52, width: 26, height: 36), cornerRadius: 6),
                  with: .color(Pen.gold))
        var neck = Path()
        neck.move(to: CGPoint(x: 44, y: 52))
        neck.addQuadCurve(to: CGPoint(x: 56, y: 52), control: CGPoint(x: 50, y: 59))
        body.stroke(neck, with: .color(Pen.purple), lineWidth: 2)
        body.draw(Text("J").font(.system(size: 12, weight: .heavy)).foregroundStyle(Pen.purple),
                  at: CGPoint(x: 50, y: 71))

        // Bare arms
        let sL = CGPoint(x: 39, y: 57), sR = CGPoint(x: 61, y: 57)
        let handL = Pen.reach(sL, armL, 27)
        let handR = Pen.reach(sR, armR, 27)
        Pen.line(&body, sL, handL, skin, 7)
        Pen.line(&body, sR, handR, skin, 7)
        Pen.dot(&body, handL, 3.5, skin)
        Pen.dot(&body, handR, 3.5, skin)

        // Your head: purple turban with gold folds + full beard
        Pen.sikhHead(body, tilt: headTilt, drop: headDrop, smile: smile, sunglasses: false,
                     turbanColor: Pen.purple, foldColor: Pen.gold)

        // Ball goes on top of everything
        if ballInBody {
            ball(&body, CGPoint(x: handR.x, y: handR.y - 9), spin: spin)
        } else {
            ball(&ctx, ballAt, spin: spin)
        }
    }
}

// MARK: - Ripped you (tank top, jogs, flexes, curls the golf bag)

enum Ripped {
    static let tank = Color.white
    static let shorts = Color(red: 0.35, green: 0.35, blue: 0.38)
    static let shine = Color(red: 0.88, green: 0.68, blue: 0.52)

    // Bent arm: upper arm then forearm, with a bicep that can pump up.
    @discardableResult
    static func arm(_ ctx: inout GraphicsContext, _ shoulder: CGPoint,
                    upper: Double, fore: Double, flex: Double = 0) -> CGPoint {
        let elbow = Pen.reach(shoulder, upper, 16)
        let hand = Pen.reach(elbow, fore, 15)
        Pen.line(&ctx, shoulder, elbow, Pen.skin, 10)
        Pen.line(&ctx, elbow, hand, Pen.skin, 8)
        let bicep = CGPoint(x: (shoulder.x + elbow.x) / 2, y: (shoulder.y + elbow.y) / 2)
        Pen.dot(&ctx, bicep, 5.5 + flex, Pen.skin)
        Pen.dot(&ctx, CGPoint(x: bicep.x - 1, y: bicep.y - 1.5), 1.8 + flex / 3, shine)
        Pen.dot(&ctx, hand, 4.5, Pen.skin)   // fist
        return hand
    }

    static func golfBag(_ ctx: inout GraphicsContext, hangingFrom hand: CGPoint) {
        for dx in [-3.0, 0.0, 3.0] {   // club heads sticking out
            Pen.line(&ctx, CGPoint(x: hand.x + dx, y: hand.y + 2), CGPoint(x: hand.x + dx, y: hand.y - 5),
                     Color(white: 0.8), 1.2)
            Pen.dot(&ctx, CGPoint(x: hand.x + dx, y: hand.y - 6), 1.6, Color(white: 0.7))
        }
        ctx.fill(Path(roundedRect: CGRect(x: hand.x - 6, y: hand.y + 1, width: 12, height: 26), cornerRadius: 4),
                 with: .color(Pen.purple))
        ctx.fill(Path(CGRect(x: hand.x - 6, y: hand.y + 8, width: 12, height: 3)), with: .color(Pen.gold))
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double) {
        Pen.shadow(&ctx)

        var bob = 0.0, liftL = 0.0, liftR = 0.0
        var upL = -12.0, foreL = -8.0, upR = 12.0, foreR = 8.0, flex = 0.0
        var headTilt = 0.0, headDrop = 0.0, smile = true
        var seated = false, curling = false

        switch mood {
        case .walk:   // jogging
            let w = sin(t * 8)
            bob = -abs(w) * 4
            liftL = max(0, w) * 10
            liftR = max(0, -w) * 10
            upL = -15 + 20 * w; foreL = 140 + 20 * w
            upR = 15 + 20 * w; foreR = -140 + 20 * w
        case .slump:  // sitting on a bench
            seated = true
            bob = 14
            upL = -25; foreL = 10
            upR = 25; foreR = -10
            headTilt = 14 + 3 * sin(t * 1.5)
            headDrop = 4
            smile = false
        case .celebrate:   // double-bicep flex
            let pump = (sin(t * 6) + 1) / 2
            bob = -1.5 * pump
            upL = -95; foreL = -178
            upR = 95; foreR = 178
            flex = 1 + 2 * pump
        case .swing:   // curling the golf bag
            curling = true
            upR = 10
            foreR = 10 + 150 * (sin(t * 3) + 1) / 2
            flex = 2 * (sin(t * 3) + 1) / 2
        }

        if seated {   // bench
            ctx.fill(Path(roundedRect: CGRect(x: 20, y: 105, width: 60, height: 6), cornerRadius: 2),
                     with: .color(Color(red: 0.45, green: 0.30, blue: 0.20)))
            Pen.line(&ctx, CGPoint(x: 26, y: 111), CGPoint(x: 26, y: 134), Color(white: 0.5), 3)
            Pen.line(&ctx, CGPoint(x: 74, y: 111), CGPoint(x: 74, y: 134), Color(white: 0.5), 3)
        }

        var body = ctx
        body.translateBy(x: 0, y: bob)

        // Legs
        if seated {
            for (hipX, kneeX) in [(44.0, 39.0), (56.0, 61.0)] {
                let knee = CGPoint(x: kneeX, y: 110 - bob)
                let foot = CGPoint(x: kneeX, y: 133 - bob)
                Pen.line(&body, CGPoint(x: hipX, y: 92), knee, shorts, 11)
                Pen.line(&body, knee, foot, Pen.skin, 8)
                Pen.shoe(&body, foot)
            }
        } else {
            for (hipX, angle, lift) in [(44.0, -6.0, liftL), (56.0, 6.0, liftR)] {
                let hip = CGPoint(x: hipX, y: 90)
                let foot = Pen.reach(hip, angle, 38 - lift)
                Pen.line(&body, hip, foot, Pen.skin, 9)
                Pen.shoe(&body, foot)
            }
            body.fill(Path(roundedRect: CGRect(x: 35, y: 84, width: 30, height: 17), cornerRadius: 4),
                      with: .color(shorts))
        }

        // V-shaped torso in a tank top, big shoulders
        Pen.dot(&body, CGPoint(x: 33, y: 59), 6.5, Pen.skin)
        Pen.dot(&body, CGPoint(x: 67, y: 59), 6.5, Pen.skin)
        var torso = Path()
        torso.move(to: CGPoint(x: 32, y: 55))
        torso.addLine(to: CGPoint(x: 68, y: 55))
        torso.addLine(to: CGPoint(x: 61, y: 90))
        torso.addLine(to: CGPoint(x: 39, y: 90))
        torso.closeSubpath()
        body.fill(torso, with: .color(Pen.skin))
        var tankTop = Path()
        tankTop.move(to: CGPoint(x: 40, y: 55))
        tankTop.addQuadCurve(to: CGPoint(x: 60, y: 55), control: CGPoint(x: 50, y: 66))
        tankTop.addLine(to: CGPoint(x: 64, y: 70))
        tankTop.addLine(to: CGPoint(x: 61, y: 90))
        tankTop.addLine(to: CGPoint(x: 39, y: 90))
        tankTop.addLine(to: CGPoint(x: 36, y: 70))
        tankTop.closeSubpath()
        body.fill(tankTop, with: .color(tank))
        var pecs = Path()
        pecs.move(to: CGPoint(x: 41, y: 70)); pecs.addQuadCurve(to: CGPoint(x: 50, y: 70), control: CGPoint(x: 45.5, y: 74))
        pecs.move(to: CGPoint(x: 50, y: 70)); pecs.addQuadCurve(to: CGPoint(x: 59, y: 70), control: CGPoint(x: 54.5, y: 74))
        body.stroke(pecs, with: .color(.black.opacity(0.15)), lineWidth: 1.2)

        // Arms
        let sL = CGPoint(x: 33, y: 59), sR = CGPoint(x: 67, y: 59)
        arm(&body, sL, upper: upL, fore: foreL, flex: curling ? 0 : flex)
        if curling {
            let elbow = Pen.reach(sR, upR, 16)
            let hand = Pen.reach(elbow, foreR, 15)
            golfBag(&body, hangingFrom: hand)
        }
        arm(&body, sR, upper: upR, fore: foreR, flex: flex)

        Pen.sikhHead(body, tilt: headTilt, drop: headDrop, smile: smile, sunglasses: false)
    }
}
