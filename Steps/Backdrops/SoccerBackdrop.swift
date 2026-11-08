import SwiftUI

// Soccer: a stadium pitch. Checkered mowing pattern in perspective, box markings, a goal with a net,
// ad boards, packed stands with camera flashes and floodlights. Dark mode = night game under the lights.
enum SoccerBackdrop {
    // Goal line y, goal width and height.
    private static func goal(_ f: BackdropFrame) -> (line: Double, w: Double, h: Double) {
        let s = scale(f)
        return (f.horizon - 26 * s, min(150, f.width * 0.30), 46 * s)
    }
    private static func scale(_ f: BackdropFrame) -> Double { min(1.2, max(0.75, f.horizon / 280)) }
    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }
    private static func rnd(_ i: Int, _ s: Double) -> Double {
        let x = sin(Double(i) * 12.9898 + s * 78.233) * 43758.5453
        return x - floor(x)
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let W = f.width, h = f.height, d = f.dark, s = scale(f)
        let g = goal(f)
        let gl = g.line, gx = f.targetX
        let boardBottom = gl - 9 * s, boardTop = boardBottom - 9 * s
        let standTop = boardTop * 0.50, roof = standTop - 10 * s

        // Sky
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: W, height: standTop + 4), d
            ? [rgb(0.04, 0.05, 0.14), rgb(0.10, 0.12, 0.26), rgb(0.20, 0.20, 0.36)]
            : [rgb(0.30, 0.58, 0.93), rgb(0.55, 0.77, 0.97), rgb(0.82, 0.92, 0.99)])
        if !d {
            for i in 0..<3 {
                let span = W + 200
                let x = (rnd(i, 6) * span + f.t * (2.5 + Double(i))).truncatingRemainder(dividingBy: span) - 100
                let y = roof * (0.25 + 0.2 * Double(i)), sc = 0.6 + 0.3 * rnd(i, 5)
                var c = Path()
                c.addEllipse(in: CGRect(x: x - 34 * sc, y: y - 6 * sc, width: 68 * sc, height: 18 * sc))
                c.addEllipse(in: CGRect(x: x - 18 * sc, y: y - 16 * sc, width: 30 * sc, height: 26 * sc))
                ctx.fill(c, with: .color(.white.opacity(0.85)))
            }
        }

        // Floodlight towers (behind the stands' roof).
        let lights = [W * 0.07, W * 0.93]
        let panelY = max(16, roof * 0.30)
        for lx in lights {
            Sketch.line(&ctx, CGPoint(x: lx, y: panelY), CGPoint(x: lx, y: roof + 4), d ? rgb(0.30, 0.32, 0.40) : rgb(0.55, 0.58, 0.64), 3)
        }

        // Stands: roof, tiers, crowd.
        let standRect = CGRect(x: 0, y: standTop, width: W, height: boardTop - standTop)
        Sketch.gradient(&ctx, standRect, d ? [rgb(0.10, 0.11, 0.18), rgb(0.17, 0.18, 0.27)]
                                           : [rgb(0.36, 0.40, 0.50), rgb(0.52, 0.56, 0.64)])
        // Crowd: rows of heads drawn as dotted strokes (cheap) in a few shirt colors.
        let rowGap = max(4.5, 5.5 * s)
        var y = standTop + rowGap
        var row = 0
        let shirt: [Color] = d
            ? [rgb(0.55, 0.30, 0.32), rgb(0.35, 0.42, 0.62), rgb(0.62, 0.58, 0.50), rgb(0.30, 0.50, 0.45)]
            : [rgb(0.86, 0.32, 0.30), rgb(0.25, 0.42, 0.78), rgb(0.97, 0.88, 0.70), rgb(0.95, 0.75, 0.25)]
        while y < boardTop - 3 {
            let dot = 3.0 + 1.6 * (y - standTop) / max(1, boardTop - standTop)
            for (k, c) in shirt.enumerated() {
                let phase = Double((row * 3 + k * 7) % 11)
                Sketch.line(&ctx, CGPoint(x: -phase, y: y), CGPoint(x: W + 8, y: y),
                            c.opacity(d ? 0.75 : 0.9), dot, dash: [0, CGFloat(dot * 4.4 + Double(k))])
            }
            y += rowGap; row += 1
        }
        // Aisles split the stands into sections.
        for i in 0..<7 {
            let ax = W * (Double(i) + 0.5) / 7
            Sketch.line(&ctx, CGPoint(x: ax + (ax - f.center) * 0.0, y: standTop + 2), CGPoint(x: ax + (ax - f.center) * 0.08, y: boardTop),
                        d ? rgb(0.06, 0.07, 0.11, 0.8) : rgb(0.30, 0.33, 0.40, 0.8), 2.5)
        }
        // Roof overhang with a lit edge.
        Sketch.gradient(&ctx, CGRect(x: 0, y: roof, width: W, height: standTop - roof + 3),
                        d ? [rgb(0.16, 0.17, 0.24), rgb(0.07, 0.08, 0.12)] : [rgb(0.80, 0.83, 0.88), rgb(0.55, 0.58, 0.64)])
        Sketch.line(&ctx, CGPoint(x: 0, y: roof), CGPoint(x: W, y: roof), d ? rgb(0.60, 0.65, 0.80, 0.7) : .white.opacity(0.9), 1.5)
        // Camera flashes popping in the crowd.
        let tick = Int(f.t * 4)
        var flashes = Path()
        for i in 0..<10 {
            let seed = Double(tick + i * 13)
            guard rnd(i, seed) > 0.45 else { continue }
            let fx = rnd(i, seed + 1) * W, fy = standTop + rnd(i, seed + 2) * (boardTop - standTop - 4)
            let r = d ? 2.6 : 1.8
            flashes.addEllipse(in: CGRect(x: fx - r, y: fy - r, width: 2 * r, height: 2 * r))
        }
        ctx.fill(flashes, with: .color(.white.opacity(d ? 0.95 : 0.8)))

        // Floodlight panels (on top of the roof), glowing at night.
        for lx in lights {
            let pw = 30 * s, ph = 16 * s
            let pr = CGRect(x: lx - pw / 2, y: panelY - ph / 2, width: pw, height: ph)
            if d {
                ctx.fill(Path(ellipseIn: pr.insetBy(dx: -70, dy: -60)),
                         with: .radialGradient(Gradient(colors: [rgb(0.95, 0.97, 1, 0.45), .clear]),
                                               center: CGPoint(x: pr.midX, y: pr.midY), startRadius: 4, endRadius: 85))
                var beam = Path()
                beam.move(to: CGPoint(x: pr.minX, y: pr.maxY)); beam.addLine(to: CGPoint(x: pr.maxX, y: pr.maxY))
                beam.addLine(to: CGPoint(x: f.center + (lx - f.center) * 0.15, y: gl)); beam.closeSubpath()
                ctx.fill(beam, with: .linearGradient(Gradient(colors: [rgb(0.9, 0.95, 1, 0.13), .clear]),
                                                     startPoint: CGPoint(x: lx, y: panelY), endPoint: CGPoint(x: lx, y: gl)))
            }
            ctx.fill(Path(roundedRect: pr, cornerRadius: 2), with: .color(d ? rgb(0.25, 0.27, 0.33) : rgb(0.45, 0.48, 0.55)))
            var bulbs = Path()
            for r in 0..<2 { for c in 0..<4 {
                let bx = pr.minX + pw * (Double(c) + 0.5) / 4, by = pr.minY + ph * (Double(r) + 0.5) / 2
                bulbs.addEllipse(in: CGRect(x: bx - 2.6 * s, y: by - 2.6 * s, width: 5.2 * s, height: 5.2 * s))
            } }
            ctx.fill(bulbs, with: .color(d ? rgb(1, 1, 0.92) : rgb(0.92, 0.94, 0.97)))
        }

        // Ad boards: plain colored panels, no names.
        let boardColors = [rgb(0.15, 0.40, 0.80), rgb(0.95, 0.95, 0.97), rgb(0.95, 0.55, 0.15), rgb(0.12, 0.62, 0.50)]
        let bw = W / 5
        for i in 0..<6 {
            let r = CGRect(x: Double(i) * bw - bw * 0.3, y: boardTop, width: bw - 1.5, height: boardBottom - boardTop)
            Sketch.fill(&ctx, r, boardColors[i % 4].opacity(d ? 0.85 : 1))
            Sketch.fill(&ctx, CGRect(x: r.minX + bw * 0.15, y: r.midY - 0.8, width: bw * 0.5, height: 1.6), .white.opacity(i % 4 == 1 ? 0 : 0.6))
        }

        // Pitch with a checkered mowing pattern in perspective.
        let pitch = CGRect(x: 0, y: boardBottom, width: W, height: h - boardBottom)
        Sketch.gradient(&ctx, pitch, d ? [rgb(0.16, 0.42, 0.26), rgb(0.10, 0.32, 0.19), rgb(0.06, 0.20, 0.12)]
                                       : [rgb(0.40, 0.70, 0.36), rgb(0.27, 0.60, 0.27), rgb(0.20, 0.48, 0.21)])
        let vp = CGPoint(x: gx, y: gl - 420 * s)    // vanishing point far behind the goal
        func toward(_ x0: Double, _ y: Double) -> Double { vp.x + (x0 - vp.x) * (y - vp.y) / (gl - vp.y) }
        var bands = Path()
        var by = boardBottom, bh = 4.0 * s, on = false
        while by < h {
            if on { bands.addRect(CGRect(x: 0, y: by, width: W, height: bh)) }
            by += bh; bh = min(bh * 1.30, 60); on.toggle()
        }
        ctx.fill(bands, with: .color(.white.opacity(d ? 0.05 : 0.08)))
        var strips = Path()
        let sw = W * 0.11
        var k = -12
        while k < 12 {
            let x0 = gx + Double(k) * sw
            strips.move(to: CGPoint(x: toward(x0, boardBottom), y: boardBottom))
            strips.addLine(to: CGPoint(x: toward(x0 + sw, boardBottom), y: boardBottom))
            strips.addLine(to: CGPoint(x: toward(x0 + sw, h), y: h))
            strips.addLine(to: CGPoint(x: toward(x0, h), y: h))
            strips.closeSubpath()
            k += 2
        }
        ctx.fill(strips, with: .color(.black.opacity(d ? 0.07 : 0.06)))
        // Light falling on the pitch at night.
        if d {
            ctx.fill(Path(pitch), with: .radialGradient(Gradient(colors: [rgb(0.85, 1, 0.85, 0.16), .clear]),
                                                         center: CGPoint(x: f.center, y: f.horizon), startRadius: 0, endRadius: W * 0.8))
        }

        // Markings: goal line, six-yard box, penalty box, spot and arc.
        let lineC = Color.white.opacity(d ? 0.75 : 0.88)
        var m = Path()
        m.move(to: CGPoint(x: 0, y: gl)); m.addLine(to: CGPoint(x: W, y: gl))
        func box(_ half: Double, _ depth: Double) {
            let y2 = gl + depth
            m.move(to: CGPoint(x: gx - half, y: gl))
            m.addLine(to: CGPoint(x: toward(gx - half, y2), y: y2))
            m.addLine(to: CGPoint(x: toward(gx + half, y2), y: y2))
            m.addLine(to: CGPoint(x: gx + half, y: gl))
        }
        box(g.w * 0.95, 16 * s)
        box(g.w * 2.3, 62 * s)
        let arcY = gl + 62 * s
        let arcW = g.w * 1.1
        m.move(to: CGPoint(x: toward(gx - arcW * 0.5, arcY), y: arcY))
        m.addQuadCurve(to: CGPoint(x: toward(gx + arcW * 0.5, arcY), y: arcY), control: CGPoint(x: gx, y: arcY + 30 * s))
        ctx.stroke(m, with: .color(lineC), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round, lineJoin: .round))
        let spotY = gl + 42 * s
        ctx.fill(Path(ellipseIn: CGRect(x: gx - 3, y: spotY - 1.5, width: 6, height: 3)), with: .color(lineC))

        // Goal: shadow, net (back + sides), then the white frame.
        let L = gx - g.w / 2, R = gx + g.w / 2, top = gl - g.h
        let backB = gl - 12 * s, backT = top + 6 * s, inset = g.w * 0.06
        var shadow = Path()
        shadow.move(to: CGPoint(x: L, y: gl)); shadow.addLine(to: CGPoint(x: R, y: gl))
        shadow.addLine(to: CGPoint(x: R + 18 * s, y: gl + 6 * s)); shadow.addLine(to: CGPoint(x: L + 18 * s, y: gl + 6 * s)); shadow.closeSubpath()
        ctx.fill(shadow, with: .color(.black.opacity(0.15)))
        // Net back panel (slightly tinted so it reads as a net).
        var back = Path()
        back.move(to: CGPoint(x: L, y: top)); back.addLine(to: CGPoint(x: R, y: top))
        back.addLine(to: CGPoint(x: R - inset, y: backT)); back.addLine(to: CGPoint(x: R - inset, y: backB))
        back.addLine(to: CGPoint(x: L + inset, y: backB)); back.addLine(to: CGPoint(x: L + inset, y: backT)); back.closeSubpath()
        ctx.fill(back, with: .linearGradient(Gradient(colors: d ? [rgb(0.05, 0.10, 0.10, 0.55), rgb(0.10, 0.22, 0.16, 0.55)]
                                                           : [rgb(0.25, 0.32, 0.35, 0.45), rgb(0.20, 0.38, 0.26, 0.45)]),
                                             startPoint: CGPoint(x: gx, y: top), endPoint: CGPoint(x: gx, y: gl)))
        var side = Path()
        side.move(to: CGPoint(x: L, y: top)); side.addLine(to: CGPoint(x: L + inset, y: backT))
        side.addLine(to: CGPoint(x: L + inset, y: backB)); side.addLine(to: CGPoint(x: L, y: gl)); side.closeSubpath()
        side.move(to: CGPoint(x: R, y: top)); side.addLine(to: CGPoint(x: R - inset, y: backT))
        side.addLine(to: CGPoint(x: R - inset, y: backB)); side.addLine(to: CGPoint(x: R, y: gl)); side.closeSubpath()
        ctx.fill(side, with: .color(d ? rgb(0.05, 0.12, 0.10, 0.45) : rgb(0.30, 0.40, 0.40, 0.40)))
        // Mesh lines.
        var mesh = Path()
        let cols = 14
        for i in 0...cols {
            let u = Double(i) / Double(cols)
            mesh.move(to: CGPoint(x: L + (R - L) * u, y: top))
            mesh.addLine(to: CGPoint(x: L + inset + (R - L - 2 * inset) * u, y: backT))
            mesh.addLine(to: CGPoint(x: L + inset + (R - L - 2 * inset) * u, y: backB))
        }
        let rows = 7
        for j in 1...rows {
            let v = Double(j) / Double(rows)
            let yb = backT + (backB - backT) * v
            mesh.move(to: CGPoint(x: L + (gl - top) * 0 + inset * (1 - v) * 0, y: top + (gl - top) * v))
            mesh.addLine(to: CGPoint(x: L + inset, y: yb))
            mesh.addLine(to: CGPoint(x: R - inset, y: yb))
            mesh.addLine(to: CGPoint(x: R, y: top + (gl - top) * v))
        }
        ctx.stroke(mesh, with: .color(.white.opacity(d ? 0.55 : 0.75)), lineWidth: 0.7)
        // Frame.
        var frame = Path()
        frame.move(to: CGPoint(x: L, y: gl)); frame.addLine(to: CGPoint(x: L, y: top))
        frame.addLine(to: CGPoint(x: R, y: top)); frame.addLine(to: CGPoint(x: R, y: gl))
        ctx.stroke(frame, with: .color(.black.opacity(0.18)), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round))
        ctx.stroke(frame, with: .color(d ? rgb(0.93, 0.94, 0.96) : .white), style: StrokeStyle(lineWidth: 3.6 * s, lineCap: .round, lineJoin: .round))
    }
}
