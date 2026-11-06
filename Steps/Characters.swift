import SwiftUI

// What the character is doing. `.move` plays a one-shot sport move (see SportMove below).
enum Mood: Hashable {
    case slump, walk, celebrate, swing
    case move(SportMove)
}

// Something your mini-me carries while walking during a session (hike, dog walk, ...).
nonisolated enum Prop: String, Codable {
    case hikingStick, dog, bags, balloon, dumbbells
}

// Which character you picked in Settings.
enum Avatar: String, CaseIterable, Identifiable {
    case golfer, baller, ripped
    var id: String { rawValue }

    var name: String {
        switch self {
        case .golfer: "Golfer"
        case .baller: "Baller"
        case .ripped: "Gym"
        }
    }
}

// MARK: - Your look ("build your mini-me")

nonisolated enum SkinTone: String, Codable, CaseIterable, Identifiable {
    case light, fair, tan, medium, brown, deep
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var rgb: (Double, Double, Double) {
        switch self {
        case .light: (0.98, 0.84, 0.73)
        case .fair: (0.93, 0.74, 0.58)
        case .tan: (0.78, 0.56, 0.40)
        case .medium: (0.63, 0.43, 0.29)
        case .brown: (0.47, 0.31, 0.20)
        case .deep: (0.31, 0.20, 0.14)
        }
    }
    var color: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
    // A lighter dot for the shine on Ripped's biceps.
    var shine: Color { Color(red: rgb.0 + (1 - rgb.0) * 0.3, green: rgb.1 + (1 - rgb.1) * 0.3,
                             blue: rgb.2 + (1 - rgb.2) * 0.3) }
}

nonisolated enum HairStyle: String, Codable, CaseIterable, Identifiable {
    case turban, hijab, short, long, ponytail, braids, curly, bun, bald, cap
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var wearsHat: Bool { self == .turban || self == .cap || self == .hijab }
}

nonisolated enum HairColor: String, Codable, CaseIterable, Identifiable {
    case black, darkBrown, brown, blonde, red, gray
    var id: String { rawValue }
    var name: String { self == .darkBrown ? "Dark brown" : rawValue.capitalized }
    var color: Color {
        switch self {
        case .black: Color(red: 0.10, green: 0.09, blue: 0.08)
        case .darkBrown: Color(red: 0.25, green: 0.16, blue: 0.10)
        case .brown: Color(red: 0.45, green: 0.30, blue: 0.18)
        case .blonde: Color(red: 0.86, green: 0.70, blue: 0.40)
        case .red: Color(red: 0.70, green: 0.30, blue: 0.15)
        case .gray: Color(red: 0.72, green: 0.72, blue: 0.72)
        }
    }
}

nonisolated enum Beard: String, Codable, CaseIterable, Identifiable {
    case none, stubble, mustache, full
    var id: String { rawValue }
    var name: String { self == .none ? "No beard" : rawValue.capitalized }
}

nonisolated enum Glasses: String, Codable, CaseIterable, Identifiable {
    case none, glasses, sunglasses
    var id: String { rawValue }
    var name: String { self == .none ? "None" : rawValue.capitalized }
}

// Male or female: changes the body shape (female = narrower shoulders, waist, wider hips).
// Saved as "straight" / "curvy" so looks saved before the rename still load.
nonisolated enum BodyShape: String, Codable, CaseIterable, Identifiable {
    case male = "straight", female = "curvy"
    var id: String { rawValue }
    var name: String { self == .male ? "Male" : "Female" }
}

nonisolated enum LipColor: String, Codable, CaseIterable, Identifiable {
    case natural, pink, red, berry
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .natural: Color(red: 0.95, green: 0.6, blue: 0.6)
        case .pink: Color(red: 0.96, green: 0.38, blue: 0.62)
        case .red: Color(red: 0.84, green: 0.10, blue: 0.18)
        case .berry: Color(red: 0.55, green: 0.12, blue: 0.32)
        }
    }
}

nonisolated enum GolfBottoms: String, Codable, CaseIterable, Identifiable {
    case pants, skort
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

nonisolated enum GymTop: String, Codable, CaseIterable, Identifiable {
    case tank, sportsTop
    var id: String { rawValue }
    var name: String { self == .tank ? "Tank top" : "Sports top" }
}

// Colors for outfits, turbans, hijabs and caps.
nonisolated enum Swatch: String, Codable, CaseIterable, Identifiable {
    case purple, gold, navy, blue, red, orange, green, teal, pink, black, white, gray
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var rgb: (Double, Double, Double) {
        switch self {
        case .purple: (0.36, 0.16, 0.56)
        case .gold: (0.99, 0.73, 0.15)
        case .navy: (0.12, 0.22, 0.50)
        case .blue: (0.20, 0.48, 0.90)
        case .red: (0.85, 0.18, 0.20)
        case .orange: (0.96, 0.52, 0.12)
        case .green: (0.15, 0.55, 0.30)
        case .teal: (0.10, 0.62, 0.62)
        case .pink: (0.95, 0.45, 0.65)
        case .black: (0.12, 0.12, 0.13)
        case .white: (0.96, 0.96, 0.96)
        case .gray: (0.50, 0.50, 0.53)
        }
    }
    var color: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
    // A lighter shade, used for the folds of a turban.
    var light: Color {
        switch self {
        case .navy: Color(red: 0.24, green: 0.36, blue: 0.66)
        case .white: Color(white: 0.78)
        default: Color(red: rgb.0 + (1 - rgb.0) * 0.3, green: rgb.1 + (1 - rgb.1) * 0.3,
                       blue: rgb.2 + (1 - rgb.2) * 0.3)
        }
    }
}

// Everything you pick in the character builder. Saved as JSON text in @AppStorage("look").
nonisolated struct Look: Equatable, Codable, RawRepresentable {
    var skin: SkinTone = .tan
    var hair: HairStyle = .turban
    var hairColor: HairColor = .black
    var beard: Beard = .full
    var glasses: Glasses = .none
    var body: BodyShape = .male
    var lashes = false
    var lips: LipColor = .natural
    var bottoms: GolfBottoms = .pants   // Golfer
    var top: GymTop = .tank             // Gym
    var hat: Swatch = .navy          // turban, hijab or cap color
    var hatTrim: Swatch? = nil       // turban folds; nil = a lighter shade of `hat`
    var main: Swatch = .purple       // polo, shorts
    var accent: Swatch = .gold       // collar, jersey, shoes
    var letter: String = "J"         // on the Baller jersey

    // The original look: turban, full beard, purple & gold (the app's first mini-me).
    static let original = Look()

    // What new people start with: a plain look they then make their own in setup.
    static let starter: Look = {
        var l = Look()
        l.skin = .medium
        l.hair = .short
        l.hairColor = .darkBrown
        l.beard = .none
        l.hat = .navy
        l.main = .blue
        l.accent = .white
        l.letter = "1"
        return l
    }()

    // How each character looked before the builder (the watch still uses these).
    static func classic(_ avatar: Avatar) -> Look {
        var look = Look()
        switch avatar {
        case .golfer: look.glasses = .sunglasses
        case .baller: look.hat = .purple; look.hatTrim = .gold
        case .ripped: break
        }
        return look
    }

    var foldColor: Color { hatTrim?.color ?? hat.light }

    // Switching male/female also sets matching defaults; everything can still be changed after.
    mutating func switchTo(_ newBody: BodyShape) {
        guard newBody != body else { return }
        body = newBody
        switch newBody {
        case .female:
            lashes = true
            lips = .pink
            beard = .none
            if [.turban, .short, .bald].contains(hair) { hair = .ponytail }
            bottoms = .skort
            top = .sportsTop
        case .male:
            let starter = Look.starter
            lashes = false
            lips = .natural
            beard = starter.beard
            if [.ponytail, .braids, .bun].contains(hair) { hair = starter.hair }
            hat = starter.hat
            hatTrim = nil
            bottoms = .pants
            top = .tank
        }
    }

    init() {}

    // Missing fields fall back to the defaults, so adding options later never resets your look.
    enum CodingKeys: String, CodingKey {
        case skin, hair, hairColor, beard, glasses, body, lashes, lips, bottoms, top, hat, hatTrim, main, accent, letter
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skin = (try? c.decode(SkinTone.self, forKey: .skin)) ?? skin
        hair = (try? c.decode(HairStyle.self, forKey: .hair)) ?? hair
        hairColor = (try? c.decode(HairColor.self, forKey: .hairColor)) ?? hairColor
        beard = (try? c.decode(Beard.self, forKey: .beard)) ?? beard
        glasses = (try? c.decode(Glasses.self, forKey: .glasses)) ?? glasses
        body = (try? c.decode(BodyShape.self, forKey: .body)) ?? body
        lashes = (try? c.decode(Bool.self, forKey: .lashes)) ?? lashes
        lips = (try? c.decode(LipColor.self, forKey: .lips)) ?? lips
        bottoms = (try? c.decode(GolfBottoms.self, forKey: .bottoms)) ?? bottoms
        top = (try? c.decode(GymTop.self, forKey: .top)) ?? top
        hat = (try? c.decode(Swatch.self, forKey: .hat)) ?? hat
        hatTrim = try? c.decode(Swatch.self, forKey: .hatTrim)
        main = (try? c.decode(Swatch.self, forKey: .main)) ?? main
        accent = (try? c.decode(Swatch.self, forKey: .accent)) ?? accent
        letter = (try? c.decode(String.self, forKey: .letter)) ?? letter
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(skin, forKey: .skin)
        try c.encode(hair, forKey: .hair)
        try c.encode(hairColor, forKey: .hairColor)
        try c.encode(beard, forKey: .beard)
        try c.encode(glasses, forKey: .glasses)
        try c.encode(body, forKey: .body)
        try c.encode(lashes, forKey: .lashes)
        try c.encode(lips, forKey: .lips)
        try c.encode(bottoms, forKey: .bottoms)
        try c.encode(top, forKey: .top)
        try c.encode(hat, forKey: .hat)
        try c.encodeIfPresent(hatTrim, forKey: .hatTrim)
        try c.encode(main, forKey: .main)
        try c.encode(accent, forKey: .accent)
        try c.encode(letter, forKey: .letter)
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let look = try? JSONDecoder().decode(Look.self, from: data) else { return nil }
        self = look
    }
    var rawValue: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}

struct CharacterView: View {
    let avatar: Avatar
    let mood: Mood
    var look: Look? = nil   // nil = the classic look for this character (watch, for now)
    var prop: Prop? = nil   // carried while walking
    var moveStart: Date? = nil   // when a `.move` mood started; nil = loop the move (previews)

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let look = look ?? Look.classic(avatar)
            Canvas { ctx, size in
                // Everyone is drawn on a 100 x 140 grid, scaled to fit.
                let s = min(size.width / 100, size.height / 140)
                ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 140 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                if case .move(let m) = mood {
                    let p = moveStart.map { min(1, max(0, timeline.date.timeIntervalSince($0) / m.duration)) }
                        ?? Moves.loop(m, t: t)
                    Moves.draw(&ctx, avatar: avatar, move: m, p: p, t: t, look: look)
                    return
                }
                switch avatar {
                case .golfer: Golfer.draw(&ctx, mood: mood, t: t, look: look, prop: mood == .walk ? prop : nil)
                case .baller: Baller.draw(&ctx, mood: mood, t: t, look: look, prop: mood == .walk ? prop : nil)
                case .ripped: Ripped.draw(&ctx, mood: mood, t: t, look: look, prop: mood == .walk ? prop : nil)
                }
            }
        }
    }
}

