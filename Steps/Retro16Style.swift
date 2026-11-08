import SwiftUI

// "16-bit adventure" style (Settings → Look → Style). Original pixel art, drawn in code on a Canvas:
// a little world with mountains and a castle, a gold block ring, and your mini-me as a pixel sprite.
// It only draws numbers ContentView already has; it never touches step counting.

func hex(_ v: UInt32) -> Color {
    Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

enum Retro16 {
    static let gold = hex(0xFFC83D)
    static let goldLight = hex(0xFFF2B0)
    static let goldDark = hex(0xB87A10)
    static let ink = hex(0x14102A)   // dark outlines
    static func page(night: Bool) -> Color { night ? hex(0x0E1230) : hex(0xF3E9D2) }
    static func text(night: Bool) -> Color { night ? .white : hex(0x1E2350) }
    static func textShadow(night: Bool) -> Color { night ? hex(0x3A5ED8) : hex(0xE9B43A) }
    // One art pixel in points: about 96 across the screen, always a whole number of points (crisp).
    static func pixel(screenWidth: CGFloat) -> CGFloat { max(3, (screenWidth / 96).rounded(.down)) }
    // A small pixel (history bars): 4 device pixels, so it stays on the screen's pixel grid.
    static func smallPixel(scale: CGFloat) -> CGFloat { max(1, (1.34 * scale).rounded()) / scale }
}

// A grid of big square pixels on a Canvas.
struct Pix {
    let ctx: GraphicsContext
    let p: CGFloat

    func rect(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ c: Color) {
        guard w > 0, h > 0 else { return }
        ctx.fill(Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: CGFloat(w) * p, height: CGFloat(h) * p)),
                 with: .color(c))
    }

    func disc(_ cx: Int, _ cy: Int, _ r: Int, _ c: Color) {
        for y in -r...r {
            let half = Int((Double(r * r - y * y)).squareRoot().rounded())
            rect(cx - half, cy + y, half * 2 + 1, 1, c)
        }
    }
}

// A small picture made of letters, one letter per pixel ("." = see-through).
struct PixelGrid {
    let w: Int, h: Int
    private(set) var cells: [Character]

    init(_ w: Int, _ h: Int) {
        self.w = w; self.h = h
        cells = Array(repeating: ".", count: w * h)
    }

    mutating func set(_ x: Int, _ y: Int, _ c: Character) {
        guard x >= 0, x < w, y >= 0, y < h else { return }
        cells[y * w + x] = c
    }

    mutating func stamp(_ rows: [String], _ x: Int, _ y: Int) {
        for (j, row) in rows.enumerated() {
            for (i, ch) in row.enumerated() where ch != "." { set(x + i, y + j, ch) }
        }
    }

    // A straight pixel line (Bresenham).
    mutating func line(_ a: (Int, Int), _ b: (Int, Int), _ c: Character) {
        var (x, y) = a
        let dx = abs(b.0 - x), dy = -abs(b.1 - y)
        let sx = x < b.0 ? 1 : -1, sy = y < b.1 ? 1 : -1
        var err = dx + dy
        while true {
            set(x, y, c)
            if x == b.0 && y == b.1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x += sx }
            if e2 <= dx { err += dx; y += sy }
        }
    }

    // A one-pixel dark edge around everything drawn (the 16-bit look).
    mutating func outline(_ c: Character) {
        let filled = cells.map { $0 != "." }
        for y in 0..<h {
            for x in 0..<w where !filled[y * w + x] {
                let touches = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { a, b in
                    a >= 0 && a < w && b >= 0 && b < h && filled[b * w + a]
                }
                if touches { cells[y * w + x] = c }
            }
        }
    }

    // Draws runs of the same color as one rectangle.
    func draw(_ px: Pix, _ x: Int, _ y: Int, _ pal: [Character: Color]) {
        for j in 0..<h {
            var i = 0
            while i < w {
                let ch = cells[j * w + i]
                var run = 1
                while i + run < w && cells[j * w + i + run] == ch { run += 1 }
                if ch != ".", let c = pal[ch] { px.rect(x + i, y + j, run, 1, c) }
                i += run
            }
        }
    }
}

