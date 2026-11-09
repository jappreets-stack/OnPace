import SwiftUI

// "Cozy pastel" style (Settings → App style): a soft pastel page, a pastel gradient ring, rounded text in a
// warm brown, and white pillowy cards. Four color sets (CozyPalette), picked in Settings and synced to the watch.
// Shared with the watch (ring colors only).
enum CozyPalette: String, CaseIterable, Identifiable {
    case peach, mint, lilac, butter
    var id: String { rawValue }
    var name: String {
        switch self {
        case .peach: "Peach & lavender"
        case .mint: "Mint & sky"
        case .lilac: "Lilac & rose"
        case .butter: "Butter & coral"
        }
    }
    typealias RGB = (Double, Double, Double)
    // The ring fades start → middle → end.
    var ring: [RGB] {
        switch self {
        case .peach: [(1.00, 0.72, 0.60), (0.95, 0.55, 0.66), (0.70, 0.62, 0.93)]
        case .mint: [(0.52, 0.86, 0.72), (0.45, 0.80, 0.88), (0.52, 0.64, 0.95)]
        case .lilac: [(0.80, 0.68, 0.97), (0.88, 0.58, 0.88), (0.97, 0.58, 0.70)]
        case .butter: [(1.00, 0.84, 0.42), (1.00, 0.68, 0.48), (0.97, 0.50, 0.50)]
        }
    }
    // Icons, the gear and the "Daily average" number.
    var accent: RGB {
        switch self {
        case .peach: (0.95, 0.55, 0.66)
        case .mint: (0.26, 0.66, 0.70)
        case .lilac: (0.70, 0.46, 0.88)
        case .butter: (0.95, 0.48, 0.42)
        }
    }
    // Goal hit: the ring, bars and "Days at goal" turn this color.
    var done: RGB { self == .mint ? (1.00, 0.78, 0.36) : (0.45, 0.80, 0.64) }
    var doneDeep: RGB { self == .mint ? (0.80, 0.55, 0.10) : (0.24, 0.62, 0.46) }   // readable on the page
    // Page gradient, light (top, bottom) and dark (top, bottom).
    var pageLight: (RGB, RGB) {
        switch self {
        case .peach: ((1.00, 0.97, 0.93), (0.99, 0.91, 0.90))
        case .mint: ((0.95, 0.99, 0.97), (0.90, 0.96, 0.99))
        case .lilac: ((0.99, 0.96, 1.00), (0.96, 0.91, 0.98))
        case .butter: ((1.00, 0.99, 0.91), (1.00, 0.93, 0.86))
        }
    }
    var pageDark: (RGB, RGB) {
        switch self {
        case .peach: ((0.17, 0.13, 0.22), (0.24, 0.17, 0.27))
        case .mint: ((0.07, 0.16, 0.17), (0.10, 0.19, 0.24))
        case .lilac: ((0.16, 0.12, 0.24), (0.22, 0.15, 0.30))
        case .butter: ((0.19, 0.14, 0.10), (0.26, 0.17, 0.14))
        }
    }
}

enum Cozy {
    // The palette you picked (the watch reads the copy the phone sends).
    static var palette: CozyPalette {
        #if os(watchOS)
        let d = Shared.defaults
        #else
        let d = UserDefaults.standard
        #endif
        return CozyPalette(rawValue: d.string(forKey: Shared.cozyPaletteKey) ?? "") ?? .peach
    }
    private static func c(_ v: CozyPalette.RGB) -> Color { Color(red: v.0, green: v.1, blue: v.2) }

    static var start: Color { c(palette.ring[0]) }
    static var end: Color { c(palette.ring[2]) }
    static var accent: Color { c(palette.accent) }
    static var done: Color { c(palette.done) }
    static var doneDeep: Color { c(palette.doneDeep) }

    // The ring's colors, start to end. Goal hit turns it to the done color.
    static var ringColors: [Color] { palette.ring.map(c) }
    static var doneColors: [Color] { [done, done.opacity(0.75), done] }

    #if os(iOS)
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    private static func ui(_ v: CozyPalette.RGB) -> UIColor { UIColor(red: v.0, green: v.1, blue: v.2, alpha: 1) }
    // Light pastel page by day, a deep tinted page by night (per palette).
    static var pageTop: Color { adaptive(light: ui(palette.pageLight.0), dark: ui(palette.pageDark.0)) }
    static var pageBottom: Color { adaptive(light: ui(palette.pageLight.1), dark: ui(palette.pageDark.1)) }
    static let card = adaptive(light: .white, dark: UIColor(white: 1, alpha: 0.08))
    static let ink = adaptive(light: UIColor(red: 0.36, green: 0.26, blue: 0.22, alpha: 1),
                              dark: UIColor(red: 0.99, green: 0.93, blue: 0.90, alpha: 1))
    static var track: Color { adaptive(light: ui(palette.ring[0]).withAlphaComponent(0.22), dark: UIColor(white: 1, alpha: 0.10)) }
    #else
    static var pageTop: Color { .black }
    static var pageBottom: Color { .black }
    static let card = Color.white.opacity(0.12)
    static let ink = Color.white
    static let track = Color.white.opacity(0.12)
    #endif

    static var page: LinearGradient {
        LinearGradient(colors: [pageTop, pageBottom], startPoint: .top, endPoint: .bottom)
    }
}

// A soft, thick ring in the palette's colors, with whatever sits inside it.
struct CozyRing<Center: View>: View {
    let progress: Double
    let hitGoal: Bool
    var lineWidth: CGFloat = 26
    @ViewBuilder var center: Center

    var body: some View {
        let colors = hitGoal ? Cozy.doneColors : Cozy.ringColors
        ZStack {
            Circle()
                .stroke(Cozy.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: colors, center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: (hitGoal ? Cozy.done : Cozy.accent).opacity(0.35), radius: 8, y: 3)
                .animation(.easeOut(duration: 0.6), value: progress)
            center
        }
    }
}

extension View {
    // A white, rounded, softly shadowed card (a faint glass card at night).
    func cozyCard(padding: CGFloat = 16) -> some View {
        self
            .padding(.horizontal, padding)
            .background(Cozy.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Cozy.accent.opacity(0.12), radius: 14, y: 6)
    }
}
