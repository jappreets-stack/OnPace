import SwiftUI

// Full-screen scenes behind the Today screen. One per fun unit (km / mi let you pick road, beach or trail).
// Every scene is drawn in code (no images) so it fits any screen and works in light and dark mode.
//
// Layout rule all scenes follow: your mini-me stands at x = `center`, feet on y = `horizon`.
// Keep ~60 pt either side of the mini-me free of tall things. The "target" (goal, hoop, flag …)
// sits to the right, outside the ring (see targetX), and tap tricks fly to `target(_:)`.

enum Backdrop: String, CaseIterable, Identifiable {
    case golf, soccer, football, basketball, tennis, baseball, track, city, road, beach, trail
    var id: String { rawValue }
}

// Everything a scene needs to draw itself.
struct BackdropFrame {
    let size: CGSize      // whole screen, in points
    let horizon: Double   // y where the ground starts = your mini-me's feet
    let center: Double    // x of your mini-me (middle of the screen)
    let dark: Bool        // dark mode: evening / night lighting
    let t: Double         // seconds, for gentle motion (clouds, flags, waves)
    var tapeBroken = false // track: the finish tape has just been run through

    var width: Double { size.width }
    var height: Double { size.height }
    // Right of the 270-pt ring (radius 145 with its stroke), but still on screen.
    var targetX: Double { center + min(152, width / 2 - 48) }
}

// Small drawing helpers every scene can use.
enum Sketch {
    static func fill(_ ctx: inout GraphicsContext, _ r: CGRect, _ c: Color) { ctx.fill(Path(r), with: .color(c)) }

    static func line(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ c: Color, _ w: Double, dash: [CGFloat] = []) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, dash: dash))
    }

    // Vertical gradient filling a rect (skies, grass fading into the distance).
    static func gradient(_ ctx: inout GraphicsContext, _ r: CGRect, _ colors: [Color]) {
        ctx.fill(Path(r), with: .linearGradient(Gradient(colors: colors),
                                                startPoint: CGPoint(x: r.midX, y: r.minY),
                                                endPoint: CGPoint(x: r.midX, y: r.maxY)))
    }

    // A day sky (light mode) or a dusk/night sky (dark mode) from the top of the screen down to `to`.
    static func sky(_ ctx: inout GraphicsContext, _ f: BackdropFrame, to y: Double) {
        let r = CGRect(x: 0, y: 0, width: f.width, height: y)
        gradient(&ctx, r, f.dark
                 ? [Color(red: 0.05, green: 0.07, blue: 0.16), Color(red: 0.16, green: 0.18, blue: 0.32)]
                 : [Color(red: 0.42, green: 0.68, blue: 0.95), Color(red: 0.80, green: 0.91, blue: 0.99)])
    }
}