// MARK: - The mini-me as a pixel sprite, colored from your Look

enum RetroSprite {
    static let width = 24, height = 28   // feet on the bottom row; room above for arms and the club
    static let centerX = 12
    private static let ox = 4, oy = 5    // where the 16 × 23 body sits in the grid

    private enum Arms { case down, swingLeft, swingRight, low, up, wave, none }
    private enum SwingPose { case address, back, top, follow }

    // One animation frame. `tick` counts at 8 per second. `lift` = pixels off the ground (hop).
    static func frame(_ look: Look, avatar: Avatar? = nil, mood: Mood, tick: Int, hop: Bool = true) -> (grid: PixelGrid, lift: Int) {
        var g = PixelGrid(width, height)
        var upper = 0, headDrop = 0, lift = 0
        var legs = legsStill
        var arms = Arms.down
        var eyesDown = false, slumped = false
        var pose: SwingPose?

        switch mood {
        case .stand:        // breathing: the top half sinks one pixel, slowly
            upper = tick % 12 >= 6 ? 1 : 0
        case .walk:         // left step, pass, right step, pass
            let f = tick % 4
            legs = [legsLeftUp, legsStill, legsRightUp, legsStill][f]
            arms = f == 0 ? .swingLeft : f == 2 ? .swingRight : .down
            upper = f % 2 == 0 ? 1 : 0
        case .slump:        // head down, shoulders low, a slow sigh
            headDrop = tick % 16 >= 8 ? 2 : 1
            arms = .low; eyesDown = true; slumped = true
        case .celebrate:    // arms up, a small hop
            arms = (tick / 2) % 2 == 0 ? .up : .wave
            if hop { lift = [0, 0, 1, 2, 3, 3, 2, 1][tick % 8] }
        case .swing:        // address, backswing, top, impact, follow-through
            let seq: [SwingPose] = [.address, .address, .address, .address, .back, .back, .top, .top, .top,
                                    .address, .follow, .follow, .follow, .follow, .follow, .address]
            pose = seq[tick % seq.count]
            arms = .none
        }

        let bodyY = oy + 11 + upper
        let pantsLegs = avatar == .golfer && look.bottoms == .pants
        g.stamp(legs.map { pantsLegs ? $0.replacingOccurrences(of: "S", with: "P") : $0 }, ox, oy + 19)

        // The club goes behind the head at the top of the swing and in the follow-through.
        if let pose, pose == .top || pose == .follow { club(&g, pose) }
        g.stamp(torso(look, avatar: avatar, slumped: slumped), ox, bodyY)
        g.stamp(head(look), ox, oy + upper + headDrop)
        g.stamp(face(look, eyesDown: eyesDown), ox, oy + 4 + upper + headDrop)

        let l = ox + 2, r = ox + 13    // arm columns
        func arm(_ x: Int, _ ys: ClosedRange<Int>) { for y in ys { g.set(x, bodyY + y, "S") } }
        switch arms {
        case .down: arm(l, 2...4); arm(r, 2...4)
        case .swingLeft: arm(l, 2...3); arm(r, 2...5)
        case .swingRight: arm(l, 2...5); arm(r, 2...3)
        case .low: arm(l, 2...5); arm(r, 2...5)
        case .up:
            g.set(l, bodyY, "T"); g.set(r, bodyY, "T")
            for (dx, dy) in [(-1, 0), (-1, -1), (-2, -2), (-2, -3)] { g.set(l + dx, bodyY + dy, "S"); g.set(r - dx, bodyY + dy, "S") }
        case .wave:
            g.set(l, bodyY, "T"); g.set(r, bodyY, "T")
            for (dx, dy) in [(-1, 0), (-2, -1), (-3, -2)] { g.set(l + dx, bodyY + dy, "S"); g.set(r - dx, bodyY + dy, "S") }
        case .none: break
        }

        if let pose {
            let hands: (Int, Int)
            switch pose {
            case .address: hands = (11, 22)
            case .back: hands = (18, 19)
            case .top: hands = (18, 13)
            case .follow: hands = (4, 13)
            }
            g.line((ox + 3, bodyY + 1), hands, "S")
            g.line((ox + 12, bodyY + 1), (hands.0 + 1, hands.1), "S")
            if pose == .address || pose == .back { club(&g, pose) }
            g.set(hands.0, hands.1, "S"); g.set(hands.0 + 1, hands.1, "S")
        }

        g.outline("O")
        return (g, lift)
    }

