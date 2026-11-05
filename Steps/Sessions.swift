import SwiftUI
import Combine

// MARK: - Session types and fun units

// What you're doing during a session. Golf counts holes; the rest give your mini-me a prop.
enum SessionKind: String, Codable, CaseIterable, Identifiable {
    case golf, hike, dogWalk, shopping, themePark, workout, custom
    var id: String { rawValue }

    var name: String {
        switch self {
        case .golf: "Golf"
        case .hike: "Hike"
        case .dogWalk: "Dog walk"
        case .shopping: "Shopping"
        case .themePark: "Theme park"
        case .workout: "Workout"
        case .custom: "Custom"
        }
    }

    var emoji: String {
        switch self {
        case .golf: "⛳️"
        case .hike: "🥾"
        case .dogWalk: "🐕"
        case .shopping: "🛍️"
        case .themePark: "🎢"
        case .workout: "💪"
        case .custom: "✨"
        }
    }

    // What your mini-me carries (golf swings instead, custom just walks).
    var prop: Prop? {
        switch self {
        case .golf, .custom: nil
        case .hike: .hikingStick
        case .dogWalk: .dog
        case .shopping: .bags
        case .themePark: .balloon
        case .workout: .dumbbells
        }
    }
}

// Steps turned into something you can picture. Rough averages (about 0.76 m per step).
enum FunUnit: String, CaseIterable, Identifiable {
    case holes, soccerFields, laps, blocks, km, mi
    var id: String { rawValue }

    var name: String {
        switch self {
        case .holes: "Golf holes"
        case .soccerFields: "Soccer fields"
        case .laps: "Track laps"
        case .blocks: "City blocks"
        case .km: "Kilometers"
        case .mi: "Miles"
        }
    }

    var stepsPerUnit: Double {
        switch self {
        case .holes: 1300        // walking a hole, tee to green plus the walk to the next tee
        case .soccerFields: 140  // one length of a 105 m field
        case .laps: 525          // one 400 m lap
        case .blocks: 105        // a ~80 m city block
        case .km: 1320
        case .mi: 2125
        }
    }

    var emoji: String {
        switch self {
        case .holes: "⛳️"
        case .soccerFields: "⚽️"
        case .laps: "🏃"
        case .blocks: "🏙️"
        case .km, .mi: "📏"
        }
    }

    var tileTitle: String {
        switch self {
        case .holes: "Golf"
        case .soccerFields: "Soccer"
        case .laps: "Track"
        case .blocks: "City"
        case .km, .mi: "Distance"
        }
    }

    var detail: String {
        switch self {
        case .holes: "holes walked"
        case .soccerFields: "soccer fields"
        case .laps: "track laps"
        case .blocks: "city blocks"
        case .km: "km walked"
        case .mi: "miles walked"
        }
    }

    // Shown at the end of goal days in the Last 7 days table.
    var goalFlag: String { self == .holes ? "⛳️" : "🏁" }

    func amount(_ steps: Int) -> String {
        let value = Double(steps) / stepsPerUnit
        let decimals = (self == .soccerFields || self == .blocks) ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }

    // "~3.2 holes walked"
    func phrase(_ steps: Int) -> String { "~\(amount(steps)) \(detail)" }
}

// A saved session. Stored under the old "rounds" key; rounds saved before sessions existed
// have no kind and load as golf.
struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    let start: Date
    let end: Date
    let holes: Int          // golf only; 0 otherwise
    let steps: Int
    var kind: SessionKind? = nil
    var name: String? = nil // custom sessions

    var sessionKind: SessionKind { kind ?? .golf }
    var title: String {
        switch sessionKind {
        case .golf: "\(holes) holes"
        case .custom: (name?.isEmpty == false ? name! : "Custom")
        default: sessionKind.name
        }
    }
}

// MARK: - Sessions card (main screen)

