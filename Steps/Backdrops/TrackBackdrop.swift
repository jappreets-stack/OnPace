import SwiftUI

// Track: standing in lane 5 of the home straight. Red lanes run left to right, the white finish line
// (with tape on two posts) is to the right, the infield and the far straight sit behind, and the
// grandstand rises at the back. Night = floodlit meet.
enum TrackBackdrop {
    // Ground perspective. X along the track (meters, + = right), d = depth (meters, + = away).
    private struct Cam {
        let cx: Double, vy: Double, hp: Double, m: Double, z0: Double
        func z(_ d: Double) -> Double { max(0.05, 1 + d / z0) }
        func y(_ d: Double) -> Double { vy + hp / z(d) }
        func x(_ X: Double, _ d: Double) -> Double { cx + X * m / z(d) }
        func p(_ X: Double, _ d: Double) -> CGPoint { CGPoint(x: x(X, d), y: y(d)) }
    }

    private static let lane = 1.22
    private static let nearEdge = -3.5 * 1.22 - 0.61   // outer edge of lane 8
    private static let farEdge = 4.5 * 1.22 + 0.61     // inner edge of lane 1
    private static let infield = 46.0

    private static func cam(_ f: BackdropFrame) -> Cam {
        let hp = min(0.8 * f.horizon, 0.56 * f.width)
        return Cam(cx: f.center, vy: f.horizon - hp, hp: hp, m: f.width / 20, z0: 21)
    }
    // Finish line, in meters right of the mini-me, chosen so it crosses lane 5 at f.targetX.
    private static func finishX(_ f: BackdropFrame) -> Double { 0.30 * 20 }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let c = cam(f)
        let dk = f.dark
        let farTrackNear = farEdge + infield
        let farTrackFar = farTrackNear + 8 * lane
        let yStandsBase = c.y(farTrackFar + 3)
        let standsTop = max(yStandsBase * 0.5, yStandsBase - min(76, f.width * 0.19))

