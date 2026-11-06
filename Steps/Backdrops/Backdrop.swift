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

    // Where a tap trick lands: the goal mouth, the rim, the cup, the flag …
    func target(_ f: BackdropFrame) -> CGPoint {
        switch self {
        case .golf: GolfBackdrop.target(f)
        case .soccer: SoccerBackdrop.target(f)
        case .football: FootballBackdrop.target(f)
        case .basketball: BasketballBackdrop.target(f)
        case .tennis: TennisBackdrop.target(f)
        case .baseball: BaseballBackdrop.target(f)
        case .track: TrackBackdrop.target(f)
        case .city: CityBackdrop.target(f)
        case .road: RoadBackdrop.target(f)
        case .beach: BeachBackdrop.target(f)
        case .trail: TrailBackdrop.target(f)
        }
    }
}


// The whole-screen background. `horizon` is where the mini-me's feet are, in this view's coordinates.
struct BackdropView: View {
    let backdrop: Backdrop
    let horizon: Double
    var signText = "1 mi"   // written on the road sign
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
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

