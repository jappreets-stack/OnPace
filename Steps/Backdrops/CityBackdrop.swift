import SwiftUI

// City: the mini-me waits on a sidewalk to hail a taxi. Layered skyline (far, mid, near storefronts),
// sidewalk with a curb, a street with lane markings and a crosswalk, a street lamp, and a taxi
// sign where the cab pulls up. Night = lit windows, glowing lamp and shop fronts.
enum CityBackdrop {
    // Ground perspective. X across (meters), d = depth (meters, + = away from the viewer).
    private struct Cam {
        let cx: Double, vy: Double, hp: Double, m: Double, z0: Double
        func z(_ d: Double) -> Double { max(0.05, 1 + d / z0) }
        func y(_ d: Double) -> Double { vy + hp / z(d) }
        func x(_ X: Double, _ d: Double) -> Double { cx + X * m / z(d) }
        func p(_ X: Double, _ d: Double) -> CGPoint { CGPoint(x: x(X, d), y: y(d)) }
    }

    private static let curbD = -0.7, wallD = 3.8, nearCurbD = -13.4

    private static func cam(_ f: BackdropFrame) -> Cam {
        let hp = min(0.85 * f.horizon, 0.55 * f.width)
        return Cam(cx: f.center, vy: f.horizon - hp, hp: hp, m: f.width / 16, z0: 20)
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
    private static func rnd(_ i: Int, _ s: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(s) * 78.233) * 43758.5453
        return v - floor(v)
    }
    private static func poly(_ ctx: inout GraphicsContext, _ pts: [CGPoint], _ c: Color) {
        var p = Path(); p.addLines(pts); p.closeSubpath(); ctx.fill(p, with: .color(c))
    }

    static func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        let c = cam(f)
        let dk = f.dark
        let yB = c.y(wallD)            // where the buildings meet the sidewalk
        let yCurb = c.y(curbD)

        // Sky
        Sketch.gradient(&ctx, CGRect(x: 0, y: 0, width: f.width, height: yB + 1), dk
            ? [rgb(0.05, 0.06, 0.17), rgb(0.15, 0.14, 0.32), rgb(0.40, 0.24, 0.40)]
            : [rgb(0.38, 0.64, 0.94), rgb(0.66, 0.83, 0.98), rgb(0.95, 0.93, 0.90)])
        if dk { stars(&ctx, f, maxY: yB * 0.35) } else { clouds(&ctx, f, maxY: yB * 0.45) }

        // Skyline, back to front.
        skyline(&ctx, f, base: yB, lo: 0.42, hi: 0.80, seed: 1,
                body: dk ? rgb(0.16, 0.17, 0.32) : rgb(0.70, 0.78, 0.88), windows: 0)
        skyline(&ctx, f, base: yB, lo: 0.30, hi: 0.66, seed: 2,
                body: dk ? rgb(0.11, 0.12, 0.24) : rgb(0.52, 0.61, 0.74), windows: 1)
        nearBuildings(&ctx, f, base: yB)

        // Sidewalk (with slab joints converging into the distance) and curb.
        let walk = CGRect(x: 0, y: yB, width: f.width, height: yCurb - yB)
        Sketch.gradient(&ctx, walk, dk ? [rgb(0.26, 0.27, 0.33), rgb(0.33, 0.33, 0.40)] : [rgb(0.74, 0.73, 0.72), rgb(0.84, 0.83, 0.81)])
        let joint = dk ? rgb(0, 0, 0, 0.25) : rgb(0.45, 0.43, 0.42, 0.35)
        var X = -40.0
        while X <= 40 {
            Sketch.line(&ctx, c.p(X, wallD), c.p(X, curbD), joint, 0.8)
            X += 2.4
        }
        Sketch.line(&ctx, CGPoint(x: 0, y: c.y(1.6)), CGPoint(x: f.width, y: c.y(1.6)), joint, 0.8)
        Sketch.gradient(&ctx, CGRect(x: 0, y: yB, width: f.width, height: 5), [.black.opacity(0.18), .clear])
        let curbH = max(4, 0.012 * f.width)
        Sketch.fill(&ctx, CGRect(x: 0, y: yCurb - 1.5, width: f.width, height: 2.5), dk ? rgb(0.52, 0.53, 0.58) : rgb(0.93, 0.92, 0.90))
        Sketch.fill(&ctx, CGRect(x: 0, y: yCurb + 1, width: f.width, height: curbH), dk ? rgb(0.22, 0.22, 0.27) : rgb(0.58, 0.57, 0.57))

