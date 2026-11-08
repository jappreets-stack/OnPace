import SwiftUI

// The app's overall look (Settings → Look → Style). Add new styles here
// and handle them in ContentView's `today` / `history` switches.
enum AppStyle: String, CaseIterable, Identifiable {
    case original, minimal, retro16
    var id: String { rawValue }
    var name: String {
        switch self {
        case .original: "Original"
        case .minimal: "Clean minimal"
        case .retro16: "16-bit adventure"
        }
    }
    // One line under the name in Settings.
    var blurb: String {
        switch self {
        case .original: "Emoji icons and a blue ring"
        case .minimal: "Simple and calm, one green ring"
        case .retro16: "Pixel art: a castle world and a ring of gold blocks"
        }
    }
}

// Clean minimal: plain system colors, one green accent, Apple-style grouped cards.
enum Minimal {
    static let accent = Color(red: 0.19, green: 0.82, blue: 0.36)
    #if os(iOS)
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    #else
    static let background = Color.black
    static let card = Color.white.opacity(0.12)
    #endif
    static let ringWidth: CGFloat = 22
}

// A thick Activity-style ring with whatever sits inside it.
struct MinimalRing<Center: View>: View {
    let progress: Double
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: Minimal.ringWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Minimal.accent, style: StrokeStyle(lineWidth: Minimal.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            center
        }
    }
}

extension View {
    // A white (light) / dark gray (dark) rounded card on the grouped background.
    func minimalCard(padding: CGFloat = 16) -> some View {
        self
            .padding(.horizontal, padding)
            .background(Minimal.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
