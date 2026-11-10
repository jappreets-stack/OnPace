import SwiftUI

// "Cozy pastel" style (Settings → App style): a soft pastel page, a pastel gradient ring, rounded text in a
// warm brown, and white pillowy cards. Several color sets (CozyPalette), picked in Settings and synced to the watch.
// Shared with the watch (ring colors only).
enum CozyPalette: String, CaseIterable, Identifiable {
    // Each set is its own hue, in rainbow order in Settings. (The saved names stay the same for old settings.)
    case peach, butter, matcha, mint, rain, lilac, dusk, nightRed
    var id: String { rawValue }
    var name: String {
        switch self {
        case .peach: "Peach & coral"
        case .butter: "Butter & honey"
        case .matcha: "Matcha"
        case .mint: "Mint & teal"
        case .rain: "Rainy blue"
        case .lilac: "Lilac & violet"
        case .dusk: "Lo-fi sunset"
        case .nightRed: "Night red"
        }
    }
    typealias RGB = (Double, Double, Double)
    // The ring fades start → middle → end.
    var ring: [RGB] {
        switch self {
        case .peach: [(1.00, 0.78, 0.64), (1.00, 0.60, 0.52), (0.96, 0.44, 0.48)]
        case .butter: [(1.00, 0.92, 0.52), (1.00, 0.80, 0.36), (0.98, 0.66, 0.24)]
        case .matcha: [(0.80, 0.88, 0.52), (0.62, 0.80, 0.40), (0.42, 0.68, 0.34)]
        case .mint: [(0.56, 0.94, 0.86), (0.34, 0.82, 0.80), (0.20, 0.66, 0.72)]
        case .rain: [(0.62, 0.80, 1.00), (0.42, 0.62, 0.96), (0.30, 0.44, 0.88)]
        case .lilac: [(0.86, 0.76, 1.00), (0.72, 0.58, 0.98), (0.56, 0.42, 0.92)]
        // Lo-fi evening: indigo sky, magenta clouds, warm orange lamp.
        case .dusk: [(0.40, 0.38, 0.82), (0.88, 0.42, 0.70), (1.00, 0.64, 0.36)]
        case .nightRed: [(0.75, 0.75, 0.75), (0.90, 0.90, 0.90), (1.00, 1.00, 1.00)]   // turned red by the Night red tint
        }
    }
    // The little ring shown for this set in Settings.
    var swatch: [RGB] { self == .nightRed ? [(0.55, 0.04, 0.04), (0.85, 0.10, 0.08), (1.00, 0.22, 0.16)] : ring }
    // Icons, the gear and the "Daily average" number.
    var accent: RGB {
        switch self {
        case .peach: (0.94, 0.48, 0.46)
        case .butter: (0.90, 0.60, 0.16)
        case .matcha: (0.42, 0.64, 0.30)
        case .mint: (0.16, 0.62, 0.64)
        case .rain: (0.30, 0.50, 0.90)
        case .lilac: (0.58, 0.44, 0.90)
        case .dusk: (0.80, 0.40, 0.66)
        case .nightRed: (1.00, 1.00, 1.00)
        }
    }
    // Goal hit: the ring, bars and "Days at goal" turn this color (never the same hue as the set).
    var done: RGB {
        switch self {
        case .matcha, .mint: (1.00, 0.70, 0.40)
        case .nightRed: (1.00, 1.00, 1.00)
        default: (0.45, 0.80, 0.64)
        }
    }
    var doneDeep: RGB {   // readable on the page
        switch self {
        case .matcha, .mint: (0.84, 0.46, 0.16)
        case .nightRed: (1.00, 1.00, 1.00)
        default: (0.24, 0.62, 0.46)
        }
    }
    // Page gradient, light (top, bottom) and dark (top, bottom), tinted with the set's hue.
    var pageLight: (RGB, RGB) {
        switch self {
        case .peach: ((1.00, 0.96, 0.93), (1.00, 0.90, 0.88))
        case .butter: ((1.00, 0.99, 0.90), (1.00, 0.95, 0.82))
        case .matcha: ((0.97, 0.99, 0.91), (0.92, 0.96, 0.86))
        case .mint: ((0.93, 0.99, 0.98), (0.86, 0.96, 0.95))
        case .rain: ((0.94, 0.97, 1.00), (0.88, 0.92, 1.00))
        case .lilac: ((0.98, 0.95, 1.00), (0.93, 0.90, 1.00))
        case .dusk: ((0.94, 0.92, 1.00), (1.00, 0.89, 0.86))
        case .nightRed: ((0, 0, 0), (0, 0, 0))
        }
    }
    var pageDark: (RGB, RGB) {
        switch self {
        case .peach: ((0.20, 0.11, 0.10), (0.28, 0.14, 0.14))
        case .butter: ((0.19, 0.15, 0.07), (0.26, 0.19, 0.08))
        case .matcha: ((0.09, 0.14, 0.08), (0.14, 0.19, 0.10))
        case .mint: ((0.05, 0.15, 0.16), (0.07, 0.20, 0.21))
        case .rain: ((0.06, 0.09, 0.20), (0.09, 0.13, 0.29))
        case .lilac: ((0.13, 0.10, 0.24), (0.19, 0.13, 0.32))
        case .dusk: ((0.11, 0.09, 0.26), (0.30, 0.13, 0.26))
        case .nightRed: ((0, 0, 0), (0, 0, 0))
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
    static var card: Color {
        palette == .nightRed ? Color(white: 0.13) : adaptive(light: .white, dark: UIColor(white: 1, alpha: 0.08))
    }
    static var ink: Color {
        palette == .nightRed ? .white : adaptive(light: UIColor(red: 0.36, green: 0.26, blue: 0.22, alpha: 1),
                                                 dark: UIColor(red: 0.99, green: 0.93, blue: 0.90, alpha: 1))
    }
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

// Night red: everything in shades of red on black, like the Ultra's Night Mode (phone and watch).
extension Cozy {
    static let nightRedTint = Color(red: 1, green: 0.12, blue: 0.08)
}

extension View {
    // Turns every color into a shade of red (white → bright red, black stays black).
    @ViewBuilder func nightRed(_ on: Bool) -> some View {
        if on {
            self.grayscale(1).colorMultiply(Cozy.nightRedTint)
        } else {
            self
        }
    }
}