struct SessionCard: View {
    @ObservedObject var store: StepStore
    let theme: Theme
    @AppStorage("roundStart") private var roundStart: Double = 0   // 0 = no session going
    @AppStorage("roundHoles") private var holes = 18
    @AppStorage("rounds") private var recordsData = Data()
    @AppStorage("sessionKind") private var kind: SessionKind = .golf
    @AppStorage("sessionName") private var customName = ""
    @AppStorage("funUnit") private var funUnit: FunUnit = .holes
    @State private var sessionSteps = 0
    @State private var confirmEnd = false

    private var inSession: Bool { roundStart > 0 }
    private var startDate: Date { Date(timeIntervalSince1970: roundStart) }
    private var records: [SessionRecord] {
        (try? JSONDecoder().decode([SessionRecord].self, from: recordsData)) ?? []
    }

    // "round" for golf, otherwise the session's own name ("hike", "beach walk").
    private var noun: String {
        switch kind {
        case .golf: "round"
        case .custom: customName.isEmpty ? "session" : customName.lowercased()
        default: kind.name.lowercased()
        }
    }

    // Golf always counts holes; other sessions use your fun unit.
    private func distance(_ steps: Int, kind: SessionKind) -> String {
        (kind == .golf ? FunUnit.holes : funUnit).phrase(steps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions").font(.headline)

            if inSession {
                HStack {
                    Text(kind == .golf ? "ROUND IN PROGRESS · \(holes) HOLES"
                                       : "\(kind.emoji) \(noun.uppercased()) IN PROGRESS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.done)
                    Spacer()
                    Text(startDate, style: .timer)
                        .font(.caption.monospacedDigit())
                }
                Text("\(sessionSteps.formatted()) steps")
                    .font(.title.weight(.bold))
                Text(distance(sessionSteps, kind: kind))
                    .foregroundStyle(Color.primary.opacity(0.7))
                Button { confirmEnd = true } label: {
                    Text("End \(noun)").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SessionKind.allCases) { option in
                            Button { kind = option } label: {
                                Text("\(option.emoji) \(option.name)")
                                    .font(.subheadline.weight(option == kind ? .semibold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(option == kind ? Color.black : Color.primary)
                                    .background(option == kind ? theme.done : Color.primary.opacity(0.08),
                                                in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(option == kind ? .isSelected : [])
                        }
                    }
                }
                if kind == .golf {
                    Picker("Holes", selection: $holes) {
                        Text("9 holes").tag(9)
                        Text("18 holes").tag(18)
                    }
                    .pickerStyle(.segmented)
                }
                if kind == .custom {
                    TextField("Name it (e.g. Beach walk)", text: $customName)
                        .textFieldStyle(.roundedBorder)
                }
                Button {
                    sessionSteps = 0
                    roundStart = Date.now.timeIntervalSince1970
                } label: {
                    Text("\(kind.emoji) Start \(noun)").frame(maxWidth: .infinity).foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.done)
                Text("Counts only the steps you take until you tap End.")
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.6))
            }

            if !records.isEmpty {
                Divider()
                Text("Past sessions (press and hold to delete)")
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.7))
                ForEach(Array(records.reversed())) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            Text("\(r.sessionKind.emoji) \(r.title) · \(duration(r))")
                                .font(.caption)
                                .foregroundStyle(Color.primary.opacity(0.7))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(r.steps.formatted()) steps")
                                .font(.subheadline.weight(.semibold))
                            Text(distance(r.steps, kind: r.sessionKind))
                                .font(.caption)
                                .foregroundStyle(Color.primary.opacity(0.7))
                        }
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Delete session", role: .destructive) { delete(r) }
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("End this \(noun)?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("Save \(noun)") { Task { await endSession(save: true) } }
            Button("Discard \(noun)", role: .destructive) { Task { await endSession(save: false) } }
        }
        // While a session is going, re-count its steps every 30 seconds.
        .task(id: roundStart) {
            while roundStart > 0 && !Task.isCancelled {
                sessionSteps = await store.steps(from: startDate)
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: store.today) { _, _ in
            guard inSession else { return }
            Task { sessionSteps = await store.steps(from: startDate) }
        }
    }

    private func endSession(save: Bool) async {
        if save {
            let start = startDate
            let end = Date.now
            let steps = await store.steps(from: start, to: end)
            var list = records
            list.append(SessionRecord(start: start, end: end, holes: kind == .golf ? holes : 0, steps: steps,
                                      kind: kind, name: kind == .custom ? customName : nil))
            recordsData = (try? JSONEncoder().encode(list)) ?? recordsData
        }
        roundStart = 0
        sessionSteps = 0
    }

    private func delete(_ record: SessionRecord) {
        let list = records.filter { $0.id != record.id }
        recordsData = (try? JSONEncoder().encode(list)) ?? recordsData
    }

    private func duration(_ r: SessionRecord) -> String {
        let mins = Int(r.end.timeIntervalSince(r.start) / 60)
        return "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
    }
}

// MARK: - Fun-unit scene (drawn inside the ring, behind your mini-me)

// A soft scene that matches your fun unit: golf green, soccer field, running track, city, road.
// Drawn on a 270 x 270 grid (the ring's size); the ground line sits at your mini-me's feet.
struct UnitScene: View {
    let unit: FunUnit

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 270
            ctx.scaleBy(x: s, y: s)
            let horizon = 152.0
            let ground = CGRect(x: 0, y: horizon, width: 270, height: 270 - horizon)

