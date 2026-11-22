import SwiftUI

/// App Store screenshot tour, only when launched with `-shots` (scripts/sim-shots.sh). Seeds realistic progress,
/// opens each screen, writes its name to Documents/shots/ready and waits until the script answers in
/// Documents/shots/next.
@MainActor
struct ShotsTour {
    nonisolated static var active: Bool { ProcessInfo.processInfo.arguments.contains("-shots") }
    nonisolated static var outer: Bool { ProcessInfo.processInfo.arguments.contains("-shotsOuter") }

    let model: AppModel

    private var dir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("shots")
    }

    /// About 1,100 words learned over three weeks, a 17-day streak, some words in learning.
    static func demoProgress(_ content: ContentStore) -> ProgressData {
        var p = ProgressData()
        p.onboarded = true
        p.placementDone = true
        p.settings.meaning = Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .turkish : .english
        p.settings.newPerDay = 10
        p.settings.dailyGoal = 30
        p.settings.decks = [.core, .phrasal]
        let now = Date()
        let core = content.ordered[.core] ?? []
        p.markKnown(core.prefix(950).map(\.key), now: now)
        var rng = SeededRandom(seed: 42)
        for (i, item) in core.dropFirst(950).prefix(180).enumerated() {
            var s = CardState()
            s.status = i < 150 ? .review : .learning
            s.interval = Double(Int.random(in: 1...20, using: &rng))
            s.ease = 2.5
            s.reps = 4
            s.correct = 4
            s.firstSeen = now.addingTimeInterval(-86400 * 20)
            s.lastReview = now.addingTimeInterval(-86400)
            s.due = i % 7 == 0 ? now.addingTimeInterval(-3600) : now.addingTimeInterval(86400 * Double(1 + i % 6))
            p.cards[item.key] = s
        }
        for item in (content.ordered[.phrasal] ?? []).prefix(24) {
            var s = CardState()
            s.status = .review
            s.interval = 3
            s.due = now.addingTimeInterval(86400 * 2)
            p.cards[item.key] = s
        }
        let cal = Calendar.current
        for off in 0..<21 {
            guard let d = cal.date(byAdding: .day, value: -off, to: now) else { continue }
            var log = DayLog()
            log.answers = off == 0 ? 18 : [34, 41, 30, 52, 36, 31, 45][off % 7] - (off == 4 ? 10 : 0)
            if off >= 18 { log.answers = 12 }
            log.correct = Int(Double(log.answers) * 0.86)
            log.newItems = 10
            log.seconds = Double(log.answers) * 9
            p.days[ProgressData.dayKey(d)] = log
        }
        return p
    }

    func run() async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("next"))
        try? await Task.sleep(for: .seconds(2))
        let content = model.content
        func item(_ word: String) -> StudyItem? {
            (content.ordered[.core] ?? []).first { $0.headword == word } ?? (content.ordered[.extended] ?? []).first { $0.headword == word }
        }

        // 1. Today
        model.tab = .today
        await shot("1-today")

        // 2. A new word (intro card)
        if let w = item("journey") {
            model.studying = AppModel.StudyRequest(decks: [.core], extraNew: nil)
            ShotsTour.forced = Exercise(item: w, kind: .intro, options: [], answerIndex: 0)
            await shot("2-intro")
            model.studying = nil
            try? await Task.sleep(for: .seconds(1))
        }

        // 3. Fill the gap with feedback shown
        if let w = item("borrow") {
            let engine = SessionEngine(content: content, progress: model.progress, now: Date(), decks: [.core], newLimit: 0, seed: 3)
            let ex = engine.make(.gapChoice, for: w)
            ShotsTour.forced = ex
            ShotsTour.forcedAnswer = ex.answerIndex
            model.studying = AppModel.StudyRequest(decks: [.core], extraNew: nil)
            await shot("3-gap")
            model.studying = nil
            ShotsTour.forcedAnswer = nil
            try? await Task.sleep(for: .seconds(1))
        }

        // 4. Listening exercise
        if let w = item("thought") {
            let engine = SessionEngine(content: content, progress: model.progress, now: Date(), decks: [.core], newLimit: 0, seed: 5)
            ShotsTour.forced = engine.make(.listen, for: w)
            model.studying = AppModel.StudyRequest(decks: [.core], extraNew: nil)
            await shot("4-listen")
            model.studying = nil
            try? await Task.sleep(for: .seconds(1))
        }
        ShotsTour.forced = nil

        // 5. Progress
        model.tab = .progress
        await shot("5-progress")

        // 6. Sounds
        model.tab = .sounds
        await shot("6-sounds")

        // 7. Lessons
        model.tab = .lessons
        await shot("7-lessons")

        model.tab = .today
        write("ready", "done")
    }

    /// Set by the tour so the session view shows a chosen exercise instead of the next one in the queue.
    static var forced: Exercise?
    static var forcedAnswer: Int?

    private func shot(_ name: String) async {
        try? await Task.sleep(for: .seconds(2.5))
        write("ready", name)
        for _ in 0..<600 {
            if let s = try? String(contentsOf: dir.appendingPathComponent("next"), encoding: .utf8), s == name { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func write(_ file: String, _ text: String) {
        try? text.write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }
}
