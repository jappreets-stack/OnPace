import SwiftUI
import Combine
import HealthKit

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
    var holes: Int          // golf only; 0 otherwise
    let steps: Int
    var kind: SessionKind? = nil
    var name: String? = nil // custom sessions
    var fromWorkout: Bool? = nil  // added from Apple's Workout app
    var meters: Double? = nil     // real distance walked (Health); nil on older sessions

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
    private let funUnit = FunUnit.walked
    @AppStorage("appStyle") private var appStyle: AppStyle = .minimal
    @State private var sessionSteps = 0
    @State private var sessionMeters: Double?
    @State private var confirmEnd = false
    @State private var showPicker = false

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
    private func distance(_ steps: Int, meters: Double?, kind: SessionKind) -> String {
        (kind == .golf ? FunUnit.holes : funUnit).phrase(steps, meters: meters)
    }

    var body: some View {
        Group {
            if inSession {
                // A session is going: live steps and distance, and an End button.
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(kind == .golf ? "⛳️ ROUND IN PROGRESS · \(holes) HOLES"
                                           : "\(kind.emoji) \(noun.uppercased()) IN PROGRESS")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.done)
                        Spacer()
                        Text(startDate, style: .timer)
                            .font(.subheadline.monospacedDigit())
                    }
                    Text("\(sessionSteps.formatted()) steps")
                        .font(.largeTitle.weight(.bold))
                    Text(distance(sessionSteps, meters: sessionMeters, kind: kind))
                        .font(.title3)
                        .foregroundStyle(Color.primary.opacity(0.7))
                    Button { confirmEnd = true } label: {
                        Text("End \(noun)").font(.title3.weight(.semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                }
                .padding(appStyle == .retro16 ? 20 : 16)
                .styleCard(appStyle)
            } else if appStyle == .retro16 {
                // 16-bit adventure: the same button as a blue menu panel.
                Button { showPicker = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").foregroundStyle(Retro16.gold)
                        Text("Start a session").foregroundStyle(.white)
                    }
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .retro16Panel()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if appStyle == .cozy {
                // Cozy pastel: a soft peach-to-pink pill.
                Button { showPicker = true } label: {
                    Label("Start a session", systemImage: "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient(colors: [Cozy.peach, Cozy.rose], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule())
                        .shadow(color: Cozy.rose.opacity(0.35), radius: 10, y: 5)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // Not in a session: one big button; the choices are in a sheet.
                Button { showPicker = true } label: {
                    Label("Start a session", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.done)
            }
        }
        .sheet(isPresented: $showPicker) {
            SessionPicker(theme: theme) {
                sessionSteps = 0
                sessionMeters = nil
                roundStart = Date.now.timeIntervalSince1970
                showPicker = false
            }
        }
        .confirmationDialog("End this \(noun)?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("Save \(noun)") { Task { await endSession(save: true) } }
            Button("Discard \(noun)", role: .destructive) { Task { await endSession(save: false) } }
        }
        // While a session is going, re-count its steps every 30 seconds.
        .task(id: roundStart) {
            while roundStart > 0 && !Task.isCancelled {
                sessionSteps = await store.steps(from: startDate)
                sessionMeters = await WalkDistance.meters(store.health, from: startDate)
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
            let meters = await WalkDistance.meters(store.health, from: start, to: end)
            var list = records
            list.append(SessionRecord(start: start, end: end, holes: kind == .golf ? holes : 0, steps: steps,
                                      kind: kind, name: kind == .custom ? customName : nil, meters: meters))
            recordsData = (try? JSONEncoder().encode(list)) ?? recordsData
        }
        roundStart = 0
        sessionSteps = 0
        sessionMeters = nil
    }



}

// MARK: - "What are you doing?" sheet

struct SessionPicker: View {
    let theme: Theme
    let start: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("roundHoles") private var holes = 18
    @AppStorage("sessionKind") private var kind: SessionKind = .golf
    @AppStorage("sessionName") private var customName = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SessionKind.allCases) { option in
                            Button { kind = option } label: {
                                VStack(spacing: 6) {
                                    Text(option.emoji).font(.system(size: 38))
                                    Text(option.name).font(.headline)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .foregroundStyle(Color.primary)
                                .background(Color.primary.opacity(option == kind ? 0.14 : 0.06),
                                            in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(theme.done, lineWidth: option == kind ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(option == kind ? .isSelected : [])
                        }
                    }
                    if kind == .golf {
                        Picker("Holes", selection: $holes) {
                            Text("9 holes").tag(9)
                            Text("18 holes").tag(18)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                    }
                    if kind == .custom {
                        TextField("Name it (e.g. Beach walk)", text: $customName)
                            .font(.title3)
                            .padding(12)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Button(action: start) {
                        Text("\(kind.emoji) Start \(kind == .golf ? "round" : kind == .custom ? (customName.isEmpty ? "session" : customName.lowercased()) : kind.name.lowercased())")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.done)
                    Text("Counts only the steps you take until you tap End.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.6))
                }
                .padding()
            }
            .navigationTitle("What are you doing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Past sessions (History tab)

struct SessionHistory: View {
    let theme: Theme
    @AppStorage("rounds") private var recordsData = Data()
    private let funUnit = FunUnit.walked
    @AppStorage("appStyle") private var appStyle: AppStyle = .minimal

    private var records: [SessionRecord] {
        (try? JSONDecoder().decode([SessionRecord].self, from: recordsData)) ?? []
    }

    private func distance(_ r: SessionRecord) -> String {
        (r.sessionKind == .golf ? FunUnit.holes : funUnit).phrase(r.steps, meters: r.meters)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past sessions").font(.title2.weight(.bold))
            if records.isEmpty {
                Text("Sessions you start in OnPace, or finish in Apple's Workout app, show up here.")
                    .font(.body)
                    .foregroundStyle(Color.primary.opacity(0.6))
            } else {
                Text("Press and hold one to change or delete it.")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.6))
                ForEach(Array(records.reversed())) { r in
                    Divider()
                    HStack(spacing: 12) {
                        Text(r.sessionKind.emoji).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).font(.body.weight(.semibold))
                            Text(r.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                 + " · \(duration(r))" + (r.fromWorkout == true ? " · Workout app" : ""))
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.6))
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(r.steps.formatted())
                                .font(.title3.weight(.semibold).monospacedDigit())
                            Text(distance(r))
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.6))
                        }
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        if r.sessionKind == .golf {
                            Button("Change to \(r.holes == 9 ? 18 : 9) holes") { toggleHoles(r) }
                        }
                        Button("Delete session", role: .destructive) { delete(r) }
                    }
                }
            }
        }
        .padding(appStyle == .retro16 ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .styleCard(appStyle)
    }

    private func delete(_ record: SessionRecord) {
        let list = records.filter { $0.id != record.id }
        recordsData = (try? JSONEncoder().encode(list)) ?? recordsData
    }

    private func toggleHoles(_ record: SessionRecord) {
        var list = records
        guard let i = list.firstIndex(where: { $0.id == record.id }) else { return }
        list[i].holes = list[i].holes == 9 ? 18 : 9
        recordsData = (try? JSONEncoder().encode(list)) ?? recordsData
    }

    private func duration(_ r: SessionRecord) -> String {
        let mins = Int(r.end.timeIntervalSince(r.start) / 60)
        return mins < 60 ? "\(mins) min" : "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
    }
}

// MARK: - Today's sessions for the watch

extension StepStore {
    // Saves today's sessions (yours and ones from the Workout app) where PhoneSync sends them to the watch.
    func shareTodaysSessions() {
        let d = UserDefaults.standard
        let records = (try? JSONDecoder().decode([SessionRecord].self, from: d.data(forKey: "rounds") ?? Data())) ?? []
        let unit = FunUnit.walked
        let today = records.filter { Calendar.current.isDateInToday($0.start) }.map { r in
            WatchSession(emoji: r.sessionKind.emoji, title: r.title, steps: r.steps,
                         distance: (r.sessionKind == .golf ? FunUnit.holes : unit).phrase(r.steps, meters: r.meters))
        }
        if let data = try? JSONEncoder().encode(today), let text = String(data: data, encoding: .utf8) {
            Shared.defaults.set(text, forKey: Shared.sessionsKey)
        }
    }
}

// MARK: - Workouts from Apple's Workout app

// Apple only shares a workout once it has ended, so this runs whenever the app refreshes:
// every new finished Golf / Hike / Walk / Run / Strength workout becomes a saved session.
extension StepStore {
    private static var importing = false

    // Which session a workout becomes (nil = skip, e.g. cycling or swimming).
    private static func session(for type: HKWorkoutActivityType) -> (SessionKind, String?)? {
        switch type {
        case .golf: (.golf, nil)
        case .hiking: (.hike, nil)
        case .walking: (.custom, "Walk")
        case .running: (.custom, "Run")
        case .traditionalStrengthTraining, .functionalStrengthTraining,
             .highIntensityIntervalTraining, .crossTraining: (.workout, nil)
        default: nil
        }
    }

    func importWorkouts() async {
        guard !Self.importing else { return }
        Self.importing = true
        defer { Self.importing = false }

        let d = UserDefaults.standard
        // The anchor remembers which workouts we've already looked at, so a session you
        // delete never comes back, and a workout that syncs from the watch late still counts.
        let anchor = d.data(forKey: "workoutAnchor").flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }
        let query = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: anchor)
        guard let result = try? await query.result(for: health) else { return }

        let firstTime = anchor == nil
        let weekAgo = Date.now.addingTimeInterval(-7 * 86_400)
        var list = (try? JSONDecoder().decode([SessionRecord].self, from: d.data(forKey: "rounds") ?? Data())) ?? []
        let liveStart = d.double(forKey: "roundStart")
        var added = 0

        // Sessions saved before distance was measured: look up how far you really walked.
        for i in list.indices where list[i].meters == nil {
            if let m = await WalkDistance.meters(health, from: list[i].start, to: list[i].end) {
                list[i].meters = m
                added += 1
            }
        }

        if d.object(forKey: "importWorkouts") as? Bool ?? true {
            for w in result.addedSamples.sorted(by: { $0.startDate < $1.startDate }) {
                guard let (kind, name) = Self.session(for: w.workoutActivityType) else { continue }
                if firstTime && w.endDate < weekAgo { continue }       // first time: only the last week
                if list.contains(where: { $0.id == w.uuid }) { continue }
                // Skip it if you also tracked that time as a session in OnPace.
                if list.contains(where: { $0.start < w.endDate && $0.end > w.startDate }) { continue }
                if liveStart > 0 && liveStart < w.endDate.timeIntervalSince1970 { continue }

                let steps = await self.steps(from: w.startDate, to: w.endDate)
                let meters = await WalkDistance.meters(health, from: w.startDate, to: w.endDate)
                let hours = w.endDate.timeIntervalSince(w.startDate) / 3600
                list.append(SessionRecord(id: w.uuid, start: w.startDate, end: w.endDate,
                                          holes: kind == .golf ? (hours < 2.5 ? 9 : 18) : 0,
                                          steps: steps, kind: kind, name: name, fromWorkout: true,
                                          meters: meters))
                added += 1
            }
        }
        if added > 0, let data = try? JSONEncoder().encode(list.sorted { $0.start < $1.start }) {
            d.set(data, forKey: "rounds")
        }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true) {
            d.set(data, forKey: "workoutAnchor")
        }
    }
}

extension View {
    // The card behind sessions: rounded gray (Original), white/dark gray (Clean minimal), blue menu panel (16-bit).
    @ViewBuilder func styleCard(_ style: AppStyle) -> some View {
        switch style {
        case .cozy: background(Cozy.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Cozy.rose.opacity(0.12), radius: 14, y: 6)
        case .minimal: background(Minimal.card, in: RoundedRectangle(cornerRadius: 22))
        case .retro16: retro16Panel()
        }
    }
}
