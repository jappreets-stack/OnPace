import SwiftUI

// "Cozy pastel" style (Settings → App style): warm cream background, a soft peach → pink → lavender ring,
// rounded text in a warm brown, and white pillowy cards. Shared with the watch (ring colors only).
enum Cozy {
    static let peach = Color(red: 1.00, green: 0.72, blue: 0.60)
    static let rose = Color(red: 0.95, green: 0.55, blue: 0.66)
    static let lavender = Color(red: 0.70, green: 0.62, blue: 0.93)
    static let mint = Color(red: 0.45, green: 0.80, blue: 0.64)
    static let mintDeep = Color(red: 0.24, green: 0.62, blue: 0.46)   // readable on cream and on white

    // The ring's colors, start to end. Goal hit turns it mint.
    static let ringColors = [peach, rose, lavender]
    static let doneColors = [mint, Color(red: 0.55, green: 0.85, blue: 0.80), mint]

    #if os(iOS)
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    // Warm cream by day, deep plum by night.
    static let pageTop = adaptive(light: UIColor(red: 1.00, green: 0.97, blue: 0.93, alpha: 1),
                                  dark: UIColor(red: 0.17, green: 0.13, blue: 0.22, alpha: 1))
    static let pageBottom = adaptive(light: UIColor(red: 0.99, green: 0.91, blue: 0.90, alpha: 1),
                                     dark: UIColor(red: 0.24, green: 0.17, blue: 0.27, alpha: 1))
    static let card = adaptive(light: .white, dark: UIColor(white: 1, alpha: 0.08))
    static let ink = adaptive(light: UIColor(red: 0.36, green: 0.26, blue: 0.22, alpha: 1),
                              dark: UIColor(red: 0.99, green: 0.93, blue: 0.90, alpha: 1))
    static let track = adaptive(light: UIColor(red: 0.98, green: 0.86, blue: 0.82, alpha: 1),
                                dark: UIColor(white: 1, alpha: 0.10))
    #else
    static let pageTop = Color.black
    static let pageBottom = Color.black
    static let card = Color.white.opacity(0.12)
    static let ink = Color.white
    static let track = Color.white.opacity(0.12)
    #endif

    static var page: LinearGradient {
        LinearGradient(colors: [pageTop, pageBottom], startPoint: .top, endPoint: .bottom)
    }
}

// A soft, thick ring that fades peach → pink → lavender, with whatever sits inside it.
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
                .shadow(color: (hitGoal ? Cozy.mint : Cozy.rose).opacity(0.35), radius: 8, y: 3)
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
            .shadow(color: Cozy.rose.opacity(0.12), radius: 14, y: 6)
    }
}
