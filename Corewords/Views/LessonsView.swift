import SwiftUI

/// Grammar mini-lessons for the most frequent function words, and the phrasal verb deck.
struct LessonsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Small words, big difference").font(.title3.bold())
                        Text("The 50 most common English words are mostly function words like the, of, to and in. They make up about half of every text. Each lesson ends with a short quiz.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    lessonGrid(model.content.lessons.filter { $0.group != "grammar" })
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tenses and grammar").font(.title3.bold())
                        Text("The structures that hold the words together: present, past and future, the present perfect, comparatives, conditionals and more. Short, with examples and a quiz.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                    lessonGrid(model.content.lessons.filter { $0.group == "grammar" })
                    PhrasalSection()
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Lessons")
            .navigationDestination(for: Lesson.self) { LessonView(lesson: $0) }
            .navigationDestination(for: String.self) { key in
                if let item = model.content.item(key) { WordDetailView(item: item) }
            }
        }
    }
}

extension LessonsView {
    func lessonGrid(_ lessons: [Lesson]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
            ForEach(lessons) { lesson in
                NavigationLink(value: lesson) { LessonTile(lesson: lesson, score: model.progress.lessonScores[lesson.id]) }
                    .buttonStyle(.plain)
            }
        }
    }
}

struct LessonTile: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    let score: Int?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandIndigo.opacity(0.12))
                Text(lesson.words.first.map { $0 } ?? "Aa").font(.rounded(17, .bold)).foregroundStyle(Color.brandIndigo)
                    .lineLimit(1).minimumScaleFactor(0.4).padding(4)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title).font(.headline).foregroundStyle(.primary)
                if model.settings.meaning == .turkish && lesson.titleTr != lesson.title {
                    Text(lesson.titleTr).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let score {
                Text("\(score)/\(lesson.quiz.count)").font(.subheadline.weight(.semibold))
                    .foregroundStyle(score == lesson.quiz.count ? Color.good : .orange)
            }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct LessonView: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    @State private var answers: [Int: Int] = [:]

    var body: some View {
        let tr = model.settings.meaning == .turkish
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(lesson.intro).font(.rounded(19, .medium))
                if tr {
                    Text(lesson.introTr).font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(lesson.points.enumerated()), id: \.offset) { _, p in
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(p.en).font(.headline)
                            if tr { Text(p.tr).font(.subheadline).foregroundStyle(.secondary) }
                            ForEach(Array(p.examples.enumerated()), id: \.offset) { _, ex in
                                HStack(alignment: .top, spacing: 10) {
                                    SpeakButton(text: speakable(ex.first ?? ""), size: 13)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.first ?? "").font(.rounded(17, .semibold))
                                        if tr, ex.count > 1 { Text(ex[1]).font(.subheadline).foregroundStyle(.secondary) }
                                    }
                                }
                            }
                        }
                    }
                }
                Text("Quiz").font(.title3.bold()).padding(.top, 8)
                ForEach(Array(lesson.quiz.enumerated()), id: \.offset) { qi, q in
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(q.q).font(.rounded(18, .semibold))
                            HStack(spacing: 8) {
                                ForEach(Array(q.options.enumerated()), id: \.offset) { oi, opt in
                                    Button {
                                        guard answers[qi] == nil else { return }
                                        answers[qi] = oi
                                        if oi == q.answer {
                                            Haptics.success(model.settings.haptics)
                                            model.speak(q.q.replacingOccurrences(of: "___", with: opt == "—" ? "" : opt))
                                        } else {
                                            Haptics.error(model.settings.haptics)
                                        }
                                        saveScore()
                                    } label: {
                                        Text(opt).font(.rounded(17, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                            .background(color(qi, oi, q).opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color(qi, oi, q), lineWidth: answers[qi] == nil ? 0 : 1.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                if answers.count == lesson.quiz.count {
                    let right = lesson.quiz.indices.filter { answers[$0] == lesson.quiz[$0].answer }.count
                    Panel {
                        HStack {
                            Image(systemName: right == lesson.quiz.count ? "star.fill" : "arrow.clockwise").foregroundStyle(.orange)
                            Text("\(right) of \(lesson.quiz.count) correct").font(.headline)
                            Spacer()
                            Button("Try again") { answers = [:] }.buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(lesson.title)
    }

    private func speakable(_ s: String) -> String {
        // Drop notes in brackets like "(not an advice)" or "(/juː/)" before speaking.
        s.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
    }

    private func color(_ qi: Int, _ oi: Int, _ q: Lesson.Question) -> Color {
        guard let a = answers[qi] else { return .accentColor }
        if oi == q.answer { return .good }
        if oi == a { return .bad }
        return .secondary
    }

    private func saveScore() {
        guard answers.count == lesson.quiz.count else { return }
        let right = lesson.quiz.indices.filter { answers[$0] == lesson.quiz[$0].answer }.count
        model.progress.lessonScores[lesson.id] = max(right, model.progress.lessonScores[lesson.id] ?? 0)
    }
}

struct PhrasalSection: View {
    @EnvironmentObject var model: AppModel
    @State private var showAll = false

    var body: some View {
        let items = model.content.ordered[.phrasal] ?? []
        let learned = model.progress.learnedCount(in: items)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Phrasal verbs").font(.title3.bold())
                if !model.store.isPro { ProBadge() }
                Spacer()
                Text("\(learned)/\(items.count)").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Verb + particle combinations with a new meaning: get up, look after, put up with. These 205 are among the most frequent in everyday English.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                model.startSession(decks: [.phrasal])
            } label: {
                Label("Study phrasal verbs", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orange))
            VStack(spacing: 0) {
                ForEach(showAll ? items : Array(items.prefix(12))) { item in
                    NavigationLink(value: item.key) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.headword).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(model.settings.meaning == .turkish ? item.tr : item.def).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(separability(item)).font(.caption).foregroundStyle(.tertiary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 14)
                }
                Button(showAll ? "Show fewer" : "Show all \(items.count)") { withAnimation { showAll.toggle() } }
                    .padding(12)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func separability(_ item: StudyItem) -> LocalizedStringKey {
        guard let p = model.content.phrasals.first(where: { "p:\($0.id)" == item.key }) else { return "" }
        switch p.type {
        case "s": return "separable"
        case "i": return "inseparable"
        default: return "no object"
        }
    }
}
