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

/// A speaker button that reads the text aloud (US or UK voice).
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
                .frame(width: size * 2, height: size * 2)
                .background(Color.accentColor.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(slow ? Text("Play slowly") : Text("Play"))
    }
}

/// US and UK transcriptions, each with its own play button.
struct IPARow: View {
    let text: String
    let us: String
    let uk: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            if !us.isEmpty { one("US", us, .us) }
            if !uk.isEmpty && uk != us { one("UK", uk, .uk) }
            if !uk.isEmpty && uk == us { one("US · UK", us, .us) }
        }
    }

    private func one(_ label: LocalizedStringKey, _ ipa: String, _ accent: Settings.Accent) -> some View {
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

/// Lays out a view in one column on compact width and two side by side on regular width (iPad, the open
/// iPhone Duo, large iPhones in landscape).
struct Adaptive<A: View, B: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var spacing: CGFloat = 20
    @ViewBuilder var first: A
    @ViewBuilder var second: B

    var body: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: spacing) { first }.frame(maxWidth: .infinity)
                VStack(spacing: spacing) { second }.frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: spacing) {
                first
                second
            }
        }
    }
}

enum Haptics {
    static func success(_ on: Bool) { if on { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func error(_ on: Bool) { if on { UINotificationFeedbackGenerator().notificationOccurred(.error) } }
    static func tap(_ on: Bool) { if on { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
}
