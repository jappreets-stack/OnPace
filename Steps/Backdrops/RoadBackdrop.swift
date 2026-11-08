import SwiftUI

// Open country road: patchwork fields, rolling hills, power-line poles, and a green distance sign
// on the right. The road curves away over a low rise to the left; the mini-me jogs on it.
enum RoadBackdrop {
    private typealias RGB = (Double, Double, Double)

    private static func col(_ f: BackdropFrame, _ day: RGB, _ night: RGB, _ a: Double = 1) -> Color {
        let c = f.dark ? night : day
        return Color(red: c.0, green: c.1, blue: c.2).opacity(a)
    }

    private static func mix(_ a: RGB, _ b: RGB, _ k: Double) -> RGB {
        let k = min(max(k, 0), 1)
        return (a.0 + (b.0 - a.0) * k, a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k)
    }

    private static func rgb(_ c: RGB, _ a: Double = 1) -> Color { Color(red: c.0, green: c.1, blue: c.2).opacity(a) }

    private static func rnd(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - floor(x)
    }

    // MARK: Road geometry

    // Where the far land meets the sky; the road vanishes here.
    private static func landTop(_ f: BackdropFrame) -> Double { f.horizon - 30 }
    private static func vanishX(_ f: BackdropFrame) -> Double { f.center - f.width * 0.20 }

    // Center of the road at height y (straight under the mini-me, bending left into the distance).
    private static func roadX(_ f: BackdropFrame, _ y: Double) -> Double {
        if y >= f.horizon { let d = y - f.horizon; return f.center - d * d / (d + 120) * 0.45 }
        let u = (f.horizon - y) / (f.horizon - landTop(f))
        return f.center + (vanishX(f) - f.center) * u * u
    }

    // Half the road width at height y (55 pt where the mini-me stands).
    private static func halfWidth(_ f: BackdropFrame, _ y: Double) -> Double {
        let u = (y - landTop(f)) / (f.horizon - landTop(f))
        // True perspective up to the mini-me, then a gentler spread so the foreground keeps some fields.
        return u <= 1 ? 55 * u : 55 * pow(u, 0.5)
    }

    // A strip running along the road between two side offsets (in road half-widths).
    private static func strip(_ f: BackdropFrame, _ a: Double, _ b: Double, from d0: Double = 0.3) -> Path {
        let top = landTop(f)
        let dMax = f.height - top + 10
        var ys: [Double] = []
        var d = d0
        while d < dMax { ys.append(top + d); d *= 1.18 }
        ys.append(top + dMax)
        var p = Path()
        for (i, y) in ys.enumerated() {
            let pt = CGPoint(x: roadX(f, y) + a * halfWidth(f, y), y: y)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        for y in ys.reversed() { p.addLine(to: CGPoint(x: roadX(f, y) + b * halfWidth(f, y), y: y)) }
        p.closeSubpath()
        return p
    }

    // MARK: Public API

    // The green panel on the sign post (no text: the app writes "1 km" / "1 mi" on it).
    static func signRect(_ f: BackdropFrame) -> CGRect {
        let w = 74.0, h = 44.0
        return CGRect(x: f.targetX - w / 2 + 6, y: f.horizon - 78 - h, width: w, height: h)
    }

    // Base of the sign post, on the ground.
    private static func target(_ f: BackdropFrame) -> CGPoint { CGPoint(x: f.targetX, y: f.horizon) }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        drawSky(&ctx, f)
        drawHills(&ctx, f)
        drawFields(&ctx, f)
        drawFarStuff(&ctx, f)
        drawRoad(&ctx, f)
        drawPoles(&ctx, f)
        drawNearTrees(&ctx, f)
        drawSign(&ctx, f)
    }

    // MARK: Sky

    private static func drawSky(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = landTop(f)
        let r = CGRect(x: 0, y: 0, width: f.width, height: top + 2)
        let colors: [Color] = f.dark
            ? [rgb((0.04, 0.06, 0.17)), rgb((0.13, 0.15, 0.33)), rgb((0.36, 0.29, 0.47)), rgb((0.62, 0.42, 0.45))]
            : [rgb((0.30, 0.58, 0.92)), rgb((0.52, 0.75, 0.97)), rgb((0.82, 0.92, 0.99)), rgb((0.99, 0.95, 0.86))]
        ctx.fill(Path(r), with: .linearGradient(Gradient(colors: colors),
                                                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: top)))

