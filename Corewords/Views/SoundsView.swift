import SwiftUI

/// The 44 sounds of English with tips for Turkish speakers, and a minimal-pair listening trainer.
struct SoundsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showHardOnly = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Adaptive {
                        trainerCard
                    } second: {
                        Toggle(isOn: $showHardOnly) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hard for Turkish speakers").font(.headline)
                                Text("Sounds Turkish doesn't have, or uses differently").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tint(.orange)
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    group("Vowels", "vowel")
                    group("Diphthongs", "diphthong")
                    group("Consonants", "consonant")
                    Text("Transcriptions follow standard dictionary IPA. US forms come from the CMU Pronouncing Dictionary, UK forms from Britfone.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Sounds")
            .navigationDestination(for: Phonetics.Sound.self) { SoundDetailView(sound: $0) }
        }
    }

    private var trainerCard: some View {
        NavigationLink {
            MinimalPairsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "ear.and.waveform").font(.system(size: 34)).foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(LinearGradient(colors: [.brandIndigo, .brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Minimal pairs").font(.headline).foregroundStyle(.primary)
                        if !model.store.isPro { ProBadge() }
                    }
                    Text("sheep or ship? three or tree? Train your ear on \(model.content.phonetics.pairs.count) word pairs.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func group(_ title: LocalizedStringKey, _ kind: String) -> some View {
        let sounds = model.content.phonetics.sounds.filter { $0.kind == kind && (!showHardOnly || $0.hard) }
        return VStack(alignment: .leading, spacing: 10) {
            if !sounds.isEmpty { Text(title).font(.title3.bold()) }
            FoldGrid(items: sounds, minimum: 96, spacing: 10) { s in
                    NavigationLink(value: s) {
                        VStack(spacing: 4) {
                            Text("/\(s.ipa)/").font(.system(size: 24, weight: .medium, design: .serif)).foregroundStyle(.primary)
                            Text(s.examples.first?.w ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            if s.hard { Circle().fill(Color.orange).frame(width: 8, height: 8).padding(8) }
                        }
                    }
                    .buttonStyle(.plain)
            }
        }
    }
}

struct SoundDetailView: View {
    @EnvironmentObject var model: AppModel
    let sound: Phonetics.Sound

    var body: some View {
        let pairs = model.content.phonetics.pairs.filter { $0.focus.contains(sound.ipa) }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("/\(sound.ipa)/").font(.system(size: 72, weight: .medium, design: .serif))
                    .frame(maxWidth: .infinity)
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        if sound.hard { Label("Hard for Turkish speakers", systemImage: "exclamationmark.triangle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.orange) }
                        Text(model.settings.meaning == .turkish ? sound.tipTr : sound.tip).font(.body)
                        if model.settings.meaning == .turkish { Text(sound.tip).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                Text("Examples").font(.headline)
                ForEach(sound.examples, id: \.w) { ex in
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(ex.w).font(.rounded(22, .semibold))
                                Spacer()
                                IPARow(text: ex.w, us: ex.us, uk: ex.uk, compact: true)
                            }
                            SayItButton(listener: model.listener, word: ex.w)
                        }
                    }
                }
                if !pairs.isEmpty {
                    Text("Minimal pairs").font(.headline)
                    ForEach(pairs) { p in PairRow(pair: p) }
                }
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("/\(sound.ipa)/")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PairRow: View {
    @EnvironmentObject var model: AppModel
    let pair: Phonetics.Pair

    var body: some View {
        HStack(spacing: 10) {
            side(pair.a)
            Text("vs").font(.caption).foregroundStyle(.secondary)
            side(pair.b)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func side(_ e: Phonetics.Example) -> some View {
        Button { model.speak(e.w) } label: {
            VStack(spacing: 2) {
                Text(e.w).font(.rounded(19, .semibold)).foregroundStyle(.primary)
                Text("/\(model.settings.accent == .uk && !e.uk.isEmpty ? e.uk : e.us)/").font(.system(size: 14, design: .serif)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.plain)
    }
}

/// Hear one word of a pair, pick which one it was.
struct MinimalPairsView: View {
    @EnvironmentObject var model: AppModel
    @State private var focus: String?
    @State private var current: Phonetics.Pair?
    @State private var playedA = true
    @State private var picked: Bool?
    @State private var right = 0
    @State private var total = 0
    @State private var sayMode = false

    static let freeGroups = 2

    private var groups: [String] {
        var seen: [String] = []
        for p in model.content.phonetics.pairs where !seen.contains(p.focus) { seen.append(p.focus) }
        return seen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Mode", selection: $sayMode) {
                    Text("Listen").tag(false)
                    Text("Speak").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: sayMode) { _, _ in nextPair() }
                Text(sayMode ? "Say the word shown. On-device speech recognition checks that it heard this word and not its pair."
                             : "Listen and choose the word you hear. Tap a word afterwards to compare.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(nil, "All")
                        ForEach(Array(groups.enumerated()), id: \.offset) { i, g in
                            chip(g, LocalizedStringKey(g), locked: i >= Self.freeGroups && !model.store.isPro)
                        }
                    }
                }
                if let p = current, sayMode {
                    let target = playedA ? p.a : p.b
                    let other = playedA ? p.b : p.a
                    VStack(spacing: 18) {
                        Text(target.w).font(.rounded(48, .bold))
                        Text("/\(model.settings.accent == .uk && !target.uk.isEmpty ? target.uk : target.us)/").font(.system(size: 20, design: .serif)).foregroundStyle(.secondary)
                        Text("not \(other.w)").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            SpeakButton(text: target.w, size: 18)
                            SpeakButton(text: target.w, size: 15, slow: true)
                            SpeakButton(text: other.w, size: 13)
                        }
                        SayItButton(listener: model.listener, word: target.w, not: other.w) { ok in
                            total += 1
                            if ok { right += 1 }
                        }
                        .id(p.id + (playedA ? "a" : "b"))
                        Button { nextPair() } label: { Text("Next pair") }.buttonStyle(PrimaryButtonStyle())
                        Text("\(right) of \(total) correct").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                } else if let p = current {
                    VStack(spacing: 20) {
                        HStack(spacing: 18) {
                            Button { play(p) } label: {
                                Image(systemName: "speaker.wave.3.fill").font(.system(size: 40, weight: .semibold))
                                    .frame(width: 110, height: 110)
                                    .background(Color.accentColor.opacity(0.14), in: Circle())
                            }
                            .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                            .accessibilityLabel(Text("Play again"))
                        }
                        HStack(spacing: 12) {
                            answer(p.a, isA: true)
                            answer(p.b, isA: false)
                        }
                        if picked != nil {
                            Button { nextPair() } label: { Text("Next pair") }.buttonStyle(PrimaryButtonStyle())
                        }
                        Text("\(right) of \(total) correct").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Minimal pairs")
        .onAppear { if current == nil { nextPair() } }
    }

    private func chip(_ g: String?, _ title: LocalizedStringKey, locked: Bool = false) -> some View {
        Button {
            if locked { model.showPaywall = true; return }
            focus = g
            nextPair()
        } label: {
            HStack(spacing: 4) {
                if locked { Image(systemName: "lock.fill").font(.caption2) }
                Text(title).font(.system(size: 15, design: g == nil ? .default : .serif))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(focus == g ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(focus == g ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var available: [Phonetics.Pair] {
        let allowed = model.store.isPro ? groups : Array(groups.prefix(Self.freeGroups))
        return model.content.phonetics.pairs.filter { allowed.contains($0.focus) && (focus == nil || $0.focus == focus) }
    }

    private func nextPair() {
        picked = nil
        let pool = available
        guard !pool.isEmpty else { return }
        var p = pool.randomElement()!
        if pool.count > 1, let c = current, c.id == p.id { p = pool.first { $0.id != c.id } ?? p }
        current = p
        playedA = Bool.random()
        if !sayMode { play(p) }
    }

    private func play(_ p: Phonetics.Pair) {
        model.speak(playedA ? p.a.w : p.b.w)
    }

    private func answer(_ e: Phonetics.Example, isA: Bool) -> some View {
        let correct = isA == playedA
        let state: OptionButton.State = picked == nil ? .idle : (correct ? .right : (picked == isA ? .wrong : .dimmed))
        return OptionButton(text: e.w, state: state) {
            if picked != nil { model.speak(e.w); return }
            picked = isA
            total += 1
            if correct { right += 1; Haptics.success(model.settings.haptics) } else { Haptics.error(model.settings.haptics) }
        }
    }
}