        // Sky.
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: f.width, height: yStandsBase + 1), dk
            ? [rgb(0.05, 0.07, 0.19), rgb(0.17, 0.17, 0.36), rgb(0.42, 0.28, 0.40)]
            : [rgb(0.34, 0.61, 0.94), rgb(0.62, 0.81, 0.98), rgb(0.90, 0.95, 1.0)])
        if dk { stars(&ctx, f, maxY: standsTop) } else { clouds(&ctx, f, maxY: standsTop) }

        if dk { masts(&ctx, f, base: standsTop + 6) }
        grandstand(&ctx, f, top: standsTop, bottom: yStandsBase)
        if !dk { masts(&ctx, f, base: standsTop + 6) }

        // Ground behind the far straight and the infield grass.
        let grassFar = dk ? rgb(0.13, 0.36, 0.24) : rgb(0.42, 0.70, 0.40)
        let grassNear = dk ? rgb(0.09, 0.28, 0.18) : rgb(0.30, 0.58, 0.32)
        Sketch.gradient(&ctx, CGRect(x: 0, y: yStandsBase, width: f.width, height: c.y(farEdge) - yStandsBase + 1), [grassFar, grassNear])
        var d = farEdge + 0.5, k = 0
        while d < farTrackNear {
            if k % 2 == 0 {
                let y0 = c.y(min(farTrackNear, d + 4)), y1 = c.y(d)
                Sketch.fill(&ctx, CGRect(x: 0, y: y0, width: f.width, height: y1 - y0), .white.opacity(dk ? 0.04 : 0.07))
            }
            d += 4; k += 1
        }

        highJump(&ctx, f, c)

        // Red track colors.
        let redFar = dk ? rgb(0.55, 0.22, 0.20) : rgb(0.84, 0.38, 0.30)
        let redNear = dk ? rgb(0.42, 0.15, 0.15) : rgb(0.72, 0.28, 0.23)
        let lineC = Color.white.opacity(dk ? 0.82 : 0.95)

        // Far straight (thin band) and the wall in front of the stands.
        let fy0 = c.y(farTrackFar), fy1 = c.y(farTrackNear)
        Sketch.fill(&ctx, CGRect(x: 0, y: fy0, width: f.width, height: fy1 - fy0), redFar)
        for i in 0...8 { let y = c.y(farTrackNear + Double(i) * lane); Sketch.line(&ctx, CGPoint(x: 0, y: y), CGPoint(x: f.width, y: y), lineC.opacity(0.6), 0.6) }
        Sketch.fill(&ctx, CGRect(x: 0, y: yStandsBase - 3, width: f.width, height: 3 + c.y(farTrackFar + 3) - yStandsBase),
                    dk ? rgb(0.18, 0.20, 0.30) : rgb(0.32, 0.38, 0.50))

        // Near straight: inner curb, 8 lanes, apron, then grass down to the bottom.
        let curb = c.y(farEdge + 0.25)
        let edgeIn = c.y(farEdge), apron = c.y(nearEdge - 1.6)
        Sketch.fill(&ctx, CGRect(x: 0, y: curb, width: f.width, height: edgeIn - curb + 0.5), dk ? rgb(0.75, 0.78, 0.85) : .white)
        Sketch.gradient(&ctx, CGRect(x: 0, y: edgeIn, width: f.width, height: apron - edgeIn), [redFar, redNear])
        Sketch.gradient(&ctx, CGRect(x: 0, y: apron, width: f.width, height: f.height - apron),
                        dk ? [rgb(0.10, 0.28, 0.18), rgb(0.05, 0.15, 0.10)] : [rgb(0.32, 0.60, 0.33), rgb(0.20, 0.44, 0.24)])
        Sketch.fill(&ctx, CGRect(x: 0, y: apron, width: f.width, height: 2.5), dk ? rgb(0.55, 0.58, 0.65) : rgb(0.92, 0.92, 0.92))
        for i in 0...8 {
            let ld = farEdge - Double(i) * lane
            let y = c.y(ld)
            Sketch.line(&ctx, CGPoint(x: -2, y: y), CGPoint(x: f.width + 2, y: y), lineC, 1.6 / c.z(ld))
        }

        // Finish line, a little start-of-straight tick on each lane line, and lane numbers past the line.
        let fx = finishX(f)
        var fl = Path()
        let w0 = 0.22, wn = nearEdge, wf = farEdge
        fl.addLines([c.p(fx - w0, wf), c.p(fx + w0, wf), c.p(fx + w0, wn), c.p(fx - w0, wn)])
        fl.closeSubpath()
        ctx.fill(fl, with: .color(lineC))
        for i in 0..<8 {
            let ld = farEdge - (Double(i) + 0.5) * lane
            let z = c.z(ld)
            let p = c.p(fx - 1.8, ld)
            let size = 0.62 * lane * c.m / z
            var t = ctx
            t.translateBy(x: p.x, y: p.y)
            t.scaleBy(x: 1, y: 1.2 * c.hp / (c.m * z0Factor(c, ld)))
            t.draw(Text("\(i + 1)").font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(dk ? 0.75 : 0.9)), at: .zero)
        }

        // Light pool / vignette.
        let pool = CGRect(x: f.center - f.width, y: edgeIn - 120, width: f.width * 2, height: 260)
        ctx.fill(Path(ellipseIn: pool), with: .radialGradient(
            Gradient(colors: [dk ? rgb(0.85, 0.92, 1, 0.14) : rgb(1, 0.97, 0.82, 0.12), .clear]),
            center: CGPoint(x: pool.midX, y: pool.midY), startRadius: 0, endRadius: f.width))

        // Finish posts and tape (tape about the mini-me's waist height).
        let postH = 52.0
        let pNear = c.p(fx, nearEdge - 0.5), pFar = c.p(fx, farEdge + 0.6)
        let hNear = postH / c.z(nearEdge - 0.5), hFar = postH / c.z(farEdge + 0.6)
        let sway = sin(f.t * 2.2) * 2
        var tape = Path()
        let farTop = CGPoint(x: pFar.x, y: pFar.y - hFar), nearTop = CGPoint(x: pNear.x, y: pNear.y - hNear)
        if f.tapeBroken {
            // Run through: two loose ends hanging from the posts, fluttering.
            let flap = sin(f.t * 9) * 4
            tape.move(to: farTop)
            tape.addQuadCurve(to: CGPoint(x: farTop.x + 6 + flap, y: farTop.y + hFar * 0.55),
                              control: CGPoint(x: farTop.x + 14, y: farTop.y + 6))
            tape.move(to: nearTop)
            tape.addQuadCurve(to: CGPoint(x: nearTop.x - 8 - flap, y: nearTop.y + hNear * 0.6),
                              control: CGPoint(x: nearTop.x - 18, y: nearTop.y + 4))
        } else {
            tape.move(to: farTop)
            tape.addQuadCurve(to: nearTop,
                              control: CGPoint(x: (pFar.x + pNear.x) / 2 + sway, y: (farTop.y + nearTop.y) / 2 + 5))
        }
        ctx.stroke(tape, with: .color(.white), lineWidth: 3)
        ctx.stroke(tape, with: .color(rgb(0.95, 0.25, 0.25)), style: StrokeStyle(lineWidth: 3, dash: [5, 5]))
        for (p, h) in [(pFar, hFar), (pNear, hNear)] {
            let w = max(2, h * 0.07)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - w * 2, y: p.y - w * 0.6, width: w * 4, height: w * 1.2)), with: .color(.black.opacity(0.25)))
            ctx.fill(Path(roundedRect: CGRect(x: p.x - w / 2, y: p.y - h, width: w, height: h), cornerRadius: w / 2),
                     with: .color(dk ? rgb(0.80, 0.82, 0.88) : rgb(0.96, 0.96, 0.98)))
            Sketch.fill(&ctx, CGRect(x: p.x - w / 2, y: p.y - h * 0.55, width: w, height: h * 0.12), rgb(0.95, 0.25, 0.25))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - w, y: p.y - h - w, width: w * 2, height: w * 2)), with: .color(rgb(0.95, 0.25, 0.25)))
        }

        let vig = CGRect(x: 0, y: f.horizon + 40, width: f.width, height: f.height - f.horizon - 40)
        Sketch.gradient(&ctx, vig, [.clear, rgb(0, 0.02, 0, dk ? 0.35 : 0.15)])
    }

    // Vertical squash for painted numbers: how tall one meter of depth looks vs one meter across.
    private static func z0Factor(_ c: Cam, _ d: Double) -> Double {
        let z = c.z(d)
        return c.z0 * z   // dy/dd = hp / (z0 · z²); dx/dX = m / z  →  ratio = hp / (m · z0 · z)
    }

    // The finish line where it crosses the mini-me's lane, at foot height.
    static func target(_ f: BackdropFrame) -> CGPoint {
        let c = cam(f)
        return CGPoint(x: c.x(finishX(f), 0), y: f.horizon)
    }

    // MARK: - Pieces

    private static func grandstand(_ ctx: inout GraphicsContext, _ f: BackdropFrame, top: Double, bottom: Double) {
        let dk = f.dark
        let rows = 6
        let roofH = max(6, (bottom - top) * 0.16)
        let seatTop = top + roofH
        let rh = (bottom - seatTop) / Double(rows)
        Sketch.fill(&ctx, CGRect(x: 0, y: top, width: f.width, height: bottom - top), dk ? rgb(0.16, 0.17, 0.25) : rgb(0.70, 0.73, 0.78))
        let crowd: [Color] = dk
            ? [rgb(0.58, 0.42, 0.45), rgb(0.35, 0.42, 0.62), rgb(0.62, 0.58, 0.45), rgb(0.45, 0.55, 0.52)]
            : [rgb(0.92, 0.42, 0.38), rgb(0.30, 0.45, 0.80), rgb(0.97, 0.86, 0.48), rgb(0.97, 0.97, 0.97), rgb(0.40, 0.66, 0.55)]
        for i in 0..<rows {
            let y = seatTop + Double(i) * rh
            Sketch.fill(&ctx, CGRect(x: 0, y: y + rh * 0.35, width: f.width, height: rh * 0.65),
                        dk ? rgb(0.16, 0.22, 0.38) : rgb(0.26, 0.48, 0.72))
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
        for k in 1..<8 {
            let ax = f.width * Double(k) / 8
            Sketch.line(&ctx, CGPoint(x: ax, y: seatTop), CGPoint(x: ax, y: bottom), dk ? rgb(0.16, 0.17, 0.25) : rgb(0.70, 0.73, 0.78), max(1.5, rh * 0.4))
        }
        if !dk { Sketch.fill(&ctx, CGRect(x: 0, y: seatTop, width: f.width, height: bottom - seatTop), rgb(0.85, 0.92, 1, 0.2)) }
        // Cantilever roof with its shadow.
        Sketch.gradient(&ctx, CGRect(x: 0, y: seatTop, width: f.width, height: rh * 1.6), [.black.opacity(dk ? 0.35 : 0.25), .clear])
        var roof = Path()
        roof.addLines([CGPoint(x: -4, y: top - roofH * 0.6), CGPoint(x: f.width + 4, y: top - roofH * 0.6),
                       CGPoint(x: f.width + 4, y: seatTop), CGPoint(x: -4, y: seatTop)])
        roof.closeSubpath()
        ctx.fill(roof, with: .linearGradient(Gradient(colors: dk ? [rgb(0.30, 0.32, 0.42), rgb(0.20, 0.21, 0.30)] : [rgb(0.97, 0.97, 0.99), rgb(0.80, 0.82, 0.86)]),
                                             startPoint: CGPoint(x: 0, y: top - roofH), endPoint: CGPoint(x: 0, y: seatTop)))
        if dk {
            var x = f.width * 0.04
            while x < f.width {
                Sketch.fill(&ctx, CGRect(x: x, y: seatTop - 2.5, width: 6, height: 2), rgb(1, 0.96, 0.82))
                x += f.width * 0.08
            }
        }
        // Blank video board on the left, flags on the roof.
        let bw = f.width * 0.2, bh = bw * 0.42
        let b = CGRect(x: f.width * 0.13, y: top - roofH * 0.6 - bh - 4, width: bw, height: bh)
        if b.minY > 8 {
            ctx.fill(Path(roundedRect: b, cornerRadius: 3), with: .color(rgb(0.12, 0.13, 0.17)))
            ctx.fill(Path(roundedRect: b.insetBy(dx: 3, dy: 3), cornerRadius: 2),
                     with: .linearGradient(Gradient(colors: [rgb(0.25, 0.55, 0.85, dk ? 0.9 : 0.8), rgb(0.35, 0.80, 0.70, dk ? 0.9 : 0.8)]),
                                           startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.maxX, y: b.maxY)))
            Sketch.line(&ctx, CGPoint(x: b.midX, y: b.maxY), CGPoint(x: b.midX, y: top - roofH * 0.6), rgb(0.3, 0.3, 0.35), 2)
        }
        let cols: [Color] = [rgb(0.97, 0.78, 0.25), rgb(0.35, 0.70, 0.55), rgb(0.40, 0.55, 0.90)]
        for (i, fxr) in [0.42, 0.62, 0.82].enumerated() {
            let fx = f.width * fxr, base = top - roofH * 0.6
            Sketch.line(&ctx, CGPoint(x: fx, y: base), CGPoint(x: fx, y: base - 20), dk ? rgb(0.6, 0.6, 0.7) : rgb(0.45, 0.45, 0.5), 1.2)
            let wv = sin(f.t * 3 + Double(i)) * 2.5
            var p = Path()
            p.addLines([CGPoint(x: fx, y: base - 20), CGPoint(x: fx + 13, y: base - 17 + wv), CGPoint(x: fx, y: base - 13)])
            p.closeSubpath()
            ctx.fill(p, with: .color(cols[i].opacity(dk ? 0.8 : 1)))
        }
    }

    // A high-jump mat with its two standards and bar, on the infield to the left.
    private static func highJump(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ c: Cam) {
        let dk = f.dark
        let X = -0.36 * 20.0 * c.z(18) / c.z(0) , d = 18.0
        let a = c.p(X - 2.5, d), b = c.p(X + 2.5, d), a2 = c.p(X - 2.5, d + 4), b2 = c.p(X + 2.5, d + 4)
        let th = 7.0 / c.z(d)
        var top = Path(); top.addLines([a2, b2, b, a]); top.closeSubpath()
        Sketch.fill(&ctx, CGRect(x: a.x, y: a.y - th, width: b.x - a.x, height: th), dk ? rgb(0.12, 0.22, 0.45) : rgb(0.16, 0.36, 0.70))
        var raised = Path(); raised.addLines([CGPoint(x: a2.x, y: a2.y - th), CGPoint(x: b2.x, y: b2.y - th),
                                              CGPoint(x: b.x, y: b.y - th), CGPoint(x: a.x, y: a.y - th)]); raised.closeSubpath()
        ctx.fill(raised, with: .color(dk ? rgb(0.20, 0.34, 0.62) : rgb(0.30, 0.52, 0.88)))
        let sa = c.p(X - 2.2, d - 1.2), sb = c.p(X + 2.2, d - 1.2)
        let sh = 26.0 / c.z(d)
        let pole = dk ? rgb(0.75, 0.78, 0.85) : rgb(0.95, 0.95, 0.97)
        Sketch.line(&ctx, sa, CGPoint(x: sa.x, y: sa.y - sh), pole, 1.6)
        Sketch.line(&ctx, sb, CGPoint(x: sb.x, y: sb.y - sh), pole, 1.6)
        Sketch.line(&ctx, CGPoint(x: sa.x, y: sa.y - sh * 0.8), CGPoint(x: sb.x, y: sb.y - sh * 0.8), rgb(0.97, 0.80, 0.25), 1.6)
    }

    private static func masts(_ ctx: inout GraphicsContext, _ f: BackdropFrame, base: Double) {
        let dk = f.dark
        for s in [-1.0, 1.0] {
            let x = f.center + s * f.width * 0.45
            let top = max(14, base * 0.22)
            Sketch.line(&ctx, CGPoint(x: x, y: base), CGPoint(x: x, y: top + 10), dk ? rgb(0.25, 0.27, 0.36) : rgb(0.55, 0.58, 0.64), 3)
            let head = CGRect(x: x - 16, y: top, width: 32, height: 12)
            if dk {
                ctx.fill(Path(ellipseIn: head.insetBy(dx: -40, dy: -34)), with: .radialGradient(
                    Gradient(colors: [rgb(1, 0.97, 0.85, 0.42), .clear]),
                    center: CGPoint(x: head.midX, y: head.midY), startRadius: 0, endRadius: 50))
            }
            Sketch.fill(&ctx, head, dk ? rgb(0.18, 0.20, 0.26) : rgb(0.42, 0.45, 0.52))
            for i in 0..<4 {
                for j in 0..<2 {
                    Sketch.fill(&ctx, CGRect(x: head.minX + 2 + Double(i) * 7.5, y: head.minY + 1.5 + Double(j) * 5, width: 5.5, height: 4),
                                dk ? rgb(1, 0.98, 0.88) : rgb(0.88, 0.90, 0.94))
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