            func fill(_ r: CGRect, _ c: Color) { ctx.fill(Path(r), with: .color(c)) }
            func line(_ a: CGPoint, _ b: CGPoint, _ c: Color, _ w: Double, dash: [CGFloat] = []) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, dash: dash))
            }
            let grass = Color(red: 0.30, green: 0.65, blue: 0.30)
            let sky = Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.18)
            fill(CGRect(x: 0, y: 0, width: 270, height: horizon), sky)

            switch unit {
            case .holes:   // fairway, putting green, flag
                fill(ground, grass.opacity(0.30))
                ctx.fill(Path(ellipseIn: CGRect(x: 160, y: horizon - 6, width: 90, height: 24)),
                         with: .color(grass.opacity(0.35)))
                line(CGPoint(x: 205, y: horizon + 6), CGPoint(x: 205, y: horizon - 48), Color.gray.opacity(0.8), 1.5)
                var flag = Path()
                flag.move(to: CGPoint(x: 205, y: horizon - 48))
                flag.addLine(to: CGPoint(x: 224, y: horizon - 42))
                flag.addLine(to: CGPoint(x: 205, y: horizon - 36))
                ctx.fill(flag, with: .color(Color.red.opacity(0.75)))
                ctx.fill(Path(ellipseIn: CGRect(x: 201, y: horizon + 4, width: 8, height: 3)), with: .color(.black.opacity(0.4)))

            case .soccerFields:   // mowed stripes, center circle, goal
                for i in 0..<9 {
                    fill(CGRect(x: Double(i) * 30, y: horizon, width: 30, height: ground.height),
                         grass.opacity(i.isMultiple(of: 2) ? 0.32 : 0.22))
                }
                // halfway line + center circle, low enough to stay under the step count
                ctx.stroke(Path(ellipseIn: CGRect(x: 85, y: horizon + 84, width: 100, height: 30)),
                           with: .color(.white.opacity(0.7)), lineWidth: 1.5)
                line(CGPoint(x: 0, y: horizon + 99), CGPoint(x: 270, y: horizon + 99), .white.opacity(0.7), 1.5)
                // goal frame + net
                let goal = CGRect(x: 182, y: horizon - 34, width: 50, height: 34)
                for x in stride(from: goal.minX, through: goal.maxX, by: 7) {
                    line(CGPoint(x: x, y: goal.minY), CGPoint(x: x, y: goal.maxY), .gray.opacity(0.35), 0.7)
                }
                for y in stride(from: goal.minY, through: goal.maxY, by: 7) {
                    line(CGPoint(x: goal.minX, y: y), CGPoint(x: goal.maxX, y: y), .gray.opacity(0.35), 0.7)
                }
                var frame = Path()
                frame.move(to: CGPoint(x: goal.minX, y: goal.maxY))
                frame.addLine(to: CGPoint(x: goal.minX, y: goal.minY))
                frame.addLine(to: CGPoint(x: goal.maxX, y: goal.minY))
                frame.addLine(to: CGPoint(x: goal.maxX, y: goal.maxY))
                ctx.stroke(frame, with: .color(.white), lineWidth: 2.5)
                ctx.stroke(frame, with: .color(.gray.opacity(0.5)), lineWidth: 0.6)

            case .laps:   // red running track with lane lines, infield grass up top
                fill(CGRect(x: 0, y: horizon - 18, width: 270, height: 18), grass.opacity(0.25))
                fill(ground, Color(red: 0.85, green: 0.35, blue: 0.25).opacity(0.35))
                for i in 0...5 {
                    let y = horizon + Double(i) * 20
                    line(CGPoint(x: 0, y: y), CGPoint(x: 270, y: y), .white.opacity(i == 0 ? 0.8 : 0.45), 1.2)
                }
                line(CGPoint(x: 205, y: horizon), CGPoint(x: 222, y: 270), .white.opacity(0.6), 2)  // finish line

            case .blocks:   // skyline with windows, sidewalk
                let buildings: [(Double, Double, Double)] = [(0, 40, 70), (38, 34, 105), (70, 30, 55), (98, 36, 90),
                                                             (132, 40, 120), (170, 28, 65), (196, 38, 100), (232, 40, 75)]
                for (x, w, h) in buildings {
                    let r = CGRect(x: x, y: horizon - h, width: w, height: h)
                    fill(r, Color.gray.opacity(0.28))
                    for wy in stride(from: r.minY + 8, to: r.maxY - 6, by: 12) {
                        for wx in stride(from: r.minX + 6, to: r.maxX - 6, by: 10) {
                            fill(CGRect(x: wx, y: wy, width: 4, height: 5), Color.yellow.opacity(0.35))
                        }
                    }
                }
                fill(ground, Color.gray.opacity(0.22))
                for x in stride(from: 0.0, to: 270, by: 30) {   // sidewalk slabs
                    line(CGPoint(x: x, y: horizon), CGPoint(x: x - 12, y: horizon + 22), .gray.opacity(0.35), 1)
                }
                line(CGPoint(x: 0, y: horizon + 22), CGPoint(x: 270, y: horizon + 22), .gray.opacity(0.45), 2)

            case .km, .mi:   // road with dashed center line and a distance sign
                fill(CGRect(x: 0, y: horizon - 10, width: 270, height: 10), grass.opacity(0.25))
                fill(ground, Color.gray.opacity(0.30))
                line(CGPoint(x: 0, y: horizon + 96), CGPoint(x: 270, y: horizon + 96), .yellow.opacity(0.8), 3, dash: [16, 12])
                line(CGPoint(x: 0, y: horizon + 2), CGPoint(x: 270, y: horizon + 2), .white.opacity(0.7), 1.5)
                line(CGPoint(x: 212, y: horizon - 2), CGPoint(x: 212, y: horizon - 34), .gray.opacity(0.8), 2)
                let sign = CGRect(x: 194, y: horizon - 56, width: 36, height: 22)
                ctx.fill(Path(roundedRect: sign, cornerRadius: 3), with: .color(Color(red: 0.10, green: 0.50, blue: 0.30).opacity(0.85)))
                ctx.draw(Text(unit == .km ? "1 km" : "1 mi").font(.system(size: 10, weight: .bold)).foregroundStyle(.white),
                         at: CGPoint(x: sign.midX, y: sign.midY))
            }
        }
        .accessibilityHidden(true)
    }
}