    private static func club(_ g: inout PixelGrid, _ pose: SwingPose) {
        switch pose {
        case .address: g.line((12, 23), (17, 27), "C"); g.set(18, 27, "D"); g.set(19, 27, "D")
        case .back: g.line((19, 18), (22, 12), "C"); g.set(22, 11, "D"); g.set(23, 11, "D")
        case .top: g.line((18, 12), (4, 6), "C"); g.set(3, 6, "D"); g.set(3, 7, "D")
        case .follow: g.line((5, 12), (20, 5), "C"); g.set(21, 5, "D"); g.set(21, 4, "D")
        }
    }

    private static let legsStill = ["....SSS..SSS....", "....SSS..SSS....", "...FFFF..FFFF...", "...FFFF..FFFF..."]
    private static let legsLeftUp = ["....SSS..SSS....", "...FFFF..SSS....", "...FFFF..FFFF...", ".........FFFF..."]
    private static let legsRightUp = ["....SSS..SSS....", "....SSS..FFFF...", "...FFFF..FFFF...", "...FFFF........."]

    private static func head(_ look: Look) -> [String] {
        switch look.hair {
        case .turban, .hijab:
            return ["......HHHH......", "....HHhhHHHH....", "...HHHHHHhHHH...", "...HHHHHHHHhH..."]
        case .cap:
            return ["................", ".....HHHHHH.....", "....HHHHHHHH....", "....HHHHHHHHhhh."]
        case .bald:
            return ["................", "................", ".....SSSSSS.....", "....SSSSSSSS...."]
        case .bun:
            return ["......RRRR......", ".......RR.......", ".....RRRRRR.....", "....RRRRRRRR...."]
        case .curly:
            return ["................", "......R.RR......", ".....RRRRRRR....", "....RRRRRRRRR..."]
        default:
            return ["................", "................", ".....RRRRRR.....", "....RRRRRRRR...."]
        }
    }

    private static func face(_ look: Look, eyesDown: Bool) -> [String] {
        let eyes: String
        switch look.glasses {
        case .none: eyes = look.lashes ? "SEESSEES" : "SSESSESS"
        case .glasses: eyes = "gWEggEWg"
        case .sunglasses: eyes = "GGGSSGGG"
        }
        let longHair = [.long, .ponytail, .braids, .curly].contains(look.hair)
        let side: Character = look.hair == .hijab ? "H" : (longHair ? "R" : "S")
        // Eyes are two pixels tall (lashes: a wider top row); glasses are one row.
        let lower = look.glasses == .none ? "SSESSESS" : "SSSSSSSS"
        var face = ["...\(side)SSSSSSSS\(side)...",
                    "...s\(eyes)s...",
                    "....\(lower)...."]
        switch look.beard {
        case .full: face += ["....BSSSSSSB....", "....BBBMMBBB....", ".....BBBBBB.....", "......BBBB......"]
        case .mustache: face += ["....SSSSSSSS....", "....SBBBBBBS....", ".....SSMMSS.....", "......SSSS......"]
        case .stubble: face += ["....sSSSSSSs....", "....ssSMMSss....", ".....ssssss.....", "......SSSS......"]
        case .none: face += ["....SSSSSSSS....", "....SSSMMSSS....", ".....SSSSSS.....", "......SSSS......"]
        }
        if look.hair == .hijab {
            face[3] = "...HSSSSSSSSH..."; face[4] = "...HSSSMMSSSH..."; face[5] = "...HHSSSSSSHH..."; face[6] = "....HHHHHHHH...."
        }
        if longHair {
            face[2] = "...R" + face[2].dropFirst(4).dropLast(4) + "R..."
            face[3] = "...R" + face[3].dropFirst(4).dropLast(4) + "R..."
            if look.hair == .long || look.hair == .braids { face[4] = "...R" + face[4].dropFirst(4).dropLast(4) + "R..." }
        }
        if look.hair == .ponytail { face[1] = "..R" + face[1].dropFirst(3) }
        if eyesDown {   // looking at the ground: only the lower half of the eyes
            face[1] = "...s" + String(face[1].dropFirst(4).dropLast(4).map { $0 == "E" ? "S" : $0 }) + "s..."
            if look.glasses != .none { face.swapAt(1, 2) }
        }
        return face
    }

