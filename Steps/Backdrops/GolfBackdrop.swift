import SwiftUI

// Golf: rolling fairway leading to a putting green with a waving flag, bunkers, a tree line and hills.
// Light mode = sunny afternoon. Dark mode = dusk with a warm glow on the horizon, moon and stars.
enum GolfBackdrop {
    // The ball drops into the cup.
    static func target(_ f: BackdropFrame) -> CGPoint { CGPoint(x: f.targetX, y: cupY(f)) }

    private static func cupY(_ f: BackdropFrame) -> Double { f.horizon - 6 }
    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }
    private static func rnd(_ i: Int, _ s: Double) -> Double {
        let x = sin(Double(i) * 12.9898 + s * 78.233) * 43758.5453
        return x - floor(x)
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let W = f.width, H = f.horizon, h = f.height, d = f.dark
        let s = min(1.2, max(0.75, H / 280))            // vertical scale for small / tall layouts
        let far = H - min(58, max(34, H * 0.16))         // where the land meets the sky

        // Sky
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: W, height: far + 6), d
            ? [rgb(0.06, 0.07, 0.19), rgb(0.17, 0.15, 0.34), rgb(0.48, 0.30, 0.44), rgb(0.93, 0.58, 0.40)]
            : [rgb(0.33, 0.60, 0.93), rgb(0.58, 0.79, 0.97), rgb(0.86, 0.94, 0.99)])

        if d {
            // Stars that twinkle, and a moon.
            var stars = Path()
            for i in 0..<36 {
                let x = rnd(i, 1) * W, y = rnd(i, 2) * far * 0.65
                let r = 0.6 + rnd(i, 3) * 1.0 + 0.35 * sin(f.t * (1 + rnd(i, 4) * 2) + Double(i))
                stars.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
            ctx.fill(stars, with: .color(.white.opacity(0.75)))
            let m = CGPoint(x: W * 0.14, y: max(30, far * 0.22))
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - 40, y: m.y - 40, width: 80, height: 80)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.25), .clear]), center: m, startRadius: 8, endRadius: 40))
            let moon = Path(ellipseIn: CGRect(x: m.x - 12, y: m.y - 12, width: 24, height: 24))
                .subtracting(Path(ellipseIn: CGRect(x: m.x - 5, y: m.y - 16, width: 24, height: 24)))
            ctx.fill(moon, with: .color(rgb(0.98, 0.95, 0.85)))
            // Warm afterglow over the hills on the right.
            let g = CGPoint(x: W * 0.8, y: far)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: far + 6)),
                     with: .radialGradient(Gradient(colors: [rgb(1.0, 0.70, 0.45, 0.55), .clear]), center: g, startRadius: 0, endRadius: W * 0.7))
        } else {
            // Sun with a soft glow.
            let sun = CGPoint(x: W * 0.15, y: max(34, far * 0.24))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 110, y: sun.y - 110, width: 220, height: 220)),
                     with: .radialGradient(Gradient(colors: [rgb(1, 0.98, 0.85, 0.75), rgb(1, 0.95, 0.80, 0)]), center: sun, startRadius: 10, endRadius: 110))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 17, y: sun.y - 17, width: 34, height: 34)), with: .color(rgb(1, 0.98, 0.88)))
        }

        // Drifting clouds
        for i in 0..<4 {
            let span = W + 240
            let sc = 0.65 + rnd(i, 5) * 0.55
            let x = (rnd(i, 6) * span + f.t * (3 + Double(i) * 1.3)).truncatingRemainder(dividingBy: span) - 120
            let y = far * (0.16 + 0.17 * Double(i)) + 6
            var c = Path()
            c.addEllipse(in: CGRect(x: x - 36 * sc, y: y - 8 * sc, width: 72 * sc, height: 22 * sc))
            c.addEllipse(in: CGRect(x: x - 22 * sc, y: y - 20 * sc, width: 34 * sc, height: 30 * sc))
            c.addEllipse(in: CGRect(x: x - 2 * sc, y: y - 15 * sc, width: 30 * sc, height: 24 * sc))
            ctx.fill(c, with: .linearGradient(Gradient(colors: d ? [rgb(0.55, 0.42, 0.58, 0.55), rgb(0.30, 0.24, 0.42, 0.45)]
                                                               : [.white.opacity(0.95), rgb(0.86, 0.91, 0.97, 0.9)]),
                                              startPoint: CGPoint(x: x, y: y - 20 * sc), endPoint: CGPoint(x: x, y: y + 14 * sc)))
        }

        // Hills: far (hazy) and nearer, then the tree line.
        func hill(base: Double, amp: Double, freq: Double, phase: Double, color: Color) {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: far + 4))
            var x = 0.0
            while x <= W + 8 {
                let y = base - amp * (0.5 + 0.35 * sin(x * freq + phase) + 0.15 * sin(x * freq * 2.7 + phase * 1.7))
                p.addLine(to: CGPoint(x: x, y: y)); x += 8
            }
            p.addLine(to: CGPoint(x: W, y: far + 4)); p.closeSubpath()
            ctx.fill(p, with: .color(color))
        }
        hill(base: far - 12 * s, amp: 34 * s, freq: 0.011, phase: 1.2, color: d ? rgb(0.33, 0.25, 0.43) : rgb(0.66, 0.80, 0.84))
        hill(base: far - 2 * s, amp: 22 * s, freq: 0.017, phase: 4.0, color: d ? rgb(0.22, 0.19, 0.33) : rgb(0.50, 0.70, 0.58))

        // Tree line: little round crowns on the far edge of the course.
        var trees = Path()
        var tx = -6.0, k = 0
        while tx < W + 10 {
            let r = (5 + rnd(k, 7) * 6) * s
            trees.addEllipse(in: CGRect(x: tx - r, y: far - r * 1.5, width: 2 * r, height: 2.2 * r))
            tx += r * 1.3; k += 1
        }
        trees.addRect(CGRect(x: 0, y: far - 4, width: W, height: 6))
        ctx.fill(trees, with: .linearGradient(Gradient(colors: d ? [rgb(0.13, 0.18, 0.24), rgb(0.09, 0.13, 0.17)]
                                                             : [rgb(0.24, 0.50, 0.33), rgb(0.17, 0.38, 0.26)]),
                                              startPoint: CGPoint(x: 0, y: far - 20 * s), endPoint: CGPoint(x: 0, y: far + 2)))

        // Ground (rough), hazy in the distance.
        Sketch.gradient(&ctx, CGRect(x: 0, y: far, width: W, height: h - far), d
            ? [rgb(0.18, 0.30, 0.25), rgb(0.11, 0.25, 0.17), rgb(0.06, 0.15, 0.11)]
            : [rgb(0.55, 0.72, 0.42), rgb(0.36, 0.60, 0.28), rgb(0.24, 0.47, 0.21)])

        // A distant fairway of another hole.
        var farFair = Path()
        farFair.addEllipse(in: CGRect(x: -W * 0.1, y: far + (H - far) * 0.25, width: W * 0.62, height: (H - far) * 0.32))
        ctx.fill(farFair, with: .color(d ? rgb(0.20, 0.36, 0.26, 0.8) : rgb(0.62, 0.80, 0.46, 0.9)))

        // Main fairway, curving toward the green.
        let gx = f.targetX
        var fair = Path()
        fair.move(to: CGPoint(x: W * 0.02, y: h))
        fair.addQuadCurve(to: CGPoint(x: gx - W * 0.52, y: H - 4), control: CGPoint(x: W * 0.02, y: H + 40 * s))
        fair.addQuadCurve(to: CGPoint(x: gx + W * 0.16, y: H + 2), control: CGPoint(x: gx - W * 0.2, y: H - 14 * s))
        fair.addQuadCurve(to: CGPoint(x: W * 1.15, y: h), control: CGPoint(x: gx + W * 0.30, y: H + 80 * s))
        fair.closeSubpath()
        ctx.fill(fair, with: .linearGradient(Gradient(colors: d ? [rgb(0.20, 0.42, 0.28), rgb(0.10, 0.27, 0.17)]
                                                           : [rgb(0.58, 0.82, 0.40), rgb(0.40, 0.68, 0.28)]),
                                             startPoint: CGPoint(x: 0, y: H), endPoint: CGPoint(x: 0, y: h)))
        // Mowing stripes, wider as they come closer.
        var stripes = ctx
        stripes.clip(to: fair)
        var y = H - 10.0, band = 5.0 * s, on = false
        var sp = Path()
        while y < h {
            if on { sp.addRect(CGRect(x: 0, y: y, width: W, height: band)) }
            y += band; band = min(band * 1.32, 46); on.toggle()
        }
        stripes.fill(sp, with: .color(.white.opacity(d ? 0.04 : 0.09)))

        // Fairway bunker on the left.
        func bunker(_ c: CGPoint, _ rx: Double, _ ry: Double) {
            let r = CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry)
            ctx.fill(Path(ellipseIn: r.insetBy(dx: -3, dy: -1.5)), with: .color(d ? rgb(0.08, 0.20, 0.12) : rgb(0.30, 0.55, 0.24)))
            ctx.fill(Path(ellipseIn: r), with: .linearGradient(Gradient(colors: d ? [rgb(0.45, 0.40, 0.36), rgb(0.62, 0.55, 0.46)]
                                                                               : [rgb(0.82, 0.74, 0.54), rgb(0.97, 0.91, 0.72)]),
                                                         startPoint: CGPoint(x: c.x, y: r.minY), endPoint: CGPoint(x: c.x, y: r.maxY)))
        }
        bunker(CGPoint(x: f.center - W * 0.31, y: H + 50 * s), 34, 9 * s)
        bunker(CGPoint(x: gx + W * 0.10, y: H + 13 * s), 20, 5.5 * s)

        // Putting green with fringe, a soft highlight and the cup.
        let gc = CGPoint(x: gx + 2, y: H - 5)
        let rx = W * 0.15, ry = 11 * s
        ctx.fill(Path(ellipseIn: CGRect(x: gc.x - rx - 6, y: gc.y - ry - 3, width: 2 * rx + 12, height: 2 * ry + 6)),
                 with: .color(d ? rgb(0.15, 0.36, 0.22) : rgb(0.45, 0.74, 0.32)))
        ctx.fill(Path(ellipseIn: CGRect(x: gc.x - rx, y: gc.y - ry, width: 2 * rx, height: 2 * ry)),
                 with: .radialGradient(Gradient(colors: d ? [rgb(0.30, 0.55, 0.36), rgb(0.18, 0.44, 0.27)]
                                                          : [rgb(0.74, 0.94, 0.55), rgb(0.52, 0.82, 0.38)]),
                                       center: CGPoint(x: gc.x - rx * 0.3, y: gc.y - ry * 0.3), startRadius: 0, endRadius: rx))

        // Tree just behind the green, on the right.
        func tree(_ x: Double, _ base: Double, _ sz: Double) {
            Sketch.fill(&ctx, CGRect(x: x - sz * 0.07, y: base - sz * 0.5, width: sz * 0.14, height: sz * 0.5), d ? rgb(0.16, 0.11, 0.10) : rgb(0.42, 0.28, 0.18))
            var crown = Path()
            crown.addEllipse(in: CGRect(x: x - sz * 0.42, y: base - sz * 1.05, width: sz * 0.84, height: sz * 0.7))
            crown.addEllipse(in: CGRect(x: x - sz * 0.30, y: base - sz * 1.30, width: sz * 0.60, height: sz * 0.6))
            ctx.fill(crown, with: .linearGradient(Gradient(colors: d ? [rgb(0.17, 0.30, 0.26), rgb(0.08, 0.17, 0.14)]
                                                                 : [rgb(0.38, 0.66, 0.36), rgb(0.18, 0.42, 0.22)]),
                                                  startPoint: CGPoint(x: x - sz * 0.3, y: base - sz * 1.3), endPoint: CGPoint(x: x + sz * 0.3, y: base - sz * 0.35)))
        }
        tree(gx + W * 0.17, H - 14 * s, 44 * s)

        // Flag pole, its shadow and a waving flag.
        let cy = cupY(f)
        let top = cy - 80 * s
        Sketch.line(&ctx, CGPoint(x: gx, y: cy), CGPoint(x: gx - 26, y: cy + 5), .black.opacity(d ? 0.25 : 0.16), 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x: gx - 5, y: cy - 2, width: 10, height: 4)), with: .color(rgb(0.10, 0.18, 0.10)))
        Sketch.line(&ctx, CGPoint(x: gx, y: cy), CGPoint(x: gx, y: top), d ? rgb(0.90, 0.88, 0.84) : .white, 2.2)
        var flag = Path()
        let fl = 30 * s, fh = 19 * s
        flag.move(to: CGPoint(x: gx + 1, y: top))
        for i in 1...6 {
            let u = Double(i) / 6
            flag.addLine(to: CGPoint(x: gx + 1 + fl * u, y: top + fh * 0.5 * u + 3 * u * sin(f.t * 4 - u * 4)))
        }
        for i in stride(from: 6, through: 0, by: -1) {
            let u = Double(i) / 6
            flag.addLine(to: CGPoint(x: gx + 1 + fl * u, y: top + fh - fh * 0.5 * u + 3 * u * sin(f.t * 4 - u * 4)))
        }
        flag.closeSubpath()
        ctx.fill(flag, with: .linearGradient(Gradient(colors: [rgb(0.98, 0.30, 0.25), rgb(0.80, 0.14, 0.14)]),
                                             startPoint: CGPoint(x: gx, y: top), endPoint: CGPoint(x: gx + fl, y: top + fh)))

        // Big tree framing the left edge.
        tree(W * 0.03, H + 26 * s, 120 * s)
        ctx.fill(Path(ellipseIn: CGRect(x: -W * 0.06, y: H + 20 * s, width: 90 * s, height: 14 * s)), with: .color(.black.opacity(0.10)))
    }
}
