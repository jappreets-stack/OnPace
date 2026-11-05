import SwiftUI

// What the character is doing.
enum Mood { case slump, walk, celebrate, swing }

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

    // The original look: turban, full beard, purple & gold.
    static let original = Look()

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
            let original = Look.original
            lashes = false
            lips = .natural
            beard = original.beard
            hair = original.hair
            hat = original.hat
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

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let look = look ?? Look.classic(avatar)
            Canvas { ctx, size in
                // Everyone is drawn on a 100 x 140 grid, scaled to fit.
                let s = min(size.width / 100, size.height / 140)
                ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 140 * s) / 2)
                ctx.scaleBy(x: s, y: s)
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
        Pen.line(&ctx, mid, hand, look.skin.color, 6)
        Pen.line(&ctx, shoulder, mid, look.main.color, 9)   // polo sleeve
        Pen.dot(&ctx, hand, 3.5, look.skin.color)
    }

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double, look: Look, prop: Prop? = nil) {
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

        let skort = look.bottoms == .skort
        for (hipX, angle, lift) in [(45.0, -spread, liftL), (55.0, spread, liftR)] {
            let hip = CGPoint(x: hipX, y: 90)
            let foot = Pen.reach(hip, angle, 38 - lift)
            Pen.line(&body, hip, foot, skort ? look.skin.color : pants, skort ? 7 : 9)
            Pen.shoe(&body, foot)
        }
        if skort {
            var skirt = Path()
            skirt.move(to: CGPoint(x: 36, y: 88))
            skirt.addLine(to: CGPoint(x: 64, y: 88))
            skirt.addLine(to: CGPoint(x: 67, y: 104))
            skirt.addLine(to: CGPoint(x: 33, y: 104))
            skirt.closeSubpath()
            body.fill(skirt, with: .color(pants))
        }

        Props.behind(&body, prop)
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

    static func draw(_ ctx: inout GraphicsContext, mood: Mood, t: Double, look: Look, prop: Prop? = nil) {
        let skin = look.skin.color
        // Letter and trim in the main color, unless it matches the jersey.
        let trim = look.main == look.accent ? (look.accent == .white ? Color.black : Color.white) : look.main.color
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
        body.fill(Path(roundedRect: CGRect(x: 35, y: 84, width: 30, height: 22), cornerRadius: 5),
                  with: .color(look.main.color))
        Pen.line(&body, CGPoint(x: 36, y: 86), CGPoint(x: 36, y: 104), look.accent.color, 1.5)
        Pen.line(&body, CGPoint(x: 64, y: 86), CGPoint(x: 64, y: 104), look.accent.color, 1.5)

        // Jersey in your accent color with your letter
        Props.behind(&body, prop)
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
        let slim = look.body == .female
        let elbow = Pen.reach(shoulder, upper, 16)
        let hand = Pen.reach(elbow, fore, 15)
        Pen.line(&ctx, shoulder, elbow, look.skin.color, slim ? 8 : 10)
        Pen.line(&ctx, elbow, hand, look.skin.color, slim ? 7 : 8)
        let bicep = CGPoint(x: (shoulder.x + elbow.x) / 2, y: (shoulder.y + elbow.y) / 2)
        Pen.dot(&ctx, bicep, (slim ? 4.5 : 5.5) + flex, look.skin.color)
        Pen.dot(&ctx, CGPoint(x: bicep.x - 1, y: bicep.y - 1.5), 1.8 + flex / 3, look.skin.shine)
        Pen.dot(&ctx, hand, 4.5, look.skin.color)   // fist
        return hand
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
            body.fill(Path(roundedRect: CGRect(x: 35, y: 84, width: 30, height: 17), cornerRadius: 4),
                      with: .color(shorts))
        }

        Props.behind(&body, prop)
        // Torso: V-shaped with big shoulders, or an hourglass for the curvy body
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
