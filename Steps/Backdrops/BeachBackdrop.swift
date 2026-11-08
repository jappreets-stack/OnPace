import SwiftUI

// Beach: the sea on the left with waves rolling up the sand, the beach curving away to the right toward
// a distant headland, a palm on the left, a striped umbrella and a lifeguard tower on the right.
// The mini-me throws a frisbee up over the sand to the right.
enum BeachBackdrop {
    private typealias RGB = (Double, Double, Double)

    private static func col(_ f: BackdropFrame, _ day: RGB, _ night: RGB, _ a: Double = 1) -> Color {
        let c = f.dark ? night : day
        return Color(red: c.0, green: c.1, blue: c.2).opacity(a)
    }

    private static func rgb(_ c: RGB, _ a: Double = 1) -> Color { Color(red: c.0, green: c.1, blue: c.2).opacity(a) }

    private static func rnd(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - floor(x)
    }

    // MARK: Geometry

    // Where the sea meets the sky.
    private static func seaTop(_ f: BackdropFrame) -> Double { f.horizon - 55 }

    // The water's edge at x: just behind the mini-me, sweeping toward you on the left and away on the right.
    private static func shoreY(_ f: BackdropFrame, _ x: Double) -> Double {
        let u = x / f.width
        let g = 0.12 + 0.88 * exp(-2.6 * (u - 0.5))
        return seaTop(f) + (f.horizon + 6 - seaTop(f)) * g
    }

    // How "near" the shore is at x (1 at the mini-me, smaller further away).
    private static func nearness(_ f: BackdropFrame, _ x: Double) -> Double {
        (shoreY(f, x) - seaTop(f)) / (f.horizon - seaTop(f))
    }

    // The shoreline pushed `d` points (scaled by perspective) out into the water.
    private static func shorePath(_ f: BackdropFrame, offset d: Double, n: Int = 36) -> [CGPoint] {
        (0...n).map { i in
            let x = -4 + (f.width + 8) * Double(i) / Double(n)
            let y = shoreY(f, x) - d * nearness(f, x)
            return CGPoint(x: x, y: max(y, seaTop(f) + 0.5))
        }
    }