    private static func torso(_ look: Look, avatar: Avatar?, slumped: Bool) -> [String] {
        let narrow = look.body == .female || slumped
        var rows = [narrow ? "....TTTAATTT...." : "...TTTTAATTTT...",
                    narrow ? "...TTTTTTTTTT..." : "..TTTTTTTTTTTT..",
                    "...TTTTTTTTTT...", "...TTTTTTTTTT...", "...TTTTTTTTTT...",
                    "....PPPPPPPP....", "....PPPPPPPP....", "....PPP..PPP...."]
        if avatar == .ripped {   // tank top: bare shoulders
            rows[0] = narrow ? "....STTTTTTS...." : "...STTTTTTTTS..."
            rows[1] = narrow ? "...STTTTTTTTS..." : "..SSTTTTTTTTSS.."
        }
        return rows
    }

    static func palette(_ look: Look) -> [Character: Color] {
        let wearsHat = look.hair == .cap || look.hair == .turban || look.hair == .hijab
        let skin = look.skin.rgb, main = look.main.rgb
        return ["H": wearsHat ? look.hat.color : look.hairColor.color, "h": look.foldColor,
                "R": look.hairColor.color,
                "S": look.skin.color, "s": Color(red: skin.0 * 0.82, green: skin.1 * 0.82, blue: skin.2 * 0.82),
                "E": hex(0x101018), "G": hex(0x101018), "g": hex(0x2A2E44), "W": hex(0xE8F4FF),
                "B": look.hairColor.color, "M": look.beard == .full ? hex(0x7A2E2E) : look.lips.color,
                "T": look.main.color, "A": look.accent.color, "F": look.accent.color,
                "P": Color(red: main.0 * 0.62, green: main.1 * 0.62, blue: main.2 * 0.62),
                "O": Retro16.ink, "C": hex(0xC8CCD8), "D": hex(0x5A6070)]
    }
}

// MARK: - The Today scene: mountains, a castle, a path, and the gold block ring

struct Retro16SceneWindow: View {
    let look: Look
    let avatar: Avatar
    let mood: Mood
    let progress: Double
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 370

    static let rows = 64
    private static let ringY = 31, radius = 26

    var body: some View {
        // The window sits inside 16-pt page margins, so the screen is 32 pt wider.
        let p = Retro16.pixel(screenWidth: width + 32)
        let night = scheme == .dark
        TimelineView(.animation(minimumInterval: 1.0 / 8, paused: reduceMotion)) { tl in   // 8 fps, like old games
            Canvas { ctx, size in
                var ctx = ctx
                let cols = Int((size.width / p).rounded(.up))
                // Center the pixel grid; the shift is snapped to whole device pixels.
                let shift = ((CGFloat(cols) * p - size.width) / 2 * displayScale).rounded() / displayScale
                ctx.translateBy(x: -shift, y: 0)
                let px = Pix(ctx: ctx, p: p)
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let tick = reduceMotion ? 0 : Int(t * 8)
                draw(px, cols: cols, rows: Self.rows, t: t, tick: tick, night: night)
            }
        }
        .frame(height: CGFloat(Self.rows) * p)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .clipShape(PixelPanel(step: p))
        .overlay(Retro16Border(step: p))
    }

