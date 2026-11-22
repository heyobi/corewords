import SwiftUI

/// One study session: reviews and new words with varied exercises, immediate feedback and a summary.
struct StudySessionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: AppModel.StudyRequest

    enum Phase: Equatable {
        case question
        case feedback(grade: Grade, chosen: Int?, typed: String?)
    }

    @State private var engine: SessionEngine?
    @State private var exercise: Exercise?
    @State private var phase: Phase = .question
    @State private var startedAt = Date()
    @State private var totalAtStart = 0
    @State private var finished = false
    @State private var coverageAtStart = 0.0
    @State private var learnedAtStart = 0
    /// State before the last answer, so "Too easy" can re-grade it.
    @State private var previous: CardState?
    @State private var note: FeedbackNote = .none

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 700 && geo.size.width > geo.size.height * 1.1
            VStack(spacing: 0) {
                topBar
                if finished || exercise == nil {
                    SessionSummary(engine: engine, coverageAtStart: coverageAtStart, learnedAtStart: learnedAtStart) { dismiss() }
                } else if let ex = exercise {
                    ExerciseView(exercise: ex, phase: $phase, wide: wide, checking: engine?.isChecking ?? false, note: note,
                                 onAnswer: answer, onIntroDone: introDone, onKnown: markKnown, onContinue: next,
                                 onSwitchToTyping: switchToTyping, onTooEasy: tooEasy)
                        .id(ex.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(maxWidth: wide ? .infinity : 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onAppear(perform: setUp)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { model.saveNow(); dismiss() } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
            let done = Double(engine?.reviewed ?? 0)
            let left = Double(engine?.remaining ?? 0)
            ProgressView(value: finished ? 1 : done, total: finished ? 1 : max(1, done + left))
                .tint(.accentColor)
                .animation(.easeInOut, value: done)
            Text("\(engine?.remaining ?? 0)")
                .font(.rounded(15, .semibold)).foregroundStyle(.secondary).monospacedDigit()
                .accessibilityLabel(Text("\(engine?.remaining ?? 0) left"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func setUp() {
        guard engine == nil else { return }
        coverageAtStart = model.progress.coverage(model.content)
        learnedAtStart = model.progress.cards.values.filter(\.isLearned).count
        // Availability is checked when the exercise starts; if speech can't be recognized offline it falls back to typing.
        let sayIt = model.settings.sayItEnabled && model.store.isPro
        let seed: UInt64 = ShotsTour.active ? 7 : UInt64(Date().timeIntervalSince1970)
        let e = SessionEngine(content: model.content, progress: model.progress, now: Date(), decks: request.decks,
                              newLimit: request.extraNew, sayItAvailable: sayIt, seed: seed)
        engine = e
        totalAtStart = e.remaining
        exercise = e.current(progress: model.progress)
        if ShotsTour.active, let forced = ShotsTour.forced {
            exercise = forced
            if let a = ShotsTour.forcedAnswer { phase = .feedback(grade: .good, chosen: a, typed: nil) }
        }
        startedAt = Date()
    }

    private func answer(_ grade: Grade, chosen: Int?, typed: String?) {
        guard let ex = exercise, let engine else { return }
        let key = ex.item.key
        let seconds = Date().timeIntervalSince(startedAt)
        let before = model.progress.state(key)
        previous = before
        if engine.isChecking {
            // "I know this word" check: right → skip it (one confirmation in 3 weeks); wrong → teach it.
            let passed = grade != .again
            if passed { model.progress.passKnownCheck(key, now: Date()) }
            engine.checked(passed: passed)
            note = passed ? .knownChecked : .checkFailed
        } else {
            model.progress.record(key, grade: grade, now: Date(), seconds: seconds)
            let after = model.progress.state(key)
            engine.answered(grade, newState: after)
            if after.status == .review && before.status != .review {
                note = .learned(days: Int(after.interval.rounded()))
            } else if after.status == .review {
                note = .review(days: Int(after.interval.rounded()), mastered: model.progress.isMastered(after) && !model.progress.isMastered(before))
            } else if grade == .again {
                note = .again
            } else {
                note = .none
            }
        }
        if grade == .again { Haptics.error(model.settings.haptics) } else { Haptics.success(model.settings.haptics) }
        withAnimation(.spring(duration: 0.3)) { phase = .feedback(grade: grade, chosen: chosen, typed: typed) }
    }

    /// "Too easy": count the last right answer as easy, so the word comes back much later.
    private func tooEasy() {
        guard let ex = exercise, let previous, let engine else { return }
        model.progress.upgradeToEasy(ex.item.key, previous: previous, now: Date())
        engine.remove(ex.item.key)
        let after = model.progress.state(ex.item.key)
        note = .review(days: Int(after.interval.rounded()), mastered: model.progress.isMastered(after))
        next()
    }

    private func introDone() {
        engine?.introduced()
        next()
    }

    private func markKnown() {
        engine?.startKnownCheck()
        next()
    }

    private func switchToTyping() {
        guard let ex = exercise, let engine else { return }
        exercise = engine.make(.typeWord, for: ex.item)
    }

    private func next() {
        guard let engine else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .question
            if let e = engine.current(progress: model.progress) {
                exercise = e
            } else {
                finished = true
                exercise = nil
            }
        }
        startedAt = Date()
    }
}

/// Shows one exercise and, after answering, the feedback panel.
struct ExerciseView: View {
    @EnvironmentObject var model: AppModel
    let exercise: Exercise
    @Binding var phase: StudySessionView.Phase
    let wide: Bool
    let checking: Bool
    let note: FeedbackNote
    let onAnswer: (Grade, Int?, String?) -> Void
    let onIntroDone: () -> Void
    let onKnown: () -> Void
    let onContinue: () -> Void
    let onSwitchToTyping: () -> Void
    let onTooEasy: () -> Void

    var item: StudyItem { exercise.item }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    if exercise.kind == .intro {
                        IntroCard(item: item, wide: wide)
                    } else if wide {
                        HStack(alignment: .center, spacing: 28) {
                            prompt.frame(maxWidth: .infinity)
                            answerArea.frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 28) {
                            prompt
                            answerArea
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBar
        }
        .onAppear(perform: autoplay)
    }

    private func autoplay() {
        guard model.settings.autoplay || exercise.kind == .listen else { return }
        switch exercise.kind {
        case .intro, .wordToMeaning, .listen: model.speak(item.headword)
        default: break
        }
    }

    private var answered: Bool { if case .feedback = phase { return true } else { return false } }

    // MARK: prompt

    @ViewBuilder private var prompt: some View {
        VStack(spacing: 14) {
            Text(instruction).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            switch exercise.kind {
            case .wordToMeaning, .sayIt:
                VStack(spacing: 10) {
                    Text(item.headword).font(.rounded(46, .bold)).multilineTextAlignment(.center).minimumScaleFactor(0.5)
                    if exercise.kind == .sayIt || answered {
                        IPARow(text: item.headword, us: item.us, uk: item.uk, compact: true)
                    } else {
                        SpeakButton(text: item.headword)
                    }
                }
            case .meaningToWord, .typeWord:
                VStack(spacing: 10) {
                    Text(meaning).font(.rounded(26, .semibold)).multilineTextAlignment(.center)
                    if model.settings.meaning == .turkish {
                        Text(item.def).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if exercise.kind == .typeWord {
                        Text(answered ? item.plainExample : item.gapped).font(.rounded(19)).multilineTextAlignment(.center).padding(.top, 6)
                    }
                }
            case .listen:
                HStack(spacing: 18) {
                    SpeakButton(text: item.headword, size: 34)
                    SpeakButton(text: item.headword, size: 22, slow: true)
                }
                .padding(.vertical, 10)
                if answered { Text(item.headword).font(.rounded(30, .bold)) }
            case .gapChoice:
                VStack(spacing: 10) {
                    if answered { ExampleText(item: item, font: .rounded(23, .medium)).multilineTextAlignment(.center) }
                    else { Text(item.gapped).font(.rounded(23, .medium)).multilineTextAlignment(.center) }
                    Text(meaning).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            case .intro:
                EmptyView()
            }
        }
        .padding(.vertical, wide ? 0 : 20)
    }

    private var instruction: LocalizedStringKey {
        if checking { return "Quick check: what does it mean?" }
        switch exercise.kind {
        case .intro: return "New word"
        case .wordToMeaning: return "What does it mean?"
        case .meaningToWord: return "Which word means this?"
        case .listen: return "Which word do you hear?"
        case .gapChoice: return "Fill the gap"
        case .typeWord: return "Type the missing word"
        case .sayIt: return "Say it out loud"
        }
    }

    private var meaning: String { model.settings.meaning == .turkish ? item.tr : item.def }

    // MARK: answers

    @ViewBuilder private var answerArea: some View {
        switch exercise.kind {
        case .wordToMeaning, .meaningToWord, .listen, .gapChoice:
            VStack(spacing: 12) {
                ForEach(Array(exercise.options.enumerated()), id: \.offset) { i, opt in
                    OptionButton(text: opt, state: optionState(i), big: exercise.kind != .wordToMeaning) {
                        guard !answered else { return }
                        let ok = i == exercise.answerIndex
                        if ok && exercise.kind != .listen { model.speak(item.headword) }
                        onAnswer(ok ? .good : .again, i, nil)
                    }
                }
                if !answered {
                    Button("I don't know") { onAnswer(.again, nil, nil) }
                        .font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
                }
            }
        case .typeWord:
            TypeAnswer(item: item, answered: answered) { typed in
                let accepted = [item.answer, item.headword] + item.forms
                let g = AnswerCheck.grade(typed, accepted: accepted)
                if g != .again { model.speak(item.headword) }
                onAnswer(g, nil, typed)
            }
        case .sayIt:
            SayItAnswer(listener: model.listener, item: item, answered: answered, onResult: { ok in onAnswer(ok ? .good : .again, nil, nil) },
                        onSkip: onSwitchToTyping)
        case .intro:
            EmptyView()
        }
    }

    private func optionState(_ i: Int) -> OptionButton.State {
        guard case .feedback(_, let chosen, _) = phase else { return .idle }
        if i == exercise.answerIndex { return .right }
        if i == chosen { return .wrong }
        return .dimmed
    }

    // MARK: bottom

    @ViewBuilder private var bottomBar: some View {
        if exercise.kind == .intro {
            HStack(spacing: 12) {
                Button(action: onKnown) { Label("I know it", systemImage: "checkmark") }.buttonStyle(SecondaryButtonStyle())
                Button(action: onIntroDone) { Label("Learn it", systemImage: "brain.head.profile") }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20).padding(.bottom, 12).padding(.top, 8)
            .frame(maxWidth: 560)
        } else if case .feedback(let grade, _, let typed) = phase {
            FeedbackPanel(item: item, grade: grade, typed: typed, note: note, onContinue: onContinue,
                          onTooEasy: grade == .good && !checking ? onTooEasy : nil)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct OptionButton: View {
    enum State { case idle, right, wrong, dimmed }
    let text: String
    let state: State
    var big = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(big ? .rounded(20, .semibold) : .rounded(17, .medium))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if state == .right { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.good) }
                if state == .wrong { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.bad) }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border, lineWidth: 2))
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch state {
        case .right: Color.good.opacity(0.14)
        case .wrong: Color.bad.opacity(0.12)
        default: Color(uiColor: .secondarySystemGroupedBackground)
        }
    }

    private var border: Color {
        switch state {
        case .right: Color.good
        case .wrong: Color.bad
        default: Color.secondary.opacity(0.15)
        }
    }
}

/// The first meeting with a word.
struct IntroCard: View {
    @EnvironmentObject var model: AppModel
    let item: StudyItem
    let wide: Bool

    var body: some View {
        let main = VStack(spacing: 14) {
            Text("New word").font(.subheadline.weight(.semibold)).foregroundStyle(Color.brandTeal)
            Text(item.headword).font(.rounded(50, .bold)).multilineTextAlignment(.center).minimumScaleFactor(0.5)
            POSBadge(pos: item.pos)
            IPARow(text: item.headword, us: item.us, uk: item.uk)
            SayItButton(listener: model.listener, word: item.headword, forms: item.forms)
        }
        let detail = VStack(alignment: .leading, spacing: 14) {
            if model.settings.meaning == .turkish {
                Label { Text(item.tr).font(.rounded(22, .semibold)) } icon: { Text("🇹🇷") }
            }
            Text(item.def).font(.rounded(18)).foregroundStyle(model.settings.meaning == .turkish ? .secondary : .primary)
            Divider()
            HStack(alignment: .top, spacing: 10) {
                SpeakButton(text: item.plainExample, size: 15)
                ExampleText(item: item)
            }
            if !item.forms.isEmpty {
                Text("Forms: \(item.forms.joined(separator: ", "))").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

        if wide {
            HStack(alignment: .center, spacing: 28) {
                main.frame(maxWidth: .infinity)
                detail.frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 22) {
                main.padding(.top, 16)
                detail
            }
        }
    }
}

struct TypeAnswer: View {
    let item: StudyItem
    let answered: Bool
    let onSubmit: (String) -> Void
    @State private var text = ""
    @State private var hint = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField(hint ? String(item.answer.prefix(1)) + "…" : String(localized: "Type here"), text: $text)
                .font(.rounded(24, .semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($focused)
                .disabled(answered)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit { if !text.isEmpty { onSubmit(text) } }
            if !answered {
                HStack(spacing: 12) {
                    Button { hint = true } label: { Label("Hint", systemImage: "lightbulb") }
                        .buttonStyle(SecondaryButtonStyle()).disabled(hint)
                    Button { onSubmit(text) } label: { Text("Check") }
                        .buttonStyle(PrimaryButtonStyle()).disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button("Show the answer") { onSubmit("") }.font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .onAppear { focused = true }
    }
}

struct SayItAnswer: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var listener: Listener
    let item: StudyItem
    let answered: Bool
    let onResult: (Bool) -> Void
    let onSkip: () -> Void
    @State private var holding = false

    var body: some View {
        VStack(spacing: 16) {
            if listener.state == .denied || listener.state == .unavailable {
                Text(listener.state == .denied
                     ? "Corewords needs microphone and speech recognition permission for this exercise. You can allow it in Settings."
                     : "On-device speech recognition isn't available on this iPhone right now.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Type it instead", action: onSkip).buttonStyle(SecondaryButtonStyle())
            } else if !answered {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(holding ? 0.25 : 0.12)).frame(width: 120, height: 120)
                        .scaleEffect(holding ? 1.12 : 1)
                    Image(systemName: holding ? "waveform" : "mic.fill").font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.variableColor.iterative, isActive: holding)
                }
                .animation(.easeInOut(duration: 0.2), value: holding)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !holding else { return }
                        holding = true
                        model.speaker.stop()
                        Task { await listener.start(accent: model.settings.accent) }
                    }
                    .onEnded { _ in
                        holding = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(600))
                            let heard = listener.transcript
                            listener.stop()
                            onResult(AnswerCheck.spoken(heard, matches: item))
                        }
                    })
                .accessibilityLabel(Text("Hold to speak"))
                Text(holding ? (listener.transcript.isEmpty ? String(localized: "Listening…") : listener.transcript)
                             : String(localized: "Hold the button and say the word"))
                    .font(.callout).foregroundStyle(.secondary)
                Button("I can't speak now", action: onSkip).font(.subheadline).foregroundStyle(.secondary)
            } else {
                if !listener.transcript.isEmpty {
                    Text("We heard: \"\(listener.transcript)\"").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// What the answer did to the word's memory, shown under the result.
enum FeedbackNote: Equatable {
    case none
    case again
    case learned(days: Int)
    case review(days: Int, mastered: Bool)
    case knownChecked
    case checkFailed
}

/// Right or wrong, with the word's details and what happens next, so every answer teaches something.
struct FeedbackPanel: View {
    @EnvironmentObject var model: AppModel
    let item: StudyItem
    let grade: Grade
    let typed: String?
    let note: FeedbackNote
    let onContinue: () -> Void
    var onTooEasy: (() -> Void)?

    var body: some View {
        let ok = grade != .again
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill").font(.title2)
                Text(ok ? (grade == .hard ? "Almost! Watch the spelling." : "Correct!") : "Not quite")
                    .font(.rounded(20, .bold))
                Spacer()
                SpeakButton(text: item.headword, size: 16)
                SpeakButton(text: item.headword, size: 14, slow: true)
            }
            .foregroundStyle(ok ? Color.good : Color.bad)
            noteView
            if let typed, !typed.isEmpty, grade != .good {
                Text("You wrote: \(typed)").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.headword).font(.rounded(22, .bold))
                let ipa = model.settings.accent == .uk && !item.uk.isEmpty ? item.uk : item.us
                if !ipa.isEmpty { Text("/\(ipa)/").font(.system(size: 16, design: .serif)).foregroundStyle(.secondary) }
            }
            Text(model.settings.meaning == .turkish ? "\(item.tr) — \(item.def)" : item.def).font(.callout)
            ExampleText(item: item, font: .rounded(16))
            HStack(spacing: 10) {
                if let onTooEasy {
                    Button(action: onTooEasy) { Text("Too easy") }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 150)
                        .accessibilityHint(Text("Shows this word again much later"))
                }
                Button(action: onContinue) { Text("Continue") }
                    .buttonStyle(PrimaryButtonStyle(color: ok ? .good : .bad))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(maxWidth: 720)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var noteView: some View {
        switch note {
        case .none:
            EmptyView()
        case .again:
            Label("It will come back in a few minutes.", systemImage: "arrow.clockwise").font(.subheadline).foregroundStyle(.secondary)
        case .learned(let days):
            Label(days <= 1 ? "Learned! Next review tomorrow." : "Learned! Next review in \(days) days.", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brandTeal)
        case .review(let days, let mastered):
            if mastered {
                Label("Mastered! In your long-term memory now. Next check in \(days) days.", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            } else {
                Label("Stronger memory: next review in \(days) days.", systemImage: "arrow.up.right")
                    .font(.subheadline).foregroundStyle(Color.brandTeal)
            }
        case .knownChecked:
            Label("You know it. Skipped; we'll check it once more in 3 weeks.", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brandTeal)
        case .checkFailed:
            Label("No problem, let's learn it properly.", systemImage: "brain.head.profile").font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct SessionSummary: View {
    @EnvironmentObject var model: AppModel
    let engine: SessionEngine?
    let coverageAtStart: Double
    let learnedAtStart: Int
    let onDone: () -> Void

    var body: some View {
        let reviewed = engine?.reviewed ?? 0
        let correct = engine?.correct ?? 0
        let accuracy = reviewed > 0 ? Int((Double(correct) / Double(reviewed) * 100).rounded()) : 0
        let learned = model.progress.cards.values.filter(\.isLearned).count
        let cov = model.progress.coverage(model.content)
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: reviewed > 0 ? "party.popper.fill" : "checkmark.seal.fill")
                    .font(.system(size: 64)).foregroundStyle(Color.brandTeal).padding(.top, 30)
                Text(reviewed > 0 ? "Session complete" : "Nothing to study right now").font(.rounded(30, .bold))
                if reviewed > 0 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        tile("\(reviewed)", "exercises", "square.stack.3d.up.fill", .brandIndigo)
                        tile("\(accuracy)%", "correct", "target", .good)
                        tile("+\(max(0, learned - learnedAtStart))", "words learned", "sparkles", .brandTeal)
                        tile("\(model.progress.streak(now: Date()))", "day streak", "flame.fill", .orange)
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You now know \(learned) words, about \(Int(cov.rounded()))% of everyday English.")
                                .font(.headline)
                            if cov > coverageAtStart + 0.005 {
                                Text("+\(String(format: "%.1f", cov - coverageAtStart)) points of everyday English in this session.")
                                    .font(.subheadline).foregroundStyle(Color.brandTeal)
                            }
                            if (engine?.knownByCheck ?? 0) > 0 {
                                Text("\(engine?.knownByCheck ?? 0) words you already knew were skipped after a quick check.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    let newWords = (engine?.learnedKeys ?? []).compactMap { model.content.item($0) }
                    if !newWords.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("New in your memory").font(.title3.bold())
                            ForEach(newWords) { w in
                                HStack(spacing: 10) {
                                    SpeakButton(text: w.headword, size: 14)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.headword).font(.headline)
                                        Text(model.settings.meaning == .turkish ? w.tr : w.def).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                } else {
                    Text("Your reviews are scheduled for later. Come back tomorrow, or add more decks.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                Button(action: onDone) { Text("Done") }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private func tile(_ v: String, _ label: LocalizedStringKey, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(v).font(.rounded(28, .bold))
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
