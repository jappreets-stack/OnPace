import SwiftUI

// Tennis: a blue hard court seen from behind the near baseline (where the mini-me serves),
// net across the middle, green windscreen and a stadium bowl behind. Night = floodlit match.
enum TennisBackdrop {
    // Simple ground perspective. X and d are meters (d = distance past the near baseline).
    private struct Cam {
        let cx: Double, vy: Double, hp: Double, m: Double, z0: Double
        func z(_ d: Double) -> Double { max(0.05, 1 + d / z0) }
        func y(_ d: Double) -> Double { vy + hp / z(d) }
        func p(_ x: Double, _ d: Double) -> CGPoint { CGPoint(x: cx + x * m / z(d), y: y(d)) }
    }

    private static let length = 23.77, half = 5.485, singles = 4.115
    private static let netD = 11.885, serviceNear = 5.485, serviceFar = 18.285

    private static func cam(_ f: BackdropFrame) -> Cam {
        let hp = min(0.85 * f.horizon, 0.62 * f.width)
        return Cam(cx: f.center, vy: f.horizon - hp, hp: hp, m: 0.95 * f.width / half, z0: 14)
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }

    private static func poly(_ ctx: inout GraphicsContext, _ pts: [CGPoint], _ c: Color) {
        var p = Path(); p.addLines(pts); p.closeSubpath()
        ctx.fill(p, with: .color(c))
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let c = cam(f)
        let dk = f.dark
        let yBack = c.y(length + 6.4)
        let fenceTop = yBack - max(10, 0.035 * f.width)

        // Sky.
        let skyR = CGRect(x: 0, y: 0, width: f.width, height: yBack + 1)
        Sketch.gradient(&ctx, skyR, dk
            ? [rgb(0.06, 0.08, 0.20), rgb(0.20, 0.20, 0.38), rgb(0.42, 0.30, 0.42)]
            : [rgb(0.36, 0.62, 0.93), rgb(0.62, 0.81, 0.98), rgb(0.88, 0.95, 1.0)])
        if dk { stars(&ctx, f, maxY: fenceTop * 0.6) } else { clouds(&ctx, f, maxY: fenceTop) }

        // Stadium bowl behind the court.
        stands(&ctx, f, bottom: fenceTop)

        // Floodlights (night) stand behind the stands at the edges.
        if dk { floodlights(&ctx, f, base: fenceTop) }

        // Windscreen along the back fence.
        let wind = CGRect(x: 0, y: fenceTop, width: f.width, height: yBack - fenceTop + 1)
        Sketch.gradient(&ctx, wind, dk ? [rgb(0.07, 0.20, 0.16), rgb(0.05, 0.15, 0.12)]
                                       : [rgb(0.10, 0.34, 0.26), rgb(0.08, 0.27, 0.21)])
        Sketch.line(&ctx, CGPoint(x: 0, y: fenceTop), CGPoint(x: f.width, y: fenceTop),
                    dk ? rgb(0.5, 0.6, 0.6, 0.6) : rgb(0.85, 0.92, 0.9, 0.7), 1.2)
        // fence posts
        var x = -fmod(f.center, f.width / 7)
        while x < f.width + 1 {
            Sketch.line(&ctx, CGPoint(x: x, y: fenceTop - 3), CGPoint(x: x, y: yBack), rgb(0.03, 0.10, 0.08, 0.6), 1.5)
            x += f.width / 7
        }

        // Court surround (green) from the back fence to the bottom of the screen.
        let ground = CGRect(x: 0, y: yBack, width: f.width, height: f.height - yBack)
        Sketch.gradient(&ctx, ground, dk ? [rgb(0.12, 0.32, 0.26), rgb(0.10, 0.26, 0.22), rgb(0.06, 0.16, 0.14)]
                                         : [rgb(0.30, 0.60, 0.44), rgb(0.24, 0.53, 0.38), rgb(0.18, 0.43, 0.31)])

        // The court itself.
        let blueFar = dk ? rgb(0.17, 0.33, 0.60) : rgb(0.28, 0.52, 0.82)
        let blueNear = dk ? rgb(0.10, 0.22, 0.45) : rgb(0.16, 0.38, 0.68)
        var court = Path()
        court.addLines([c.p(-half - 0.8, length + 0.8), c.p(half + 0.8, length + 0.8),
                        c.p(half + 0.8, -5), c.p(-half - 0.8, -5)])
        court.closeSubpath()
        ctx.fill(court, with: .linearGradient(Gradient(colors: [blueFar, blueNear]),
                                              startPoint: CGPoint(x: 0, y: c.y(length)),
                                              endPoint: CGPoint(x: 0, y: c.y(-5))))

        // Floodlight pool at night, warm sun wash by day.
        let pool = CGRect(x: f.center - f.width * 0.8, y: c.y(netD) - f.width * 0.45,
                          width: f.width * 1.6, height: f.width * 0.9)
        ctx.fill(Path(ellipseIn: pool), with: .radialGradient(
            Gradient(colors: [dk ? rgb(0.75, 0.85, 1, 0.22) : rgb(1, 0.98, 0.85, 0.18), .clear]),
            center: CGPoint(x: pool.midX, y: pool.midY), startRadius: 0, endRadius: f.width * 0.8))

        // Lines.
        let lineC = dk ? rgb(0.92, 0.95, 1.0) : .white
        func ln(_ x1: Double, _ d1: Double, _ x2: Double, _ d2: Double) {
            let w = 2.6 / c.z((d1 + d2) / 2)
            Sketch.line(&ctx, c.p(x1, d1), c.p(x2, d2), lineC, w)
        }
        ln(-half, 0, half, 0); ln(-half, length, half, length)
        ln(-half, 0, -half, length); ln(half, 0, half, length)
        ln(-singles, 0, -singles, length); ln(singles, 0, singles, length)
        ln(-singles, serviceNear, singles, serviceNear); ln(-singles, serviceFar, singles, serviceFar)
        ln(0, serviceNear, 0, serviceFar)
        ln(0, 0, 0, 0.3); ln(0, length, 0, length - 0.3)

        // Net: shadow, translucent mesh, white tape. Drawn a bit low so the far court stays visible.
        let yN = c.y(netD)
        let nh = 0.42 * (yN - c.y(length))
        let shadow = CGRect(x: 0, y: yN, width: f.width, height: max(2, nh * 0.35))
        Sketch.gradient(&ctx, shadow, [rgb(0, 0, 0.1, dk ? 0.35 : 0.22), .clear])
        let mesh = CGRect(x: 0, y: yN - nh, width: f.width, height: nh)
        Sketch.fill(&ctx, mesh, rgb(0.04, 0.06, 0.09, 0.55))
        // Mesh: one path for the whole grid (cheap to redraw).
        var grid = Path()
        var gx = 0.0
        let step = max(3.0, nh * 0.32)
        while gx < f.width {
            grid.move(to: CGPoint(x: gx, y: yN - nh)); grid.addLine(to: CGPoint(x: gx, y: yN))
            gx += step
        }
        var gy = yN - nh + step
        while gy < yN {
            grid.move(to: CGPoint(x: 0, y: gy)); grid.addLine(to: CGPoint(x: f.width, y: gy))
            gy += step
        }
        ctx.stroke(grid, with: .color(rgb(0, 0, 0, 0.22)), lineWidth: 0.6)
        Sketch.fill(&ctx, CGRect(x: 0, y: yN - nh - 1.5, width: f.width, height: 3), lineC)
        // center strap
        Sketch.line(&ctx, CGPoint(x: f.center, y: yN - nh), CGPoint(x: f.center, y: yN), lineC, 2)

        // A few balls resting by the back fence, and a soft vignette at the bottom.
        for (bx, bd) in [(-6.3, 24.5), (6.8, 25.2), (7.2, 25.0)] {
            let p = c.p(bx, bd)
            let r = 3.0 / c.z(bd) * 1.6
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - 2 * r, width: 2 * r, height: 2 * r)),
                     with: .color(rgb(0.85, 0.95, 0.25)))
        }
        let vig = CGRect(x: 0, y: f.horizon + 40, width: f.width, height: f.height - f.horizon - 40)
        Sketch.gradient(&ctx, vig, [.clear, rgb(0, 0, 0.05, dk ? 0.35 : 0.15)])
    }

    // On the court, past the net, to the right: inside the far service box.
    static func target(_ f: BackdropFrame) -> CGPoint {
        let c = cam(f)
        let d = 17.6
        return CGPoint(x: f.targetX, y: c.y(d))
    }

    // MARK: - Pieces

    private static func stands(_ ctx: inout GraphicsContext, _ f: BackdropFrame, bottom: Double) {
        let dk = f.dark
        let top = max(bottom * 0.62, bottom - min(70, f.width * 0.17))
        let rows = 7
        let rh = (bottom - top) / Double(rows)
        // Seating bowl: each row a band; slight curve so it reads as a stadium.
        let concrete = dk ? rgb(0.18, 0.19, 0.27) : rgb(0.72, 0.75, 0.80)
        Sketch.fill(&ctx, CGRect(x: 0, y: top - 6, width: f.width, height: bottom - top + 6), concrete)
        let crowd: [Color] = dk
            ? [rgb(0.55, 0.40, 0.45), rgb(0.35, 0.42, 0.60), rgb(0.62, 0.58, 0.45), rgb(0.40, 0.55, 0.50)]
            : [rgb(0.90, 0.45, 0.40), rgb(0.35, 0.50, 0.80), rgb(0.95, 0.85, 0.50), rgb(0.95, 0.95, 0.95), rgb(0.40, 0.65, 0.55)]
        for i in 0..<rows {
            let y = top + Double(i) * rh
            let seat = dk ? rgb(0.15, 0.22, 0.36) : rgb(0.20, 0.42, 0.66)
            Sketch.fill(&ctx, CGRect(x: 0, y: y + rh * 0.35, width: f.width, height: rh * 0.65), seat.opacity(0.9))
            // Crowd: dashed strokes in a few colors, each offset differently. Cheap and busy-looking.
            let dot = max(1.6, rh * 0.42)
            for (k, col) in crowd.enumerated() {
                let gap = dot * Double(crowd.count) * 1.35
                let phase = Double((i * 7 + k * 3) % 11) * dot * 0.9
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y + rh * 0.45)); p.addLine(to: CGPoint(x: f.width, y: y + rh * 0.45))
                ctx.stroke(p, with: .color(col.opacity(dk ? 0.75 : 0.85)),
                           style: StrokeStyle(lineWidth: dot, lineCap: .round, dash: [0.1, gap], dashPhase: phase))
            }
        }
        // Aisles
        for k in 1..<6 {
            let ax = f.width * Double(k) / 6
            Sketch.line(&ctx, CGPoint(x: ax, y: top), CGPoint(x: ax, y: bottom), concrete, max(2, rh * 0.5))
        }
        // Rim and roof edge with flags.
        Sketch.fill(&ctx, CGRect(x: 0, y: top - 8, width: f.width, height: 4), dk ? rgb(0.28, 0.30, 0.40) : rgb(0.93, 0.94, 0.96))
        let flagCols: [Color] = [rgb(0.95, 0.75, 0.25), rgb(0.95, 0.95, 0.98), rgb(0.35, 0.72, 0.55), rgb(0.90, 0.40, 0.35)]
        for k in 0..<4 {
            let fx = f.width * (0.08 + 0.28 * Double(k))
            let base = top - 8
            Sketch.line(&ctx, CGPoint(x: fx, y: base), CGPoint(x: fx, y: base - 22), dk ? rgb(0.6, 0.6, 0.7) : rgb(0.45, 0.45, 0.5), 1.2)
            let wv = sin(f.t * 3 + Double(k)) * 2.5
            poly(&ctx, [CGPoint(x: fx, y: base - 22), CGPoint(x: fx + 14, y: base - 19 + wv),
                        CGPoint(x: fx, y: base - 15)], flagCols[k].opacity(dk ? 0.8 : 1))
        }
        // Soft shade under the roof line, haze in daylight.
        Sketch.gradient(&ctx, CGRect(x: 0, y: top - 4, width: f.width, height: rh * 2), [rgb(0, 0, 0, 0.18), .clear])
        if !dk {
            Sketch.fill(&ctx, CGRect(x: 0, y: top - 8, width: f.width, height: bottom - top + 8), rgb(0.85, 0.92, 1, 0.25))
        }
        // Scoreboard on the left rim (blank panels, no text).
        let sw = f.width * 0.16, sh = sw * 0.42
        let sb = CGRect(x: f.width * 0.13, y: top - 8 - sh - 6, width: sw, height: sh)
        guard sb.minY > 6 else { return }
        ctx.fill(Path(roundedRect: sb, cornerRadius: 3), with: .color(dk ? rgb(0.08, 0.09, 0.12) : rgb(0.16, 0.18, 0.22)))
        for r in 0..<2 {
            for q in 0..<3 {
                let cell = CGRect(x: sb.minX + 5 + Double(q) * (sw - 10) / 3, y: sb.minY + 4 + Double(r) * (sh - 8) / 2,
                                  width: (sw - 10) / 3 - 3, height: (sh - 8) / 2 - 3)
                Sketch.fill(&ctx, cell, (q == 2 ? rgb(1, 0.75, 0.25) : rgb(0.4, 0.85, 0.55)).opacity(dk ? 0.9 : 0.75))
            }
        }
        Sketch.line(&ctx, CGPoint(x: sb.midX, y: sb.maxY), CGPoint(x: sb.midX, y: top - 8), rgb(0.3, 0.3, 0.35), 2)
    }

    private static func floodlights(_ ctx: inout GraphicsContext, _ f: BackdropFrame, base: Double) {
        for side in [-1.0, 1.0] {
            let x = f.center + side * f.width * 0.43
            let top = max(18, base * 0.25)
            Sketch.line(&ctx, CGPoint(x: x, y: base), CGPoint(x: x, y: top + 10), rgb(0.25, 0.27, 0.35), 3)
            let head = CGRect(x: x - 16, y: top, width: 32, height: 12)
            ctx.fill(Path(ellipseIn: head.insetBy(dx: -40, dy: -34)), with: .radialGradient(
                Gradient(colors: [rgb(1, 0.97, 0.85, 0.45), .clear]),
                center: CGPoint(x: head.midX, y: head.midY), startRadius: 0, endRadius: 48))
            Sketch.fill(&ctx, head, rgb(0.20, 0.22, 0.28))
            for i in 0..<4 {
                for j in 0..<2 {
                    let l = CGRect(x: head.minX + 2 + Double(i) * 7.5, y: head.minY + 1.5 + Double(j) * 5, width: 5.5, height: 4)
                    Sketch.fill(&ctx, l, rgb(1, 0.98, 0.88))
                }
            }
        }
    }

    private static func clouds(_ ctx: inout GraphicsContext, _ f: BackdropFrame, maxY: Double) {
        let span = f.width + 240
        for (i, (y0, s, sp)) in [(0.18, 1.0, 4.0), (0.40, 0.7, 2.6), (0.08, 0.55, 3.2)].enumerated() {
            let x = fmod(f.t * sp + Double(i) * span / 3, span) - 120
            let y = maxY * y0 + 20
            let w = 90 * s
            let col = Color.white.opacity(0.85)
            for (dx, dy, r) in [(0.0, 0.0, 0.22), (0.25, -0.12, 0.28), (0.52, -0.02, 0.22), (0.72, 0.04, 0.16)] {
                let rr = w * r
                ctx.fill(Path(ellipseIn: CGRect(x: x + w * dx - rr, y: y + w * dy - rr, width: rr * 2, height: rr * 2)), with: .color(col))
            }
            ctx.fill(Path(roundedRect: CGRect(x: x - w * 0.18, y: y, width: w * 1.05, height: w * 0.16), cornerRadius: w * 0.08), with: .color(col))
        }
    }

    private static func stars(_ ctx: inout GraphicsContext, _ f: BackdropFrame, maxY: Double) {
        for i in 0..<28 {
            let a = Double(i)
            let x = fmod(a * 0.618034 * f.width * 1.7, f.width)
            let y = fmod(a * a * 13.7 + a * 31, max(20, maxY))
            let tw = 0.55 + 0.45 * sin(f.t * 1.3 + a)
            let r = (i % 4 == 0) ? 1.4 : 0.9
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.6 * tw)))
        }
        let mx = f.width * 0.5, my = max(28, maxY * 0.35)
        ctx.fill(Path(ellipseIn: CGRect(x: mx - 30, y: my - 30, width: 60, height: 60)),
                 with: .radialGradient(Gradient(colors: [rgb(1, 0.95, 0.85, 0.25), .clear]), center: CGPoint(x: mx, y: my), startRadius: 8, endRadius: 30))
        ctx.fill(Path(ellipseIn: CGRect(x: mx - 10, y: my - 10, width: 20, height: 20)), with: .color(rgb(0.98, 0.95, 0.85)))
    }
}
