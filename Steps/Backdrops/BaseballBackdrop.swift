import SwiftUI

// Baseball: the view from behind home plate (the mini-me is the batter). Dirt infield and bases
// in perspective, striped outfield, padded wall with distance numbers, bleachers, light towers.
// Night = a game under the lights.
enum BaseballBackdrop {
    // Ground perspective. X and d in meters (d = distance out from home plate).
    private struct Cam {
        let cx: Double, vy: Double, hp: Double, m: Double, z0: Double
        func z(_ d: Double) -> Double { max(0.05, 1 + d / z0) }
        func y(_ d: Double) -> Double { vy + hp / z(d) }
        func p(_ x: Double, _ d: Double) -> CGPoint { CGPoint(x: cx + x * m / z(d), y: y(d)) }
    }

    private static func cam(_ f: BackdropFrame) -> Cam {
        let hp = min(0.58 * f.horizon, 0.40 * f.width)
        return Cam(cx: f.center, vy: f.horizon - hp, hp: hp, m: 0.028 * f.width, z0: 30)
    }

    // Outfield fence distance (meters) for an angle off the center line (radians, ±π/4 = foul poles).
    private static func fence(_ a: Double) -> Double { 99 + 23 * cos(2 * a) }
    private static func fencePt(_ c: Cam, _ a: Double, inset: Double = 0) -> CGPoint {
        let r = fence(a) - inset
        return c.p(r * sin(a), r * cos(a))
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }

    private static func shape(_ pts: [CGPoint]) -> Path {
        var p = Path(); p.addLines(pts); p.closeSubpath(); return p
    }