    private func draw(_ px: Pix, cols: Int, rows: Int, t: Double, tick: Int, night: Bool) {
        let cx = cols / 2
        let ringY = Self.ringY
        let horizon = ringY + 3
        let feetY = ringY + 14
        let castleX = min(cols - 10, cx + 36)

        sky(px, cols, horizon, t, tick, night)
        mountains(px, cols, horizon, night)
        ground(px, cols, rows, horizon, night)
        // the hill the castle stands on
        for dx in -13...13 {
            let h = 4 - dx * dx / 42
            if h > 0 { px.rect(castleX + dx, horizon - h, 1, h, hex(night ? 0x23482E : 0x4E9A48)) }
        }
        castle(px, castleX, horizon - 3, tick, night)
        path(px, rows, horizon, feetY, from: castleX, to: cx, night)
        trees(px, cols, horizon, night)
        ring(px, cx, ringY, night)

        // The mini-me, standing on the path.
        let (grid, lift) = RetroSprite.frame(look, avatar: avatar, mood: mood, tick: tick)
        let shadow = Color.black.opacity(night ? 0.35 : 0.22)
        px.rect(cx - 5 + lift / 2, feetY, 10 - lift, 1, shadow)
        px.rect(cx - 3 + lift / 2, feetY + 1, 6 - lift, 1, shadow)
        grid.draw(px, cx - RetroSprite.centerX, feetY - RetroSprite.height - lift, RetroSprite.palette(look))
    }

    private func sky(_ px: Pix, _ cols: Int, _ horizon: Int, _ t: Double, _ tick: Int, _ night: Bool) {
        let bands: [UInt32] = night
            ? [0x0A0E2C, 0x0F153A, 0x141C48, 0x1A2456, 0x202C64, 0x283672, 0x30407E, 0x3A4C8A]
            : [0x2A4FC8, 0x3561D4, 0x4274DE, 0x5288E6, 0x669DEE, 0x7FB3F4, 0x9CC8F8, 0xBBDCFB]
        let band = max(1, horizon / bands.count)
        for (i, c) in bands.enumerated() {
            px.rect(0, i * band, cols, i == bands.count - 1 ? horizon - i * band : band, hex(c))
        }
        if night {
            for s in 0..<34 {
                let x = (s * 37 + 11) % cols, y = (s * 23 + 3) % max(1, horizon - 14)
                let twinkle = (tick / 3 + s * 5) % 11 == 0
                px.rect(x, y, 1, 1, Color.white.opacity(twinkle ? 0.25 : (s % 3 == 0 ? 0.95 : 0.6)))
                if s % 9 == 0 && !twinkle {   // a few bigger stars
                    px.rect(x - 1, y, 1, 1, Color.white.opacity(0.35)); px.rect(x + 1, y, 1, 1, Color.white.opacity(0.35))
                }
            }
            // crescent moon
            px.disc(11, 8, 4, hex(0xF4EFCF))
            px.disc(13, 7, 4, hex(bands[1]))
        } else {
            px.disc(11, 8, 4, hex(0xFFF3B0))
            px.disc(11, 8, 3, hex(0xFFE27A))
            for k in 0..<3 {
                let x = Int((Double(k) * 41 + t * 1.2).truncatingRemainder(dividingBy: Double(cols + 24))) - 12
                cloud(px, x, 3 + k * 6 + (k == 2 ? -4 : 0))
            }
        }
    }

    private func cloud(_ px: Pix, _ x: Int, _ y: Int) {
        let white = Color.white, shade = hex(0xC6D8F6)
        px.rect(x + 4, y, 3, 1, white)
        px.rect(x + 2, y + 1, 7, 1, white)
        px.rect(x + 1, y + 2, 10, 1, white)
        px.rect(x, y + 3, 12, 1, white)
        px.rect(x + 1, y + 4, 10, 1, shade)
    }

    private func mountains(_ px: Pix, _ cols: Int, _ horizon: Int, _ night: Bool) {
        let rock = hex(night ? 0x3A4478 : 0x7C8FC9), rockLight = hex(night ? 0x4A5690 : 0x95A6D8)
        let snow = hex(night ? 0xB8C4E8 : 0xF2F6FF)
        let hill = hex(night ? 0x24483A : 0x5C8F6E), hillTop = hex(night ? 0x2F5A48 : 0x7FB08A)
        let trees = hex(night ? 0x162E24 : 0x2E5A3A)
        for x in 0..<cols {
            let h = 15 + Int(7 * sin(Double(x) / 10) + 4 * sin(Double(x) / 4.3))
            px.rect(x, horizon - h, 1, h, rock)
            if sin(Double(x) / 4.3) > 0.3 { px.rect(x, horizon - h + 2, 1, h / 3, rockLight) }   // sunlit faces
            if h > 20 { px.rect(x, horizon - h, 1, min(3, h - 20), snow) }
            let h2 = 8 + Int(3 * sin(Double(x) / 6 + 2) + 2 * sin(Double(x) / 2.6))
            px.rect(x, horizon - h2, 1, h2, hill)
            px.rect(x, horizon - h2, 1, 1, hillTop)
            let h3 = 3 + Int(2 * sin(Double(x) / 1.7 + 1))
            px.rect(x, horizon - h3, 1, h3, trees)
        }
    }