        // Road down to the bottom.
        let road = CGRect(x: 0, y: yCurb + 1 + curbH, width: f.width, height: f.height - yCurb - curbH)
        Sketch.gradient(&ctx, road, dk ? [rgb(0.17, 0.17, 0.22), rgb(0.11, 0.11, 0.15)] : [rgb(0.40, 0.41, 0.45), rgb(0.30, 0.31, 0.35)])
        Sketch.gradient(&ctx, CGRect(x: 0, y: road.minY, width: f.width, height: 10), [.black.opacity(0.25), .clear])
        // Lane markings: dashed white, double yellow in the middle.
        func dashes(_ d: Double, _ col: Color, _ w: Double) {
            let z = c.z(d), y = c.y(d)
            var x0 = fmod(-c.x(0, d), 1) - 3.0 * c.m / z
            while x0 < f.width {
                let len = 3.0 * c.m / z
                Sketch.fill(&ctx, CGRect(x: x0, y: y - w / 2, width: len, height: w), col)
                x0 += len * 2.2
            }
        }
        let white = Color.white.opacity(dk ? 0.6 : 0.85)
        let yellow = rgb(0.98, 0.80, 0.22, dk ? 0.8 : 0.95)
        dashes(-4.2, white, 2.4 / c.z(-4.2))
        for dd in [-7.55, -7.85] {
            let y = c.y(dd)
            Sketch.fill(&ctx, CGRect(x: 0, y: y - 1.2 / c.z(dd), width: f.width, height: 2.4 / c.z(dd)), yellow)
        }
        dashes(-11.4, white, 2.4 / c.z(-11.4))

        // Crosswalk on the left: stripes running toward the vanishing point.
        let cwX = -0.36 * f.width / c.m
        let dFar = curbD - 0.3
        var bd = dFar
        while bd - 0.55 > nearCurbD {
            poly(&ctx, [c.p(cwX - 1.8, bd), c.p(cwX + 1.8, bd), c.p(cwX + 1.8, bd - 0.55), c.p(cwX - 1.8, bd - 0.55)],
                 .white.opacity(dk ? 0.5 : 0.8))
            bd -= 1.1
        }

        // Near curb and sidewalk at the very bottom (we are looking across the street).
        let yNear = c.y(nearCurbD)
        if yNear < f.height {
            Sketch.fill(&ctx, CGRect(x: 0, y: yNear, width: f.width, height: 8), dk ? rgb(0.30, 0.30, 0.36) : rgb(0.70, 0.69, 0.68))
            Sketch.gradient(&ctx, CGRect(x: 0, y: yNear + 8, width: f.width, height: f.height - yNear - 8),
                            dk ? [rgb(0.28, 0.28, 0.34), rgb(0.20, 0.20, 0.25)] : [rgb(0.80, 0.79, 0.77), rgb(0.70, 0.69, 0.67)])
        }
        // Manhole cover
        let mh = c.p(-0.12 * f.width / c.m * c.z(-5.6), -5.6)
        let mr = 0.45 * c.m / c.z(-5.6)
        ctx.fill(Path(ellipseIn: CGRect(x: mh.x - mr, y: mh.y - mr * 0.3, width: mr * 2, height: mr * 0.6)), with: .color(.black.opacity(0.28)))

        // Street furniture: lamp (left), hydrant, planter tree (right), taxi sign at the pickup spot.
        lamp(&ctx, f, c)
        hydrant(&ctx, f, c.p(-0.46 * f.width / c.m * c.z(0.2), 0.2))
        tree(&ctx, f, c.p(0.44 * f.width / c.m * c.z(2.6), 2.6))
        taxiSign(&ctx, f, c)