// MARK: - Shared drawing helpers

enum Pen {
    static let hair = Color(red: 0.10, green: 0.09, blue: 0.08)   // eyes
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

    // An hourglass torso for the curvy body: shoulders, a narrower waist, wider hips.
    static func hourglass(top y0: Double, bottom y1: Double, shoulders sw: Double, waist ww: Double,
                          hips hw: Double) -> Path {
        let mid = (y0 + y1) / 2 + 4
        var p = Path()
        p.move(to: CGPoint(x: 50 - sw, y: y0))
        p.addLine(to: CGPoint(x: 50 + sw, y: y0))
        p.addQuadCurve(to: CGPoint(x: 50 + hw, y: y1), control: CGPoint(x: 50 + ww, y: mid))
        p.addLine(to: CGPoint(x: 50 - hw, y: y1))
        p.addQuadCurve(to: CGPoint(x: 50 - sw, y: y0), control: CGPoint(x: 50 - ww, y: mid))
        p.closeSubpath()
        return p
    }

    static func mouth(_ ctx: inout GraphicsContext, y: Double, smile: Bool, color: Color = lips, width: Double = 1.8) {
        var m = Path()
        m.move(to: CGPoint(x: 46, y: y))
        m.addQuadCurve(to: CGPoint(x: 54, y: y), control: CGPoint(x: 50, y: smile ? y + 4 : y - 3.5))
        ctx.stroke(m, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    // Your head, drawn from your look: hair or headwear, beard, glasses.
    static func head(_ base: GraphicsContext, look: Look, tilt: Double = 0, drop: Double = 0, smile: Bool = true) {
        var head = base
        head.translateBy(x: 50, y: 50 + drop)
        head.rotate(by: .degrees(tilt))
        head.translateBy(x: -50, y: -50)
        let skin = look.skin.color
        let hairColor = look.hairColor.color

        // Behind the head: long hair falls to the shoulders, a bun sits on top.
        if look.hair == .long {
            head.fill(Path(roundedRect: CGRect(x: 34, y: 19, width: 32, height: 40), cornerRadius: 13),
                      with: .color(hairColor))
        }
        if look.hair == .bun { dot(&head, CGPoint(x: 50, y: 16), 5.5, hairColor) }
        if look.hair == .ponytail {   // tail swinging out behind the head
            var tail = Path()
            tail.move(to: CGPoint(x: 58, y: 21))
            tail.addQuadCurve(to: CGPoint(x: 69, y: 44), control: CGPoint(x: 72, y: 24))
            head.stroke(tail, with: .color(hairColor), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        }
        if look.hair == .hijab {   // scarf around the head, draping over the shoulders
            var scarf = Path()
            scarf.move(to: CGPoint(x: 36, y: 30))
            scarf.addQuadCurve(to: CGPoint(x: 50, y: 13), control: CGPoint(x: 35, y: 13))
            scarf.addQuadCurve(to: CGPoint(x: 64, y: 30), control: CGPoint(x: 65, y: 13))
            scarf.addLine(to: CGPoint(x: 66, y: 48))
            scarf.addQuadCurve(to: CGPoint(x: 70, y: 62), control: CGPoint(x: 66, y: 57))
            scarf.addLine(to: CGPoint(x: 30, y: 62))
            scarf.addQuadCurve(to: CGPoint(x: 34, y: 48), control: CGPoint(x: 34, y: 57))
            scarf.closeSubpath()
            head.fill(scarf, with: .color(look.hat.color))
        } else {
            head.fill(Path(CGRect(x: 46, y: 44, width: 8, height: 9)), with: .color(skin))        // neck
        }
        head.fill(Path(ellipseIn: CGRect(x: 37, y: 22, width: 26, height: 28)), with: .color(skin)) // face

        if look.beard == .full || look.beard == .stubble {
            var beard = Path()
            beard.move(to: CGPoint(x: 37.5, y: 36))
            beard.addQuadCurve(to: CGPoint(x: 50, y: 58), control: CGPoint(x: 38, y: 56))
            beard.addQuadCurve(to: CGPoint(x: 62.5, y: 36), control: CGPoint(x: 62, y: 56))
            beard.addQuadCurve(to: CGPoint(x: 37.5, y: 36), control: CGPoint(x: 50, y: 44))
            head.fill(beard, with: .color(hairColor.opacity(look.beard == .full ? 1 : 0.3)))
        }
        mouth(&head, y: 46, smile: smile, color: look.lips.color, width: look.lips == .natural ? 1.8 : 2.3)
        if look.beard == .mustache {
            var m = Path()
            m.move(to: CGPoint(x: 44.5, y: 44))
            m.addQuadCurve(to: CGPoint(x: 55.5, y: 44), control: CGPoint(x: 50, y: 40.5))
            head.stroke(m, with: .color(hairColor), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }

        // Eyes (always dark), eyebrows in your hair color (hidden under a cap's brim).
        if look.glasses != .sunglasses {
            dot(&head, CGPoint(x: 45, y: 34), 1.7, hair)
            dot(&head, CGPoint(x: 55, y: 34), 1.7, hair)
            if look.lashes {   // a little flick at the outer corner of each eye
                line(&head, CGPoint(x: 43.4, y: 33.2), CGPoint(x: 41.6, y: 31.8), hair, 1.1)
                line(&head, CGPoint(x: 56.6, y: 33.2), CGPoint(x: 58.4, y: 31.8), hair, 1.1)
            }
            if look.hair != .cap {
                line(&head, CGPoint(x: 42.5, y: 30.5), CGPoint(x: 47.5, y: 30), hairColor, 1.4)
                line(&head, CGPoint(x: 52.5, y: 30), CGPoint(x: 57.5, y: 30.5), hairColor, 1.4)
            }
        }
        switch look.glasses {
        case .none: break
        case .glasses:
            for x in [45.0, 55.0] {
                head.stroke(Path(ellipseIn: CGRect(x: x - 4.2, y: 29.8, width: 8.4, height: 8.4)),
                            with: .color(.black.opacity(0.85)), lineWidth: 1.2)
            }
            line(&head, CGPoint(x: 49.2, y: 33.5), CGPoint(x: 50.8, y: 33.5), .black.opacity(0.85), 1.2)
        case .sunglasses:
            head.fill(Path(roundedRect: CGRect(x: 40, y: 31, width: 9, height: 6), cornerRadius: 2.5), with: .color(.black))
            head.fill(Path(roundedRect: CGRect(x: 51, y: 31, width: 9, height: 6), cornerRadius: 2.5), with: .color(.black))
            line(&head, CGPoint(x: 49, y: 33), CGPoint(x: 51, y: 33), .black, 1.5)
            line(&head, CGPoint(x: 42, y: 32.5), CGPoint(x: 44.5, y: 32.5), .white.opacity(0.7), 1)
        }

        // On top: hair or headwear.
        switch look.hair {
        case .turban:
            var wrap = Path()
            wrap.move(to: CGPoint(x: 36, y: 31))
            wrap.addQuadCurve(to: CGPoint(x: 50, y: 12), control: CGPoint(x: 34, y: 14))
            wrap.addQuadCurve(to: CGPoint(x: 64, y: 31), control: CGPoint(x: 66, y: 14))
            wrap.addQuadCurve(to: CGPoint(x: 36, y: 31), control: CGPoint(x: 50, y: 25))
            head.fill(wrap, with: .color(look.hat.color))
            var folds = Path()
            folds.move(to: CGPoint(x: 39, y: 26))
            folds.addQuadCurve(to: CGPoint(x: 58, y: 16), control: CGPoint(x: 46, y: 18))
            folds.move(to: CGPoint(x: 61, y: 27))
            folds.addQuadCurve(to: CGPoint(x: 43, y: 16), control: CGPoint(x: 55, y: 18))
            head.stroke(folds, with: .color(look.foldColor), lineWidth: 1.5)
        case .hijab:   // band framing the forehead
            var band = Path()
            band.move(to: CGPoint(x: 36.5, y: 33))
            band.addQuadCurve(to: CGPoint(x: 50, y: 18), control: CGPoint(x: 35.5, y: 18))
            band.addQuadCurve(to: CGPoint(x: 63.5, y: 33), control: CGPoint(x: 64.5, y: 18))
            band.addLine(to: CGPoint(x: 61.5, y: 27.5))
            band.addQuadCurve(to: CGPoint(x: 38.5, y: 27.5), control: CGPoint(x: 50, y: 22.5))
            band.closeSubpath()
            head.fill(band, with: .color(look.hat.color))
            var edge = Path()
            edge.move(to: CGPoint(x: 38.5, y: 27.5))
            edge.addQuadCurve(to: CGPoint(x: 61.5, y: 27.5), control: CGPoint(x: 50, y: 22.5))
            head.stroke(edge, with: .color(look.foldColor), lineWidth: 1.2)
        case .short, .long, .bun, .curly, .ponytail, .braids:
            var top = Path()   // hair over the top of the head, hairline at the forehead
            top.move(to: CGPoint(x: 37, y: 34))
            top.addQuadCurve(to: CGPoint(x: 50, y: 19), control: CGPoint(x: 36, y: 19))
            top.addQuadCurve(to: CGPoint(x: 63, y: 34), control: CGPoint(x: 64, y: 19))
            top.addLine(to: CGPoint(x: 61.5, y: 28))
            top.addQuadCurve(to: CGPoint(x: 38.5, y: 28), control: CGPoint(x: 50, y: 23))
            top.closeSubpath()
            head.fill(top, with: .color(hairColor))
            if look.hair == .long {   // strands down the sides of the face
                line(&head, CGPoint(x: 37.5, y: 29), CGPoint(x: 36.5, y: 54), hairColor, 3.5)
                line(&head, CGPoint(x: 62.5, y: 29), CGPoint(x: 63.5, y: 54), hairColor, 3.5)
            }
            if look.hair == .ponytail {   // hair tie
                dot(&head, CGPoint(x: 59, y: 21.5), 2, look.accent.color)
            }
            if look.hair == .braids {   // two braids down over the shoulders
                for x in [37.0, 63.0] {
                    for i in 0..<7 {
                        dot(&head, CGPoint(x: x + (x < 50 ? -1 : 1) * Double(i) * 0.3, y: 32 + Double(i) * 4.6),
                            3.1, hairColor)
                    }
                    dot(&head, CGPoint(x: x + (x < 50 ? -2 : 2), y: 62), 1.8, look.accent.color)
                }
            }
            if look.hair == .curly {   // a ring of curls around the top
                for deg in stride(from: -15.0, through: 195.0, by: 26.25) {
                    let a = deg * .pi / 180
                    dot(&head, CGPoint(x: 50 + cos(a) * 13, y: 30 - sin(a) * 12), 4.6, hairColor)
                }
            }
        case .bald:
            head.fill(Path(ellipseIn: CGRect(x: 42, y: 23.5, width: 6, height: 3)), with: .color(.white.opacity(0.3)))
        case .cap:
            var dome = Path()
            dome.move(to: CGPoint(x: 36.5, y: 29))
            dome.addQuadCurve(to: CGPoint(x: 50, y: 17), control: CGPoint(x: 36, y: 17))
            dome.addQuadCurve(to: CGPoint(x: 63.5, y: 29), control: CGPoint(x: 64, y: 17))
            dome.closeSubpath()
            head.fill(dome, with: .color(look.hat.color))
            let brim = Path(roundedRect: CGRect(x: 34, y: 26.5, width: 32, height: 4.5), cornerRadius: 2.25)
            head.fill(brim, with: .color(look.hat.color))
            head.fill(brim, with: .color(.black.opacity(0.2)))
            dot(&head, CGPoint(x: 50, y: 17.5), 1.5, look.foldColor)
        }
    }
}

// MARK: - Golfer (polo in your main color with an accent collar, swings in a round)

enum Golfer {
    static let pants = Color(red: 0.86, green: 0.83, blue: 0.75)

    static func arm(_ ctx: inout GraphicsContext, shoulder: CGPoint, hand: CGPoint, look: Look) {
        let mid = CGPoint(x: (shoulder.x + hand.x) / 2, y: (shoulder.y + hand.y) / 2)
        arm(&ctx, shoulder: shoulder, elbow: mid, hand: hand, look: look)
    }

    // Arm bent at the elbow: polo sleeve over the upper arm.
    static func arm(_ ctx: inout GraphicsContext, shoulder: CGPoint, elbow: CGPoint, hand: CGPoint, look: Look) {
        Pen.line(&ctx, elbow, hand, look.skin.color, 6)
        Pen.line(&ctx, shoulder, elbow, look.main.color, 9)   // polo sleeve
        Pen.dot(&ctx, hand, 3.5, look.skin.color)
    }

    static func skirt(_ body: inout GraphicsContext) {
        var skirt = Path()
        skirt.move(to: CGPoint(x: 36, y: 88))
        skirt.addLine(to: CGPoint(x: 64, y: 88))
        skirt.addLine(to: CGPoint(x: 67, y: 104))
        skirt.addLine(to: CGPoint(x: 33, y: 104))
        skirt.closeSubpath()
        body.fill(skirt, with: .color(pants))
    }

    // Polo with the accent collar and a belt.
    static func torso(_ body: inout GraphicsContext, look: Look) {
        let curvy = look.body == .female
        body.fill(curvy ? Pen.hourglass(top: 52, bottom: 92, shoulders: 12, waist: 5, hips: 15)
                        : Path(roundedRect: CGRect(x: 35, y: 52, width: 30, height: 40), cornerRadius: 9),
                  with: .color(look.main.color))
        var collar = Path()
        collar.move(to: CGPoint(x: 43, y: 52))
        collar.addLine(to: CGPoint(x: 50, y: 61))
        collar.addLine(to: CGPoint(x: 57, y: 52))
        body.stroke(collar, with: .color(look.accent.color),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        body.fill(Path(CGRect(x: 35, y: 86, width: 30, height: 4)), with: .color(.black.opacity(0.6)))
    }

    static func rig(_ look: Look) -> MoveRig {
        let skort = look.bottoms == .skort, curvy = look.body == .female
        return MoveRig(hipL: 45, hipR: 55, hipY: 90, thigh: 19, shin: 19,
                       legColor: skort ? look.skin.color : pants, legWidth: skort ? 7 : 9, shoe: .white,
                       shoulderL: CGPoint(x: curvy ? 40 : 38, y: 57), shoulderR: CGPoint(x: curvy ? 60 : 62, y: 57),
                       upper: 14, fore: 14,
                       lower: { b in if skort { skirt(&b) } },
                       torso: { b in torso(&b, look: look) },
                       arm: { b, s, e, h in arm(&b, shoulder: s, elbow: e, hand: h, look: look) })
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double, look: Look, prop: Prop? = nil) {
        if case .move(let m) = mood {
            Moves.draw(&ctx, avatar: .golfer, move: m, p: Moves.loop(m, t: t), t: t, look: look)
            return
        }
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
        case .move: break   // drawn by Moves above
        }

        var body = ctx
        body.translateBy(x: 0, y: bob)

        let skort = look.bottoms == .skort
        for (hipX, angle, lift) in [(45.0, -spread, liftL), (55.0, spread, liftR)] {
            let hip = CGPoint(x: hipX, y: 90)
            let foot = Pen.reach(hip, angle, 38 - lift)
            Pen.line(&body, hip, foot, skort ? look.skin.color : pants, skort ? 7 : 9)
            Pen.shoe(&body, foot)
        }
        if skort { skirt(&body) }

        Props.behind(&body, prop)
        let curvy = look.body == .female
        torso(&body, look: look)

        let sL = CGPoint(x: curvy ? 40 : 38, y: 57), sR = CGPoint(x: curvy ? 60 : 62, y: 57)
        if let a = club {
            let hands = Pen.reach(CGPoint(x: 50, y: 60), a, 26)
            let clubHead = Pen.reach(hands, a, 32)
            Pen.line(&body, hands, clubHead, Color(white: 0.85), 2)
            body.fill(Path(ellipseIn: CGRect(x: clubHead.x - 3.5, y: clubHead.y - 2.5, width: 7, height: 5)),
                      with: .color(Color(white: 0.7)))
            arm(&body, shoulder: sL, hand: hands, look: look)
            arm(&body, shoulder: sR, hand: hands, look: look)
        } else {
            let handL = Pen.reach(sL, armL, 28), handR = Pen.reach(sR, armR, 28)
            arm(&body, shoulder: sL, hand: handL, look: look)
            arm(&body, shoulder: sR, hand: handR, look: look)
            Props.front(&body, ground: &ctx, prop, handL: handL, handR: handR, bob: bob, t: t, look: look)
        }

        Pen.head(body, look: look, tilt: headTilt, drop: headDrop, smile: smile)
    }
}

// MARK: - Baller (jersey with your letter, dribbles, dunks, spins the ball)

enum Baller {
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

    static func shorts(_ body: inout GraphicsContext, look: Look) {
        body.fill(Path(roundedRect: CGRect(x: 35, y: 84, width: 30, height: 22), cornerRadius: 5),
                  with: .color(look.main.color))
        Pen.line(&body, CGPoint(x: 36, y: 86), CGPoint(x: 36, y: 104), look.accent.color, 1.5)
        Pen.line(&body, CGPoint(x: 64, y: 86), CGPoint(x: 64, y: 104), look.accent.color, 1.5)
    }

    // Jersey in your accent color with your letter.
    static func jersey(_ body: inout GraphicsContext, look: Look) {
        // Letter and trim in the main color, unless it matches the jersey.
        let trim = look.main == look.accent ? (look.accent == .white ? Color.black : Color.white) : look.main.color
        let curvy = look.body == .female
        body.fill(curvy ? Pen.hourglass(top: 52, bottom: 88, shoulders: 11, waist: 5, hips: 14)
                        : Path(roundedRect: CGRect(x: 37, y: 52, width: 26, height: 36), cornerRadius: 6),
                  with: .color(look.accent.color))
        var neck = Path()
        neck.move(to: CGPoint(x: 44, y: 52))
        neck.addQuadCurve(to: CGPoint(x: 56, y: 52), control: CGPoint(x: 50, y: 59))
        body.stroke(neck, with: .color(trim), lineWidth: 2)
        body.draw(Text(look.letter).font(.system(size: look.letter.count > 1 ? 10 : 12, weight: .heavy)).foregroundStyle(trim),
                  at: CGPoint(x: 50, y: 71))
    }

    static func rig(_ look: Look) -> MoveRig {
        let curvy = look.body == .female, skin = look.skin.color
        return MoveRig(hipL: 45, hipR: 55, hipY: 92, thigh: 18, shin: 18,
                       legColor: skin, legWidth: 8, shoe: look.accent.color,
                       shoulderL: CGPoint(x: curvy ? 40 : 39, y: 57), shoulderR: CGPoint(x: curvy ? 60 : 61, y: 57),
                       upper: 13.5, fore: 13.5,
                       lower: { b in shorts(&b, look: look) },
                       torso: { b in jersey(&b, look: look) },
                       arm: { b, s, e, h in
                           Pen.line(&b, s, e, skin, 7)
                           Pen.line(&b, e, h, skin, 7)
                           Pen.dot(&b, h, 3.5, skin)
                       })
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double, look: Look, prop: Prop? = nil) {
        if case .move(let m) = mood {   // the move brings its own ball (if any); his ball stays home
            Moves.draw(&ctx, avatar: .baller, move: m, p: Moves.loop(m, t: t), t: t, look: look)
            return
        }
        let skin = look.skin.color
        Pen.shadow(&ctx)

        var bob = 0.0, spread = 6.0
        var armL = -12.0, armR = 12.0
        var headTilt = 0.0, headDrop = 0.0, smile = true
        var ballAt = CGPoint(x: 75, y: 127)
        var ballInBody = false   // true when the ball moves with his jump
        var spin = 0.0

        switch mood {
        case .walk where prop != nil:   // walking with a prop instead of the ball
            let w = sin(t * 6)
            bob = -abs(w) * 2
            armL = -10 - 12 * w
            armR = 10 - 12 * w
            ballAt = CGPoint(x: -100, y: -100)   // ball stays home
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
        case .move: break   // drawn by Moves above
        }

        var body = ctx
        body.translateBy(x: 0, y: bob)

        // Legs, high-tops, shorts
        for (hipX, angle) in [(45.0, -spread), (55.0, spread)] {
            let hip = CGPoint(x: hipX, y: 92)
            let foot = Pen.reach(hip, angle, 36)
            Pen.line(&body, hip, foot, skin, 8)
            Pen.shoe(&body, foot, look.accent.color)
        }
        shorts(&body, look: look)

        // Jersey in your accent color with your letter
        Props.behind(&body, prop)
        let curvy = look.body == .female
        jersey(&body, look: look)

        // Bare arms
        let sL = CGPoint(x: curvy ? 40 : 39, y: 57), sR = CGPoint(x: curvy ? 60 : 61, y: 57)
        let handL = Pen.reach(sL, armL, 27)
        let handR = Pen.reach(sR, armR, 27)
        Pen.line(&body, sL, handL, skin, 7)
        Pen.line(&body, sR, handR, skin, 7)
        Pen.dot(&body, handL, 3.5, skin)
        Pen.dot(&body, handR, 3.5, skin)
        Props.front(&body, ground: &ctx, prop, handL: handL, handR: handR, bob: bob, t: t, look: look)

        Pen.head(body, look: look, tilt: headTilt, drop: headDrop, smile: smile)

        // Ball goes on top of everything
        if ballInBody {
            ball(&body, CGPoint(x: handR.x, y: handR.y - 9), spin: spin)
        } else {
            ball(&ctx, ballAt, spin: spin)
        }
    }
}

// MARK: - Gym (tank or sports top, jogs, flexes, curls the golf bag)

enum Ripped {
    static let tank = Color.white

    // Bent arm: upper arm then forearm, with a bicep that can pump up.
    @discardableResult
    static func arm(_ ctx: inout GraphicsContext, _ shoulder: CGPoint, look: Look,
                    upper: Double, fore: Double, flex: Double = 0) -> CGPoint {
        let elbow = Pen.reach(shoulder, upper, 16)
        let hand = Pen.reach(elbow, fore, 15)
        arm(&ctx, shoulder, elbow: elbow, hand: hand, look: look, flex: flex)
        return hand
    }

    static func arm(_ ctx: inout GraphicsContext, _ shoulder: CGPoint, elbow: CGPoint, hand: CGPoint,
                    look: Look, flex: Double = 0) {
        let slim = look.body == .female
        Pen.line(&ctx, shoulder, elbow, look.skin.color, slim ? 8 : 10)
        Pen.line(&ctx, elbow, hand, look.skin.color, slim ? 7 : 8)
        let bicep = CGPoint(x: (shoulder.x + elbow.x) / 2, y: (shoulder.y + elbow.y) / 2)
        Pen.dot(&ctx, bicep, (slim ? 4.5 : 5.5) + flex, look.skin.color)
        Pen.dot(&ctx, CGPoint(x: bicep.x - 1, y: bicep.y - 1.5), 1.8 + flex / 3, look.skin.shine)
        Pen.dot(&ctx, hand, 4.5, look.skin.color)   // fist
    }

    static func shorts(_ body: inout GraphicsContext, look: Look) {
        body.fill(Path(roundedRect: CGRect(x: 35, y: 84, width: 30, height: 17), cornerRadius: 4),
                  with: .color(look.main.color))
    }

    static func rig(_ look: Look) -> MoveRig {
        let curvy = look.body == .female, shoulderX = curvy ? 13.0 : 17.0
        return MoveRig(hipL: 44, hipR: 56, hipY: 90, thigh: 19, shin: 19,
                       legColor: look.skin.color, legWidth: 9, shoe: .white,
                       shoulderL: CGPoint(x: 50 - shoulderX, y: 59), shoulderR: CGPoint(x: 50 + shoulderX, y: 59),
                       upper: 16, fore: 15,
                       lower: { b in shorts(&b, look: look) },
                       torso: { b in torso(&b, look: look) },
                       arm: { b, s, e, h in arm(&b, s, elbow: e, hand: h, look: look) })
    }

    static func golfBag(_ ctx: inout GraphicsContext, hangingFrom hand: CGPoint, look: Look) {
        for dx in [-3.0, 0.0, 3.0] {   // club heads sticking out
            Pen.line(&ctx, CGPoint(x: hand.x + dx, y: hand.y + 2), CGPoint(x: hand.x + dx, y: hand.y - 5),
                     Color(white: 0.8), 1.2)
            Pen.dot(&ctx, CGPoint(x: hand.x + dx, y: hand.y - 6), 1.6, Color(white: 0.7))
        }
        ctx.fill(Path(roundedRect: CGRect(x: hand.x - 6, y: hand.y + 1, width: 12, height: 26), cornerRadius: 4),
                 with: .color(look.main.color))
        ctx.fill(Path(CGRect(x: hand.x - 6, y: hand.y + 8, width: 12, height: 3)), with: .color(look.accent.color))
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double, look: Look, prop: Prop? = nil) {
        if case .move(let m) = mood {
            Moves.draw(&ctx, avatar: .ripped, move: m, p: Moves.loop(m, t: t), t: t, look: look)
            return
        }
        let shorts = look.main.color
        Pen.shadow(&ctx)

        var bob = 0.0, liftL = 0.0, liftR = 0.0
        var upL = -12.0, foreL = -8.0, upR = 12.0, foreR = 8.0, flex = 0.0
        var headTilt = 0.0, headDrop = 0.0, smile = true
        var seated = false, curling = false

        switch mood {
        case .walk where prop != nil:   // brisk walk, arms low so the prop hangs
            let w = sin(t * 6)
            bob = -abs(w) * 2
            liftL = max(0, w) * 7
            liftR = max(0, -w) * 7
            upL = -12 - 14 * w; foreL = upL + 6
            upR = 12 - 14 * w; foreR = upR - 6
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
        case .move: break   // drawn by Moves above
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
                Pen.line(&body, knee, foot, look.skin.color, 8)
                Pen.shoe(&body, foot)
            }
        } else {
            for (hipX, angle, lift) in [(44.0, -6.0, liftL), (56.0, 6.0, liftR)] {
                let hip = CGPoint(x: hipX, y: 90)
                let foot = Pen.reach(hip, angle, 38 - lift)
                Pen.line(&body, hip, foot, look.skin.color, 9)
                Pen.shoe(&body, foot)
            }
            Ripped.shorts(&body, look: look)
        }

        Props.behind(&body, prop)
        torso(&body, look: look)
        let shoulderX = look.body == .female ? 13.0 : 17.0

        // Arms
        let sL = CGPoint(x: 50 - shoulderX, y: 59), sR = CGPoint(x: 50 + shoulderX, y: 59)
        let handL = arm(&body, sL, look: look, upper: upL, fore: foreL, flex: curling ? 0 : flex)
        if curling {
            let elbow = Pen.reach(sR, upR, 16)
            let hand = Pen.reach(elbow, foreR, 15)
            golfBag(&body, hangingFrom: hand, look: look)
        }
        let handR = arm(&body, sR, look: look, upper: upR, fore: foreR, flex: flex)
        Props.front(&body, ground: &ctx, prop, handL: handL, handR: handR, bob: bob, t: t, look: look)

        Pen.head(body, look: look, tilt: headTilt, drop: headDrop, smile: smile)
    }

    // Torso: V-shaped with big shoulders, or an hourglass for the curvy body
    static func torso(_ body: inout GraphicsContext, look: Look) {
        let curvy = look.body == .female
        let shoulderX = curvy ? 13.0 : 17.0
        Pen.dot(&body, CGPoint(x: 50 - shoulderX, y: 59), curvy ? 5 : 6.5, look.skin.color)
        Pen.dot(&body, CGPoint(x: 50 + shoulderX, y: 59), curvy ? 5 : 6.5, look.skin.color)
        var torso = Path()
        if curvy {
            torso = Pen.hourglass(top: 55, bottom: 90, shoulders: 13, waist: 5, hips: 14)
        } else {
            torso.move(to: CGPoint(x: 32, y: 55))
            torso.addLine(to: CGPoint(x: 68, y: 55))
            torso.addLine(to: CGPoint(x: 61, y: 90))
            torso.addLine(to: CGPoint(x: 39, y: 90))
            torso.closeSubpath()
        }
        body.fill(torso, with: .color(look.skin.color))
        var clothes = body
        clothes.clip(to: torso)
        if look.top == .sportsTop {   // crop top in your accent color, midriff showing
            var crop = Path()
            crop.move(to: CGPoint(x: 28, y: 73))
            crop.addLine(to: CGPoint(x: 28, y: 61))
            crop.addLine(to: CGPoint(x: 40, y: 55))
            crop.addQuadCurve(to: CGPoint(x: 60, y: 55), control: CGPoint(x: 50, y: 64))
            crop.addLine(to: CGPoint(x: 72, y: 61))
            crop.addLine(to: CGPoint(x: 72, y: 73))
            crop.closeSubpath()
            clothes.fill(crop, with: .color(look.accent.color))
        } else if curvy {
            var tankTop = Path()
            tankTop.move(to: CGPoint(x: 28, y: 95))
            tankTop.addLine(to: CGPoint(x: 28, y: 63))
            tankTop.addLine(to: CGPoint(x: 41, y: 55))
            tankTop.addQuadCurve(to: CGPoint(x: 59, y: 55), control: CGPoint(x: 50, y: 66))
            tankTop.addLine(to: CGPoint(x: 72, y: 63))
            tankTop.addLine(to: CGPoint(x: 72, y: 95))
            tankTop.closeSubpath()
            clothes.fill(tankTop, with: .color(tank))
        }
        if look.top == .tank && !curvy {
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
        }
    }
}


// MARK: - Session props (hiking stick, dog, shopping bags, balloon, dumbbells)

enum Props {
    static let wood = Color(red: 0.55, green: 0.36, blue: 0.20)
    static let pack = Color(red: 0.30, green: 0.45, blue: 0.25)

    // Drawn before the torso, so it peeks out from behind (the hiking backpack).
    static func behind(_ body: inout GraphicsContext, _ prop: Prop?) {
        guard prop == .hikingStick else { return }
        body.fill(Path(roundedRect: CGRect(x: 29, y: 51, width: 42, height: 32), cornerRadius: 8), with: .color(pack))
    }

    // Drawn on top, in the hands. `ground` is the unbouncing canvas (the dog walks on it).
    static func front(_ body: inout GraphicsContext, ground: inout GraphicsContext, _ prop: Prop?,
                      handL: CGPoint, handR: CGPoint, bob: Double, t: Double, look: Look) {
        guard let prop else { return }
        switch prop {
        case .hikingStick:
            Pen.line(&body, CGPoint(x: handR.x + 1, y: handR.y - 8), CGPoint(x: handR.x + 5, y: 134 - bob), wood, 2.2)
            Pen.dot(&body, handR, 3.6, look.skin.color)   // hand over the stick

        case .dog:
            let trot = sin(t * 10)
            let dogColor = Color(red: 0.72, green: 0.50, blue: 0.30)
            let dark = Color(red: 0.40, green: 0.25, blue: 0.15)
            // legs
            for (x, phase) in [(75.0, 1.0), (79.0, -1.0), (85.0, -1.0), (89.0, 1.0)] {
                Pen.line(&ground, CGPoint(x: x, y: 125), CGPoint(x: x + 2.5 * trot * phase, y: 134), dogColor, 2.6)
            }
            // tail (wagging), body, head, ear, nose, eye
            Pen.line(&ground, CGPoint(x: 73, y: 121), CGPoint(x: 68 + 2 * sin(t * 14), y: 113), dogColor, 2.4)
            ground.fill(Path(roundedRect: CGRect(x: 71, y: 118, width: 21, height: 9), cornerRadius: 4.5), with: .color(dogColor))
            Pen.dot(&ground, CGPoint(x: 93, y: 115), 5, dogColor)
            ground.fill(Path(ellipseIn: CGRect(x: 88.5, y: 111, width: 4, height: 8)), with: .color(dark))
            Pen.dot(&ground, CGPoint(x: 98, y: 116), 1.4, .black)
            Pen.dot(&ground, CGPoint(x: 94.5, y: 113.5), 0.9, .black)
            // collar + leash from your hand (body coordinates are shifted by the bob)
            Pen.line(&ground, CGPoint(x: 90, y: 118), CGPoint(x: 90, y: 121), look.accent.color, 2)
            var leash = Path()
            let hand = CGPoint(x: handR.x, y: handR.y + bob)
            leash.move(to: hand)
            leash.addQuadCurve(to: CGPoint(x: 90, y: 119),
                               control: CGPoint(x: (hand.x + 90) / 2, y: max(hand.y, 119) + 6))
            ground.stroke(leash, with: .color(.black.opacity(0.7)), lineWidth: 1)

        case .bags:
            for (hand, color) in [(handL, look.main.color), (handR, look.accent.color)] {
                var handle = Path()
                handle.move(to: CGPoint(x: hand.x - 3, y: hand.y + 4))
                handle.addQuadCurve(to: CGPoint(x: hand.x + 3, y: hand.y + 4), control: CGPoint(x: hand.x, y: hand.y - 3))
                body.stroke(handle, with: .color(.black.opacity(0.6)), lineWidth: 1)
                body.fill(Path(roundedRect: CGRect(x: hand.x - 5.5, y: hand.y + 3, width: 11, height: 13), cornerRadius: 1.5),
                          with: .color(color))
                body.fill(Path(CGRect(x: hand.x - 5.5, y: hand.y + 3, width: 11, height: 2.5)), with: .color(.black.opacity(0.15)))
                Pen.dot(&body, hand, 3.4, look.skin.color)
            }

        case .balloon:
            let top = CGPoint(x: 84 + 2 * sin(t * 1.3), y: 22 + 2 * sin(t * 2))
            var string = Path()
            string.move(to: handR)
            string.addQuadCurve(to: CGPoint(x: top.x, y: top.y + 9), control: CGPoint(x: handR.x + 14, y: (handR.y + top.y) / 2))
            body.stroke(string, with: .color(.black.opacity(0.5)), lineWidth: 0.8)
            body.fill(Path(ellipseIn: CGRect(x: top.x - 7, y: top.y - 8, width: 14, height: 17)), with: .color(Swatch.red.color))
            body.fill(Path(ellipseIn: CGRect(x: top.x - 4, y: top.y - 5, width: 3, height: 5)), with: .color(.white.opacity(0.5)))
            Pen.dot(&body, CGPoint(x: top.x, y: top.y + 9), 1.3, Swatch.red.color)

        case .dumbbells:
            for hand in [handL, handR] {
                Pen.line(&body, CGPoint(x: hand.x - 6, y: hand.y), CGPoint(x: hand.x + 6, y: hand.y), Color(white: 0.6), 2.2)
                for dx in [-6.0, 6.0] {
                    body.fill(Path(roundedRect: CGRect(x: hand.x + dx - 2, y: hand.y - 4.5, width: 4, height: 9), cornerRadius: 1),
                              with: .color(Color(white: 0.25)))
                }
                Pen.dot(&body, hand, 3.6, look.skin.color)
            }
        }
    }
}

// MARK: - Sport moves (one-shot animations: golf swing, kick, jump shot, ...)

// A move plays once: wind-up, the action at `release` (ball leaves the foot/hand), then a
// follow-through that holds at the end. Show it with `CharacterView(mood: .move(m), moveStart: Date())`.
enum SportMove: String, CaseIterable {
    case golfSwing, kick, fieldGoal, jumpShot, serve, batSwing, sprint, hail, jog, throwDisc, plantFlag

    // Seconds the whole move takes.
    var duration: Double {
        switch self {
        case .golfSwing: 1.6
        case .kick, .fieldGoal: 1.2
        case .jumpShot: 1.3
        case .serve: 1.5
        case .batSwing: 1.1
        case .sprint: 1.4
        case .hail: 1.0
        case .jog: 1.6
        case .throwDisc: 1.2
        case .plantFlag: 1.5
        }
    }

    // 0...1: when the ball/disc leaves (hand goes up for hail, flag goes in, the finish for sprint).
    var release: Double {
        switch self {
        case .golfSwing: 0.5
        case .kick, .fieldGoal: 0.55
        case .jumpShot: 0.55
        case .serve: 0.6
        case .batSwing: 0.5
        case .sprint: 0.8
        case .hail: 0.4
        case .jog: 0.6
        case .throwDisc: 0.55
        case .plantFlag: 0.6
        }
    }

    // Where the ball/disc is on the 100 x 140 grid at the release moment (start the ball flight here).
    static func releasePoint(_ m: SportMove) -> CGPoint { m.releasePoint }
    var releasePoint: CGPoint { Moves.pose(self, p: release, t: 0).contact }
}

// One outfit's body parts, so every outfit can draw every move.
struct MoveRig {
    var hipL: Double, hipR: Double, hipY: Double
    var thigh: Double, shin: Double
    var legColor: Color, legWidth: Double, shoe: Color
    var shoulderL: CGPoint, shoulderR: CGPoint
    var upper: Double, fore: Double
    var lower: (inout GraphicsContext) -> Void    // shorts / skirt, over the legs
    var torso: (inout GraphicsContext) -> Void
    var arm: (inout GraphicsContext, CGPoint, CGPoint, CGPoint) -> Void   // shoulder, elbow, hand
}

// Things drawn with a move, in grid (ground) coordinates.
enum MoveItem {
    case golfBall(CGPoint), soccer(CGPoint), football(CGPoint), basketball(CGPoint), tennis(CGPoint)
    case disc(CGPoint)
    case club(CGPoint, Double)                  // hands, angle
    case racket(CGPoint, Double, behind: Bool)  // hand, angle; behind = behind the back
    case bat(CGPoint, Double)                   // hands, angle
    case flag(bottom: CGPoint, top: CGPoint, flutter: Double)
    case speedLines(Double)                     // strength 0...1
}

// The body position at one moment of a move.
struct MovePose {
    var bob = 0.0                                  // + = whole body lower
    var lean = 0.0                                 // degrees, + = upper body tips forward (right)
    var footL = CGPoint(x: 42, y: 128), footR = CGPoint(x: 58, y: 128)   // grid coordinates
    var kneeL = 1.0, kneeR = -1.0                  // which way the knee bends
    var handL = CGPoint(x: 34, y: 84), handR = CGPoint(x: 66, y: 84)     // upper-body coordinates
    var elbowL = 1.0, elbowR = -1.0
    var holdL = false, holdR = false               // hand holds something: keep it exactly there
    var openL = false, openR = false               // open hand (waving)
    var headTilt = 0.0, smile = true
    var items: [MoveItem] = []
    var contact = CGPoint(x: 50, y: 128)           // ball / hand / foot at the release moment

    // Upper-body coordinates (rotated by `lean` around the hips, moved by `bob`) -> grid.
    func ground(_ q: CGPoint) -> CGPoint {
        let a = lean * .pi / 180, dx = q.x - 50, dy = q.y - 90
        return CGPoint(x: 50 + dx * cos(a) - dy * sin(a), y: 90 + dx * sin(a) + dy * cos(a) + bob)
    }
    // Grid -> upper-body coordinates.
    func upper(_ g: CGPoint) -> CGPoint {
        let a = -lean * .pi / 180, dx = g.x - 50, dy = g.y - bob - 90
        return CGPoint(x: 50 + dx * cos(a) - dy * sin(a), y: 90 + dx * sin(a) + dy * cos(a))
    }
}

enum Moves {
    // Looping progress for previews (no start time): play the move, hold the end a moment, repeat.
    static func loop(_ m: SportMove, t: Double) -> Double {
        min(1, t.truncatingRemainder(dividingBy: m.duration + 0.8) / m.duration)
    }

    // Draws `avatar` doing `move` at progress `p` (0...1). Also the entry for fixed-progress renders.
    static func draw(_ ctx: inout GraphicsContext, avatar: Avatar, move: SportMove, p: Double, t: Double, look: Look) {
        let rig: MoveRig
        switch avatar {
        case .golfer: rig = Golfer.rig(look)
        case .baller: rig = Baller.rig(look)
        case .ripped: rig = Ripped.rig(look)
        }
        draw(&ctx, rig: rig, pose: pose(move, p: min(1, max(0, p)), t: t), look: look)
    }

    static func draw(_ ctx: inout GraphicsContext, rig: MoveRig, pose o: MovePose, look: Look) {
        Pen.shadow(&ctx)
        for item in o.items { if case .speedLines = item { drawItem(&ctx, item, look: look) } }

        var body = ctx
        body.translateBy(x: 0, y: o.bob)
        for (hipX, foot, bend) in [(rig.hipL, o.footL, o.kneeL), (rig.hipR, o.footR, o.kneeR)] {
            let hip = CGPoint(x: hipX, y: rig.hipY)
            let f = CGPoint(x: foot.x, y: foot.y - o.bob)
            let knee = joint(hip, f, rig.thigh, rig.shin, bend: bend)
            Pen.line(&body, hip, knee, rig.legColor, rig.legWidth)
            Pen.line(&body, knee, f, rig.legColor, rig.legWidth)
            Pen.shoe(&body, f, rig.shoe)
        }
        rig.lower(&body)

        var upper = body
        upper.translateBy(x: 50, y: 90)
        upper.rotate(by: .degrees(o.lean))
        upper.translateBy(x: -50, y: -90)

        for item in o.items { if case .racket(_, _, true) = item { drawItem(&ctx, item, look: look) } }
        rig.torso(&upper)
        for item in o.items {
            switch item {
            case .club, .bat, .flag, .racket(_, _, false): drawItem(&ctx, item, look: look)
            default: break
            }
        }
        // Poses are made for the golfer (shoulders 38/62, arm 28). A free hand keeps the same place
        // relative to this outfit's own shoulder and arm length; a holding hand stays exactly put.
        let k = (rig.upper + rig.fore) / 28
        for (s, target, ref, hold, bend, open) in [(rig.shoulderL, o.handL, CGPoint(x: 38, y: 57), o.holdL, o.elbowL, o.openL),
                                                   (rig.shoulderR, o.handR, CGPoint(x: 62, y: 57), o.holdR, o.elbowR, o.openR)] {
            let h = hold ? target : CGPoint(x: s.x + (target.x - ref.x) * k, y: s.y + (target.y - ref.y) * k)
            let e = joint(s, h, rig.upper, rig.fore, bend: bend)
            rig.arm(&upper, s, e, h)
            if open {   // spread fingers, pointing on from the forearm
                let a = atan2(h.x - e.x, h.y - e.y) * 180 / .pi
                for da in [-28.0, 0, 28] {
                    Pen.line(&upper, Pen.reach(h, a + da, 2), Pen.reach(h, a + da, 5.5), look.skin.color, 1.8)
                }
            }
        }
        Pen.head(upper, look: look, tilt: o.headTilt, smile: o.smile)
        for item in o.items {
            switch item {
            case .golfBall, .soccer, .basketball, .tennis, .disc: drawItem(&ctx, item, look: look)
            default: break
            }
        }
    }

    // Elbow / knee for a two-part limb from `a` to `b`. Out of reach = the limb stretches straight.
    static func joint(_ a: CGPoint, _ b: CGPoint, _ l1: Double, _ l2: Double, bend: Double) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let d = max(0.001, hypot(dx, dy))
        if d >= l1 + l2 { return CGPoint(x: a.x + dx * l1 / (l1 + l2), y: a.y + dy * l1 / (l1 + l2)) }
        let ang = acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))) * bend
        let ux = dx / d, uy = dy / d
        return CGPoint(x: a.x + (ux * cos(ang) - uy * sin(ang)) * l1, y: a.y + (ux * sin(ang) + uy * cos(ang)) * l1)
    }

    // MARK: Balls and gear (also handy for drawing the ball in flight)

    static let wood = Color(red: 0.78, green: 0.58, blue: 0.36)
    static let tennisColor = Color(red: 0.80, green: 0.93, blue: 0.20)

    static func soccerBall(_ ctx: inout GraphicsContext, _ c: CGPoint, r: Double = 5.5, spin: Double = 0) {
        Pen.dot(&ctx, c, r, .white)
        var b = ctx
        b.translateBy(x: c.x, y: c.y)
        b.rotate(by: .radians(spin))
        var pent = Path()
        for i in 0..<5 {
            let a = Double(i) * 2 * .pi / 5 - .pi / 2
            let q = CGPoint(x: cos(a) * r * 0.42, y: sin(a) * r * 0.42)
            if i == 0 { pent.move(to: q) } else { pent.addLine(to: q) }
            b.stroke({ var l = Path(); l.move(to: q); l.addLine(to: CGPoint(x: cos(a) * r, y: sin(a) * r)); return l }(),
                     with: .color(.black.opacity(0.7)), lineWidth: r * 0.14)
        }
        pent.closeSubpath()
        b.fill(pent, with: .color(Color(white: 0.12)))
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(.black.opacity(0.6)), lineWidth: r * 0.12)
    }

    static func football(_ ctx: inout GraphicsContext, _ c: CGPoint, angle: Double = -20) {
        var b = ctx
        b.translateBy(x: c.x, y: c.y)
        b.rotate(by: .degrees(angle))
        b.fill(Path(ellipseIn: CGRect(x: -8, y: -5, width: 16, height: 10)), with: .color(Color(red: 0.55, green: 0.30, blue: 0.15)))
        Pen.line(&b, CGPoint(x: -3.5, y: 0), CGPoint(x: 3.5, y: 0), .white, 1.2)
        for x in [-2.0, 0, 2] { Pen.line(&b, CGPoint(x: x, y: -1.4), CGPoint(x: x, y: 1.4), .white, 0.9) }
    }

    static func tennisBall(_ ctx: inout GraphicsContext, _ c: CGPoint, r: Double = 3.2) {
        Pen.dot(&ctx, c, r, tennisColor)
        var seam = Path()
        seam.move(to: CGPoint(x: c.x - r * 0.7, y: c.y - r * 0.7))
        seam.addQuadCurve(to: CGPoint(x: c.x - r * 0.7, y: c.y + r * 0.7), control: CGPoint(x: c.x + r * 0.2, y: c.y))
        ctx.stroke(seam, with: .color(.white.opacity(0.9)), lineWidth: 0.7)
    }

    static func golfBall(_ ctx: inout GraphicsContext, _ c: CGPoint, r: Double = 2.4) {
        Pen.dot(&ctx, c, r, .white)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(.black.opacity(0.35)), lineWidth: 0.5)
    }

    static func disc(_ ctx: inout GraphicsContext, _ c: CGPoint, color: Color, tilt: Double = -8) {
        var b = ctx
        b.translateBy(x: c.x, y: c.y)
        b.rotate(by: .degrees(tilt))
        let rim = Path(ellipseIn: CGRect(x: -9, y: -3.2, width: 18, height: 6.4))
        b.fill(rim, with: .color(color))
        b.stroke(rim, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
        b.stroke(Path(ellipseIn: CGRect(x: -5.5, y: -1.8, width: 11, height: 3.6)), with: .color(.white.opacity(0.5)), lineWidth: 0.7)
    }

    static func drawItem(_ ctx: inout GraphicsContext, _ item: MoveItem, look: Look) {
        switch item {
        case .golfBall(let c): golfBall(&ctx, c)
        case .soccer(let c): soccerBall(&ctx, c)
        case .football(let c): football(&ctx, CGPoint(x: c.x, y: c.y - 2), angle: -10)
        case .basketball(let c): Baller.ball(&ctx, c, spin: 0.4)
        case .tennis(let c): tennisBall(&ctx, c)
        case .disc(let c): disc(&ctx, c, color: look.accent == .white ? Swatch.orange.color : look.accent.color)

        case .club(let hands, let a):   // same club as the golfer's round
            let head = Pen.reach(hands, a, 32)
            Pen.line(&ctx, hands, head, Color(white: 0.85), 2)
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 3.5, y: head.y - 2.5, width: 7, height: 5)),
                     with: .color(Color(white: 0.7)))

        case .racket(let hand, let a, _):   // handle, throat, oval frame with strings
            let frame = Color(white: 0.2)
            let throat = Pen.reach(hand, a, 9)
            Pen.line(&ctx, Pen.reach(hand, a, -2), throat, frame, 2.4)
            let c = Pen.reach(hand, a, 17)
            var head = ctx
            head.translateBy(x: c.x, y: c.y)
            head.rotate(by: .degrees(-a))
            let oval = Path(ellipseIn: CGRect(x: -5.5, y: -8, width: 11, height: 16))
            head.fill(oval, with: .color(.white.opacity(0.35)))
            var strings = Path()
            for x in [-2.6, 0, 2.6] { strings.move(to: CGPoint(x: x, y: -7.4)); strings.addLine(to: CGPoint(x: x, y: 7.4)) }
            for y in [-4.0, 0, 4] { strings.move(to: CGPoint(x: -5, y: y)); strings.addLine(to: CGPoint(x: 5, y: y)) }
            head.stroke(strings, with: .color(.black.opacity(0.35)), lineWidth: 0.5)
            head.stroke(oval, with: .color(look.accent == .white || look.accent == .black ? Swatch.red.color : look.accent.color),
                        lineWidth: 2)

        case .bat(let hands, let a):   // wooden bat: knob, thin handle, fat barrel
            let knob = Pen.reach(hands, a, -3), end = Pen.reach(hands, a, 32)
            let n = CGPoint(x: cos(a * .pi / 180), y: -sin(a * .pi / 180))   // across the bat
            func side(_ q: CGPoint, _ w: Double) -> CGPoint { CGPoint(x: q.x + n.x * w, y: q.y + n.y * w) }
            let neck = Pen.reach(hands, a, 13)
            var bat = Path()
            bat.move(to: side(knob, 1.1))
            bat.addLine(to: side(neck, 1.3))
            bat.addLine(to: side(end, 2.6))
            bat.addLine(to: side(end, -2.6))
            bat.addLine(to: side(neck, -1.3))
            bat.addLine(to: side(knob, -1.1))
            bat.closeSubpath()
            ctx.fill(bat, with: .color(wood))
            Pen.dot(&ctx, end, 2.6, wood)
            Pen.dot(&ctx, knob, 1.8, Color(red: 0.45, green: 0.30, blue: 0.18))

        case .flag(let bottom, let top, let flutter):
            Pen.line(&ctx, bottom, top, Color(white: 0.9), 2)
            Pen.line(&ctx, bottom, top, .black.opacity(0.2), 0.6)
            let w = 3 * flutter
            var cloth = Path()
            cloth.move(to: top)
            cloth.addQuadCurve(to: CGPoint(x: top.x + 15, y: top.y + 1 + w * 0.4),
                               control: CGPoint(x: top.x + 7.5, y: top.y - w))
            cloth.addLine(to: CGPoint(x: top.x + 15, y: top.y + 10 + w * 0.4))
            cloth.addQuadCurve(to: CGPoint(x: top.x, y: top.y + 10),
                               control: CGPoint(x: top.x + 7.5, y: top.y + 10 - w))
            cloth.closeSubpath()
            ctx.fill(cloth, with: .color(look.accent.color))
            ctx.stroke(cloth, with: .color(.black.opacity(0.25)), lineWidth: 0.6)
            Pen.dot(&ctx, top, 1.5, Color(white: 0.9))

        case .speedLines(let k):
            for (y, len) in [(66.0, 12.0), (80, 16), (94, 11)] {
                Pen.line(&ctx, CGPoint(x: 22 - len * k, y: y), CGPoint(x: 22, y: y), .gray.opacity(0.55 * k), 2)
            }
        }
    }

    // MARK: Poses

    static func ramp(_ p: Double, _ a: Double, _ b: Double) -> Double { min(1, max(0, (p - a) / (b - a))) }
    static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    static func easeIn(_ x: Double) -> Double { x * x }
    static func easeOut(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }
    static func mix(_ a: Double, _ b: Double, _ u: Double) -> Double { a + (b - a) * u }
    static func mix(_ a: CGPoint, _ b: CGPoint, _ u: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
    }
    static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
    static func bez(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ u: Double) -> CGPoint {   // curved path a -> b
        mix(mix(a, c, u), mix(c, b, u), u)
    }

    static func pose(_ m: SportMove, p: Double, t: Double) -> MovePose {
        var o = MovePose()
        let r = m.release
        switch m {

        case .golfSwing:   // backswing, hit at release, hold the finish
            o.footL = pt(39, 128); o.footR = pt(61, 128)
            // Arms and club move apart (wrist hinge), so the club cocks up early on the way back,
            // unhinges late on the way down, and finishes up past the shoulder: it stays on the grid.
            let a: Double, club: Double
            if p < 0.4 {
                let u = smooth(p / 0.4); a = -110 * u * u; club = -190 * pow(u, 0.6)
            } else if p < r {
                let v = 1 - easeIn(ramp(p, 0.4, r)); a = -110 * v * v; club = -190 * pow(v, 0.6)
            } else {
                let w = easeOut(ramp(p, r, 0.65)); a = 110 * w * w; club = 165 * pow(w, 0.6)
            }
            let hands = Pen.reach(pt(50, 60), a, 26)
            o.handL = hands; o.handR = hands
            o.holdL = true; o.holdR = true
            o.elbowL = a < 0 ? -1 : 1; o.elbowR = a < 0 ? -1 : 1
            let finish = ramp(p, r, 0.7)
            o.footL = mix(pt(39, 128), pt(44, 126), finish)   // back heel comes up in the finish
            o.headTilt = -4 * finish
            o.items.append(.club(hands, club))
            o.contact = pt(53, 122.5)
            if p < r { o.items.append(.golfBall(o.contact)) }

        case .kick, .fieldGoal:   // step in, plant, kicking leg swings through, ball at the foot until release
            let step = ramp(p, 0, 0.3)
            o.footL = pt(mix(42, 51, smooth(step)), 128 - 5 * sin(.pi * step))
            o.bob = 2.5 * smooth(ramp(p, 0.15, 0.4)) * (1 - smooth(ramp(p, 0.75, 1)))
            let cock = smooth(ramp(p, 0.08, 0.4))
            let follow = easeOut(ramp(p, r, 0.8))
            var f = mix(pt(58, 128), pt(40, 113), cock)
            f.y -= 5 * sin(.pi * cock)
            if p >= 0.4 { f = mix(pt(40, 113), pt(74, 123), easeIn(ramp(p, 0.4, r))) }
            if p >= r { f = mix(pt(74, 123), pt(86, 103), follow) }
            o.footR = f
            o.kneeR = -1
            o.lean = -5 * cock - 5 * follow
            o.handL = mix(mix(pt(34, 84), pt(30, 74), cock), pt(24, 66), ramp(p, 0.4, r))
            o.handR = mix(mix(pt(66, 84), pt(50, 80), cock), pt(78, 72), smooth(ramp(p, 0.4, 0.75)))
            o.elbowL = 1; o.elbowR = -1
            o.contact = pt(83, 123)
            if p < r { o.items.append(m == .fieldGoal ? .football(o.contact) : .soccer(o.contact)) }

        case .jumpShot:   // dip, jump, ball up over the head, release at the top, wrist follow-through
            let dip = smooth(ramp(p, 0, 0.25)), rise = ramp(p, 0.25, 0.5)
            if p < 0.25 { o.bob = 6 * dip }
            else if p < 0.5 { o.bob = mix(6, -12, easeOut(rise)) }
            else if p < 0.62 { o.bob = -12 }
            else if p < 0.86 { o.bob = -12 * (1 - easeIn(ramp(p, 0.62, 0.86))) }
            else { o.bob = 4 * sin(.pi * ramp(p, 0.86, 1)) }
            let air = min(0, o.bob)
            o.footL = pt(43 + 2 * ramp(-air, 0, 12), 128 + air)
            o.footR = pt(57 - 1 * ramp(-air, 0, 12), 128 + air)
            o.kneeL = 1; o.kneeR = -1
            let up = smooth(rise)
            let flick = smooth(ramp(p, r, r + 0.12))
            let settle = smooth(ramp(p, 0.86, 1))
            o.handL = mix(mix(pt(43, 78 + 3 * dip), pt(57, 33), up), pt(54, 40), flick * 0.6 + settle * 0.2)
            o.handR = mix(mix(pt(58, 78 + 3 * dip), pt(65, 31), up), pt(72, 34), flick)
            o.elbowL = up > 0.5 ? -1 : 1; o.elbowR = up > 0.5 ? 1 : -1
            o.openR = p >= r
            o.holdL = true; o.holdR = true
            o.headTilt = -5 * up
            let ball = mix(pt(51, 71 + 3 * dip), pt(65, 23), up)
            o.contact = o.ground(ball)
            if p < r { o.items.append(.basketball(o.contact)) }

        case .serve:   // toss up, racket back, reach up and hit at release, follow through forward
            let rise = ramp(p, 0.42, r), land = ramp(p, r, 0.8)
            if p < 0.42 { o.bob = 3 * smooth(ramp(p, 0.15, 0.42)) }
            else if p < r { o.bob = mix(3, -4, easeOut(rise)) }
            else { o.bob = -4 * (1 - smooth(land)) + 2 * sin(.pi * land) }
            let air = min(0, o.bob)
            o.footL = pt(41, 128 + air); o.footR = pt(59 + 3 * smooth(land), 128 + air)
            // Left hand tosses the ball, stays up pointing at it, then comes down.
            // (swings round the outside of the shoulder, so it never crosses the face)
            let toss = smooth(ramp(p, 0, 0.25))
            var armL = mix(352, 167, toss)
            if p > r { armL = mix(167, 352, smooth(ramp(p, r, 0.85))) }
            o.handL = Pen.reach(pt(39, 57), armL, 26.7)
            o.elbowL = 1
            // Racket hand.
            var a: Double
            if p < 0.4 {
                let u = smooth(ramp(p, 0.05, 0.4))
                o.handR = mix(pt(67, 82), pt(72, 47), u); a = mix(40, -15, u)
            } else if p < r {
                let u = easeIn(ramp(p, 0.4, r))
                o.handR = mix(pt(72, 47), pt(66, 30), u); a = mix(-15, 170, u)
            } else {
                let u = easeOut(ramp(p, r, 0.82))
                o.handR = mix(pt(66, 30), pt(72, 76), u); a = mix(170, 55, u)
            }
            o.elbowR = p < 0.4 ? -1 : 1
            o.holdR = true
            o.holdL = true   // the toss hand (no jump when the ball leaves it)
            let behind = a < 25 && p > 0.2
            o.items.append(.racket(o.ground(o.handR), a, behind: behind))
            o.contact = o.ground(Pen.reach(o.handR, a, 17))   // racket face (exact at release)
            let hit = MovePose(bob: -4).ground(Pen.reach(pt(66, 30), 170, 17))
            if p < 0.25 {
                o.items.append(.tennis(o.ground(pt(o.handL.x + 1, o.handL.y - 5))))
            } else if p < r {   // in the air: up past the racket, then down onto it
                let u = ramp(p, 0.25, r)
                let start = pt(46, 26), end = hit
                o.items.append(.tennis(pt(mix(start.x, end.x, u), mix(start.y, end.y, u) - 12 * sin(.pi * u))))
            }

        case .batSwing:   // stance, bat back, swing through at release, finish high
            let load = smooth(ramp(p, 0, 0.3)), swing = easeIn(ramp(p, 0.3, r)), follow = easeOut(ramp(p, r, 0.8))
            let stride = ramp(p, 0.12, 0.38)
            o.footL = pt(37, 128)
            o.footR = pt(mix(61, 67, smooth(stride)), 128 - 6 * sin(.pi * stride))
            o.kneeL = 1; o.kneeR = -1
            o.bob = 2 * load * (1 - follow) + 1
            o.lean = -6 * load * (1 - swing) + 6 * swing - 2 * follow
            var hands: CGPoint, a: Double
            if p < 0.3 { hands = mix(pt(45, 54), pt(41, 50), load); a = mix(212, 222, load) }
            else if p < r { hands = mix(pt(41, 50), pt(58, 74), swing); a = mix(222, 90, swing) }
            else { hands = mix(pt(58, 74), pt(66, 48), follow); a = mix(90, 150, follow) }
            o.handL = hands; o.handR = Pen.reach(hands, a, 4)
            o.holdL = true; o.holdR = true
            o.elbowL = -1; o.elbowR = 1
            o.items.append(.bat(o.ground(hands), a - o.lean))
            o.contact = o.ground(Pen.reach(hands, a, 24))   // the bat's sweet spot (exact at release)

        case .sprint:   // fast run with a forward lean, lean through the line at release
            let run = min(p, r) / r
            let phi = 2 * .pi * 3 * run
            let finish = smooth(ramp(p, 0.7, 0.9))
            o.lean = 13 + 10 * finish
            o.bob = -2.5 * abs(sin(phi)) * (1 - finish) + 2 * finish
            func foot(_ q: Double) -> CGPoint {
                pt(50 + 18 * cos(q), 128 + min(0, o.bob) - 16 * max(0, -sin(q)))
            }
            o.footR = foot(phi); o.footL = foot(phi + .pi)
            o.kneeL = -1; o.kneeR = -1
            // Arms pump opposite to the legs: front hand up by the chin, back hand down behind.
            let swingR = (1 - cos(phi)) / 2
            o.handR = mix(mix(pt(55, 84), pt(76, 62), swingR), pt(44, 86), finish)
            o.handL = mix(mix(pt(27, 82), pt(54, 64), 1 - swingR), pt(24, 80), finish)   // arms back to dip
            o.elbowL = 1; o.elbowR = 1
            if p < r { o.items.append(.speedLines(1 - finish)) }
            o.contact = pt(68, 128)

        case .hail:   // arm shoots up waving, other hand on the hip, little hop
            let raise = easeOut(ramp(p, 0, r))
            o.bob = -6 * sin(.pi * ramp(p, 0.2, 0.6))
            let air = min(0, o.bob)
            o.footL = pt(42, 128 + air); o.footR = pt(58, 128 + air)
            o.kneeL = 1; o.kneeR = -1
            let wave = 5 * sin(2 * .pi * 2 * ramp(p, r, 1))
            o.handR = mix(pt(66, 84), pt(65 + wave, 27), raise)
            o.elbowR = raise > 0.4 ? 1 : -1
            o.openR = raise > 0.6
            o.holdR = true
            o.handL = mix(pt(34, 84), pt(43, 85), smooth(ramp(p, 0, 0.3)))
            o.elbowL = 1
            o.headTilt = -5 * raise
            o.contact = o.ground(o.handR)

        case .jog:   // easy jog, a friendly wave at release
            let phi = 2 * .pi * 2 * p
            o.lean = 4
            o.bob = -2 * abs(sin(phi))
            func foot(_ q: Double) -> CGPoint { pt(50 + 9 * cos(q), 128 + o.bob - 8 * max(0, -sin(q))) }
            o.footR = foot(phi); o.footL = foot(phi + .pi)
            o.kneeL = -1; o.kneeR = -1
            let swingR = (1 - cos(phi)) / 2
            o.handL = mix(pt(31, 80), pt(47, 70), 1 - swingR)
            let jogR = mix(pt(58, 82), pt(71, 69), swingR)
            let up = smooth(ramp(p, 0.42, r)) * (1 - smooth(ramp(p, 0.85, 1)))
            let wave = 5 * sin(2 * .pi * 1.5 * ramp(p, r, 0.85))
            o.handR = mix(jogR, pt(67 + wave, 30), up)
            o.elbowL = 1; o.elbowR = up > 0.4 ? 1 : 1
            o.openR = up > 0.6
            o.headTilt = -3 * up
            let atR = foot(2 * .pi * 2 * r), other = foot(2 * .pi * 2 * r + .pi)
            o.contact = atR.x > other.x ? atR : other

        case .throwDisc:   // backhand: disc across the body, uncoil, let go with the arm out front
            let coil = smooth(ramp(p, 0, 0.35)), throwU = easeIn(ramp(p, 0.35, r)), follow = easeOut(ramp(p, r, 0.8))
            let stride = ramp(p, 0.25, r)
            o.footL = pt(41, 128)
            o.footR = pt(mix(58, 68, smooth(stride)), 128 - 5 * sin(.pi * stride))
            o.lean = -7 * coil * (1 - throwU) + 7 * throwU - 2 * follow
            o.bob = 2 * coil * (1 - follow)
            var h: CGPoint
            if p < 0.35 { h = mix(pt(66, 84), pt(41, 73), coil) }
            else if p < r { h = mix(pt(41, 73), pt(86, 64), throwU) }
            else { h = mix(pt(86, 64), pt(82, 50), follow) }
            o.handR = h
            o.holdR = true
            o.elbowR = p < 0.35 ? 1 : -1
            o.handL = mix(mix(pt(34, 84), pt(36, 78), coil), pt(22, 70), smooth(ramp(p, 0.35, 0.7)))
            o.elbowL = 1
            o.contact = o.ground(pt(h.x + 3, h.y))
            if p < r { o.items.append(.disc(o.contact)) }

        case .plantFlag:   // lift the flag high, drive it into the ground, hands on hips
            let lift = smooth(ramp(p, 0, 0.35)), drive = easeIn(ramp(p, 0.38, r)), proud = smooth(ramp(p, r + 0.05, 0.85))
            o.bob = p < r ? -1.5 * lift * (1 - drive) + 9 * drive : 9 * (1 - proud)
            o.lean = p < r ? -4 * lift * (1 - drive) + 14 * drive : 14 * (1 - proud) - 3 * proud
            o.footL = pt(41, 128)
            let stride = ramp(p, 0.36, r)
            o.footR = pt(mix(59, 63, smooth(stride)) - 4 * proud, 128 - 4 * sin(.pi * stride))
            o.kneeL = 1; o.kneeR = -1
            let base = pt(76, 130)
            o.holdR = true
            if p < r {
                var grip = mix(pt(70, 90), pt(71, 40), lift)
                if p >= 0.38 { grip = mix(pt(71, 40), pt(76, 100), drive) }
                o.handR = o.upper(grip)
                o.elbowR = -1
                o.items.append(.flag(bottom: pt(grip.x, grip.y + 30), top: pt(grip.x, grip.y - 10), flutter: sin(t * 7)))
                o.handL = mix(pt(34, 84), pt(36, 78), lift)
            } else {
                let letGo = o.upper(pt(76, 100))
                o.handR = mix(letGo, pt(57, 85), proud)
                o.elbowR = -1
                o.handL = mix(pt(36, 78), pt(43, 85), proud)
                o.items.append(.flag(bottom: base, top: pt(76, 90), flutter: sin(t * 7)))
            }
            o.elbowL = 1
            o.headTilt = -4 * proud
            o.contact = base
        }
        return o
    }
}