    private func ground(_ px: Pix, _ cols: Int, _ rows: Int, _ horizon: Int, _ night: Bool) {
        px.rect(0, horizon, cols, rows - horizon, hex(night ? 0x2A5530 : 0x58B848))
        px.rect(0, horizon, cols, 1, hex(night ? 0x22462A : 0x4CA63E))
        let tuft = hex(night ? 0x356A3A : 0x6FCB5A), dark = hex(night ? 0x224628 : 0x4A9C3C)
        for y in (horizon + 2)..<rows {
            for x in 0..<cols where (x * 7 + y * 13) % 19 == 0 {
                px.rect(x, y, 1, 1, tuft)
                px.rect(x + 1, y + 1, 1, 1, dark)
            }
        }
        let flowers: [UInt32] = night ? [0x8A86C8, 0x6E8AB8, 0xA8A8C8] : [0xFFE04D, 0xFF7AA8, 0xFFFFFF]
        for i in 0..<26 {
            let x = (i * 29 + 7) % cols, y = horizon + 3 + (i * 17) % max(1, rows - horizon - 4)
            px.rect(x, y, 1, 1, hex(flowers[i % 3]))
        }
    }

    // A dirt path from the castle gate, winding down to where the mini-me stands, then toward you.
    private func path(_ px: Pix, _ rows: Int, _ horizon: Int, _ feetY: Int, from castleX: Int, to cx: Int, _ night: Bool) {
        let dirt = hex(night ? 0x8C7A5C : 0xE2C58F), edge = hex(night ? 0x6E5E44 : 0xC9A86B)
        for y in horizon..<rows {
            let f = min(1, Double(y - horizon) / Double(feetY - horizon))
            let ease = 1 - (1 - f) * (1 - f)
            let x = Int((Double(castleX) + Double(cx - castleX) * ease).rounded())
            let w = 2 + Int(f * 10) + max(0, y - feetY) / 2
            px.rect(x - w / 2, y, w, 1, dirt)
            px.rect(x - w / 2, y, 1, 1, edge)
            px.rect(x - w / 2 + w - 1, y, 1, 1, edge)
        }
    }

    private func castle(_ px: Pix, _ x: Int, _ base: Int, _ tick: Int, _ night: Bool) {
        let stone = hex(night ? 0x6A6E8E : 0xBCC0D0), light = hex(night ? 0x8488A8 : 0xE2E4EE)
        let dark = hex(night ? 0x4A4E6C : 0x8A8EA4), roof = hex(night ? 0x8A2C3C : 0xC83C3C)
        let roofLight = hex(night ? 0xA8404E : 0xE85A50)
        let window = hex(night ? 0xFFD84D : 0x2A2A3A), gate = hex(night ? 0x2A1E16 : 0x6B4423)

        func tower(_ tx: Int, _ w: Int, _ h: Int) {
            px.rect(tx, base - h, w, h, stone)
            px.rect(tx, base - h, 1, h, light)
            px.rect(tx + w - 1, base - h, 1, h, dark)
        }
        func cone(_ tx: Int, _ w: Int, _ top: Int) {   // pointed roof over a tower `w` wide whose top is `top`
            var row = 0, half = w / 2 + 1
            while half > 0 {
                px.rect(tx + w / 2 - half, top - 1 - row, half * 2 + (w % 2), 1, roof)
                px.rect(tx + w / 2 - half, top - 1 - row, 1, 1, roofLight)
                half -= 1; row += 1
            }
        }
        // curtain wall with battlements
        tower(x - 6, 13, 8)
        for i in stride(from: x - 6, through: x + 6, by: 2) { px.rect(i, base - 9, 1, 1, stone) }
        // side towers
        for tx in [x - 9, x + 6] {
            tower(tx, 4, 12)
            cone(tx, 4, base - 12)
            px.rect(tx + 1, base - 9, 1, 2, window)
        }
        // keep with a flag
        tower(x - 2, 5, 16)
        cone(x - 2, 5, base - 16)
        px.rect(x, base - 12, 1, 2, window)
        px.rect(x, base - 25, 1, 4, hex(0x4A4A5A))
        let wave = (tick / 3) % 2 == 0
        px.rect(x + 1, base - 25, wave ? 4 : 3, 1, Retro16.gold)
        px.rect(x + 1, base - 24, wave ? 3 : 4, 1, Retro16.gold)
        // gate
        px.rect(x - 1, base - 4, 3, 4, gate)
        px.rect(x, base - 5, 1, 1, gate)
    }