        let vig = CGRect(x: 0, y: f.horizon + 40, width: f.width, height: f.height - f.horizon - 40)
        Sketch.gradient(&ctx, vig, [.clear, rgb(0, 0, 0.05, dk ? 0.35 : 0.18)])
    }

    // The curb lane, just right of the mini-me, where the taxi pulls up.
    static func target(_ f: BackdropFrame) -> CGPoint {
        let c = cam(f)
        return CGPoint(x: f.targetX, y: c.y(-2.2))
    }

    // MARK: - Pieces

    private static func skyline(_ ctx: inout GraphicsContext, _ f: BackdropFrame, base: Double, lo: Double, hi: Double,
                                seed: Int, body: Color, windows: Int) {
        let dk = f.dark
        var x = -10.0 - rnd(seed, 9) * 30
        var i = 0
        while x < f.width + 10 {
            let w = f.width * (0.10 + 0.13 * rnd(i, seed))
            let h = base * (lo + (hi - lo) * rnd(i, seed + 10))
            let top = base - h
            let r = CGRect(x: x, y: top, width: w, height: h + 1)
            Sketch.fill(&ctx, r, body)
            // a few roof shapes: antenna, stepped top, water tank
            let kind = Int(rnd(i, seed + 20) * 4)
            if kind == 0 {
                Sketch.line(&ctx, CGPoint(x: r.midX, y: top), CGPoint(x: r.midX, y: top - h * 0.18), body, 1.5)
                if dk && sin(f.t * 2 + Double(i)) > 0.3 {
                    ctx.fill(Path(ellipseIn: CGRect(x: r.midX - 1.6, y: top - h * 0.18 - 1.6, width: 3.2, height: 3.2)), with: .color(rgb(1, 0.3, 0.3)))
                }
            } else if kind == 1 {
                Sketch.fill(&ctx, CGRect(x: x + w * 0.2, y: top - h * 0.06, width: w * 0.6, height: h * 0.06 + 1), body)
            } else if kind == 2 {
                Sketch.fill(&ctx, CGRect(x: x + w * 0.6, y: top - 9, width: 9, height: 9), body)
                Sketch.line(&ctx, CGPoint(x: x + w * 0.6 + 4.5, y: top - 13), CGPoint(x: x + w * 0.6 + 4.5, y: top - 9), body, 1)
            }
            // side shading for depth
            Sketch.fill(&ctx, CGRect(x: x + w * 0.78, y: top, width: w * 0.22, height: h), .black.opacity(dk ? 0.18 : 0.08))
            if windows > 0 {
                let cols = max(2, Int(w / 9)), rows = max(3, Int(h / 11))
                let cw = w / Double(cols)
                for cI in 0..<cols {
                    if dk {
                        for rI in 0..<rows where rnd(i * 37 + cI * 7 + rI, seed + Int(f.t / 9)) < 0.22 {
                            Sketch.fill(&ctx, CGRect(x: x + Double(cI) * cw + cw * 0.3, y: top + 6 + Double(rI) * 11, width: cw * 0.4, height: 5),
                                        rgb(1, 0.85, 0.50, 0.75))
                        }
                    } else {
                        Sketch.fill(&ctx, CGRect(x: x + Double(cI) * cw + cw * 0.3, y: top + 5, width: cw * 0.4, height: h - 5),
                                    rgb(0.80, 0.88, 0.97, 0.35))
                    }
                }
            } else if dk {
                for k in 0..<3 where rnd(i * 5 + k, seed) < 0.6 {
                    Sketch.fill(&ctx, CGRect(x: x + w * (0.15 + 0.25 * Double(k)), y: top + h * (0.15 + 0.5 * rnd(i, k)), width: 2.5, height: 2.5),
                                rgb(1, 0.85, 0.55, 0.55))
                }
            }
            x += w + f.width * 0.01 * rnd(i, seed + 30)
            i += 1
        }
        // haze toward the ground for depth
        Sketch.gradient(&ctx, CGRect(x: 0, y: base * (1 - hi), width: f.width, height: base * hi),
                        [.clear, (dk ? rgb(0.35, 0.25, 0.45) : rgb(0.92, 0.94, 0.97)).opacity(0.35)])
    }

    // Two big storefront buildings left and right, a low café behind the mini-me.
    private static func nearBuildings(_ ctx: inout GraphicsContext, _ f: BackdropFrame, base: Double) {
        let dk = f.dark
        let gap = 72.0
        let leftR = CGRect(x: -6, y: base - min(base * 0.6, 190), width: f.center - gap + 6, height: min(base * 0.6, 190))
        let rightR = CGRect(x: f.center + gap, y: base - min(base * 0.48, 150), width: f.width - f.center - gap + 6, height: min(base * 0.48, 150))
        let cafe = CGRect(x: f.center - gap - 4, y: base - 58, width: gap * 2 + 8, height: 58)

        building(&ctx, f, leftR, facade: dk ? rgb(0.33, 0.20, 0.20) : rgb(0.70, 0.40, 0.33), seed: 3, awning: rgb(0.20, 0.55, 0.45))
        building(&ctx, f, rightR, facade: dk ? rgb(0.24, 0.27, 0.34) : rgb(0.86, 0.79, 0.66), seed: 4, awning: rgb(0.85, 0.35, 0.30))

        // Café: one story, flat roof, big window, striped awning.
        Sketch.fill(&ctx, cafe, dk ? rgb(0.20, 0.24, 0.30) : rgb(0.58, 0.70, 0.72))
        Sketch.fill(&ctx, CGRect(x: cafe.minX - 3, y: cafe.minY - 4, width: cafe.width + 6, height: 5), dk ? rgb(0.28, 0.32, 0.40) : rgb(0.46, 0.56, 0.60))
        let win = CGRect(x: cafe.minX + 10, y: cafe.minY + 18, width: cafe.width - 20, height: cafe.height - 22)
        Sketch.gradient(&ctx, win, dk ? [rgb(1, 0.80, 0.48, 0.85), rgb(0.95, 0.62, 0.35, 0.85)] : [rgb(0.80, 0.90, 0.98), rgb(0.55, 0.70, 0.82)])
        stripedAwning(&ctx, CGRect(x: cafe.minX + 4, y: cafe.minY + 5, width: cafe.width - 8, height: 12), rgb(0.95, 0.70, 0.25), dk)
    }

    private static func building(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ r: CGRect, facade: Color, seed: Int, awning: Color) {
        let dk = f.dark
        Sketch.fill(&ctx, r, facade)
        // cornice + side shade
        Sketch.fill(&ctx, CGRect(x: r.minX - 3, y: r.minY, width: r.width + 6, height: 7), facade.opacity(0.9))
        Sketch.fill(&ctx, CGRect(x: r.minX - 3, y: r.minY + 7, width: r.width + 6, height: 2), .black.opacity(0.2))
        let shopH = min(56, r.height * 0.32)
        let upper = CGRect(x: r.minX, y: r.minY + 14, width: r.width, height: r.height - 14 - shopH - 8)
        // windows
        let cols = max(2, Int(r.width / 34)), rows = max(2, Int(upper.height / 30))
        let cw = r.width / Double(cols), rh = upper.height / Double(rows)
        for i in 0..<cols {
            for j in 0..<rows {
                let w = CGRect(x: r.minX + Double(i) * cw + cw * 0.24, y: upper.minY + Double(j) * rh + rh * 0.18, width: cw * 0.52, height: rh * 0.62)
                let lit = dk && rnd(i * 13 + j, seed + Int((f.t + Double(i * 3 + j)) / 11)) < 0.5
                if dk {
                    Sketch.fill(&ctx, w, lit ? rgb(1, 0.84, 0.52) : rgb(0.10, 0.12, 0.20))
                } else {
                    Sketch.gradient(&ctx, w, [rgb(0.62, 0.78, 0.93), rgb(0.40, 0.55, 0.72)])
                    // sky reflection streak
                    Sketch.fill(&ctx, CGRect(x: w.minX + w.width * 0.15, y: w.minY, width: w.width * 0.18, height: w.height), .white.opacity(0.25))
                }
                Sketch.fill(&ctx, CGRect(x: w.minX - 2, y: w.maxY, width: w.width + 4, height: 2.5), .black.opacity(0.18))
            }
        }
        // shop front: glass, door, awning
        let shop = CGRect(x: r.minX + 8, y: r.maxY - shopH, width: r.width - 16, height: shopH)
        Sketch.fill(&ctx, CGRect(x: r.minX, y: shop.minY - 8, width: r.width, height: 8), .black.opacity(0.15))
        Sketch.gradient(&ctx, shop, dk ? [rgb(1, 0.82, 0.50, 0.9), rgb(0.92, 0.60, 0.32, 0.9)] : [rgb(0.78, 0.88, 0.96), rgb(0.50, 0.64, 0.78)])
        var mx = shop.minX + shop.width / 3
        while mx < shop.maxX - 4 {
            Sketch.line(&ctx, CGPoint(x: mx, y: shop.minY), CGPoint(x: mx, y: shop.maxY), facade, 3)
            mx += shop.width / 3
        }
        stripedAwning(&ctx, CGRect(x: shop.minX - 4, y: shop.minY - 4, width: shop.width + 8, height: min(16, shopH * 0.3)), awning, dk)
        if dk {
            ctx.fill(Path(ellipseIn: CGRect(x: shop.minX, y: r.maxY - 6, width: shop.width, height: 24)),
                     with: .radialGradient(Gradient(colors: [rgb(1, 0.8, 0.5, 0.35), .clear]),
                                           center: CGPoint(x: shop.midX, y: r.maxY + 4), startRadius: 0, endRadius: shop.width * 0.55))
        }
    }

    private static func stripedAwning(_ ctx: inout GraphicsContext, _ r: CGRect, _ col: Color, _ dk: Bool) {
        let a = col.opacity(dk ? 0.75 : 1)
        Sketch.fill(&ctx, r, .white.opacity(dk ? 0.7 : 0.95))
        let n = max(4, Int(r.width / 10))
        let sw = r.width / Double(n)
        for i in stride(from: 0, to: n, by: 2) {
            Sketch.fill(&ctx, CGRect(x: r.minX + Double(i) * sw, y: r.minY, width: sw, height: r.height), a)
        }
        // scalloped edge
        for i in 0..<n {
            let cx = r.minX + (Double(i) + 0.5) * sw
            ctx.fill(Path(ellipseIn: CGRect(x: cx - sw / 2, y: r.maxY - sw / 2, width: sw, height: sw)),
                     with: .color(i % 2 == 0 ? a : .white.opacity(dk ? 0.7 : 0.95)))
        }
        Sketch.gradient(&ctx, CGRect(x: r.minX, y: r.maxY + sw / 2, width: r.width, height: 6), [.black.opacity(0.18), .clear])
    }

    private static func lamp(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ c: Cam) {
        let dk = f.dark
        let d = curbD + 0.5
        let base = c.p(-0.30 * f.width / c.m * c.z(d), d)
        let h = min(170, base.y * 0.72)
        let pole = dk ? rgb(0.30, 0.32, 0.40) : rgb(0.20, 0.24, 0.28)
        let top = CGPoint(x: base.x, y: base.y - h)
        var arm = Path()
        arm.move(to: CGPoint(x: base.x, y: base.y))
        arm.addLine(to: top)
        arm.addQuadCurve(to: CGPoint(x: base.x + 26, y: top.y + 6), control: CGPoint(x: base.x + 4, y: top.y - 12))
        ctx.stroke(arm, with: .color(pole), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        Sketch.fill(&ctx, CGRect(x: base.x - 4.5, y: base.y - 12, width: 9, height: 12), pole)
        let head = CGPoint(x: base.x + 26, y: top.y + 9)
        if dk {
            // light cone and pool on the sidewalk
            var cone = Path()
            cone.addLines([CGPoint(x: head.x - 5, y: head.y), CGPoint(x: head.x + 5, y: head.y),
                           CGPoint(x: head.x + 46, y: base.y + 4), CGPoint(x: head.x - 46, y: base.y + 4)])
            cone.closeSubpath()
            ctx.fill(cone, with: .linearGradient(Gradient(colors: [rgb(1, 0.88, 0.6, 0.30), rgb(1, 0.88, 0.6, 0.04)]),
                                                 startPoint: head, endPoint: CGPoint(x: head.x, y: base.y)))
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 55, y: base.y - 6, width: 110, height: 18)), with: .color(rgb(1, 0.88, 0.6, 0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 28, y: head.y - 28, width: 56, height: 56)),
                     with: .radialGradient(Gradient(colors: [rgb(1, 0.9, 0.65, 0.55), .clear]), center: head, startRadius: 2, endRadius: 28))
        }
        var shade = Path()
        shade.addLines([CGPoint(x: head.x - 9, y: head.y), CGPoint(x: head.x + 9, y: head.y), CGPoint(x: head.x + 4, y: head.y - 6), CGPoint(x: head.x - 4, y: head.y - 6)])
        shade.closeSubpath()
        ctx.fill(shade, with: .color(pole))
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - 5, y: head.y - 1.5, width: 10, height: 4)), with: .color(dk ? rgb(1, 0.95, 0.75) : rgb(0.95, 0.95, 0.88)))
    }

    private static func hydrant(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ p: CGPoint) {
        let red = f.dark ? rgb(0.70, 0.18, 0.18) : rgb(0.88, 0.22, 0.20)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 2, width: 18, height: 5)), with: .color(.black.opacity(0.2)))
        ctx.fill(Path(roundedRect: CGRect(x: p.x - 5, y: p.y - 20, width: 10, height: 20), cornerRadius: 2), with: .color(red))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 25, width: 12, height: 10)), with: .color(red))
        Sketch.fill(&ctx, CGRect(x: p.x - 8.5, y: p.y - 15, width: 17, height: 4), red)
        Sketch.fill(&ctx, CGRect(x: p.x - 6.5, y: p.y - 4, width: 13, height: 3), red.opacity(0.8))
    }

    private static func tree(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ p: CGPoint) {
        let dk = f.dark
        let h = min(120, p.y * 0.5)
        Sketch.fill(&ctx, CGRect(x: p.x - 13, y: p.y - 10, width: 26, height: 10), dk ? rgb(0.30, 0.30, 0.35) : rgb(0.55, 0.52, 0.50))
        Sketch.line(&ctx, CGPoint(x: p.x, y: p.y - 10), CGPoint(x: p.x, y: p.y - h * 0.6), dk ? rgb(0.25, 0.18, 0.14) : rgb(0.42, 0.30, 0.20), 4)
        let leaf = dk ? rgb(0.12, 0.30, 0.22) : rgb(0.30, 0.58, 0.32)
        let leaf2 = dk ? rgb(0.16, 0.38, 0.27) : rgb(0.40, 0.68, 0.38)
        let sway = sin(f.t * 1.2) * 1.5
        for (dx, dy, r, col) in [(-12.0, -0.62, 20.0, leaf), (12.0, -0.64, 19.0, leaf), (0.0, -0.82, 24.0, leaf2), (-4.0, -0.66, 16.0, leaf2)] {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x + dx + sway - r, y: p.y + h * dy - r, width: r * 2, height: r * 2)), with: .color(col))
        }
    }

    private static func taxiSign(_ ctx: inout GraphicsContext, _ f: BackdropFrame, _ c: Cam) {
        let dk = f.dark
        let d = curbD + 0.45
        let p = CGPoint(x: f.targetX + 34, y: c.y(d))
        let h = 64.0
        Sketch.line(&ctx, p, CGPoint(x: p.x, y: p.y - h), dk ? rgb(0.55, 0.57, 0.62) : rgb(0.42, 0.45, 0.50), 2.4)
        let s = CGRect(x: p.x - 18, y: p.y - h - 2, width: 36, height: 24)
        ctx.fill(Path(roundedRect: s, cornerRadius: 3), with: .color(rgb(0.98, 0.80, 0.18)))
        ctx.stroke(Path(roundedRect: s.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 2), with: .color(.black.opacity(0.75)), lineWidth: 1.2)
        ctx.draw(Text("TAXI").font(.system(size: 10, weight: .black, design: .rounded)).foregroundColor(.black.opacity(0.85)),
                 at: CGPoint(x: s.midX, y: s.midY))
    }

    private static func clouds(_ ctx: inout GraphicsContext, _ f: BackdropFrame, maxY: Double) {
        let span = f.width + 240
        for (i, (y0, s, sp)) in [(0.35, 1.0, 4.0), (0.75, 0.7, 2.6), (0.10, 0.55, 3.2)].enumerated() {
            let x = fmod(f.t * sp + Double(i) * span / 3, span) - 120
            let y = maxY * y0 + 14
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
        for i in 0..<20 {
            let a = Double(i)
            let x = fmod(a * 0.618034 * f.width * 1.7, f.width)
            let y = fmod(a * a * 13.7 + a * 31, max(20, maxY))
            let tw = 0.55 + 0.45 * sin(f.t * 1.3 + a)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(.white.opacity(0.55 * tw)))
        }
        let mx = f.width * 0.70, my = 30.0
        ctx.fill(Path(ellipseIn: CGRect(x: mx - 30, y: my - 30, width: 60, height: 60)),
                 with: .radialGradient(Gradient(colors: [rgb(1, 0.95, 0.85, 0.25), .clear]), center: CGPoint(x: mx, y: my), startRadius: 8, endRadius: 30))
        ctx.fill(Path(ellipseIn: CGRect(x: mx - 10, y: my - 10, width: 20, height: 20)), with: .color(rgb(0.98, 0.95, 0.85)))
    }
}
