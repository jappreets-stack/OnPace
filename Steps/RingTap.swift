import SwiftUI
import Combine

// Tap the ring and your mini-me does its sport move in the scene behind it (kick into the goal,
// jump shot, golf swing, …), then says a cheeky line about today.
// Tap too much and it gets grumpy and turns its back for a bit.

// MARK: - What the mini-me knows about today

struct QuipContext {
    var steps: Int
    var goal: Int
    var behind: Int          // steps behind pace (0 when on pace)
    var catchUpMinutes: Int
    var onPace: Bool
    var streak: Int
    var distance: String     // "4.9 miles walked"
    var session: String?     // "beach walk", "round" … while a session is running
    var golfRound: Bool
    var hour = Calendar.current.component(.hour, from: .now)

    var hitGoal: Bool { steps >= goal }
    var left: Int { max(goal - steps, 0) }
    var over: Int { max(steps - goal, 0) }
}

// MARK: - The lines

enum Quips {
    // Lines grouped by how today is going. {left}, {behind}, {min} … get your real numbers.
    static let groups: [String: [String]] = [
        "morning": [
            "Morning. My legs are stretched. Yours?",
            "{steps} steps so far. Does coffee count as cardio?",
            "Rise and shuffle.",
            "Big day ahead: {goal} steps. No pressure.",
            "I'm warmed up. Just saying.",
            "Let's ease into it. Then not ease.",
            "First steps are the hardest. Then it's just steps.",
            "Breakfast first. Then we walk. Deal?",
        ],
        "behind": [
            "{behind} behind. My legs work. Yours?",
            "{min} min of walking fixes this. I checked.",
            "I'm not mad. I'm just sitting here. Like you.",
            "{left} to go. That's a lot of tiny me-steps.",
            "Couch: 1. Us: 0. Rematch?",
            "Walk {min} min and I'll stop making this face.",
            "We're {behind} behind. I blame the chair.",
            "I'd walk for you, but I'm made of code.",
            "Fun fact: phones don't walk themselves.",
            "{min} minutes. That's one podcast intro.",
            "Every step counts. Even to the fridge.",
        ],
        "onPace": [
            "On pace. Look at us go.",
            "Right on track. Don't get cocky.",
            "{left} to go and we're cruising.",
            "Smooth. Keep this up and I'll stop nagging.",
            "{distance}. Not bad, partner.",
            "On pace. I'd high-five you, but… glass.",
            "We're doing it. Quietly. Like legends.",
            "Steady steps. Very professional.",
            "This is the part where we keep going.",
        ],
        "goalHit": [
            "Goal hit. I'm off duty.",
            "{goal} done. Did you see me flex?",
            "+{over} extra. Show-off.",
            "Goal hit. Couch privileges unlocked.",
            "We did it. I'll be unbearable now.",
            "{distance}. My tiny feet are tired.",
            "Mission complete. Snacks?",
            "Done for today. Tomorrow-you, good luck.",
        ],
        "wayOver": [
            "{steps} steps?! Who are you?",
            "+{over}. Okay, we get it. You walk.",
            "I need a nap. You clearly don't.",
            "At this point we're just showing off.",
            "{distance}. Did we leave the state?",
        ],
        "lateNight": [
            "It's late and we're {left} short. Hallway laps?",
            "{min} min around the kitchen. I'll count.",
            "Bedtime's coming. So is midnight.",
            "Walk in your pajamas. Nobody's watching.",
            "{left} to go. The night is young-ish.",
        ],
        "session": [
            "{session} mode: on.",
            "Counting every step. Even the wobbly ones.",
            "Is this the {session}? Feels like the {session}.",
            "Phone down. Enjoy the {session}.",
            "Best {session} ever? Too early to tell.",
        ],
        "golf": [
            "Head down. On the ball, not the phone.",
            "Fore! Sorry. Habit.",
            "Walking the course: real golfers do it.",
            "Keep it in the fairway. I'm watching.",
            "Every hole is about 1,300 steps. Swing less, walk more.",
        ],
        "streak": [
            "{streak} days in a row. Don't you dare break it.",
            "Streak: {streak}. I've told all my friends.",
            "{streak}-day streak. I'm framing this.",
            "{streak} days straight. Legend behavior.",
        ],
        "poked": [
            "Yes?",
            "Again?",
            "That tickles.",
            "I'm busy walking.",
            "Personal space, please.",
            "Did you need something?",
        ],
        "grumpy": [
            "Tap less. Walk more.",
            "Okay. Ignoring you now.",
            "I said walk.",
            "My screen, my rules. Go walk.",
        ],
    ]