    private func trees(_ px: Pix, _ cols: Int, _ horizon: Int, _ night: Bool) {
        let tree = ["...gGGG...", ".gggGGGGG.", "ggGGGGGGdG", "gGGGGGGddG", ".GGGGGddd.", "..GGddd...", "....TT....", "....TT...."]
        let pal: [Character: Color] = night
            ? ["G": hex(0x1E5030), "g": hex(0x2C6A40), "d": hex(0x123820), "T": hex(0x3E2C1C)]
            : ["G": hex(0x2E8B3E), "g": hex(0x5CC25C), "d": hex(0x1E5C2A), "T": hex(0x6D4C2F)]
        func stamp(_ x: Int, _ y: Int) {
            for (j, row) in tree.enumerated() {
                for (i, ch) in row.enumerated() where ch != "." { if let c = pal[ch] { px.rect(x + i, y + j, 1, 1, c) } }
            }
        }
        stamp(1, horizon - 6)
        stamp(8, horizon - 2)
        stamp(cols - 9, horizon + 2)
    }

    // Chunky gold blocks around the mini-me, filled as you walk (clockwise from the top).
    private func ring(_ px: Pix, _ cx: Int, _ cy: Int, _ night: Bool) {
        let blocks = 40
        let lit = Int((progress * Double(blocks)).rounded(.down))
        for i in 0..<blocks {
            let a = Double(i) / Double(blocks) * 2 * .pi - .pi / 2
            let bx = cx + Int((cos(a) * Double(Self.radius)).rounded()) - 1
            let by = cy + Int((sin(a) * Double(Self.radius)).rounded()) - 1
            let on = i < lit || (i == 0 && progress > 0)
            px.rect(bx - 1, by - 1, 4, 4, Retro16.ink.opacity(on ? 1 : 0.6))
            if on {
                px.rect(bx, by, 2, 2, Retro16.gold)
                px.rect(bx, by, 1, 1, Retro16.goldLight)
                px.rect(bx + 1, by + 1, 1, 1, Retro16.goldDark)
            } else {
                px.rect(bx, by, 2, 2, night ? hex(0x4A5088) : Color.white.opacity(0.55))
            }
        }
    }
}

// MARK: - Panels: deep-blue menu boxes with a light pixel border and stepped corners

struct PixelPanel: InsettableShape {
    var step: CGFloat = 4
    var amount: CGFloat = 0

    func inset(by more: CGFloat) -> PixelPanel { PixelPanel(step: step, amount: amount + more) }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: amount, dy: amount), s = step
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 2 * s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.minY + s)); p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY + 2 * s)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + 2 * s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 2 * s))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - 2 * s)); p.addLine(to: CGPoint(x: r.maxX - s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.maxY - s)); p.addLine(to: CGPoint(x: r.maxX - 2 * s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 2 * s, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 2 * s, y: r.maxY - s)); p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY - 2 * s)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - 2 * s))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 2 * s))
        p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + 2 * s)); p.addLine(to: CGPoint(x: r.minX + s, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.minX + 2 * s, y: r.minY + s))
        p.closeSubpath()
        return p
    }
}

