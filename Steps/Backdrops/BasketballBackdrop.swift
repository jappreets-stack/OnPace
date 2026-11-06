import SwiftUI

// Basketball: an indoor arena. Shiny hardwood with planks in perspective, painted key, free-throw circle
// and 3-point arc, a glass backboard with rim and net on a padded stanchion, an LED courtside strip,
// dim stands with camera flashes, a hanging scoreboard and arena lights. Dark mode = lights dimmed,
// spotlights on the court.
enum BasketballBackdrop {
    // The ball drops through the middle of the rim.
    static func target(_ f: BackdropFrame) -> CGPoint { CGPoint(x: f.targetX, y: layout(f).rim) }

    private static func scale(_ f: BackdropFrame) -> Double { min(1.2, max(0.75, f.horizon / 280)) }
    // Baseline y and rim y.
    private static func layout(_ f: BackdropFrame) -> (base: Double, rim: Double) {
        let s = scale(f)
        let base = f.horizon - 24 * s
        return (base, base - 74 * s)
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
        let L = layout(f)
        let gx = f.targetX, base = L.base
        let floorTop = base - 9 * s
        let stripBottom = floorTop, stripTop = stripBottom - 9 * s
        let standTop = stripTop * 0.42

        // Ceiling: dark arena roof with a soft glow.
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: W, height: standTop + 4), d
            ? [rgb(0.03, 0.03, 0.07), rgb(0.07, 0.07, 0.13)]
            : [rgb(0.16, 0.17, 0.24), rgb(0.30, 0.31, 0.40)])
        // Roof trusses.
        var truss = Path()
        for i in 0...8 {
            let x = W * Double(i) / 8
            truss.move(to: CGPoint(x: x, y: 0)); truss.addLine(to: CGPoint(x: f.center + (x - f.center) * 1.3, y: standTop))
        }
        truss.move(to: CGPoint(x: 0, y: standTop * 0.45)); truss.addLine(to: CGPoint(x: W, y: standTop * 0.45))
        ctx.stroke(truss, with: .color(.white.opacity(d ? 0.05 : 0.08)), lineWidth: 1.5)

        // Rows of arena lights.
        var bulbs = Path()
        let lightY = max(10, standTop * 0.22)
        let n = 9
        for i in 0..<n {
            let x = W * (Double(i) + 0.5) / Double(n)
            bulbs.addEllipse(in: CGRect(x: x - 3.5, y: lightY - 2.5, width: 7, height: 5))
        }
        for i in 0..<n {
            let x = W * (Double(i) + 0.5) / Double(n)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 28, y: lightY - 22, width: 56, height: 44)),
                     with: .radialGradient(Gradient(colors: [rgb(1, 0.95, 0.80, d ? 0.30 : 0.40), .clear]),
                                           center: CGPoint(x: x, y: lightY), startRadius: 1, endRadius: 28))
        }
        ctx.fill(bulbs, with: .color(rgb(1, 0.97, 0.85)))

        // Hanging scoreboard over center court (no text, just glowing panels).
        if standTop > 70 {
            let sbW = min(140, W * 0.34), sbH = min(46, standTop * 0.42)
            let sb = CGRect(x: f.center - sbW / 2, y: lightY + 12, width: sbW, height: sbH)
            Sketch.line(&ctx, CGPoint(x: sb.minX + 10, y: 0), CGPoint(x: sb.minX + 10, y: sb.minY), .black.opacity(0.5), 1.5)
            Sketch.line(&ctx, CGPoint(x: sb.maxX - 10, y: 0), CGPoint(x: sb.maxX - 10, y: sb.minY), .black.opacity(0.5), 1.5)
            ctx.fill(Path(roundedRect: sb, cornerRadius: 4), with: .color(rgb(0.08, 0.08, 0.11)))
            let screen = sb.insetBy(dx: 5, dy: 5)
            let pulse = 0.5 + 0.5 * sin(f.t * 1.2)
            ctx.fill(Path(roundedRect: screen, cornerRadius: 2),
                     with: .linearGradient(Gradient(colors: [rgb(0.20, 0.35, 0.80), rgb(0.55, 0.25, 0.75), rgb(0.95, 0.45, 0.20)]),
                                           startPoint: CGPoint(x: screen.minX - screen.width * pulse, y: screen.midY),
                                           endPoint: CGPoint(x: screen.maxX + screen.width * (1 - pulse), y: screen.midY)))
            // A fake score display: two bright blocks.
            for k in [0.25, 0.75] {
                Sketch.fill(&ctx, CGRect(x: screen.minX + screen.width * k - 9, y: screen.midY - 5, width: 18, height: 10), .white.opacity(0.8))
            }
            Sketch.fill(&ctx, CGRect(x: sb.minX + 3, y: sb.maxY - 2, width: sbW - 6, height: 2), rgb(1, 0.6, 0.2, 0.9))
        }

        // Stands: dim, with rows of fans and camera flashes.
        Sketch.gradient(&ctx, CGRect(x: 0, y: standTop, width: W, height: stripTop - standTop),
                        d ? [rgb(0.06, 0.06, 0.10), rgb(0.12, 0.11, 0.16)] : [rgb(0.20, 0.20, 0.27), rgb(0.33, 0.32, 0.38)])
        let shirts: [Color] = d
            ? [rgb(0.45, 0.25, 0.25), rgb(0.40, 0.40, 0.45), rgb(0.25, 0.30, 0.50), rgb(0.48, 0.38, 0.20)]
            : [rgb(0.75, 0.30, 0.28), rgb(0.85, 0.85, 0.88), rgb(0.30, 0.42, 0.75), rgb(0.88, 0.70, 0.30)]
        let rowGap = max(4.5, 5.5 * s)
        var y = standTop + rowGap, row = 0
        while y < stripTop - 3 {
            let t01 = (y - standTop) / max(1, stripTop - standTop)
            let dot = 3.0 + 1.6 * t01
            for (k, c) in shirts.enumerated() {
                let phase = Double((row * 3 + k * 5) % 11)
                Sketch.line(&ctx, CGPoint(x: -phase, y: y), CGPoint(x: W + 8, y: y),
                            c.opacity((d ? 0.55 : 0.75) * (0.7 + 0.3 * t01)), dot, dash: [0, CGFloat(dot * 4.4 + Double(k))])
            }
            y += rowGap; row += 1
        }
        for i in 0..<6 {
            let ax = W * (Double(i) + 0.5) / 6
            Sketch.line(&ctx, CGPoint(x: ax, y: standTop + 2), CGPoint(x: ax + (ax - f.center) * 0.08, y: stripTop),
                        .black.opacity(0.35), 2.5)
        }
        // Balcony edge.
        Sketch.fill(&ctx, CGRect(x: 0, y: standTop - 3, width: W, height: 4), d ? rgb(0.18, 0.18, 0.24) : rgb(0.42, 0.42, 0.50))
        let tick = Int(f.t * 4)
        var flashes = Path()
        for i in 0..<12 {
            let seed = Double(tick + i * 11)
            guard rnd(i, seed) > 0.5 else { continue }
            let fx = rnd(i, seed + 1) * W, fy = standTop + rnd(i, seed + 2) * (stripTop - standTop - 4)
            flashes.addEllipse(in: CGRect(x: fx - 2.2, y: fy - 2.2, width: 4.4, height: 4.4))
        }
        ctx.fill(flashes, with: .color(.white.opacity(0.9)))

        // LED courtside strip with a slow moving shine.
        let strip = CGRect(x: 0, y: stripTop, width: W, height: stripBottom - stripTop)
        Sketch.fill(&ctx, strip, rgb(0.06, 0.06, 0.09))
        let sx = (f.t * 30).truncatingRemainder(dividingBy: W * 1.5) - W * 0.25
        ctx.fill(Path(strip.insetBy(dx: 0, dy: 1.5)),
                 with: .linearGradient(Gradient(colors: [rgb(0.15, 0.35, 0.85), rgb(0.40, 0.75, 1.0), rgb(0.15, 0.35, 0.85)]),
                                       startPoint: CGPoint(x: sx - 80, y: 0), endPoint: CGPoint(x: sx + 80, y: 0)))

        // Hardwood floor.
        let floorR = CGRect(x: 0, y: floorTop, width: W, height: h - floorTop)
        Sketch.gradient(&ctx, floorR, d
            ? [rgb(0.42, 0.29, 0.17), rgb(0.33, 0.22, 0.13), rgb(0.24, 0.16, 0.10)]
            : [rgb(0.80, 0.58, 0.35), rgb(0.86, 0.64, 0.40), rgb(0.74, 0.52, 0.31)])
        let vp = CGPoint(x: gx, y: base - 520 * s)
        func toward(_ x0: Double, _ y: Double) -> Double { vp.x + (x0 - vp.x) * (y - vp.y) / (base - vp.y) }
        // Planks running toward the hoop, plus staggered plank ends.
        var planks = Path()
        let pw = 7.0
        var px = gx - W * 1.6
        var pi = 0
        while px < gx + W * 1.6 {
            let xb = toward(px, h)
            if xb > -W && xb < W * 2 {
                planks.move(to: CGPoint(x: px, y: floorTop)); planks.addLine(to: CGPoint(x: xb, y: h))
            }
            px += pw; pi += 1
        }
        ctx.stroke(planks, with: .color(.black.opacity(d ? 0.18 : 0.10)), lineWidth: 0.7)
        var joints = Path()
        for i in 0..<70 {
            let yy = floorTop + pow(rnd(i, 21), 1.6) * (h - floorTop)
            let k = Int(rnd(i, 22) * 300) - 150
            let x0 = gx + Double(k) * pw
            let a = toward(x0, yy), b = toward(x0 + pw, yy)
            joints.move(to: CGPoint(x: a, y: yy)); joints.addLine(to: CGPoint(x: b, y: yy))
        }
        ctx.stroke(joints, with: .color(.black.opacity(d ? 0.18 : 0.10)), lineWidth: 0.7)
        // Alternating plank tones for a natural wood look.
        var tone = Path()
        var tk = -60
        while tk < 60 {
            let x0 = gx + Double(tk) * pw * 3
            tone.move(to: CGPoint(x: x0, y: floorTop)); tone.addLine(to: CGPoint(x: x0 + pw, y: floorTop))
            tone.addLine(to: CGPoint(x: toward(x0 + pw, h), y: h)); tone.addLine(to: CGPoint(x: toward(x0, h), y: h)); tone.closeSubpath()
            tk += 2
        }
        ctx.fill(tone, with: .color(d ? rgb(0.10, 0.05, 0.0, 0.12) : rgb(0.55, 0.30, 0.10, 0.08)))

        // Court markings: painted key, free-throw circle, 3-point arc, baseline.
        let lineC = Color.white.opacity(d ? 0.75 : 0.92)
        let keyHalf = W * 0.11
        let ftY = base + 58 * s
        var key = Path()
        key.move(to: CGPoint(x: gx - keyHalf, y: base)); key.addLine(to: CGPoint(x: gx + keyHalf, y: base))
        key.addLine(to: CGPoint(x: toward(gx + keyHalf, ftY), y: ftY)); key.addLine(to: CGPoint(x: toward(gx - keyHalf, ftY), y: ftY)); key.closeSubpath()
        ctx.fill(key, with: .color(d ? rgb(0.12, 0.20, 0.45, 0.85) : rgb(0.16, 0.30, 0.66, 0.88)))
        var m = Path()
        m.addPath(key)
        m.move(to: CGPoint(x: 0, y: base)); m.addLine(to: CGPoint(x: W, y: base))
        // Free-throw circle (an ellipse in perspective).
        let ftHalf = toward(gx + keyHalf, ftY) - gx
        m.addEllipse(in: CGRect(x: gx - ftHalf, y: ftY - 12 * s, width: 2 * ftHalf, height: 24 * s))
        // 3-point line: short straight bits from the baseline, then a wide arc toward the viewer.
        let tpHalf = W * 0.52, tpStraight = base + 16 * s, tpDeep = base + 118 * s
        let lx = toward(gx - tpHalf, tpStraight), rx = toward(gx + tpHalf, tpStraight)
        m.move(to: CGPoint(x: gx - tpHalf, y: base)); m.addLine(to: CGPoint(x: lx, y: tpStraight))
        m.addCurve(to: CGPoint(x: gx, y: tpDeep), control1: CGPoint(x: lx, y: tpStraight + (tpDeep - tpStraight) * 0.7),
                   control2: CGPoint(x: gx - (gx - lx) * 0.55, y: tpDeep))
        m.addCurve(to: CGPoint(x: rx, y: tpStraight), control1: CGPoint(x: gx + (rx - gx) * 0.55, y: tpDeep),
                   control2: CGPoint(x: rx, y: tpStraight + (tpDeep - tpStraight) * 0.7))
        m.addLine(to: CGPoint(x: gx + tpHalf, y: base))
        ctx.stroke(m, with: .color(lineC), style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round, lineJoin: .round))

        // Sheen: glossy reflections of the arena lights on the floor.
        for i in 0..<4 {
            let x = W * (0.12 + 0.26 * Double(i))
            let r = CGRect(x: x - 26, y: floorTop + 4, width: 52, height: (h - floorTop) * 0.45)
            ctx.fill(Path(ellipseIn: r), with: .linearGradient(Gradient(colors: [.white.opacity(d ? 0.10 : 0.20), .clear]),
                                                               startPoint: CGPoint(x: x, y: r.minY), endPoint: CGPoint(x: x, y: r.maxY)))
        }
        if d {
            // Spotlight pool on the court.
            ctx.fill(Path(floorR), with: .radialGradient(Gradient(colors: [rgb(1, 0.85, 0.6, 0.22), .clear]),
                                                         center: CGPoint(x: f.center + W * 0.1, y: f.horizon + 20), startRadius: 0, endRadius: W * 0.75))
        }

        // Stanchion: padded base behind the baseline, pole and arm up to the backboard.
        let bbW = min(86, W * 0.21), bbH = 50 * s
        let bbBottom = L.rim + 6 * s, bbTop = bbBottom - bbH
        let stanX = gx, stanY = floorTop - 2
        ctx.fill(Path(ellipseIn: CGRect(x: stanX - 26 * s, y: stanY + 2, width: 52 * s, height: 10 * s)), with: .color(.black.opacity(0.25)))
        var pad = Path()
        pad.move(to: CGPoint(x: stanX - 20 * s, y: stanY + 6 * s)); pad.addLine(to: CGPoint(x: stanX + 20 * s, y: stanY + 6 * s))
        pad.addLine(to: CGPoint(x: stanX + 14 * s, y: stanY - 18 * s)); pad.addLine(to: CGPoint(x: stanX - 14 * s, y: stanY - 18 * s)); pad.closeSubpath()
        ctx.fill(pad, with: .linearGradient(Gradient(colors: [rgb(0.20, 0.30, 0.62), rgb(0.10, 0.16, 0.36)]),
                                            startPoint: CGPoint(x: stanX - 20 * s, y: 0), endPoint: CGPoint(x: stanX + 20 * s, y: 0)))
        // Pole up from the pad, and an arm reaching forward to the back of the backboard (seen through the glass).
        var pole = Path()
        pole.move(to: CGPoint(x: stanX, y: stanY - 16 * s)); pole.addLine(to: CGPoint(x: stanX, y: bbBottom))
        pole.move(to: CGPoint(x: stanX, y: bbBottom)); pole.addLine(to: CGPoint(x: stanX, y: bbTop + bbH * 0.35))
        ctx.stroke(pole, with: .color(rgb(0.10, 0.11, 0.14)), style: StrokeStyle(lineWidth: 6.5 * s, lineCap: .round))
        Sketch.line(&ctx, CGPoint(x: stanX - 1.2 * s, y: stanY - 16 * s), CGPoint(x: stanX - 1.2 * s, y: bbBottom + 4),
                    .white.opacity(d ? 0.15 : 0.25), 1.2 * s)
        // Blue padding on the lower part of the pole.
        Sketch.fill(&ctx, CGRect(x: stanX - 5 * s, y: stanY - 40 * s, width: 10 * s, height: 26 * s), rgb(0.18, 0.28, 0.60))
        // Shadow of the hoop on the floor.
        ctx.fill(Path(ellipseIn: CGRect(x: gx - 22 * s, y: base + 6 * s, width: 44 * s, height: 7 * s)), with: .color(.black.opacity(0.12)))

        // Glass backboard with a white frame and shooter's square.
        let bb = CGRect(x: gx - bbW / 2, y: bbTop, width: bbW, height: bbH)
        ctx.fill(Path(roundedRect: bb, cornerRadius: 2), with: .linearGradient(
            Gradient(colors: [.white.opacity(d ? 0.22 : 0.40), .white.opacity(d ? 0.08 : 0.18)]),
            startPoint: CGPoint(x: bb.minX, y: bb.minY), endPoint: CGPoint(x: bb.maxX, y: bb.maxY)))
        // A glint across the glass.
        var glint = Path()
        glint.move(to: CGPoint(x: bb.minX + bbW * 0.12, y: bb.maxY)); glint.addLine(to: CGPoint(x: bb.minX + bbW * 0.30, y: bb.minY))
        glint.addLine(to: CGPoint(x: bb.minX + bbW * 0.40, y: bb.minY)); glint.addLine(to: CGPoint(x: bb.minX + bbW * 0.22, y: bb.maxY)); glint.closeSubpath()
        ctx.fill(glint, with: .color(.white.opacity(0.18)))
        ctx.stroke(Path(roundedRect: bb, cornerRadius: 2), with: .color(.white.opacity(0.95)), lineWidth: 2.4 * s)
        let sq = CGRect(x: gx - bbW * 0.17, y: bbBottom - bbH * 0.48, width: bbW * 0.34, height: bbH * 0.36)
        ctx.stroke(Path(sq), with: .color(.white.opacity(0.95)), lineWidth: 1.8 * s)
        Sketch.fill(&ctx, CGRect(x: bb.minX, y: bb.maxY - 3 * s, width: bbW, height: 3 * s), rgb(0.95, 0.40, 0.12))

        // Net hanging under the rim, swaying a little.
        let rimW = 30 * s, rimH = 7 * s
        let netTop = L.rim, netBot = L.rim + 22 * s
        let sway = 1.2 * sin(f.t * 2.0)
        var net = Path()
        let strands = 7
        for i in 0...strands {
            let u = Double(i) / Double(strands)
            let xt = gx - rimW / 2 + rimW * u
            let xb = gx - rimW * 0.30 + rimW * 0.60 * u + sway
            net.move(to: CGPoint(x: xt, y: netTop)); net.addLine(to: CGPoint(x: xb, y: netBot))
            // Diamond mesh: zig-zag to the neighbor strand.
            if i < strands {
                let u2 = Double(i + 1) / Double(strands)
                for j in 0..<3 {
                    let v1 = Double(j) / 3, v2 = (Double(j) + 0.5) / 3
                    func pt(_ uu: Double, _ v: Double) -> CGPoint {
                        let a = gx - rimW / 2 + rimW * uu, b = gx - rimW * 0.30 + rimW * 0.60 * uu + sway
                        return CGPoint(x: a + (b - a) * v, y: netTop + (netBot - netTop) * v)
                    }
                    net.move(to: pt(u, v1)); net.addLine(to: pt(u2, v2))
                    net.move(to: pt(u2, v1)); net.addLine(to: pt(u, v2))
                }
            }
        }
        ctx.stroke(net, with: .color(.white.opacity(0.9)), lineWidth: 0.9)
        // Rim: back half thinner, front half bold.
        let rimR = CGRect(x: gx - rimW / 2, y: L.rim - rimH / 2, width: rimW, height: rimH)
        ctx.stroke(Path(ellipseIn: rimR), with: .color(rgb(0.80, 0.30, 0.08)), lineWidth: 2 * s)
        var front = Path()
        front.addArc(center: CGPoint(x: gx, y: L.rim), radius: rimW / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false,
                     transform: CGAffineTransform(translationX: gx, y: L.rim).scaledBy(x: 1, y: rimH / rimW).translatedBy(x: -gx, y: -L.rim))
        ctx.stroke(front, with: .color(rgb(1.0, 0.45, 0.12)), lineWidth: 3 * s)
    }
}
