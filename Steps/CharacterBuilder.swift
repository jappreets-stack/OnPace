import SwiftUI

// "Build your mini-me": pick an outfit, skin tone, hair, beard, glasses and colors.
// Everything shows up live on the character at the top.
struct CharacterBuilder: View {
    @Binding var avatar: Avatar
    @Binding var look: Look
    @State private var pose: Mood = .walk

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    CharacterView(avatar: avatar, mood: pose, look: look)
                        .frame(height: 170)
                    Picker("Pose", selection: $pose) {
                        Text("Walking").tag(Mood.walk)
                        Text("Goal hit").tag(Mood.celebrate)
                        Text("Behind").tag(Mood.slump)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 6)
            } footer: {
                Text("Tap a pose to see how your mini-me moves during the day.")
            }

            Section {
                Picker("Male or female", selection: Binding(get: { look.body },
                                                            set: { look.switchTo($0) })) {
                    ForEach(BodyShape.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Male or female")
            } footer: {
                Text("Sets a matching body, hair and outfit. You can still change anything below.")
            }

            Section("Outfit") {
                Picker("Outfit", selection: $avatar) {
                    ForEach(Avatar.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                if avatar == .golfer {
                    Picker("Bottoms", selection: $look.bottoms) {
                        ForEach(GolfBottoms.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if avatar == .ripped {
                    Picker("Top", selection: $look.top) {
                        ForEach(GymTop.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                // One outfit color; the trim (collar, shoes) picks a match by itself.
                ColorDots(title: "Outfit color", options: Swatch.allCases, color: \.color, name: \.name,
                          selection: Binding(get: { look.main },
                                             set: { look.main = $0; look.accent = $0.partner }))
                if avatar == .baller {
                    HStack {
                        Text("Jersey letter")
                        Spacer()
                        TextField("J", text: $look.letter)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .frame(width: 60)
                            .onChange(of: look.letter) { _, new in
                                let short = String(new.uppercased().prefix(2))
                                if short != new { look.letter = short }
                            }
                    }
                }
            }

            Section("Skin tone") {
                ColorDots(title: nil, options: SkinTone.allCases, color: \.color, name: \.name,
                          selection: $look.skin)
            }

            Section("Hair") {
                HeadChips(options: HairStyle.options(for: look.body), name: \.name, base: look, selection: $look.hair) {
                    $0.hair = $1
                }
                if look.hair.wearsHat {
                    ColorDots(title: "\(look.hair.name) color",
                              options: Swatch.allCases, color: \.color, name: \.name,
                              selection: Binding(get: { look.hat },
                                                 set: { look.hat = $0; look.hatTrim = nil }))
                }
                ColorDots(title: "Hair & beard color", options: HairColor.allCases, color: \.color,
                          name: \.name, selection: $look.hairColor)
            }

            Section("Face") {
                Toggle("Eyelashes", isOn: $look.lashes)
                ColorDots(title: "Lip color", options: LipColor.allCases, color: \.color, name: \.name,
                          selection: $look.lips)
            }

            Section("Beard") {
                HeadChips(options: Beard.allCases, name: \.name, base: look, selection: $look.beard) {
                    $0.beard = $1
                }
            }

            Section("Glasses") {
                HeadChips(options: Glasses.allCases, name: \.name, base: look, selection: $look.glasses) {
                    $0.glasses = $1
                }
            }

            Section {
                Button("Start over") {
                    look = .starter
                    avatar = .golfer
                }
            }
        }
        .navigationTitle("Build your mini-me")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// A row of tappable color circles; the picked one gets a ring around it.
struct ColorDots<Option: Hashable & Identifiable>: View {
    let title: String?
    let options: [Option]
    let color: KeyPath<Option, Color>
    let name: KeyPath<Option, String>
    @Binding var selection: Option

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text("\(title): \(selection[keyPath: name])")
                    .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options) { option in
                        Button { selection = option } label: {
                            Circle()
                                .fill(option[keyPath: color])
                                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                .frame(width: 30, height: 30)
                                .padding(3)
                                .overlay(Circle().stroke(Color.primary,
                                                         lineWidth: option == selection ? 2.5 : 0))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option[keyPath: name])
                        .accessibilityAddTraits(option == selection ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// A row of little heads, each showing what one option would look like on you.
struct HeadChips<Option: Hashable & Identifiable>: View {
    let options: [Option]
    let name: KeyPath<Option, String>
    let base: Look
    @Binding var selection: Option
    let apply: (inout Look, Option) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button { selection = option } label: {
                        VStack(spacing: 4) {
                            HeadView(look: { var l = base; apply(&l, option); return l }())
                                .frame(width: 52, height: 60)
                            Text(option[keyPath: name])
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(option == selection ? 0.12 : 0),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary, lineWidth: option == selection ? 2 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// Just the head, still, for the option chips.
struct HeadView: View {
    let look: Look

    var body: some View {
        Canvas { ctx, size in
            // The head lives in x 28...72, y 8...62 of the 100 x 140 character grid.
            let s = min(size.width / 44, size.height / 54)
            ctx.translateBy(x: (size.width - 44 * s) / 2, y: (size.height - 54 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            ctx.translateBy(x: -28, y: -8)
            Pen.head(ctx, look: look)
        }
    }
}

#Preview {
    @Previewable @State var avatar = Avatar.golfer
    @Previewable @State var look = Look.original
    NavigationStack { CharacterBuilder(avatar: $avatar, look: $look) }
}