// Dark outline, then a light border, then a thin inner line.
struct Retro16Border: View {
    var step: CGFloat = 4
    var body: some View {
        ZStack {
            PixelPanel(step: step).strokeBorder(Retro16.ink, lineWidth: 2)
            PixelPanel(step: step).inset(by: 2).strokeBorder(hex(0xF4F6FF), lineWidth: 3)
            PixelPanel(step: step).inset(by: 5).strokeBorder(hex(0x8A93C8).opacity(0.7), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct Retro16PanelBackground: View {
    var step: CGFloat = 4
    var body: some View {
        PixelPanel(step: step)
            .fill(LinearGradient(colors: [hex(0x3354CC), hex(0x16207A)], startPoint: .top, endPoint: .bottom))
            .overlay(Retro16Border(step: step))
    }
}

extension View {
    // A blue menu panel. Text inside reads as white (dark color scheme just for the panel's content).
    func retro16Panel() -> some View {
        self
            .background(Retro16PanelBackground())
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Small pieces

// The settings button: a pixel gear in a little menu box.
struct Retro16GearButton: View {
    let action: () -> Void
    private static let gear: PixelGrid = {
        var g = PixelGrid(12, 12)
        g.stamp(["....WW....",
                 ".W.WWWW.W.",
                 "..WWWWWW..",
                 ".WWW..WWW.",
                 "WWW....WWW",
                 "WWW....WWW",
                 ".WWW..WWW.",
                 "..WWWWWW..",
                 ".W.WWWW.W.",
                 "....WW...."], 1, 1)
        g.outline("O")
        return g
    }()

    var body: some View {
        Button(action: action) {
            Canvas { ctx, _ in
                Self.gear.draw(Pix(ctx: ctx, p: 3), 0, 0, ["W": .white, "O": Retro16.ink])
            }
            .frame(width: 36, height: 36)
            .padding(6)
            .background(Retro16PanelBackground(step: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}

// History: one day's bar as 10 gold pixel blocks, with a tiny pixel mini-me where the bar ends.
struct Retro16DayBar: View {
    let fraction: Double
    let look: Look
    let avatar: Avatar
    let mood: Mood
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let barTop = 24, barRows = 6

    var body: some View {
        let q = Retro16.smallPixel(scale: displayScale)
        TimelineView(.animation(minimumInterval: 1.0 / 8, paused: reduceMotion)) { tl in
            Canvas { ctx, size in
                let px = Pix(ctx: ctx, p: q)
                let cols = Int(size.width / q)
                let gap = 1, blocks = 10
                let blockW = (cols - gap * (blocks - 1)) / blocks
                let filled = fraction * Double(blocks)
                let full = Int(filled)
                let partial = Int(((filled - Double(full)) * Double(blockW - 2)).rounded())
                for i in 0..<blocks {
                    let x = i * (blockW + gap)
                    px.rect(x, Self.barTop, blockW, Self.barRows, Retro16.ink)
                    px.rect(x + 1, Self.barTop + 1, blockW - 2, Self.barRows - 2, Color.white.opacity(0.16))
                    let w = i < full ? blockW - 2 : (i == full ? partial : 0)
                    if w > 0 {
                        px.rect(x + 1, Self.barTop + 1, w, Self.barRows - 2, Retro16.gold)
                        px.rect(x + 1, Self.barTop + 1, w, 1, Retro16.goldLight)
                        px.rect(x + 1, Self.barTop + Self.barRows - 2, w, 1, Retro16.goldDark)
                    }
                }
                // Where the filled part ends.
                let end = full * (blockW + gap) + (full < blocks ? partial : -gap)
                let tick = reduceMotion ? 0 : Int(tl.date.timeIntervalSinceReferenceDate * 8)
                let (grid, _) = RetroSprite.frame(look, avatar: avatar, mood: mood, tick: tick, hop: false)
                let x = min(max(end - RetroSprite.centerX, -3), cols - RetroSprite.width + 3)
                grid.draw(px, x, Self.barTop + 1 - RetroSprite.height, RetroSprite.palette(look))
            }
        }
        .frame(height: CGFloat(Self.barTop + Self.barRows) * q)
        .accessibilityHidden(true)
    }
}
