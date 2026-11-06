import SwiftUI

// American football: looking down the field at the end zone. Yard lines and numbers in perspective,
// alternating mowed bands, a plain-colored end zone with pylons, yellow goalposts with waving ribbons,
// packed stands and light towers. Dark mode = night game under the lights.
enum FootballBackdrop {
    // A kick sails just above the crossbar, between the uprights.
    static func target(_ f: BackdropFrame) -> CGPoint {
        let p = posts(f)
        return CGPoint(x: f.targetX, y: p.bar - 16 * scale(f))
    }

    private static func scale(_ f: BackdropFrame) -> Double { min(1.2, max(0.75, f.horizon / 280)) }
    // End line, goal line, crossbar y and half the upright spread.
    private static func posts(_ f: BackdropFrame) -> (end: Double, goal: Double, bar: Double, half: Double) {
        let s = scale(f)
        let end = f.horizon - 40 * s
        return (end, f.horizon - 18 * s, end - 40 * s, min(36 * s, f.width * 0.09))
    }
    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }
    private static func rnd(_ i: Int, _ s: Double) -> Double {
        let x = sin(Double(i) * 12.9898 + s * 78.233) * 43758.5453
        return x - floor(x)
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let W = f.width, h = f.height, d = f.dark, s = scale(f)
        let p = posts(f)
        let gx = f.targetX
        let wallBottom = p.end - 8 * s, wallTop = wallBottom - 8 * s
        let standTop = wallTop * 0.46, roof = standTop - 9 * s

        // Sky
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: W, height: standTop + 4), d
            ? [rgb(0.04, 0.05, 0.14), rgb(0.11, 0.11, 0.26), rgb(0.24, 0.20, 0.36)]
            : [rgb(0.32, 0.58, 0.92), rgb(0.58, 0.78, 0.96), rgb(0.88, 0.92, 0.96)])
        if !d {
            for i in 0..<3 {
                let span = W + 200
                let x = (rnd(i, 9) * span + f.t * (2.5 + Double(i))).truncatingRemainder(dividingBy: span) - 100
                let y = roof * (0.22 + 0.22 * Double(i)), sc = 0.6 + 0.3 * rnd(i, 5)
                var c = Path()
                c.addEllipse(in: CGRect(x: x - 34 * sc, y: y - 6 * sc, width: 68 * sc, height: 18 * sc))
                c.addEllipse(in: CGRect(x: x - 18 * sc, y: y - 16 * sc, width: 30 * sc, height: 26 * sc))
                ctx.fill(c, with: .color(.white.opacity(0.85)))
            }
        }

        // Light towers behind the stands.
        let lights = [W * 0.08, W * 0.60]
        let panelY = max(18, roof * 0.32)
        for lx in lights {
            var mast = Path()
            mast.move(to: CGPoint(x: lx - 1.5, y: panelY)); mast.addLine(to: CGPoint(x: lx - 4, y: roof + 4))
            mast.addLine(to: CGPoint(x: lx + 4, y: roof + 4)); mast.addLine(to: CGPoint(x: lx + 1.5, y: panelY)); mast.closeSubpath()
            ctx.fill(mast, with: .color(d ? rgb(0.28, 0.30, 0.38) : rgb(0.55, 0.58, 0.64)))
        }

        // Stands with a crowd (dotted strokes = many heads for a few draw calls).
        Sketch.gradient(&ctx, CGRect(x: 0, y: standTop, width: W, height: wallTop - standTop),
                        d ? [rgb(0.10, 0.10, 0.17), rgb(0.18, 0.17, 0.26)] : [rgb(0.40, 0.38, 0.46), rgb(0.56, 0.54, 0.60)])
        let shirts: [Color] = d
            ? [rgb(0.62, 0.30, 0.30), rgb(0.62, 0.60, 0.58), rgb(0.32, 0.40, 0.62), rgb(0.58, 0.50, 0.25)]
            : [rgb(0.85, 0.22, 0.22), rgb(0.97, 0.97, 0.97), rgb(0.20, 0.36, 0.72), rgb(0.98, 0.80, 0.25)]
        let rowGap = max(4.5, 5.5 * s)
        var y = standTop + rowGap, row = 0
        while y < wallTop - 3 {
            let dot = 3.0 + 1.6 * (y - standTop) / max(1, wallTop - standTop)
            for (k, c) in shirts.enumerated() {
                let phase = Double((row * 5 + k * 7) % 13)
                Sketch.line(&ctx, CGPoint(x: -phase, y: y), CGPoint(x: W + 8, y: y),
                            c.opacity(d ? 0.75 : 0.9), dot, dash: [0, CGFloat(dot * 4.4 + Double(k))])
            }
            y += rowGap; row += 1
        }
        for i in 0..<6 {
            let ax = W * (Double(i) + 0.5) / 6
            Sketch.line(&ctx, CGPoint(x: ax, y: standTop + 2), CGPoint(x: ax + (ax - f.center) * 0.08, y: wallTop),
                        d ? rgb(0.06, 0.06, 0.10, 0.8) : rgb(0.32, 0.30, 0.38, 0.8), 2.5)
        }
        Sketch.gradient(&ctx, CGRect(x: 0, y: roof, width: W, height: standTop - roof + 3),
                        d ? [rgb(0.17, 0.17, 0.24), rgb(0.07, 0.07, 0.12)] : [rgb(0.82, 0.83, 0.87), rgb(0.56, 0.57, 0.62)])
        Sketch.line(&ctx, CGPoint(x: 0, y: roof), CGPoint(x: W, y: roof), d ? rgb(0.6, 0.65, 0.8, 0.7) : .white.opacity(0.9), 1.5)
        let tick = Int(f.t * 4)
        var flashes = Path()
        for i in 0..<10 {
            let seed = Double(tick + i * 17)
            guard rnd(i, seed) > 0.45 else { continue }
            let fx = rnd(i, seed + 1) * W, fy = standTop + rnd(i, seed + 2) * (wallTop - standTop - 4)
            let r = d ? 2.6 : 1.8
            flashes.addEllipse(in: CGRect(x: fx - r, y: fy - r, width: 2 * r, height: 2 * r))
        }
        ctx.fill(flashes, with: .color(.white.opacity(d ? 0.95 : 0.8)))

        // Light panels, glowing at night.
        for lx in lights {
            let pw = 34 * s, ph = 15 * s
            let pr = CGRect(x: lx - pw / 2, y: panelY - ph / 2, width: pw, height: ph)
            if d {
                ctx.fill(Path(ellipseIn: pr.insetBy(dx: -70, dy: -60)),
                         with: .radialGradient(Gradient(colors: [rgb(0.95, 0.97, 1, 0.45), .clear]),
                                               center: CGPoint(x: pr.midX, y: pr.midY), startRadius: 4, endRadius: 85))
            }
            ctx.fill(Path(roundedRect: pr, cornerRadius: 2), with: .color(d ? rgb(0.25, 0.27, 0.33) : rgb(0.45, 0.48, 0.55)))
            var bulbs = Path()
            for r in 0..<2 { for c in 0..<5 {
                let bx = pr.minX + pw * (Double(c) + 0.5) / 5, by = pr.minY + ph * (Double(r) + 0.5) / 2
                bulbs.addEllipse(in: CGRect(x: bx - 2.4 * s, y: by - 2.4 * s, width: 4.8 * s, height: 4.8 * s))
            } }
            ctx.fill(bulbs, with: .color(d ? rgb(1, 1, 0.92) : rgb(0.92, 0.94, 0.97)))
        }

        // Padded wall in front of the stands.
        Sketch.gradient(&ctx, CGRect(x: 0, y: wallTop, width: W, height: wallBottom - wallTop),
                        d ? [rgb(0.14, 0.20, 0.36), rgb(0.09, 0.13, 0.26)] : [rgb(0.20, 0.30, 0.55), rgb(0.13, 0.21, 0.42)])
        Sketch.line(&ctx, CGPoint(x: 0, y: wallTop), CGPoint(x: W, y: wallTop), .white.opacity(0.5), 1)

        // Ground beyond the field, then the field itself.
        let vp = CGPoint(x: gx, y: p.end - 320 * s)
        func toward(_ x0: Double, _ y: Double) -> Double { vp.x + (x0 - vp.x) * (y - vp.y) / (p.end - vp.y) }
        Sketch.gradient(&ctx, CGRect(x: 0, y: wallBottom, width: W, height: h - wallBottom),
                        d ? [rgb(0.10, 0.26, 0.16), rgb(0.05, 0.15, 0.09)] : [rgb(0.30, 0.55, 0.28), rgb(0.18, 0.40, 0.18)])
        let half = W * 0.78
        let sideL = gx - half, sideR = gx + half
        var field = Path()
        field.move(to: CGPoint(x: sideL, y: p.end)); field.addLine(to: CGPoint(x: sideR, y: p.end))
        field.addLine(to: CGPoint(x: toward(sideR, h), y: h)); field.addLine(to: CGPoint(x: toward(sideL, h), y: h)); field.closeSubpath()
        ctx.fill(field, with: .linearGradient(Gradient(colors: d ? [rgb(0.16, 0.42, 0.24), rgb(0.08, 0.27, 0.15)]
                                                            : [rgb(0.38, 0.70, 0.34), rgb(0.24, 0.55, 0.24)]),
                                              startPoint: CGPoint(x: 0, y: p.end), endPoint: CGPoint(x: 0, y: h)))

        // End zone: a plain colored band with diagonal stripes.
        var ez = Path()
        ez.move(to: CGPoint(x: sideL, y: p.end)); ez.addLine(to: CGPoint(x: sideR, y: p.end))
        ez.addLine(to: CGPoint(x: toward(sideR, p.goal), y: p.goal)); ez.addLine(to: CGPoint(x: toward(sideL, p.goal), y: p.goal)); ez.closeSubpath()
        ctx.fill(ez, with: .color(d ? rgb(0.13, 0.22, 0.45) : rgb(0.16, 0.32, 0.64)))
        var ezStripes = ctx
        ezStripes.clip(to: ez)
        var diag = Path()
        var dx = -W
        while dx < W * 2 {
            diag.move(to: CGPoint(x: dx, y: p.goal)); diag.addLine(to: CGPoint(x: dx + (p.goal - p.end) * 1.2, y: p.end))
            dx += 16
        }
        ezStripes.stroke(diag, with: .color(.white.opacity(0.10)), lineWidth: 5)

        // Yard lines every 5 yards, spaced wider as they come closer; alternate mowed bands.
        var lines: [Double] = [p.goal]
        var gap = 11.0 * s
        while lines.last! < h + 40 {
            lines.append(lines.last! + gap); gap *= 1.2
        }
        var bands = Path()
        for i in stride(from: 0, to: lines.count - 1, by: 2) {
            let a = lines[i], b = lines[i + 1]
            bands.move(to: CGPoint(x: toward(sideL, a), y: a)); bands.addLine(to: CGPoint(x: toward(sideR, a), y: a))
            bands.addLine(to: CGPoint(x: toward(sideR, b), y: b)); bands.addLine(to: CGPoint(x: toward(sideL, b), y: b)); bands.closeSubpath()
        }
        ctx.fill(bands, with: .color(.white.opacity(d ? 0.05 : 0.08)))
        if d {
            ctx.fill(field, with: .radialGradient(Gradient(colors: [rgb(0.85, 1, 0.85, 0.15), .clear]),
                                                   center: CGPoint(x: f.center, y: f.horizon), startRadius: 0, endRadius: W * 0.8))
        }

        let lineC = Color.white.opacity(d ? 0.78 : 0.92)
        var m = Path()
        for (i, ly) in lines.enumerated() where ly < h {
            m.move(to: CGPoint(x: toward(sideL, ly), y: ly)); m.addLine(to: CGPoint(x: toward(sideR, ly), y: ly))
            _ = i
        }
        // End line and sidelines.
        m.move(to: CGPoint(x: sideL, y: p.end)); m.addLine(to: CGPoint(x: sideR, y: p.end))
        m.move(to: CGPoint(x: sideL, y: p.end)); m.addLine(to: CGPoint(x: toward(sideL, h), y: h))
        ctx.stroke(m, with: .color(lineC), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
        // Hash marks between the yard lines.
        var hash = Path()
        for i in 0..<(lines.count - 1) where lines[i] < h {
            for k in 1..<5 {
                let hy = lines[i] + (lines[i + 1] - lines[i]) * Double(k) / 5
                for hx in [gx - half * 0.12, gx + half * 0.12, sideL + half * 0.04] {
                    let x = toward(hx, hy), len = 3.0 * (hy - vp.y) / (p.end - vp.y)
                    hash.move(to: CGPoint(x: x - len, y: hy)); hash.addLine(to: CGPoint(x: x + len, y: hy))
                }
            }
        }
        ctx.stroke(hash, with: .color(lineC.opacity(0.8)), lineWidth: 1.2)

        // Yard numbers on every 10-yard line, lying flat on the grass (squashed by perspective).
        let numbers = ["10", "20", "30", "40", "50"]
        for (n, label) in numbers.enumerated() {
            let i = (n + 1) * 2
            guard i < lines.count, lines[i] < h else { break }
            let ly = lines[i]
            let k = (ly - vp.y) / (p.end - vp.y)
            let size = 17.0 * k * s
            let ny = (ly + lines[min(i + 1, lines.count - 1)]) / 2   // in the middle of the next 5-yard band
            for side in [sideL + half * 0.45, gx + half * 0.55] {
                var c = ctx
                c.translateBy(x: toward(side, ny), y: ny)
                c.scaleBy(x: 1, y: 0.6)
                c.draw(Text(label).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(lineC), at: .zero)
            }
        }

        // Orange pylons on the corners of the end zone.
        for (px, py) in [(sideL, p.end), (toward(sideL, p.goal), p.goal)] where px > -10 {
            Sketch.fill(&ctx, CGRect(x: px - 2.5 * s, y: py - 9 * s, width: 5 * s, height: 9 * s), rgb(1, 0.50, 0.10))
        }

        // Goalposts: padded base, gooseneck, crossbar and tall uprights with waving ribbons.
        let yellow = d ? rgb(0.98, 0.84, 0.25) : rgb(1.0, 0.82, 0.10)
        let dark = rgb(0.55, 0.42, 0.05)
        let base = p.end + 1
        ctx.fill(Path(ellipseIn: CGRect(x: gx - 4 * s, y: base - 2, width: 30 * s, height: 5 * s)), with: .color(.black.opacity(0.18)))
        var neck = Path()
        neck.move(to: CGPoint(x: gx, y: base)); neck.addLine(to: CGPoint(x: gx, y: p.bar + 10 * s))
        neck.addQuadCurve(to: CGPoint(x: gx, y: p.bar), control: CGPoint(x: gx + 6 * s, y: p.bar + 4 * s))
        ctx.stroke(neck, with: .color(dark), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round))
        ctx.stroke(neck, with: .color(yellow), style: StrokeStyle(lineWidth: 3.4 * s, lineCap: .round))
        Sketch.fill(&ctx, CGRect(x: gx - 3.5 * s, y: base - 14 * s, width: 7 * s, height: 14 * s), d ? rgb(0.15, 0.22, 0.45) : rgb(0.18, 0.30, 0.62))
        let upTop = p.bar - 92 * s
        var frame = Path()
        frame.move(to: CGPoint(x: gx - p.half, y: upTop)); frame.addLine(to: CGPoint(x: gx - p.half, y: p.bar))
        frame.addLine(to: CGPoint(x: gx + p.half, y: p.bar)); frame.addLine(to: CGPoint(x: gx + p.half, y: upTop))
        ctx.stroke(frame, with: .color(dark), style: StrokeStyle(lineWidth: 4.2 * s, lineCap: .round, lineJoin: .round))
        ctx.stroke(frame, with: .color(yellow), style: StrokeStyle(lineWidth: 2.8 * s, lineCap: .round, lineJoin: .round))
        // Ribbons on top of each upright.
        for ux in [gx - p.half, gx + p.half] {
            var rib = Path()
            rib.move(to: CGPoint(x: ux, y: upTop))
            for j in 1...4 {
                let u = Double(j) / 4
                rib.addLine(to: CGPoint(x: ux + 12 * s * u, y: upTop - 2 + 3 * u * sin(f.t * 5 - u * 4 + ux)))
            }
            ctx.stroke(rib, with: .color(rgb(0.98, 0.45, 0.10)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round, lineJoin: .round))
        }
    }
}