    // Which group fits right now.
    static func group(for c: QuipContext) -> String {
        if c.session != nil { return c.golfRound && Bool.random() ? "golf" : "session" }
        if c.streak >= 3 && Int.random(in: 0..<4) == 0 { return "streak" }
        if c.steps >= c.goal * 3 / 2 { return "wayOver" }
        if c.hitGoal { return "goalHit" }
        if c.hour >= 21 { return "lateNight" }
        if c.hour < 9 && c.steps < 2_000 { return "morning" }
        return c.onPace ? "onPace" : "behind"
    }

    // A line from the group that hasn't been said yet (all lines get used before any repeats).
    static func next(_ group: String, _ c: QuipContext) -> String {
        let lines = groups[group] ?? ["Hi."]
        let key = "quipsUsed." + group
        var used = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        var fresh = Array(lines.indices).filter { !used.contains($0) }
        if fresh.isEmpty { used = []; fresh = Array(lines.indices) }
        let i = fresh.randomElement()!
        UserDefaults.standard.set(used + [i], forKey: key)
        return fill(lines[i], c)
    }

    private static func fill(_ line: String, _ c: QuipContext) -> String {
        line.replacingOccurrences(of: "{steps}", with: c.steps.formatted())
            .replacingOccurrences(of: "{goal}", with: c.goal.formatted())
            .replacingOccurrences(of: "{left}", with: c.left.formatted())
            .replacingOccurrences(of: "{over}", with: c.over.formatted())
            .replacingOccurrences(of: "{behind}", with: c.behind.formatted())
            .replacingOccurrences(of: "{min}", with: "\(max(c.catchUpMinutes, 1))")
            .replacingOccurrences(of: "{streak}", with: "\(c.streak)")
            .replacingOccurrences(of: "{distance}", with: c.distance.prefix(1).uppercased() + c.distance.dropFirst())
            .replacingOccurrences(of: "{session}", with: c.session ?? "walk")
    }
}

// MARK: - Tap state (what the mini-me is doing right now)

@MainActor
final class RingTap: ObservableObject {
    struct Flight {
        let flier: Backdrop.Flier
        let from: CGPoint
        let to: CGPoint
        let peak: Double
        let start: Date
        let duration: Double
    }

    @Published var bubble: String?
    @Published var grumpy = false        // turned its back, ignores taps for a bit
    @Published var move: SportMove?      // the sport move playing now
    @Published var moveStart: Date?
    @Published var travel: CGFloat = 0   // how far the mini-me has run sideways (sprint, jog)
    @Published var flight: Flight?       // the ball / disc / taxi / flag in the scene
    @Published var taps = 0              // drives the little buzz

    private var recent: [Date] = []
    private var bubbleJob: Task<Void, Never>?

    var busy: Bool { move != nil }

    /// release: where the ball leaves the mini-me; target: where it should land (both in screen points).
    func tap(_ c: QuipContext, backdrop: Backdrop, release: CGPoint, target: CGPoint, miniMeX: CGFloat) {
        guard !grumpy, !busy else { return }
        taps += 1
        recent = recent.filter { $0 > .now.addingTimeInterval(-8) } + [.now]

        // Too many pokes in a few seconds: grumpy, back turned, quiet for 5 seconds.
        if recent.count >= 6 {
            recent = []
            grumpy = true
            say(Quips.next("grumpy", c), for: 5)
            Task { try? await Task.sleep(for: .seconds(5)); grumpy = false }
            return
        }
        if recent.count >= 3 {
            say(Quips.next("poked", c), for: 2)
            return
        }
        Task { await play(backdrop, c, release: release, target: target, miniMeX: miniMeX) }
    }

