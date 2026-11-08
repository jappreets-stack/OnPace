import SwiftUI

// Mountain trail: layered ranges fading into the haze, a snow-capped summit on the right (the mini-me
// plants a flag on its top), a pine forest, and a dirt trail winding from the meadow up toward the peak.
enum TrailBackdrop {
    private typealias RGB = (Double, Double, Double)

    private static func rgb(_ c: RGB, _ a: Double = 1) -> Color { Color(red: c.0, green: c.1, blue: c.2).opacity(a) }

    private static func col(_ f: BackdropFrame, _ day: RGB, _ night: RGB, _ a: Double = 1) -> Color {
        rgb(f.dark ? night : day, a)
    }

    private static func mix(_ a: RGB, _ b: RGB, _ k: Double) -> RGB {
        (a.0 + (b.0 - a.0) * k, a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k)
    }

    private static func rnd(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - floor(x)
    }

    // Haze color near the horizon; far layers blend toward it.
    private static func haze(_ f: BackdropFrame) -> RGB { f.dark ? (0.30, 0.30, 0.50) : (0.80, 0.89, 0.97) }

    // MARK: Geometry

    // How high the summit rises above the mini-me's feet (fits short and tall skies).
    private static func peakHeight(_ f: BackdropFrame) -> Double { min(170, max(90, f.horizon * 0.55)) }

    // The top of the summit.
    private static func target(_ f: BackdropFrame) -> CGPoint { CGPoint(x: f.targetX, y: f.horizon - peakHeight(f)) }

    // Points given as (x fraction of width, fraction of peak height above the horizon).
    private static func pt(_ f: BackdropFrame, _ u: Double, _ k: Double) -> CGPoint {
        CGPoint(x: u * f.width, y: f.horizon - k * peakHeight(f))
    }

