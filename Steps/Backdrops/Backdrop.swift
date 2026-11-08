import SwiftUI

// Which drawing goes with which backdrop.
extension Backdrop {
    func draw(_ ctx: inout GraphicsContext, _ f: BackdropFrame) {
        switch self {
        case .golf: GolfBackdrop.draw(&ctx, f)
        case .soccer: SoccerBackdrop.draw(&ctx, f)
        case .football: FootballBackdrop.draw(&ctx, f)
        case .basketball: BasketballBackdrop.draw(&ctx, f)
        case .tennis: TennisBackdrop.draw(&ctx, f)
        case .baseball: BaseballBackdrop.draw(&ctx, f)
        case .track: TrackBackdrop.draw(&ctx, f)
        case .city: CityBackdrop.draw(&ctx, f)
        case .road: RoadBackdrop.draw(&ctx, f)
        case .beach: BeachBackdrop.draw(&ctx, f)
        case .trail: TrailBackdrop.draw(&ctx, f)
        }
    }
}

// The whole-screen background. `horizon` is where the mini-me's feet are, in this view's coordinates.
struct BackdropView: View {
    let backdrop: Backdrop
    let horizon: Double
    var signText = "1 mi"   // written on the road sign
    var animated = true     // false = drawn once and kept still (saves battery when the scene is blurred)
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Only the Full background moves; Calm and Plain stay still to save battery.
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !animated)) { timeline in
            Canvas { ctx, size in
                let f = BackdropFrame(size: size, horizon: horizon, center: size.width / 2,
                                      dark: scheme == .dark, t: timeline.date.timeIntervalSinceReferenceDate)
                backdrop.draw(&ctx, f)
                if backdrop == .road {
                    let r = RoadBackdrop.signRect(f)
                    ctx.draw(Text(signText).font(.system(size: r.height * 0.42, weight: .bold)).foregroundStyle(.white),
                             at: CGPoint(x: r.midX, y: r.midY))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