    private func play(_ backdrop: Backdrop, _ c: QuipContext, release: CGPoint, target: CGPoint, miniMeX: CGFloat) async {
        let p = backdrop.play
        let m = p.move
        // Track: you only cross the finish line once you've hit your goal.
        let finishing = backdrop != .track || c.hitGoal
        let missed = p.miss != nil && Int.random(in: 0..<5) == 0
        var to = target
        if missed { to.x += 36; to.y -= 14 }

        bubble = nil
        moveStart = .now
        move = m
        if p.travels {
            let distance = (target.x - miniMeX) * (finishing ? 1.08 : 0.5)
            withAnimation(.easeInOut(duration: m.duration)) { travel = distance }
        }
        try? await Task.sleep(for: .seconds(m.duration * m.release))
        if p.flier != .none {
            flight = Flight(flier: p.flier, from: release, to: to, peak: p.peak, start: .now, duration: p.flight)
        }
        let rest = max(m.duration * (1 - m.release), p.flier == .none ? 0 : p.flight)
        try? await Task.sleep(for: .seconds(rest + 0.15))

        let cheer: String
        if backdrop == .track && !finishing { cheer = "Not at the finish yet." }
        else { cheer = missed ? (p.miss ?? p.cheer) : p.cheer }
        say(cheer + " " + Quips.next(Quips.group(for: c), c), for: 4)

        try? await Task.sleep(for: .seconds(0.6))
        if p.travels { withAnimation(.easeInOut(duration: 0.9)) { travel = 0 } }
        move = nil
        moveStart = nil
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeOut(duration: 0.3)) { flight = nil }
    }

    private func say(_ line: String, for seconds: Double) {
        bubbleJob?.cancel()
        withAnimation(.spring(duration: 0.3)) { bubble = line }
        bubbleJob = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { bubble = nil }
        }
    }
}

// MARK: - The ball, disc, taxi or flag flying through the scene (full-screen, screen points)

struct FlightLayer: View {
    let flight: RingTap.Flight?

    var body: some View {
        if let f = flight {
            TimelineView(.animation) { tl in
                let raw = tl.date.timeIntervalSince(f.start) / f.duration
                let t = min(max(raw, 0), 1)
                piece(f, t)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func piece(_ f: RingTap.Flight, _ t: Double) -> some View {
        switch f.flier {
        case .emoji(let e, let size):
            Text(e).font(.system(size: size))
                .rotationEffect(.degrees(t * 540))
                .position(arc(f, t))
        case .golfBall:
            Circle().fill(.white).frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.3), radius: 1)
                .position(arc(f, t))
        case .disc:
            Ellipse().fill(Color(red: 1.0, green: 0.45, blue: 0.20))
                .overlay(Ellipse().stroke(.white.opacity(0.6), lineWidth: 1.5).padding(3))
                .frame(width: 22, height: 8)
                .rotationEffect(.degrees(-12 + 8 * sin(t * 12)))
                .position(arc(f, t))
        case .taxi:
            // Drives in from the left edge and brakes at the curb.
            let eased = 1 - pow(1 - t, 3)
            Text("🚕").font(.system(size: 34)).scaleEffect(x: -1)
                .position(x: -40 + (f.to.x + 40) * eased, y: f.to.y - 14)
        case .flag:
            Text("🚩").font(.system(size: 28))
                .scaleEffect(t, anchor: .bottomLeading)
                .position(x: f.to.x + 8, y: f.to.y - 14)
        case .none:
            EmptyView()
        }
    }

    // Straight line from → to, lifted into an arc by `peak`.
    private func arc(_ f: RingTap.Flight, _ t: Double) -> CGPoint {
        CGPoint(x: f.from.x + (f.to.x - f.from.x) * t,
                y: f.from.y + (f.to.y - f.from.y) * t - 4 * f.peak * t * (1 - t))
    }
}

// A comic-style speech bubble.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottom) {
                Triangle().fill(.white).frame(width: 14, height: 9).offset(y: 8)
            }
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .frame(width: 240)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