    // Circle on the ground, in perspective.
    private static func groundCircle(_ c: Cam, _ x: Double, _ d: Double, _ r: Double) -> Path {
        shape((0..<40).map { i -> CGPoint in
            let a = Double(i) / 40 * 2 * .pi
            return c.p(x + r * cos(a), d + r * sin(a))
        })
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let c = cam(f)
        let dk = f.dark
        let wallH = max(9, 0.03 * f.width)
        let wallBase = c.y(fence(0))
        let wallTop = wallBase - wallH
        let standsTop = max(wallTop * 0.55, wallTop - min(64, f.width * 0.15))

        // Sky
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: f.width, height: wallBase + 2), dk
            ? [rgb(0.05, 0.07, 0.19), rgb(0.16, 0.17, 0.36), rgb(0.40, 0.28, 0.42)]
            : [rgb(0.33, 0.60, 0.93), rgb(0.60, 0.80, 0.98), rgb(0.88, 0.95, 1.0)])
        if dk { stars(&ctx, f, maxY: standsTop) } else { clouds(&ctx, f, maxY: standsTop) }

        lightTowers(&ctx, f, base: standsTop + 10, top: max(14, standsTop * 0.3))
        bleachers(&ctx, f, top: standsTop, bottom: wallTop + 1)

        // All the ground: grass from the wall down to the bottom of the screen.
        let grassFar = dk ? rgb(0.16, 0.42, 0.24) : rgb(0.36, 0.66, 0.34)
        let grassNear = dk ? rgb(0.08, 0.26, 0.14) : rgb(0.22, 0.50, 0.24)
        Sketch.gradient(&ctx, CGRect(x: 0, y: wallTop, width: f.width, height: f.height - wallTop), [grassFar, grassNear])

        let n = 28
        // Mowing stripes across all the grass (fair and foul), in perspective.
        let zBottom = c.hp / max(1, f.height - c.vy)
        var d = floor((zBottom - 1) * c.z0 / 6) * 6, k = Int(d / 6)
        while d < 125 {
            if k % 2 == 0 {
                let y0 = c.y(d + 6), y1 = min(f.height, c.y(d))
                Sketch.fill(&ctx, CGRect(x: 0, y: y0, width: f.width, height: y1 - y0), .white.opacity(dk ? 0.04 : 0.07))
            }
            d += 6; k += 1
        }

        // Warning track along the wall.
        let track = (0...n).map { fencePt(c, -.pi / 4 + Double($0) / Double(n) * .pi / 2) }
            + (0...n).reversed().map { fencePt(c, -.pi / 4 + Double($0) / Double(n) * .pi / 2, inset: 5) }
        let dirt = dk ? rgb(0.48, 0.32, 0.22) : rgb(0.78, 0.56, 0.38)
        let dirtDark = dk ? rgb(0.40, 0.26, 0.18) : rgb(0.68, 0.47, 0.31)
        ctx.fill(shape(track), with: .color(dirtDark))

        // Wall: padded panels, yellow top line, distance numbers.
        var wall = Path()
        let top = (0...n).map { i -> CGPoint in
            let p = fencePt(c, -.pi / 4 + Double(i) / Double(n) * .pi / 2); return CGPoint(x: p.x, y: p.y - wallH)
        }
        wall.addLines((0...n).map { fencePt(c, -.pi / 4 + Double($0) / Double(n) * .pi / 2) } + top.reversed())
        wall.closeSubpath()
        ctx.fill(wall, with: .color(dk ? rgb(0.06, 0.24, 0.18) : rgb(0.10, 0.36, 0.26)))
        for i in 1..<n where i % 2 == 0 {
            let p = fencePt(c, -.pi / 4 + Double(i) / Double(n) * .pi / 2)
            Sketch.line(&ctx, CGPoint(x: p.x, y: p.y - wallH + 1), CGPoint(x: p.x, y: p.y), .black.opacity(0.18), 1)
        }
        var rail = Path(); rail.addLines(top)
        ctx.stroke(rail, with: .color(rgb(0.98, 0.80, 0.20)), lineWidth: 2)
        for (a, label) in [(-0.62, "330"), (-0.3, "375"), (0.3, "375"), (0.62, "330")] {
            let p = fencePt(c, a)
            ctx.draw(Text(label).font(.system(size: wallH * 0.62, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.92)), at: CGPoint(x: p.x, y: p.y - wallH * 0.48))
        }
        // Foul poles
        for s in [-1.0, 1.0] {
            let p = fencePt(c, s * .pi / 4)
            Sketch.line(&ctx, CGPoint(x: p.x, y: p.y), CGPoint(x: p.x, y: p.y - wallH * 4.5), rgb(0.98, 0.82, 0.22), 2.2)
        }

        // Infield dirt: arc 29 m from the mound, between the foul lines.
        let phi0 = asin(27.5 / 29)
        var arc: [CGPoint] = [c.p(-1.5, -1.5)]
        for i in 0...20 {
            let a = -phi0 + Double(i) / 20 * 2 * phi0
            arc.append(c.p(29 * sin(a), 18.4 + 29 * cos(a)))
        }
        arc.append(c.p(1.5, -1.5))
        ctx.fill(shape(arc), with: .color(dirt))
        // Infield grass diamond.
        let grassIn = dk ? rgb(0.13, 0.38, 0.21) : rgb(0.33, 0.63, 0.31)
        ctx.fill(shape([c.p(0, 1.8), c.p(17.6, 19.4), c.p(0, 37.2), c.p(-17.6, 19.4)]), with: .color(grassIn))
        // Mound and the circle around home.
        ctx.fill(groundCircle(c, 0, 18.4, 2.8), with: .color(dirt))
        ctx.fill(groundCircle(c, 0, 18.4, 0.5), with: .color(.white.opacity(0.85)))
        ctx.fill(groundCircle(c, 0, 0, 4.2), with: .color(dirt))

        // Chalk: foul lines, batter's boxes, bases, home plate.
        let chalk = Color.white.opacity(dk ? 0.85 : 0.95)
        for s in [-1.0, 1.0] {
            let pole = fencePt(c, s * .pi / 4)
            Sketch.line(&ctx, c.p(s * 0.3, 0.3), pole, chalk, 1.6)
            var box = Path()
            box.addLines([c.p(s * 0.45, -0.9), c.p(s * 1.65, -0.9), c.p(s * 1.65, 0.9), c.p(s * 0.45, 0.9)])
            box.closeSubpath()
            ctx.stroke(box, with: .color(chalk), lineWidth: 1.4)
        }
        for (bx, bd) in [(19.4, 19.4), (0.0, 38.8), (-19.4, 19.4)] {
            let b = 0.95
            ctx.fill(shape([c.p(bx, bd - b), c.p(bx + b, bd), c.p(bx, bd + b), c.p(bx - b, bd)]), with: .color(.white))
        }
        ctx.fill(shape([c.p(-0.22, 0.22), c.p(0.22, 0.22), c.p(0.22, -0.05), c.p(0, -0.25), c.p(-0.22, -0.05)]), with: .color(.white))

        // Light wash: a night pool from the towers, warm sun by day.
        let pool = CGRect(x: f.center - f.width, y: wallTop - 40, width: f.width * 2, height: f.horizon - wallTop + 160)
        ctx.fill(Path(ellipseIn: pool), with: .radialGradient(
            Gradient(colors: [dk ? rgb(0.85, 0.92, 1, 0.16) : rgb(1, 0.97, 0.80, 0.12), .clear]),
            center: CGPoint(x: pool.midX, y: pool.midY), startRadius: 0, endRadius: f.width))
        let vig = CGRect(x: 0, y: f.horizon + 40, width: f.width, height: f.height - f.horizon - 40)
        Sketch.gradient(&ctx, vig, [.clear, rgb(0, 0.03, 0, dk ? 0.35 : 0.15)])
    }

    // MARK: - Pieces

    private static func bleachers(_ ctx: inout GraphicsContext, _ f: BackdropFrame, top: Double, bottom: Double) {
        let dk = f.dark
        let rows = 6
        let rh = (bottom - top) / Double(rows)
        let concrete = dk ? rgb(0.18, 0.19, 0.27) : rgb(0.74, 0.76, 0.80)
        Sketch.fill(&ctx, CGRect(x: 0, y: top - 5, width: f.width, height: bottom - top + 5), concrete)
        let crowd: [Color] = dk
            ? [rgb(0.58, 0.42, 0.45), rgb(0.35, 0.42, 0.62), rgb(0.62, 0.58, 0.45), rgb(0.45, 0.55, 0.52)]
            : [rgb(0.92, 0.42, 0.38), rgb(0.30, 0.45, 0.80), rgb(0.97, 0.86, 0.48), rgb(0.97, 0.97, 0.97), rgb(0.40, 0.66, 0.55)]
        for i in 0..<rows {
            let y = top + Double(i) * rh
            Sketch.fill(&ctx, CGRect(x: 0, y: y + rh * 0.35, width: f.width, height: rh * 0.65),
                        dk ? rgb(0.30, 0.16, 0.20) : rgb(0.66, 0.24, 0.24))
            let dot = max(1.5, rh * 0.42)
            for (k, col) in crowd.enumerated() {
                let gap = dot * Double(crowd.count) * 1.4
                let phase = Double((i * 5 + k * 3) % 11) * dot * 0.9
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y + rh * 0.45)); p.addLine(to: CGPoint(x: f.width, y: y + rh * 0.45))
                ctx.stroke(p, with: .color(col.opacity(dk ? 0.75 : 0.85)),
                           style: StrokeStyle(lineWidth: dot, lineCap: .round, dash: [0.1, gap], dashPhase: phase))
            }
        }
        if !dk { Sketch.fill(&ctx, CGRect(x: 0, y: top - 5, width: f.width, height: bottom - top + 5), rgb(0.85, 0.92, 1, 0.22)) }
        // Batter's eye: plain dark block in center field (sits behind the mini-me's head).
        let be = CGRect(x: f.center - f.width * 0.13, y: top - 3, width: f.width * 0.26, height: bottom - top + 3)
        Sketch.fill(&ctx, be, dk ? rgb(0.05, 0.14, 0.12) : rgb(0.12, 0.30, 0.24))
        Sketch.fill(&ctx, CGRect(x: 0, y: top - 7, width: f.width, height: 3), dk ? rgb(0.30, 0.32, 0.42) : rgb(0.94, 0.95, 0.97))
        // Pennants along the top, flapping.
        let cols: [Color] = [rgb(0.95, 0.35, 0.30), rgb(0.97, 0.97, 0.97), rgb(0.25, 0.45, 0.85)]
        var x = f.width * 0.03
        var k = 0
        while x < f.width {
            if abs(x - f.center) > f.width * 0.16 {
                let w = sin(f.t * 2.5 + x * 0.05) * 1.5
                var p = Path()
                p.addLines([CGPoint(x: x, y: top - 7), CGPoint(x: x + 9, y: top - 7), CGPoint(x: x + 4.5 + w, y: top + 2)])
                p.closeSubpath()
                ctx.fill(p, with: .color(cols[k % 3].opacity(dk ? 0.75 : 1)))
            }
            x += f.width * 0.055; k += 1
        }
    }

    private static func lightTowers(_ ctx: inout GraphicsContext, _ f: BackdropFrame, base: Double, top: Double) {
        let dk = f.dark
        for s in [-1.0, 1.0] {
            let x = f.center + s * f.width * 0.39
            let pole = dk ? rgb(0.25, 0.27, 0.36) : rgb(0.55, 0.58, 0.64)
            Sketch.line(&ctx, CGPoint(x: x - 3, y: base), CGPoint(x: x, y: top + 14), pole, 2.5)
            Sketch.line(&ctx, CGPoint(x: x + 3, y: base), CGPoint(x: x, y: top + 14), pole, 2.5)
            let head = CGRect(x: x - 20, y: top, width: 40, height: 16)
            if dk {
                ctx.fill(Path(ellipseIn: head.insetBy(dx: -46, dy: -40)), with: .radialGradient(
                    Gradient(colors: [rgb(1, 0.97, 0.85, 0.42), .clear]),
                    center: CGPoint(x: head.midX, y: head.midY), startRadius: 0, endRadius: 58))
            }
            ctx.fill(Path(roundedRect: head, cornerRadius: 2), with: .color(dk ? rgb(0.18, 0.20, 0.26) : rgb(0.42, 0.45, 0.52)))
            for i in 0..<5 {
                for j in 0..<2 {
                    let l = CGRect(x: head.minX + 2 + Double(i) * 7.4, y: head.minY + 2 + Double(j) * 6.5, width: 5.6, height: 5)
                    Sketch.fill(&ctx, l, dk ? rgb(1, 0.98, 0.88) : rgb(0.88, 0.90, 0.94))
                }
            }
        }
    }

    private static func clouds(_ ctx: inout GraphicsContext, _ f: BackdropFrame, maxY: Double) {
        let span = f.width + 240
        for (i, (y0, s, sp)) in [(0.30, 1.0, 4.0), (0.62, 0.7, 2.6), (0.12, 0.55, 3.2)].enumerated() {
            let x = fmod(f.t * sp + Double(i) * span / 3, span) - 120
            let y = maxY * y0 + 12
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
        for i in 0..<26 {
            let a = Double(i)
            let x = fmod(a * 0.618034 * f.width * 1.7, f.width)
            let y = fmod(a * a * 13.7 + a * 31, max(20, maxY))
            let tw = 0.55 + 0.45 * sin(f.t * 1.3 + a)
            let r = (i % 4 == 0) ? 1.4 : 0.9
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.6 * tw)))
        }
    }
}