    private static func range(_ pts: [CGPoint], base: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: pts[0].x, y: base))
        for q in pts { p.addLine(to: q) }
        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: base))
        p.closeSubpath()
        return p
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        drawSky(&ctx, f)
        drawFarRange(&ctx, f)
        drawMist(&ctx, f, y: f.horizon - peakHeight(f) * 0.28, drift: 4)
        drawMidMountains(&ctx, f)
        drawForestRidge(&ctx, f)
        drawMeadow(&ctx, f)
        drawTrail(&ctx, f)
        drawForeground(&ctx, f)
    }

    // MARK: Sky

    private static func drawSky(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let bottom = f.horizon
        let colors: [Color] = f.dark
            ? [rgb((0.04, 0.05, 0.15)), rgb((0.11, 0.13, 0.30)), rgb((0.28, 0.26, 0.47)), rgb((0.50, 0.38, 0.52))]
            : [rgb((0.27, 0.55, 0.90)), rgb((0.50, 0.74, 0.96)), rgb((0.80, 0.90, 0.98)), rgb((0.96, 0.95, 0.90))]
        ctx.fill(Path(CGRect(x: 0, y: 0, width: f.width, height: bottom)),
                 with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: bottom)))

        let s = CGPoint(x: f.width * 0.20, y: max(60, (f.horizon - peakHeight(f)) * 0.75))
        if f.dark {
            for i in 0..<55 {
                let x = rnd(i, 1) * f.width
                let y = pow(rnd(i, 2), 1.3) * (f.horizon - peakHeight(f) * 0.6)
                let r = 0.8 + rnd(i, 3) * 1.5
                let tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(f.t * (0.7 + rnd(i, 4) * 1.8) + Double(i)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)), with: .color(.white.opacity(0.85 * tw)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 50, y: s.y - 50, width: 100, height: 100)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.28), .white.opacity(0)]), center: s, startRadius: 12, endRadius: 50))
            // Crescent moon.
            var moon = Path(ellipseIn: CGRect(x: s.x - 16, y: s.y - 16, width: 32, height: 32))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: s.x - 8, y: s.y - 21, width: 32, height: 32)))
            ctx.fill(moon, with: .color(rgb((0.98, 0.95, 0.82))))
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 75, y: s.y - 75, width: 150, height: 150)),
                     with: .radialGradient(Gradient(colors: [rgb((1, 0.97, 0.82), 0.75), rgb((1, 0.95, 0.8), 0)]), center: s, startRadius: 14, endRadius: 75))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x - 20, y: s.y - 20, width: 40, height: 40)), with: .color(rgb((1, 0.96, 0.74))))
        }

        // Drifting clouds.
        let span = f.width + 240
        let clouds: [(Double, Double, Double, Double)] = [(0.05, 0.45, 0.9, 2.4), (0.60, 0.22, 0.65, 1.6)]
        for c in clouds {
            let x = (c.0 * span + f.t * c.3).truncatingRemainder(dividingBy: span) - 120
            let y = max(46, (f.horizon - peakHeight(f)) * c.1 + 20)
            cloud(&ctx, f, x, y, 30 * c.2)
        }

        // Two birds circling high up (day).
        if !f.dark {
            for i in 0..<2 {
                let a = f.t * 0.25 + Double(i) * 2.4
                let x = f.width * 0.62 + cos(a) * 30
                let y = max(50, f.horizon - peakHeight(f) - 30) + sin(a) * 8
                let w = 5.5 - Double(i)
                var p = Path()
                p.move(to: CGPoint(x: x - w, y: y - 1.5))
                p.addQuadCurve(to: CGPoint(x: x, y: y + 1), control: CGPoint(x: x - w * 0.5, y: y - 3))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y - 1.5), control: CGPoint(x: x + w * 0.5, y: y - 3))
                ctx.stroke(p, with: .color(rgb((0.25, 0.28, 0.36), 0.7)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
    }

    private static func cloud(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ x: Double, _ y: Double, _ s: Double) {
        let puffs: [(Double, Double, Double)] = [(-1.0, 0.15, 0.5), (-0.4, -0.2, 0.72), (0.3, -0.35, 0.85), (0.95, 0.05, 0.55), (0.0, 0.2, 0.6)]
        let shade = col(f, (0.82, 0.87, 0.95), (0.30, 0.30, 0.48), f.dark ? 0.5 : 0.85)
        let light = col(f, (1, 1, 1), (0.46, 0.44, 0.62), f.dark ? 0.55 : 0.92)
        for p in puffs {
            let r = s * p.2
            ctx.fill(Path(ellipseIn: CGRect(x: x + p.0 * s - r, y: y + p.1 * s - r + s * 0.12, width: r * 2, height: r * 2)), with: .color(shade))
        }
        for p in puffs {
            let r = s * p.2 * 0.92
            ctx.fill(Path(ellipseIn: CGRect(x: x + p.0 * s - r, y: y + p.1 * s - r, width: r * 2, height: r * 2)), with: .color(light))
        }
    }

    private static func drawMist(_ ctx: inout GraphicsContext, _ f: BackdropFrame, y: Double, drift: Double) {
        let c = col(f, (1, 1, 1), (0.55, 0.52, 0.72), f.dark ? 0.18 : 0.35)
        for i in 0..<3 {
            let w = f.width * 0.7
            let x = (Double(i) * f.width * 0.55 + f.t * drift).truncatingRemainder(dividingBy: f.width + w) - w * 0.5
            let r = CGRect(x: x - w / 2, y: y - 7 + Double(i) * 5, width: w, height: 12)
            ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [c, c.opacity(0)]),
                                                                center: CGPoint(x: r.midX, y: r.midY), startRadius: 0, endRadius: w / 2))
        }
    }

    // MARK: Mountains

    private static func drawFarRange(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let base = f.horizon
        let ridge: [(Double, Double)] = [(-0.02, 0.42), (0.06, 0.58), (0.12, 0.50), (0.20, 0.66), (0.27, 0.52), (0.35, 0.72),
                                         (0.43, 0.55), (0.50, 0.62), (0.57, 0.48), (0.64, 0.60), (0.72, 0.50), (0.80, 0.56),
                                         (0.88, 0.46), (0.95, 0.58), (1.03, 0.50)]
        let pts = ridge.map { pt(f, $0.0, $0.1) }
        let c = mix(f.dark ? (0.22, 0.22, 0.42) : (0.62, 0.72, 0.86), haze(f), 0.35)
        ctx.fill(range(pts, base: base), with: .color(rgb(c)))
        // Faint snow on the tallest far peaks.
        for (i, r) in ridge.enumerated() where r.1 > 0.6 {
            let p = pts[i]
            let h = peakHeight(f) * 0.08
            var cap = Path()
            cap.move(to: p)
            cap.addLine(to: CGPoint(x: p.x - h * 1.1, y: p.y + h))
            cap.addLine(to: CGPoint(x: p.x - h * 0.3, y: p.y + h * 0.7))
            cap.addLine(to: CGPoint(x: p.x + h * 0.4, y: p.y + h * 1.05))
            cap.addLine(to: CGPoint(x: p.x + h * 1.1, y: p.y + h))
            cap.closeSubpath()
            ctx.fill(cap, with: .color(col(f, (0.95, 0.97, 1.0), (0.62, 0.62, 0.80), 0.8)))
        }
    }

    // One faceted mountain: lit face on the left, shadow face on the right, snow on top.
    private static func mountain(_ ctx: inout GraphicsContext, _ f: BackdropFrame, left: [CGPoint], peak: CGPoint, right: [CGPoint],
                                 ridgeFoot: CGPoint, lit: RGB, shade: RGB, snowDrop: Double) {
        let base = f.horizon + 2
        let all = left + [peak] + right
        ctx.fill(range(all, base: base), with: .color(rgb(shade)))
        // Lit face: everything left of a ridge line falling from the peak.
        var face = Path()
        face.move(to: CGPoint(x: left[0].x, y: base))
        for q in left { face.addLine(to: q) }
        face.addLine(to: peak)
        let mid = CGPoint(x: (peak.x + ridgeFoot.x) / 2 - 6, y: (peak.y + ridgeFoot.y) / 2)
        face.addLine(to: mid)
        face.addLine(to: ridgeFoot)
        face.addLine(to: CGPoint(x: ridgeFoot.x, y: base))
        face.closeSubpath()
        ctx.fill(face, with: .linearGradient(Gradient(colors: [rgb(lit), rgb(mix(lit, haze(f), 0.35))]),
                                             startPoint: peak, endPoint: CGPoint(x: peak.x, y: base)))
        // Snow cap with a jagged lower edge, lit and shaded halves.
        let d = snowDrop
        func onLeft(_ k: Double) -> CGPoint {   // point down the left skyline at height peak.y + k
            var prev = peak
            for q in (left).reversed() {
                if q.y >= peak.y + k {
                    let t = (peak.y + k - prev.y) / max(0.001, q.y - prev.y)
                    return CGPoint(x: prev.x + (q.x - prev.x) * t, y: peak.y + k)
                }
                prev = q
            }
            return prev
        }
        func onRight(_ k: Double) -> CGPoint {
            var prev = peak
            for q in right {
                if q.y >= peak.y + k {
                    let t = (peak.y + k - prev.y) / max(0.001, q.y - prev.y)
                    return CGPoint(x: prev.x + (q.x - prev.x) * t, y: peak.y + k)
                }
                prev = q
            }
            return prev
        }
        let l = onLeft(d), r = onRight(d * 0.8)
        var snow = Path()
        snow.move(to: peak)
        snow.addLine(to: l)
        let steps = 6
        for i in 1..<steps {
            let k = Double(i) / Double(steps)
            let x = l.x + (r.x - l.x) * k
            let y = l.y + (r.y - l.y) * k + (i % 2 == 0 ? -d * 0.35 : d * 0.15)
            snow.addLine(to: CGPoint(x: x, y: y))
        }
        snow.addLine(to: r)
        snow.closeSubpath()
        ctx.fill(snow, with: .color(col(f, (0.80, 0.86, 0.95), (0.48, 0.50, 0.70))))
        var litSnow = Path()
        litSnow.move(to: peak)
        litSnow.addLine(to: l)
        for i in 1..<steps / 2 {
            let k = Double(i) / Double(steps)
            litSnow.addLine(to: CGPoint(x: l.x + (r.x - l.x) * k, y: l.y + (r.y - l.y) * k + (i % 2 == 0 ? -d * 0.35 : d * 0.15)))
        }
        litSnow.addLine(to: CGPoint(x: (peak.x + ridgeFoot.x) / 2 - 2, y: peak.y + d * 0.9))
        litSnow.closeSubpath()
        ctx.fill(litSnow, with: .color(col(f, (1, 1, 1), (0.70, 0.72, 0.88))))
    }

    private static func drawMidMountains(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let lit: RGB = f.dark ? (0.30, 0.32, 0.52) : (0.56, 0.64, 0.78)
        let shade: RGB = f.dark ? (0.17, 0.18, 0.34) : (0.38, 0.46, 0.62)
        let ph = peakHeight(f)

        // Left companion peak.
        mountain(&ctx, f,
                 left: [pt(f, -0.10, 0.2), pt(f, 0.0, 0.52), pt(f, 0.07, 0.70)],
                 peak: pt(f, 0.13, 0.80),
                 right: [pt(f, 0.19, 0.66), pt(f, 0.25, 0.58), pt(f, 0.33, 0.38), pt(f, 0.44, 0.18), pt(f, 0.55, 0.05)],
                 ridgeFoot: pt(f, 0.20, 0.0), lit: mix(lit, haze(f), 0.12), shade: mix(shade, haze(f), 0.12), snowDrop: ph * 0.16)

        // The summit (target) on the right.
        let s = target(f)
        let su = s.x / f.width
        mountain(&ctx, f,
                 left: [pt(f, su - 0.48, 0.05), pt(f, su - 0.34, 0.28), pt(f, su - 0.24, 0.42), pt(f, su - 0.16, 0.62),
                        pt(f, su - 0.10, 0.70), pt(f, su - 0.05, 0.86)],
                 peak: s,
                 right: [pt(f, su + 0.04, 0.88), pt(f, su + 0.09, 0.74), pt(f, su + 0.14, 0.70), pt(f, su + 0.22, 0.52), pt(f, su + 0.40, 0.30)],
                 ridgeFoot: pt(f, su + 0.06, 0.0), lit: lit, shade: shade, snowDrop: ph * 0.24)

        // A switchback path climbing the summit's lit face.
        let path: [(Double, Double)] = [(su - 0.20, 0.10), (su - 0.08, 0.22), (su - 0.15, 0.33), (su - 0.05, 0.45),
                                        (su - 0.10, 0.56), (su - 0.03, 0.68), (su - 0.05, 0.80), (su, 1.0)]
        var p = Path()
        p.move(to: pt(f, path[0].0, path[0].1))
        for q in path.dropFirst() { p.addLine(to: pt(f, q.0, q.1)) }
        ctx.stroke(p, with: .color(col(f, (0.96, 0.92, 0.82), (0.62, 0.60, 0.72), 0.75)),
                   style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round, dash: [3, 2.5]))
        // A tiny cairn marks the flag spot at the very top.
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - 2.5, y: s.y - 1.5, width: 5, height: 3)), with: .color(col(f, (0.45, 0.45, 0.50), (0.25, 0.25, 0.35))))
    }

    // MARK: Forest ridge and meadow

    private static func pine(_ ctx: inout GraphicsContext, _ x: Double, _ y: Double, _ h: Double, dark: Color, light: Color?, trunk: Color) {
        let w = h * 0.42
        Sketch.fill(&ctx, CGRect(x: x - h * 0.03, y: y - h * 0.14, width: h * 0.06, height: h * 0.14), trunk)
        let tiers = 3
        for i in 0..<tiers {
            let k = Double(i) / Double(tiers)
            let ty = y - h * (0.10 + k * 0.30)
            let top = y - h * (0.55 + k * 0.15)
            let hw = w * (1 - k * 0.28)
            var p = Path()
            p.move(to: CGPoint(x: x, y: i == tiers - 1 ? y - h : top))
            p.addLine(to: CGPoint(x: x - hw, y: ty))
            p.addQuadCurve(to: CGPoint(x: x + hw, y: ty), control: CGPoint(x: x, y: ty + h * 0.06))
            p.closeSubpath()
            ctx.fill(p, with: .color(dark))
            guard let light else { continue }
            var lit = Path()
            lit.move(to: CGPoint(x: x, y: i == tiers - 1 ? y - h : top))
            lit.addLine(to: CGPoint(x: x - hw, y: ty))
            lit.addQuadCurve(to: CGPoint(x: x - hw * 0.05, y: ty + h * 0.03), control: CGPoint(x: x - hw * 0.5, y: ty + h * 0.05))
            lit.closeSubpath()
            ctx.fill(lit, with: .color(light))
        }
    }

    private static func drawForestRidge(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        // Far forested hill, hazier.
        let farTop: (Double) -> Double = { u in f.horizon - 40 - 10 * sin(u * 6.5 + 0.8) - 6 * sin(u * 15) }
        var far = Path()
        far.move(to: CGPoint(x: 0, y: f.horizon + 2))
        for i in 0...30 { let u = Double(i) / 30; far.addLine(to: CGPoint(x: u * f.width, y: farTop(u))) }
        far.addLine(to: CGPoint(x: f.width, y: f.horizon + 2)); far.closeSubpath()
        let farC = mix(f.dark ? (0.10, 0.18, 0.24) : (0.34, 0.54, 0.46), haze(f), 0.35)
        ctx.fill(far, with: .color(rgb(farC)))
        let farTree = rgb(mix(farC, (0, 0.1, 0.08), 0.25))
        for i in 0..<26 {
            let u = rnd(i, 51)
            let x = u * f.width
            let h = 9 + rnd(i, 52) * 8
            pine(&ctx, x, farTop(u) + 4 + rnd(i, 53) * 8, h, dark: farTree, light: nil, trunk: farTree)
        }

        // Nearer wooded hill.
        let nearTop: (Double) -> Double = { u in f.horizon - 18 - 8 * sin(u * 4.5 + 2.0) }
        var near = Path()
        near.move(to: CGPoint(x: 0, y: f.horizon + 4))
        for i in 0...30 { let u = Double(i) / 30; near.addLine(to: CGPoint(x: u * f.width, y: nearTop(u))) }
        near.addLine(to: CGPoint(x: f.width, y: f.horizon + 4)); near.closeSubpath()
        let nearC = mix(f.dark ? (0.07, 0.16, 0.18) : (0.28, 0.50, 0.32), haze(f), 0.12)
        ctx.fill(near, with: .color(rgb(nearC)))
        let dk = rgb(mix(nearC, (0.02, 0.15, 0.10), 0.4))
        let lt = rgb(mix(nearC, f.dark ? (0.25, 0.35, 0.40) : (0.55, 0.75, 0.45), 0.35))
        for i in 0..<24 {
            let u = rnd(i, 61)
            let x = u * f.width
            let h = 14 + rnd(i, 62) * 10
            if abs(x - f.center) < 60 && h > 18 { continue }
            pine(&ctx, x, nearTop(u) + 6 + rnd(i, 63) * 8, h, dark: dk, light: lt, trunk: dk)
        }
    }

    private static func drawMeadow(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let top = f.horizon - 6
        var m = Path()
        m.move(to: CGPoint(x: 0, y: top + 4))
        for i in 0...24 {
            let u = Double(i) / 24
            m.addLine(to: CGPoint(x: u * f.width, y: top + 3 * sin(u * 9 + 1)))
        }
        m.addLine(to: CGPoint(x: f.width, y: f.height)); m.addLine(to: CGPoint(x: 0, y: f.height)); m.closeSubpath()
        ctx.fill(m, with: .linearGradient(Gradient(colors: f.dark
                                                   ? [rgb((0.12, 0.24, 0.24)), rgb((0.08, 0.18, 0.18)), rgb((0.06, 0.13, 0.15))]
                                                   : [rgb((0.58, 0.76, 0.40)), rgb((0.45, 0.68, 0.32)), rgb((0.36, 0.58, 0.27))]),
                                          startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: f.height)))

        // Wildflowers and grass tufts, denser near the horizon band.
        let flowers: [RGB] = f.dark ? [(0.6, 0.55, 0.75), (0.7, 0.65, 0.5), (0.55, 0.6, 0.75)]
                                    : [(1, 0.85, 0.3), (1, 1, 1), (0.85, 0.45, 0.75), (1, 0.55, 0.4)]
        for i in 0..<60 {
            let y = top + 6 + pow(rnd(i, 71), 1.8) * (f.height - top)
            let x = rnd(i, 72) * f.width
            if abs(x - trailX(f, y)) < trailHalf(f, y) + 4 { continue }
            let s = min(2.6, 1.1 + (y - top) * 0.006)
            if i % 3 == 0 {
                let tuft = col(f, (0.30, 0.52, 0.22), (0.05, 0.12, 0.13), 0.8)
                for j in -1...1 {
                    Sketch.line(&ctx, CGPoint(x: x + Double(j) * s, y: y), CGPoint(x: x + Double(j) * s * 2.2, y: y - s * (j == 0 ? 4 : 3)), tuft, max(0.8, s * 0.5))
                }
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(rgb(flowers[i % flowers.count], 0.9)))
            }
        }
    }

    // MARK: Trail

    // Centre of the trail at height y: from the far trees on the right, past the mini-me's feet,
    // then sweeping off to the lower left.
    private static func trailX(_ f: BackdropFrame, _ y: Double) -> Double {
        let far = f.horizon - 7
        if y <= f.horizon {
            let k = max(0, min(1, (f.horizon - y) / (f.horizon - far)))
            return f.center + f.width * 0.10 * k * k * (3 - 2 * k)
        }
        let d = y - f.horizon
        return f.center - f.width * 0.32 * sin(min(1, d / 420) * .pi / 2) + f.width * 0.06 * sin(d / 140)
    }

    private static func trailHalf(_ f: BackdropFrame, _ y: Double) -> Double {
        let far = f.horizon - 7
        if y <= f.horizon { return 4 + 12 * (y - far) / (f.horizon - far) }
        return 16 + (y - f.horizon) * 0.22
    }

    private static func drawTrail(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let far = f.horizon - 7
        var ys: [Double] = []
        var y = far
        while y < f.height + 10 { ys.append(y); y += y < f.horizon ? 1 : 14 }
        ys.append(f.height + 10)
        func band(_ s: Double) -> Path {
            var p = Path()
            for (i, y) in ys.enumerated() {
                let q = CGPoint(x: trailX(f, y) - trailHalf(f, y) * s, y: y)
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            for y in ys.reversed() { p.addLine(to: CGPoint(x: trailX(f, y) + trailHalf(f, y) * s, y: y)) }
            p.closeSubpath()
            return p
        }
        ctx.fill(band(1.15), with: .color(col(f, (0.50, 0.58, 0.30), (0.07, 0.13, 0.13), 0.6)))
        ctx.fill(band(1), with: .linearGradient(Gradient(colors: f.dark
                                                         ? [rgb((0.36, 0.33, 0.40)), rgb((0.27, 0.24, 0.28))]
                                                         : [rgb((0.88, 0.78, 0.58)), rgb((0.78, 0.64, 0.44))]),
                                                startPoint: CGPoint(x: 0, y: far), endPoint: CGPoint(x: 0, y: f.horizon + 200)))
        ctx.fill(band(0.45), with: .color(col(f, (0.94, 0.86, 0.68), (0.42, 0.39, 0.46), 0.5)))
        // Pebbles on the trail.
        for i in 0..<18 {
            let y = f.horizon + 4 + pow(rnd(i, 81), 1.4) * (f.height - f.horizon)
            if abs(y - f.horizon) < 10 { continue }
            let x = trailX(f, y) + (rnd(i, 82) - 0.5) * 1.6 * trailHalf(f, y)
            let r = 1 + (y - f.horizon) * 0.012
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)), with: .color(col(f, (0.62, 0.52, 0.38), (0.20, 0.18, 0.22))))
        }
    }

    // MARK: Foreground

    private static func drawForeground(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let dk = col(f, (0.10, 0.36, 0.24), (0.03, 0.11, 0.13))
        let lt = col(f, (0.20, 0.50, 0.30), (0.07, 0.19, 0.20))
        let trunk = col(f, (0.40, 0.28, 0.18), (0.12, 0.10, 0.12))
        // Boulder by the trail on the right.
        let bx = f.center + f.width * 0.18, by = f.horizon + 26
        ctx.fill(Path(ellipseIn: CGRect(x: bx - 22, y: by - 3, width: 46, height: 8)), with: .color(.black.opacity(0.15)))
        var rock = Path()
        rock.move(to: CGPoint(x: bx - 20, y: by + 1))
        rock.addCurve(to: CGPoint(x: bx + 2, y: by - 20), control1: CGPoint(x: bx - 22, y: by - 12), control2: CGPoint(x: bx - 12, y: by - 20))
        rock.addCurve(to: CGPoint(x: bx + 22, y: by + 1), control1: CGPoint(x: bx + 14, y: by - 20), control2: CGPoint(x: bx + 24, y: by - 8))
        rock.closeSubpath()
        ctx.fill(rock, with: .linearGradient(Gradient(colors: [col(f, (0.72, 0.72, 0.74), (0.36, 0.36, 0.44)), col(f, (0.48, 0.48, 0.52), (0.20, 0.20, 0.27))]),
                                             startPoint: CGPoint(x: bx - 14, y: by - 18), endPoint: CGPoint(x: bx + 16, y: by)))

        // Pines framing both edges (kept well clear of the mini-me and the summit).
        pine(&ctx, f.width * 0.15, f.horizon + 22, 112, dark: dk, light: lt, trunk: trunk)
        pine(&ctx, f.width * 0.03, f.horizon + 70, 175, dark: dk, light: lt, trunk: trunk)
        pine(&ctx, f.width * 1.0, f.horizon + 64, 150, dark: dk, light: lt, trunk: trunk)
    }
}
