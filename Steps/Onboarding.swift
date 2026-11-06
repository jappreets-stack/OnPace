import SwiftUI

// First-time setup: shown once, the first time someone opens OnPace.
// 1 Welcome · 2 Apple Health · 3 Daily goal · 4 Build your mini-me · 5 Fun unit.
// People who already used the app skip it (see StepsApp). Settings can show it again.
struct Onboarding: View {
    @ObservedObject var store: StepStore
    let theme: Theme
    @AppStorage("didSetup") private var didSetup = false
    @AppStorage("goal") private var goal = 10_000
    @AppStorage("avatar") private var avatar: Avatar = .golfer
    @AppStorage("look") private var look: Look = .original
    @AppStorage("funUnit") private var funUnit: FunUnit = .holes
    @State private var page = 0
    @State private var asking = false

    private let pages = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Dots: where you are in setup.
                HStack(spacing: 8) {
                    ForEach(0..<pages, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? theme.done : Color.primary.opacity(0.2))
                            .frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .padding(.top, 12)
                .animation(.easeOut, value: page)

                ScrollView {
                    Group {
                        switch page {
                        case 0: welcome
                        case 1: health
                        case 2: goalPage
                        case 3: miniMe
                        default: funUnitPage
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .id(page)
                }

                VStack(spacing: 10) {
                    Button(action: primary) {
                        Text(buttonTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.done)
                    .disabled(asking)

                    // Every step can be skipped; the defaults work fine.
                    if page > 0 && page < pages - 1 {
                        Button("Skip") { next() }
                            .font(.body)
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .background(theme.background.ignoresSafeArea())
            .toolbar {
                if page > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { withAnimation { page -= 1 } } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Back")
                    }
                }
            }
        }
        .tint(Color.primary)
        .preferredColorScheme(theme.scheme)
    }

    private var buttonTitle: String {
        switch page {
        case 0: "Get started"
        case 1: "Allow Health access"
        case pages - 1: "Let's go"
        default: "Next"
        }
    }

    private func primary() {
        switch page {
        case 1:
            // Apple's own Health screen pops up; we move on whatever they choose.
            asking = true
            Task {
                await store.start(goal: goal)
                asking = false
                next()
            }
        case pages - 1:
            didSetup = true
        default:
            next()
        }
    }

    private func next() {
        if page == pages - 1 { didSetup = true; return }
        withAnimation(.easeInOut) { page += 1 }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 18) {
            CharacterView(avatar: avatar, mood: .celebrate, look: look)
                .frame(width: 170, height: 220)
            Text("Welcome to OnPace")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Hit your step goal every day.")
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("❤️").font(.system(size: 64)).frame(maxWidth: .infinity)
            Text("Connect Apple Health")
                .font(.largeTitle.weight(.bold))
            Text("So OnPace can see your walking.")
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.7))
            VStack(alignment: .leading, spacing: 14) {
                Bullet(icon: "👟", text: "Steps")
                Bullet(icon: "📏", text: "Distance")
                Bullet(icon: "💪", text: "Workouts")
            }
            Text("🔒 Stays on your iPhone.")
                .font(.body)
                .foregroundStyle(Color.primary.opacity(0.7))
            Text("Next: turn on all, tap Allow.")
                .font(.body.weight(.semibold))
        }
    }

    private var goalPage: some View {
        VStack(spacing: 22) {
            Text("Your daily goal")
                .font(.largeTitle.weight(.bold))
            Text("Steps a day")
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
            HStack(spacing: 24) {
                RoundButton(symbol: "minus") { goal = max(2_000, goal - 500) }
                    .accessibilityLabel("500 fewer steps")
                Text(goal.formatted())
                    .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(minWidth: 170)
                RoundButton(symbol: "plus") { goal = min(30_000, goal + 500) }
                    .accessibilityLabel("500 more steps")
            }
            HStack(spacing: 10) {
                ForEach([5_000, 7_500, 10_000, 12_000], id: \.self) { n in
                    Button { goal = n } label: {
                        Text(n == 7_500 ? "7.5K" : "\(n / 1000)K")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(goal == n ? Color.black : Color.primary)
                            .background(goal == n ? theme.done : Color.primary.opacity(0.08),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Change it anytime.")
                .font(.body)
                .foregroundStyle(Color.primary.opacity(0.6))
        }
    }

    private var miniMe: some View {
        VStack(spacing: 14) {
            Text("Build your mini-me")
                .font(.largeTitle.weight(.bold))
            Text("Walks with you all day.")
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
            CharacterView(avatar: avatar, mood: .walk, look: look)
                .frame(height: 120)
            Picker("Male or female", selection: Binding(get: { look.body }, set: { look.switchTo($0) })) {
                ForEach(BodyShape.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Outfit", selection: $avatar) {
                ForEach(Avatar.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 14) {
                ColorDots(title: "Skin tone", options: SkinTone.allCases, color: \.color, name: \.name,
                          selection: $look.skin)
                Text("Hair").font(.subheadline)
                HeadChips(options: HairStyle.allCases, name: \.name, base: look, selection: $look.hair) {
                    $0.hair = $1
                }
            }
            NavigationLink {
                CharacterBuilder(avatar: $avatar, look: $look)
            } label: {
                Label("More options (beard, glasses, colors…)", systemImage: "slider.horizontal.3")
                    .font(.body.weight(.semibold))
            }
        }
    }

    private var funUnitPage: some View {
        VStack(spacing: 18) {
            Text("Pick a fun unit")
                .font(.largeTitle.weight(.bold))
            Text("Your steps, made fun.")
                .font(.title3)
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(FunUnit.allCases) { unit in
                    Button { funUnit = unit } label: {
                        VStack(spacing: 4) {
                            Text(unit.emoji).font(.system(size: 34))
                            Text(unit.name).font(.headline)
                            Text(unit.example).font(.caption).foregroundStyle(Color.primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .foregroundStyle(Color.primary)
                        .background(Color.primary.opacity(funUnit == unit ? 0.14 : 0.06),
                                    in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .stroke(theme.done, lineWidth: funUnit == unit ? 3 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(funUnit == unit ? .isSelected : [])
                }
            }
            UnitScene(unit: funUnit)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
        }
    }
}

private extension FunUnit {
    // What one unit is, in plain words.
    var example: String {
        switch self {
        case .holes: "1 hole ≈ 1,300 steps"
        case .soccerFields: "1 field = 105 m"
        case .laps: "1 lap = 400 m"
        case .blocks: "1 block ≈ 80 m"
        case .km: "1 km = 1,000 m"
        case .mi: "1 mi = 1,609 m"
        }
    }
}

private struct Bullet: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon).font(.title2)
            Text(text).font(.title3)
        }
    }
}

private struct RoundButton: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .frame(width: 54, height: 54)
                .background(Color.primary.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