        // Sun (day) or moon (night), up and to the left.
        let sx = f.width * 0.17, sy = max(54, top * 0.36)
        if f.dark {
            for i in 0..<46 {
                let x = rnd(i, 1) * f.width
                let y = pow(rnd(i, 2), 1.4) * top * 0.78
                let s = 0.8 + rnd(i, 3) * 1.6
                let tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(f.t * (0.8 + rnd(i, 4) * 1.6) + Double(i)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                         with: .color(.white.opacity(0.85 * tw)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 46, y: sy - 46, width: 92, height: 92)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.28), .white.opacity(0)]),
                                           center: CGPoint(x: sx, y: sy), startRadius: 10, endRadius: 46))
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 16, y: sy - 16, width: 32, height: 32)),
                     with: .color(rgb((0.97, 0.95, 0.86))))
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 8, y: sy - 6, width: 7, height: 7)), with: .color(rgb((0.86, 0.84, 0.76))))
            ctx.fill(Path(ellipseIn: CGRect(x: sx + 3, y: sy + 4, width: 5, height: 5)), with: .color(rgb((0.86, 0.84, 0.76))))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 70, y: sy - 70, width: 140, height: 140)),
                     with: .radialGradient(Gradient(colors: [rgb((1, 0.97, 0.80), 0.75), rgb((1, 0.95, 0.80), 0)]),
                                           center: CGPoint(x: sx, y: sy), startRadius: 14, endRadius: 70))
            ctx.fill(Path(ellipseIn: CGRect(x: sx - 20, y: sy - 20, width: 40, height: 40)), with: .color(rgb((1, 0.96, 0.74))))
        }

        // Drifting clouds.
        let span = f.width + 240
        let clouds: [(Double, Double, Double, Double)] = [(0.10, 0.20, 1.0, 3.0), (0.55, 0.12, 0.75, 2.2), (0.85, 0.40, 0.6, 1.6)]
        for (i, c) in clouds.enumerated() {
            let x = (c.0 * span + f.t * c.3).truncatingRemainder(dividingBy: span) - 120
            let y = max(40, top * c.1 + 30)
            cloud(&ctx, f, x, y, 34 * c.2, seed: i)
        }
    }

    private static func cloud(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ x: Double, _ y: Double, _ s: Double, seed: Int) {
        let puffs: [(Double, Double, Double)] = [(-1.05, 0.15, 0.50), (-0.45, -0.22, 0.72), (0.30, -0.40, 0.88), (1.0, 0.02, 0.58), (0.0, 0.18, 0.62)]
        let shade = col(f, (0.80, 0.86, 0.95), (0.30, 0.30, 0.48), f.dark ? 0.55 : 0.9)
        let light = col(f, (1, 1, 1), (0.48, 0.46, 0.64), f.dark ? 0.6 : 0.95)
        for p in puffs {
            let r = s * p.2
            ctx.fill(Path(ellipseIn: CGRect(x: x + p.0 * s - r, y: y + p.1 * s - r + s * 0.12, width: r * 2, height: r * 2)), with: .color(shade))
        }
        for p in puffs {
            let r = s * p.2 * 0.92
            ctx.fill(Path(ellipseIn: CGRect(x: x + p.0 * s - r, y: y + p.1 * s - r, width: r * 2, height: r * 2)), with: .color(light))
        }
    }

    // MARK: Hills and fields

    private static func ridge(_ f: BackdropFrame, base: Double, amp: Double, k1: Double, k2: Double, ph: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: base + 4))
        let n = 40
        for i in 0...n {
            let x = f.width * Double(i) / Double(n)
            let u = x / f.width
            let y = base - amp * (0.6 + 0.25 * sin(u * k1 + ph) + 0.15 * sin(u * k2 + ph * 2.3))
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: f.width, y: base + 4))
        p.closeSubpath()
        return p
    }

    private static func drawHills(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = landTop(f)
        ctx.fill(ridge(f, base: top, amp: 62, k1: 5.2, k2: 11, ph: 0.4),
                 with: .color(col(f, (0.66, 0.78, 0.86), (0.25, 0.25, 0.42))))
        ctx.fill(ridge(f, base: top, amp: 36, k1: 7.5, k2: 17, ph: 2.1),
                 with: .linearGradient(Gradient(colors: [col(f, (0.55, 0.72, 0.52), (0.17, 0.24, 0.32)),
                                                         col(f, (0.62, 0.77, 0.56), (0.20, 0.26, 0.34))]),
                                       startPoint: CGPoint(x: 0, y: top - 36), endPoint: CGPoint(x: 0, y: top)))
        // A tree line along the far ridge.
        for i in 0..<34 {
            let x = rnd(i, 7) * f.width
            let r = 2.5 + rnd(i, 8) * 2.5
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: top - r * 1.6, width: r * 2, height: r * 2.2)),
                     with: .color(col(f, (0.36, 0.55, 0.36), (0.12, 0.18, 0.25))))
        }
    }

    private static func drawFields(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = landTop(f)
        let vx = vanishX(f)
        Sketch.fill(&ctx, CGRect(x: 0, y: top, width: f.width, height: f.height - top), col(f, (0.42, 0.66, 0.30), (0.10, 0.20, 0.20)))

        // Patchwork: depth rows × wedges from the vanishing point.
        let rows: [Double] = [1.5, 4, 8, 13, 20, 30, 48, 85, 150, 260, 2000]
        let slopes: [Double] = [-400, -14, -5, -2.2, 0.0, 2.6, 6.5, 12, 400]
        let day: [RGB] = [(0.52, 0.74, 0.33), (0.85, 0.75, 0.40), (0.42, 0.67, 0.30), (0.66, 0.78, 0.36), (0.78, 0.68, 0.38), (0.36, 0.60, 0.28)]
        let night: [RGB] = [(0.11, 0.22, 0.22), (0.24, 0.24, 0.25), (0.09, 0.19, 0.20), (0.15, 0.24, 0.22), (0.21, 0.21, 0.24), (0.08, 0.17, 0.19)]
        let hazeD: RGB = (0.72, 0.82, 0.78), hazeN: RGB = (0.24, 0.26, 0.38)
        for r in 0..<(rows.count - 1) {
            let d0 = rows[r], d1 = rows[r + 1]
            let haze = 1 - min(1, (d0 + d1) / 2 / 34)
            for c in 0..<(slopes.count - 1) {
                let idx = Int(rnd(r * 13 + c, 5) * 6) % 6
                let base = f.dark ? night[idx] : day[idx]
                let tone = mix(base, f.dark ? hazeN : hazeD, haze * 0.75)
                var p = Path()
                p.move(to: CGPoint(x: vx + slopes[c] * d0, y: top + d0))
                p.addLine(to: CGPoint(x: vx + slopes[c + 1] * d0, y: top + d0))
                p.addLine(to: CGPoint(x: vx + slopes[c + 1] * d1, y: top + d1))
                p.addLine(to: CGPoint(x: vx + slopes[c] * d1, y: top + d1))
                p.closeSubpath()
                ctx.fill(p, with: .color(rgb(tone)))
                // Crop rows on the golden fields.
                if idx == 1 || idx == 4, d1 < 200 {
                    for k in 1..<4 {
                        let s = slopes[c] + (slopes[c + 1] - slopes[c]) * Double(k) / 4
                        if abs(s) > 60 { continue }
                        Sketch.line(&ctx, CGPoint(x: vx + s * d0, y: top + d0), CGPoint(x: vx + s * d1, y: top + d1),
                                    rgb(mix(tone, (0.5, 0.4, 0.2), 0.25), 0.6), max(0.6, d1 / 40))
                    }
                }
            }
            // Hedgerow along each field boundary.
            if r > 0 && r < 9 {
                let y = top + d0
                Sketch.line(&ctx, CGPoint(x: 0, y: y), CGPoint(x: f.width, y: y),
                            col(f, (0.30, 0.50, 0.26), (0.07, 0.14, 0.16), 0.7), max(1, d0 / 9))
            }
        }
        // Soft light fading the far fields into the haze.
        Sketch.gradient(&ctx, CGRect(x: 0, y: top, width: f.width, height: 22),
                        [col(f, (0.85, 0.90, 0.88), (0.36, 0.31, 0.46), 0.6), col(f, (0.85, 0.90, 0.88), (0.36, 0.31, 0.46), 0)])
    }

    private static func tree(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ x: Double, _ y: Double, _ s: Double) {
        ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.7, y: y - s * 0.12, width: s * 1.4, height: s * 0.24)), with: .color(.black.opacity(0.15)))
        Sketch.fill(&ctx, CGRect(x: x - s * 0.07, y: y - s * 0.55, width: s * 0.14, height: s * 0.55), col(f, (0.45, 0.32, 0.22), (0.15, 0.13, 0.16)))
        let dark = col(f, (0.24, 0.48, 0.24), (0.06, 0.15, 0.17))
        let mid = col(f, (0.33, 0.60, 0.28), (0.09, 0.21, 0.22))
        let hi = col(f, (0.50, 0.74, 0.36), (0.15, 0.29, 0.30))
        ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.5, y: y - s * 1.15, width: s, height: s * 0.75)), with: .color(dark))
        ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.42, y: y - s * 1.28, width: s * 0.8, height: s * 0.7)), with: .color(mid))
        ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.30, y: y - s * 1.22, width: s * 0.36, height: s * 0.3)), with: .color(hi))
    }

    private static func drawFarStuff(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = landTop(f)
        // Barn on the left, far away.
        let bx = f.width * 0.10, by = top + 11, s = 15.0
        Sketch.fill(&ctx, CGRect(x: bx, y: by - s, width: s * 1.3, height: s), col(f, (0.72, 0.22, 0.18), (0.28, 0.14, 0.18)))
        var roof = Path()
        roof.move(to: CGPoint(x: bx - 2, y: by - s)); roof.addLine(to: CGPoint(x: bx + s * 0.65, y: by - s * 1.6))
        roof.addLine(to: CGPoint(x: bx + s * 1.3 + 2, y: by - s)); roof.closeSubpath()
        ctx.fill(roof, with: .color(col(f, (0.42, 0.20, 0.18), (0.16, 0.10, 0.14))))
        Sketch.fill(&ctx, CGRect(x: bx + s * 0.45, y: by - s * 0.6, width: s * 0.4, height: s * 0.6),
                    f.dark ? rgb((1, 0.82, 0.45)) : rgb((0.96, 0.92, 0.86)))
        // Silo.
        Sketch.fill(&ctx, CGRect(x: bx + s * 1.45, y: by - s * 1.5, width: s * 0.45, height: s * 1.5), col(f, (0.80, 0.80, 0.78), (0.30, 0.30, 0.38)))
        ctx.fill(Path(ellipseIn: CGRect(x: bx + s * 1.45, y: by - s * 1.72, width: s * 0.45, height: s * 0.45)), with: .color(col(f, (0.70, 0.70, 0.72), (0.26, 0.26, 0.34))))

        // A few small trees in the fields.
        let spots: [(Double, Double, Double)] = [(0.30, 6, 8), (0.36, 6.5, 7), (0.70, 9, 11), (0.92, 14, 15), (0.04, 20, 20)]
        for s in spots where abs(s.0 * f.width - f.center) > 60 || s.1 < 8 {
            tree(&ctx, f, s.0 * f.width, top + s.1, s.2)
        }
    }

    // MARK: Road

    private static func drawRoad(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = landTop(f)
        ctx.fill(strip(f, -1.18, 1.18), with: .color(col(f, (0.80, 0.72, 0.55), (0.26, 0.25, 0.30))))
        ctx.fill(strip(f, -1, 1), with: .linearGradient(
            Gradient(colors: [col(f, (0.62, 0.64, 0.68), (0.25, 0.26, 0.34)), col(f, (0.36, 0.37, 0.41), (0.13, 0.14, 0.19))]),
            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: f.horizon + 160)))
        let edge = col(f, (0.96, 0.96, 0.94), (0.70, 0.72, 0.78), 0.9)
        ctx.fill(strip(f, 0.86, 0.92, from: 1.5), with: .color(edge))
        ctx.fill(strip(f, -0.92, -0.86, from: 1.5), with: .color(edge))

        // Dashed yellow center line in perspective, scrolling toward you as the mini-me jogs.
        // Depth z = 1 at the mini-me's feet; matches the road's width curve on both sides of that.
        let k = f.horizon - top
        func yAt(_ z: Double) -> Double { z >= 1 ? top + k / z : top + k / (z * z) }
        let period = 0.55, dash = 0.24
        let phase = (f.t * 0.45).truncatingRemainder(dividingBy: period)
        let yellow = col(f, (0.98, 0.82, 0.25), (0.85, 0.72, 0.30))
        var z = 0.12 - phase
        while z < 12 {
            let z0 = max(z, 0.12)
            let yNear = yAt(z0), yFar = yAt(z + dash)
            if z + dash > 0.12, yNear - yFar > 0.5, yFar < f.height {
                let wN = halfWidth(f, yNear) * 0.035, wF = halfWidth(f, yFar) * 0.035
                var p = Path()
                p.move(to: CGPoint(x: roadX(f, yFar) - wF, y: yFar))
                p.addLine(to: CGPoint(x: roadX(f, yFar) + wF, y: yFar))
                p.addLine(to: CGPoint(x: roadX(f, yNear) + wN, y: yNear))
                p.addLine(to: CGPoint(x: roadX(f, yNear) - wN, y: yNear))
                p.closeSubpath()
                ctx.fill(p, with: .color(yellow))
            }
            z += period
        }
    }

    // MARK: Power-line poles (left of the road, receding)

    private static func drawPoles(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = landTop(f)
        let k = f.horizon - top
        var tops: [(CGPoint, CGPoint)] = []
        let wood = col(f, (0.42, 0.30, 0.22), (0.12, 0.11, 0.15))
        for i in stride(from: 6, through: -2, by: -1) {
            let d = k / pow(1.55, Double(i))
            let y = top + d
            if y > f.height { continue }
            let hw = halfWidth(f, y)
            let x = roadX(f, y) - hw * 1.7
            let h = hw * 1.75
            let w = max(1, hw * 0.05)
            let cross = hw * 0.32
            if x < -cross - 10 { continue }
            ctx.fill(Path(ellipseIn: CGRect(x: x - w * 3, y: y - w * 0.6, width: w * 6, height: w * 1.2)), with: .color(.black.opacity(0.15)))
            Sketch.fill(&ctx, CGRect(x: x - w / 2, y: y - h, width: w, height: h), wood)
            Sketch.fill(&ctx, CGRect(x: x - cross, y: y - h * 0.9, width: cross * 2, height: max(0.8, w * 0.8)), wood)
            tops.append((CGPoint(x: x - cross * 0.85, y: y - h * 0.9), CGPoint(x: x + cross * 0.85, y: y - h * 0.9)))
        }
        let wire = col(f, (0.20, 0.20, 0.22), (0.05, 0.05, 0.08), 0.55)
        for j in 1..<max(1, tops.count) where tops.count > 1 {
            for side in 0..<2 {
                let a = side == 0 ? tops[j - 1].0 : tops[j - 1].1
                let b = side == 0 ? tops[j].0 : tops[j].1
                var p = Path()
                p.move(to: a)
                let sag = abs(b.x - a.x) * 0.06 + abs(b.y - a.y) * 0.4
                p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + sag))
                ctx.stroke(p, with: .color(wire), lineWidth: 0.8)
            }
        }
    }

    private static func drawNearTrees(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        // Grass tufts beside the road in the foreground.
        let tuft = col(f, (0.30, 0.52, 0.22), (0.06, 0.14, 0.15), 0.8)
        for i in 0..<40 {
            let y = f.horizon + 12 + pow(rnd(i, 21), 1.7) * (f.height - f.horizon)
            let x = rnd(i, 23) * f.width
            if abs(x - roadX(f, y)) < halfWidth(f, y) * 1.3 + 6 { continue }
            if abs(x - f.targetX) < 30 && y < f.horizon + 14 { continue }
            let s = 3 + (y - f.horizon) * 0.03
            for j in -1...1 {
                Sketch.line(&ctx, CGPoint(x: x + Double(j) * s * 0.4, y: y), CGPoint(x: x + Double(j) * s * 0.9, y: y - s * (j == 0 ? 1.6 : 1.1)), tuft, max(1, s * 0.22))
            }
        }
        // One big tree behind the sign on the far right, one on the near left edge.
        tree(&ctx, f, f.width * 0.97, f.horizon - 6, 50)
    }

    // MARK: Distance sign

    private static func drawSign(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let r = signRect(f)
        let base = target(f)
        // Ground shadow.
        ctx.fill(Path(ellipseIn: CGRect(x: base.x - 10, y: base.y - 3, width: 44, height: 7)), with: .color(.black.opacity(0.18)))
        // Post.
        let post = CGRect(x: base.x - 2.5, y: r.maxY - 4, width: 5, height: base.y - r.maxY + 4)
        Sketch.fill(&ctx, post, col(f, (0.62, 0.64, 0.66), (0.34, 0.36, 0.42)))
        Sketch.fill(&ctx, CGRect(x: post.minX, y: post.minY, width: 1.6, height: post.height), col(f, (0.85, 0.86, 0.88), (0.50, 0.52, 0.58)))
        // Panel with a soft shadow, white border, slight top highlight.
        var sh = ctx
        sh.addFilter(.shadow(color: .black.opacity(0.28), radius: 4, x: 1, y: 2))
        sh.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(col(f, (0.0, 0.46, 0.27), (0.0, 0.36, 0.23))))
        ctx.fill(Path(roundedRect: r.insetBy(dx: 1, dy: 1), cornerRadius: 5),
                 with: .linearGradient(Gradient(colors: [col(f, (0.05, 0.56, 0.34), (0.03, 0.44, 0.29)), col(f, (0.0, 0.42, 0.25), (0.0, 0.32, 0.21))]),
                                       startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
        ctx.stroke(Path(roundedRect: r.insetBy(dx: 3, dy: 3), cornerRadius: 3.5), with: .color(.white.opacity(f.dark ? 0.8 : 0.95)), lineWidth: 1.6)
    }
}
