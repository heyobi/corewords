import SwiftUI

extension Color {
    static let brandIndigo = Color(red: 0.31, green: 0.275, blue: 0.898)
    static let brandTeal = Color(red: 0.05, green: 0.58, blue: 0.53)
    static let good = Color(red: 0.13, green: 0.65, blue: 0.38)
    static let bad = Color(red: 0.88, green: 0.27, blue: 0.27)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A rounded panel used across the app.
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(18, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(17, .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A speaker button that reads the text aloud (US or UK voice). The tap target is at least 44 pt.
struct SpeakButton: View {
    @EnvironmentObject var model: AppModel
    let text: String
    var accent: Settings.Accent? = nil
    var size: CGFloat = 22
    var slow = false

    var body: some View {
        Button {
            if let accent { model.speak(text, accent: accent, slow: slow) } else { model.speak(text, slow: slow) }
        } label: {
            Image(systemName: slow ? "tortoise.fill" : "speaker.wave.2.fill")
                .font(.system(size: size, weight: .semibold))
                .frame(width: max(44, size * 2.2), height: max(44, size * 2.2))
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .contentShape(Circle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(slow ? Text("Play slowly") : Text("Play"))
    }
}

/// The word's IPA with play and slow-play buttons. Shows only the learner's accent unless "both accents" is on.
struct IPARow: View {
    @EnvironmentObject var model: AppModel
    let text: String
    let us: String
    let uk: String
    var compact = false

    var body: some View {
        let accent = model.settings.accent
        if model.settings.showBothAccents {
            HStack(spacing: compact ? 10 : 14) {
                if !us.isEmpty { one("US", us, .us, slow: false) }
                if !uk.isEmpty && uk != us { one("UK", uk, .uk, slow: false) }
            }
        } else {
            let ipa = accent == .uk && !uk.isEmpty ? uk : us
            HStack(spacing: 10) {
                SpeakButton(text: text, accent: accent, size: compact ? 15 : 18)
                SpeakButton(text: text, accent: accent, size: compact ? 13 : 15, slow: true)
                if !ipa.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(accent == .us ? "US" : "UK").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text("/\(ipa)/").font(.system(size: compact ? 16 : 19, design: .serif)).textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func one(_ label: LocalizedStringKey, _ ipa: String, _ accent: Settings.Accent, slow: Bool) -> some View {
        HStack(spacing: 6) {
            SpeakButton(text: text, accent: accent, size: compact ? 13 : 15)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("/\(ipa)/").font(.system(size: compact ? 15 : 17, design: .serif))
                    .textSelection(.enabled)
            }
        }
    }
}

/// Hold to say a word; on-device speech recognition says whether it was understood. Used outside graded
/// exercises: on new-word cards, word pages and in the Sounds tab. Part of Pro.
struct SayItButton: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var listener: Listener
    let word: String
    var forms: [String] = []
    /// A word that must NOT be heard (minimal pairs: say "ship", not "sheep").
    var not: String? = nil
    var onResult: ((Bool) -> Void)? = nil
    @State private var holding = false
    @State private var result: Bool?
    @State private var heard = ""

    var body: some View {
        HStack(spacing: 10) {
            if !model.store.isPro {
                Button { model.showPaywall = true } label: {
                    Label("Say it", systemImage: "mic.fill").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                ProBadge()
            } else if listener.state == .denied || listener.state == .unavailable {
                Text(listener.state == .denied ? "Allow the microphone and speech recognition in Settings to use Say it."
                     : "On-device English speech recognition isn't available on this device yet. In iOS Settings › General › Keyboard, turn on Dictation and add English.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label(holding ? "Listening…" : "Hold to say it", systemImage: holding ? "waveform" : "mic.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(Color.accentColor.opacity(holding ? 0.25 : 0.1), in: Capsule())
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: holding)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !holding else { return }
                            holding = true
                            result = nil
                            model.speaker.stop()
                            Task { await listener.start(accent: model.settings.accent) }
                        }
                        .onEnded { _ in
                            holding = false
                            Task {
                                try? await Task.sleep(for: .milliseconds(600))
                                heard = listener.transcript
                                listener.stop()
                                let ok = AnswerCheck.heard(heard, word: word, forms: forms, not: not)
                                result = ok
                                if ok { Haptics.success(model.settings.haptics) } else { Haptics.error(model.settings.haptics) }
                                onResult?(ok)
                            }
                        })
                    .accessibilityLabel(Text("Hold to say it"))
                if let result {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result ? Color.good : Color.bad).font(.title3)
                    Text(heard.isEmpty ? String(localized: "Nothing heard") : "\"\(heard)\"")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}

/// The example sentence with the target word highlighted.
struct ExampleText: View {
    let item: StudyItem
    var font: Font = .rounded(19)

    var body: some View {
        item.exampleRuns.reduce(Text("")) { acc, run in
            acc + (run.1 ? Text(run.0).bold().foregroundColor(.accentColor) : Text(run.0))
        }
        .font(font)
    }
}

struct ProgressRing: View {
    let value: Double  // 0...1
    var lineWidth: CGFloat = 12
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: value)
        }
    }
}

struct POSBadge: View {
    let pos: String
    var body: some View {
        Text(Self.label(pos))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(.secondary)
    }

    static func label(_ pos: String) -> LocalizedStringKey {
        switch pos {
        case "n": "noun"
        case "v": "verb"
        case "adj": "adjective"
        case "adv": "adverb"
        case "prep": "preposition"
        case "pron": "pronoun"
        case "det": "determiner"
        case "conj": "conjunction"
        case "num": "number"
        case "modal": "modal verb"
        case "int": "interjection"
        case "phr": "phrasal verb"
        default: "word"
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(LinearGradient(colors: [.brandIndigo, .brandTeal], startPoint: .leading, endPoint: .trailing), in: Capsule())
            .foregroundStyle(.white)
    }
}

/// Two columns split at the middle of the screen, not just the middle of the view, with a clear gap on both
/// sides. On an open iPhone Duo the middle of the screen is the fold, so nothing sits on it even when the view
/// is offset by the sidebar or the status bar.
struct FoldSplit<L: View, R: View>: View {
    var alignment: VerticalAlignment = .top
    var gap: CGFloat = 36
    @ViewBuilder var left: L
    @ViewBuilder var right: R
    @State private var frame: CGRect = .zero

    static var screenMidX: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let w = scene?.windows.first(where: \.isKeyWindow)?.bounds.width ?? scene?.screen.bounds.width ?? 0
        return w / 2
    }

    var body: some View {
        let width = frame.width
        // Only trust a plausible measurement; otherwise fall back to two equal, uncapped halves.
        let measured = width >= 500
        var mid = Self.screenMidX - frame.minX
        if !measured || mid < width * 0.3 || mid > width * 0.7 { mid = width / 2 }
        return HStack(alignment: alignment, spacing: 0) {
            left
                .frame(maxWidth: measured ? max(0, mid - gap) : .infinity, alignment: .leading)
            Color.clear.frame(width: 2 * gap, height: 1)
            right
                .frame(maxWidth: measured ? max(0, width - mid - gap) : .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { f in
            frame = f
        }
    }
}

/// One column on compact width; two columns on regular width (iPad, the open iPhone Duo, large iPhones in
/// landscape), split at the fold.
struct Adaptive<A: View, B: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var spacing: CGFloat = 20
    @ViewBuilder var first: A
    @ViewBuilder var second: B

    var body: some View {
        if sizeClass == .regular {
            FoldSplit(alignment: .top, gap: 18) {
                VStack(spacing: spacing) { first }
            } right: {
                VStack(spacing: spacing) { second }
            }
        } else {
            VStack(spacing: spacing) {
                first
                second
            }
        }
    }
}

/// A grid that, on regular width, puts the first half of the items left of the fold and the rest right of it,
/// so no cell straddles the iPhone Duo's fold.
struct FoldGrid<Item: Identifiable, Cell: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let items: [Item]
    var minimum: CGFloat = 280
    var spacing: CGFloat = 12
    @ViewBuilder var cell: (Item) -> Cell

    var body: some View {
        if sizeClass == .regular && items.count > 1 {
            let half = (items.count + 1) / 2
            FoldSplit(alignment: .top, gap: 18) {
                grid(Array(items.prefix(half)))
            } right: {
                grid(Array(items.dropFirst(half)))
            }
        } else {
            grid(items)
        }
    }

    private func grid(_ list: [Item]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: spacing)], spacing: spacing) {
            ForEach(list) { cell($0) }
        }
    }
}

enum Haptics {
    static func success(_ on: Bool) { if on { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func error(_ on: Bool) { if on { UINotificationFeedbackGenerator().notificationOccurred(.error) } }
    static func tap(_ on: Bool) { if on { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
}