    // MARK: Public API

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        drawSky(&ctx, f)
        drawSea(&ctx, f)
        drawSand(&ctx, f)
        drawSurf(&ctx, f)
        drawTower(&ctx, f)
        drawUmbrella(&ctx, f)
        drawPalm(&ctx, f)
    }

    // MARK: Sky

    private static func sunPoint(_ f: BackdropFrame) -> CGPoint {
        CGPoint(x: f.width * 0.30, y: max(58, seaTop(f) * 0.36))
    }

    private static func drawSky(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = seaTop(f)
        let colors: [Color] = f.dark
            ? [rgb((0.03, 0.05, 0.15)), rgb((0.10, 0.14, 0.32)), rgb((0.27, 0.27, 0.48)), rgb((0.52, 0.40, 0.52))]
            : [rgb((0.20, 0.55, 0.92)), rgb((0.45, 0.75, 0.97)), rgb((0.78, 0.92, 0.99)), rgb((0.99, 0.96, 0.88))]
        ctx.fill(Path(CGRect(x: 0, y: 0, width: f.width, height: top + 1)),
                 with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: top)))

        let s = sunPoint(f)
        if f.dark {
            for i in 0..<50 {
                let x = rnd(i, 1) * f.width
                let y = pow(rnd(i, 2), 1.3) * top * 0.8
                let r = 0.8 + rnd(i, 3) * 1.5
                let tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(f.t * (0.7 + rnd(i, 4) * 1.8) + Double(i)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)), with: .color(.white.opacity(0.85 * tw)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 50, y: s.y - 50, width: 100, height: 100)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.3), .white.opacity(0)]), center: s, startRadius: 12, endRadius: 50))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 17, y: s.y - 17, width: 34, height: 34)), with: .color(rgb((0.97, 0.95, 0.87))))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 9, y: s.y - 6, width: 8, height: 8)), with: .color(rgb((0.87, 0.85, 0.78))))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x + 3, y: s.y + 4, width: 5, height: 5)), with: .color(rgb((0.87, 0.85, 0.78))))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 80, y: s.y - 80, width: 160, height: 160)),
                     with: .radialGradient(Gradient(colors: [rgb((1, 0.97, 0.80), 0.8), rgb((1, 0.95, 0.8), 0)]), center: s, startRadius: 16, endRadius: 80))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 22, y: s.y - 22, width: 44, height: 44)), with: .color(rgb((1, 0.96, 0.72))))
        }

        // Thin, drifting clouds.
        let span = f.width + 260
        let clouds: [(Double, Double, Double, Double)] = [(0.15, 0.30, 1.0, 2.6), (0.62, 0.16, 0.7, 1.8)]
        for (i, c) in clouds.enumerated() {
            let x = (c.0 * span + f.t * c.3).truncatingRemainder(dividingBy: span) - 130
            let y = max(44, top * c.1 + 34)
            let w = 120 * c.2
            let shade = col(f, (1, 1, 1), (0.55, 0.50, 0.70), f.dark ? 0.35 : 0.85)
            ctx.fill(Path(roundedRect: CGRect(x: x - w / 2, y: y, width: w, height: 9 * c.2), cornerRadius: 4.5 * c.2), with: .color(shade))
            ctx.fill(Path(ellipseIn: CGRect(x: x - w * 0.28, y: y - 12 * c.2, width: w * 0.42, height: 20 * c.2)), with: .color(shade))
            ctx.fill(Path(ellipseIn: CGRect(x: x - w * 0.02, y: y - 7 * c.2, width: w * 0.32, height: 15 * c.2)), with: .color(shade))
            _ = i
        }

        // Two gulls gliding (day only).
        if !f.dark {
            for i in 0..<2 {
                let x = (f.width * (0.45 + 0.2 * Double(i)) + f.t * (6 + Double(i) * 2)).truncatingRemainder(dividingBy: f.width + 40) - 20
                let y = top * (0.30 + 0.12 * Double(i)) + 4 * sin(f.t * 0.9 + Double(i) * 2)
                let w = 7.0 - Double(i) * 1.5
                let flap = 2 * sin(f.t * 3 + Double(i))
                var p = Path()
                p.move(to: CGPoint(x: x - w, y: y - flap * 0.5))
                p.addQuadCurve(to: CGPoint(x: x, y: y + 1.5), control: CGPoint(x: x - w * 0.5, y: y - 3 - flap))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y - flap * 0.5), control: CGPoint(x: x + w * 0.5, y: y - 3 - flap))
                ctx.stroke(p, with: .color(rgb((0.25, 0.30, 0.40), 0.75)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }

        // Distant headland on the right, sitting on the horizon.
        var hl = Path()
        let hx = f.width * 0.70
        hl.move(to: CGPoint(x: hx, y: top + 1))
        hl.addCurve(to: CGPoint(x: f.width * 0.86, y: top - 26), control1: CGPoint(x: hx + f.width * 0.06, y: top - 2), control2: CGPoint(x: f.width * 0.78, y: top - 26))
        hl.addCurve(to: CGPoint(x: f.width + 2, y: top - 34), control1: CGPoint(x: f.width * 0.93, y: top - 26), control2: CGPoint(x: f.width * 0.96, y: top - 36))
        hl.addLine(to: CGPoint(x: f.width + 2, y: top + 1))
        hl.closeSubpath()
        ctx.fill(hl, with: .color(col(f, (0.55, 0.70, 0.72), (0.18, 0.20, 0.36))))
    }

    // MARK: Sea

    private static func drawSea(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = seaTop(f)
        let bottom = shoreY(f, 0) + 10
        ctx.fill(Path(CGRect(x: 0, y: top, width: f.width, height: bottom - top)), with: .linearGradient(
            Gradient(colors: f.dark
                     ? [rgb((0.20, 0.25, 0.45)), rgb((0.08, 0.20, 0.36)), rgb((0.05, 0.24, 0.36))]
                     : [rgb((0.30, 0.60, 0.80)), rgb((0.10, 0.55, 0.72)), rgb((0.20, 0.72, 0.76))]),
            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        // Horizon line.
        Sketch.line(&ctx, CGPoint(x: 0, y: top), CGPoint(x: f.width, y: top), col(f, (0.22, 0.45, 0.68), (0.55, 0.50, 0.68), 0.8), 1)

        // Sun / moon reflection: shimmering dashes under it.
        let s = sunPoint(f)
        let glint = col(f, (1, 0.98, 0.85), (0.95, 0.93, 0.85))
        for i in 0..<16 {
            let k = Double(i) / 15
            let y = top + 2 + pow(k, 1.6) * (shoreY(f, s.x) - top - 10)
            let w = (6 + k * 34) * (0.6 + 0.4 * sin(f.t * 1.7 + Double(i) * 1.3))
            let dx = sin(f.t * 1.1 + Double(i) * 2.1) * (2 + k * 6)
            ctx.fill(Path(roundedRect: CGRect(x: s.x - w / 2 + dx, y: y, width: w, height: 1 + k * 2.5), cornerRadius: 1.5),
                     with: .color(glint.opacity(f.dark ? 0.55 : 0.6) .opacity(1 - k * 0.5)))
        }

        // Little wave crests across the open water, bobbing gently.
        let crest = col(f, (1, 1, 1), (0.70, 0.78, 0.92), f.dark ? 0.30 : 0.5)
        for i in 0..<36 {
            let k = pow(rnd(i, 11), 1.5)
            let y = top + 3 + k * (bottom - top - 6)
            let x = rnd(i, 12) * f.width + sin(f.t * 0.6 + Double(i)) * 3
            if y > shoreY(f, x) - 8 * nearness(f, x) - 4 { continue }
            let w = 4 + k * 22
            var p = Path()
            p.move(to: CGPoint(x: x - w / 2, y: y))
            p.addQuadCurve(to: CGPoint(x: x + w / 2, y: y), control: CGPoint(x: x, y: y - 1.5 - k * 3))
            ctx.stroke(p, with: .color(crest), style: StrokeStyle(lineWidth: 0.8 + k * 1.2, lineCap: .round))
        }
    }

    // MARK: Sand

    private static func drawSand(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        // How far the wash reaches up the sand right now.
        let wash = 7 + 6 * sin(f.t * 0.75)

        // Dry sand everywhere below the shoreline.
        var sand = Path()
        let pts = shorePath(f, offset: 0)
        sand.move(to: pts[0])
        for p in pts.dropFirst() { sand.addLine(to: p) }
        sand.addLine(to: CGPoint(x: f.width + 4, y: f.height + 4))
        sand.addLine(to: CGPoint(x: -4, y: f.height + 4))
        sand.closeSubpath()
        ctx.fill(sand, with: .linearGradient(
            Gradient(colors: f.dark
                     ? [rgb((0.46, 0.41, 0.42)), rgb((0.36, 0.31, 0.34)), rgb((0.25, 0.22, 0.27))]
                     : [rgb((0.96, 0.88, 0.70)), rgb((0.94, 0.82, 0.60)), rgb((0.90, 0.76, 0.54))]),
            startPoint: CGPoint(x: 0, y: seaTop(f)), endPoint: CGPoint(x: 0, y: f.height)))

        // Darker wet sand right at the water's edge.
        var wet = Path()
        let wetLine = shorePath(f, offset: -16)
        wet.move(to: pts[0]); for p in pts.dropFirst() { wet.addLine(to: p) }
        for p in wetLine.reversed() { wet.addLine(to: p) }
        wet.closeSubpath()
        ctx.fill(wet, with: .color(col(f, (0.80, 0.68, 0.50), (0.26, 0.25, 0.33), 0.7)))

        // Soft ripples and a few shells in the sand.
        let ripple = col(f, (0.82, 0.70, 0.50), (0.18, 0.17, 0.23), 0.45)
        for i in 0..<14 {
            let x = rnd(i, 31) * f.width
            let y0 = max(shoreY(f, x) + 22, f.horizon + 6)
            let y = y0 + pow(rnd(i, 32), 1.5) * (f.height - y0)
            let w = 14 + (y - f.horizon) * 0.08
            var p = Path()
            p.move(to: CGPoint(x: x - w, y: y))
            p.addQuadCurve(to: CGPoint(x: x + w, y: y), control: CGPoint(x: x, y: y - 3))
            ctx.stroke(p, with: .color(ripple), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        let shell = col(f, (1, 0.95, 0.90), (0.60, 0.56, 0.62))
        for i in 0..<8 {
            let x = rnd(i, 41) * f.width
            let y = max(shoreY(f, x) + 18, f.horizon + 4) + rnd(i, 42) * 120
            if abs(x - f.center) < 34 && y < f.horizon + 20 { continue }
            let r = 1.6 + (y - f.horizon) * 0.012
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)), with: .color(shell))
        }
        _ = wash
    }

    // MARK: Surf

    private static func drawSurf(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let foam = col(f, (1, 1, 1), (0.78, 0.84, 0.95))

        // The thin sheet of water sliding up the sand and back.
        let reach = 5 + 7 * (0.5 + 0.5 * sin(f.t * 0.8))
        let edge = shorePath(f, offset: -reach)
        let back = shorePath(f, offset: 10)
        var sheet = Path()
        sheet.move(to: back[0]); for p in back.dropFirst() { sheet.addLine(to: p) }
        for p in edge.reversed() { sheet.addLine(to: p) }
        sheet.closeSubpath()
        ctx.fill(sheet, with: .color(col(f, (0.55, 0.85, 0.85), (0.20, 0.36, 0.48), 0.65)))
        var lace = Path()
        lace.move(to: edge[0]); for p in edge.dropFirst() { lace.addLine(to: p) }
        ctx.stroke(lace, with: .color(foam.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        // Waves rolling in: each starts out at sea and breaks onto the shore.
        for i in 0..<3 {
            let p = (f.t / 5.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let d = 12 + (1 - p) * 46
            let a = sin(p * .pi) * (f.dark ? 0.7 : 0.9)
            var w = Path()
            var open = false
            for q in 0...40 {
                let x = -4 + (f.width + 8) * Double(q) / 40
                let n = nearness(f, x)
                let y = shoreY(f, x) - d * n
                if n < 0.55 || y < seaTop(f) + 6 { open = false; continue }
                if open { w.addLine(to: CGPoint(x: x, y: y)) } else { w.move(to: CGPoint(x: x, y: y)); open = true }
            }
            var face = ctx
            face.translateBy(x: 0, y: 3)
            face.stroke(w, with: .color(col(f, (0.05, 0.40, 0.55), (0.02, 0.12, 0.22), a * 0.35)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            ctx.stroke(w, with: .color(foam.opacity(a * (0.35 + 0.45 * p))), style: StrokeStyle(lineWidth: 1 + p * 2, lineCap: .round, lineJoin: .round, dash: p < 0.7 ? [16, 6, 5, 6] : []))
        }
    }

    // MARK: Lifeguard tower (far back on the right)

    private static func drawTower(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let x = f.width * 0.66
        let base = shoreY(f, x) + 12
        let s = 0.9
        let wood = col(f, (0.95, 0.95, 0.93), (0.55, 0.55, 0.62))
        let leg = col(f, (0.70, 0.62, 0.52), (0.30, 0.28, 0.34))
        ctx.fill(Path(ellipseIn: CGRect(x: x - 14 * s, y: base - 2, width: 30 * s, height: 4)), with: .color(.black.opacity(0.15)))
        Sketch.line(&ctx, CGPoint(x: x - 9 * s, y: base), CGPoint(x: x - 6 * s, y: base - 20 * s), leg, 1.6)
        Sketch.line(&ctx, CGPoint(x: x + 9 * s, y: base), CGPoint(x: x + 6 * s, y: base - 20 * s), leg, 1.6)
        Sketch.line(&ctx, CGPoint(x: x - 8 * s, y: base - 8 * s), CGPoint(x: x + 8 * s, y: base - 8 * s), leg, 1)
        Sketch.fill(&ctx, CGRect(x: x - 10 * s, y: base - 33 * s, width: 20 * s, height: 13 * s), wood)
        Sketch.fill(&ctx, CGRect(x: x - 7 * s, y: base - 30 * s, width: 14 * s, height: 6 * s), col(f, (0.45, 0.70, 0.85), (0.90, 0.78, 0.45)))
        var roof = Path()
        roof.move(to: CGPoint(x: x - 13 * s, y: base - 33 * s))
        roof.addLine(to: CGPoint(x: x, y: base - 40 * s))
        roof.addLine(to: CGPoint(x: x + 13 * s, y: base - 33 * s))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(col(f, (0.90, 0.30, 0.25), (0.45, 0.20, 0.25))))
        // Little flag.
        let wave = sin(f.t * 3) * 1.5
        Sketch.line(&ctx, CGPoint(x: x, y: base - 40 * s), CGPoint(x: x, y: base - 50 * s), leg, 0.8)
        var flag = Path()
        flag.move(to: CGPoint(x: x, y: base - 50 * s))
        flag.addLine(to: CGPoint(x: x + 7, y: base - 48 * s + wave))
        flag.addLine(to: CGPoint(x: x, y: base - 45.5 * s))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(col(f, (0.95, 0.75, 0.20), (0.75, 0.60, 0.25))))
    }

    // MARK: Beach umbrella (right)

    private static func drawUmbrella(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let x = f.width * 0.90
        let base = f.horizon + 46
        let top = base - 78
        let r = 42.0
        // Shadow + towel.
        ctx.fill(Path(ellipseIn: CGRect(x: x - r - 12, y: base - 8, width: r * 2 + 6, height: 18)), with: .color(.black.opacity(0.14)))
        var towel = Path()
        towel.move(to: CGPoint(x: x - 58, y: base + 4)); towel.addLine(to: CGPoint(x: x - 18, y: base - 2))
        towel.addLine(to: CGPoint(x: x - 6, y: base + 18)); towel.addLine(to: CGPoint(x: x - 52, y: base + 26))
        towel.closeSubpath()
        ctx.fill(towel, with: .color(col(f, (0.30, 0.62, 0.90), (0.20, 0.32, 0.55))))
        var stripe = Path()
        stripe.move(to: CGPoint(x: x - 56, y: base + 10)); stripe.addLine(to: CGPoint(x: x - 15, y: base + 4))
        ctx.stroke(stripe, with: .color(.white.opacity(f.dark ? 0.5 : 0.85)), lineWidth: 2.5)
        // Pole.
        Sketch.line(&ctx, CGPoint(x: x + 2, y: base), CGPoint(x: x - 4, y: top), col(f, (0.92, 0.92, 0.92), (0.55, 0.55, 0.60)), 2.4)
        // Canopy: a dome of alternating stripes meeting at the top.
        let cx = x - 4, cy = top + 10
        let apex = CGPoint(x: cx, y: cy - 24)
        let n = 6
        let red = col(f, (0.93, 0.30, 0.28), (0.55, 0.22, 0.30))
        let white = col(f, (1, 0.97, 0.92), (0.66, 0.64, 0.72))
        func rim(_ th: Double) -> CGPoint { CGPoint(x: cx + r * cos(th), y: cy + 7 * sin(th)) }
        for i in 0..<n {
            let t0 = Double.pi * (1 - Double(i) / Double(n))
            let t1 = Double.pi * (1 - Double(i + 1) / Double(n))
            let p0 = rim(t0), p1 = rim(t1)
            var seg = Path()
            seg.move(to: apex)
            seg.addQuadCurve(to: p0, control: CGPoint(x: cx + r * cos(t0) * 0.8, y: apex.y + 3))
            seg.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) / 2, y: max(p0.y, p1.y) + 5))
            seg.addQuadCurve(to: apex, control: CGPoint(x: cx + r * cos(t1) * 0.8, y: apex.y + 3))
            seg.closeSubpath()
            ctx.fill(seg, with: .color(i % 2 == 0 ? red : white))
        }
        // Light from the upper left, shade to the right.
        var dome = Path()
        dome.move(to: apex)
        dome.addQuadCurve(to: rim(.pi), control: CGPoint(x: cx - r * 0.8, y: apex.y + 3))
        dome.addQuadCurve(to: rim(0), control: CGPoint(x: cx, y: cy + 14))
        dome.addQuadCurve(to: apex, control: CGPoint(x: cx + r * 0.8, y: apex.y + 3))
        dome.closeSubpath()
        ctx.fill(dome, with: .linearGradient(Gradient(colors: [.white.opacity(0.18), .black.opacity(0.14)]),
                                             startPoint: CGPoint(x: cx - r, y: apex.y), endPoint: CGPoint(x: cx + r, y: cy)))
        ctx.fill(Path(ellipseIn: CGRect(x: apex.x - 2.5, y: apex.y - 4, width: 5, height: 5)), with: .color(red))
    }

    // MARK: Palm (left edge, leaning out of the picture so its fronds frame the sky)

    private static func drawPalm(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let bx = f.width * 0.13
        let base = shoreY(f, bx) + 30
        let sway = sin(f.t * 0.7) * 2
        let crown = CGPoint(x: f.width * 0.02 + sway, y: f.horizon - 150)

        ctx.fill(Path(ellipseIn: CGRect(x: bx - 16, y: base - 4, width: 40, height: 8)), with: .color(.black.opacity(0.16)))

        // Tapered, gently curved trunk.
        func trunkPoint(_ k: Double) -> CGPoint {
            let c = CGPoint(x: bx + 4, y: base + (crown.y - base) * 0.55)
            let u = 1 - k
            return CGPoint(x: u * u * bx + 2 * u * k * c.x + k * k * crown.x,
                           y: u * u * base + 2 * u * k * c.y + k * k * crown.y)
        }
        let n = 16
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...n {
            let k = Double(i) / Double(n)
            let p = trunkPoint(k)
            let w = 8 - 4 * k
            left.append(CGPoint(x: p.x - w, y: p.y)); right.append(CGPoint(x: p.x + w, y: p.y))
        }
        var trunk = Path()
        trunk.move(to: left[0]); for p in left.dropFirst() { trunk.addLine(to: p) }
        for p in right.reversed() { trunk.addLine(to: p) }
        trunk.closeSubpath()
        ctx.fill(trunk, with: .linearGradient(Gradient(colors: [col(f, (0.50, 0.36, 0.22), (0.17, 0.14, 0.18)), col(f, (0.72, 0.55, 0.35), (0.28, 0.24, 0.28))]),
                                              startPoint: CGPoint(x: bx - 8, y: 0), endPoint: CGPoint(x: bx + 8, y: 0)))
        let ring = col(f, (0.42, 0.30, 0.18), (0.12, 0.10, 0.13), 0.7)
        for i in 1..<n {
            let a = left[i], b = right[i]
            var p = Path()
            p.move(to: a); p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: a.y + 3))
            ctx.stroke(p, with: .color(ring), lineWidth: 1)
        }

        // Fronds: curved, tapered leaves drooping from the crown.
        let c = trunkPoint(1)
        let leafDark = col(f, (0.14, 0.48, 0.28), (0.05, 0.17, 0.19))
        let leafLight = col(f, (0.26, 0.64, 0.34), (0.09, 0.24, 0.25))
        let fronds: [(Double, Double)] = [(-2.8, 60), (-2.2, 64), (-1.4, 50), (-0.75, 74), (-0.2, 82), (0.45, 70), (1.0, 52), (2.8, 50)]
        for (j, fr) in fronds.enumerated() {
            let a = fr.0 + sin(f.t * 0.9 + Double(j)) * 0.04
            let len = fr.1
            let tip = CGPoint(x: c.x + cos(a) * len, y: c.y + sin(a) * len * 0.5 + len * 0.45)
            let ctrl = CGPoint(x: c.x + cos(a) * len * 0.6, y: c.y + sin(a) * len * 0.6 - 14)
            let nx = -sin(a) * 10, ny = cos(a) * 10
            var leaf = Path()
            leaf.move(to: c)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: ctrl.x + nx, y: ctrl.y + ny))
            leaf.addQuadCurve(to: c, control: CGPoint(x: ctrl.x - nx, y: ctrl.y - ny))
            ctx.fill(leaf, with: .color(j % 2 == 0 ? leafDark : leafLight))
            var rib = Path()
            rib.move(to: c); rib.addQuadCurve(to: tip, control: ctrl)
            ctx.stroke(rib, with: .color(col(f, (0.08, 0.34, 0.20), (0.03, 0.11, 0.13), 0.8)), lineWidth: 1.2)
        }
        for k in 0..<3 {
            let dx = Double(k - 1) * 6
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + dx - 4, y: c.y + 1 + Double(k % 2) * 3, width: 8, height: 8)),
                     with: .color(col(f, (0.40, 0.28, 0.16), (0.16, 0.13, 0.16))))
        }
    }
}
