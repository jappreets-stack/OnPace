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
