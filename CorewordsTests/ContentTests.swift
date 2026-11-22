import XCTest
@testable import Corewords

/// Checks the bundled content and the session logic that depends on it.
final class ContentTests: XCTestCase {
    static let content = ContentStore(bundle: Bundle(for: AppModel.self))
    var content: ContentStore { Self.content }

    func testCountsAndOrder() {
        XCTAssertEqual(content.ordered[.core]?.count, 2858)  // 49 basics + 2,809 NGSL 1.2
        XCTAssertGreaterThan(content.ordered[.extended]?.count ?? 0, 2100)
        XCTAssertGreaterThanOrEqual(content.ordered[.phrasal]?.count ?? 0, 200)
        XCTAssertEqual(content.lessons.count, 30)
        XCTAssertEqual(content.phonetics.sounds.count, 44)
        // NGSL starts with the most frequent word after the basics.
        XCTAssertEqual(content.ordered[.core]?[49].headword, "the")
    }

    func testEveryItemIsComplete() {
        for item in content.items.values {
            XCTAssertFalse(item.headword.isEmpty)
            XCTAssertFalse(item.tr.isEmpty, item.key)
            XCTAssertFalse(item.def.isEmpty, item.key)
            XCTAssertFalse(item.targets.isEmpty, "no [target] in example of \(item.headword)")
            XCTAssertFalse(item.gapped.contains("["), item.key)
            XCTAssertTrue(item.gapped.contains("_____"), item.key)
            XCTAssertFalse(item.us.isEmpty, "no US IPA for \(item.headword)")
        }
    }

    func testCoverageIsMonotonicAndEndsNear92() {
        let core = content.words.filter { $0.band == "core" }.sorted { $0.rank < $1.rank }
        var prev = 0.0
        for w in core {
            XCTAssertGreaterThanOrEqual(w.cov, prev)
            prev = w.cov
        }
        XCTAssertEqual(core.last?.cov ?? 0, 92, accuracy: 0.01)
        let total = content.items.values.reduce(0) { $0 + $1.share }
        XCTAssertEqual(total, 98, accuracy: 0.5)
    }

    func testLessonQuizzesAreValid() {
        for l in content.lessons {
            for q in l.quiz {
                XCTAssertTrue(q.q.contains("___"), l.id)
                XCTAssertTrue(q.options.indices.contains(q.answer), l.id)
            }
        }
    }

    func testExampleTargetParsing() {
        let item = StudyItem(key: "t", deck: .phrasal, headword: "pick up", pos: "phr", tr: "", def: "", example: "Can you [pick] me [up] at six?",
                             us: "", uk: "", forms: [], order: 0, share: 0)
        XCTAssertEqual(item.targets, ["pick", "up"])
        XCTAssertEqual(item.answer, "pick up")
        XCTAssertEqual(item.gapped, "Can you _____ me _____ at six?")
        XCTAssertEqual(item.plainExample, "Can you pick me up at six?")
        XCTAssertEqual(item.exampleRuns.filter(\.1).map(\.0), ["pick", "up"])
    }

    func testSessionPutsReviewsFirstAndLimitsNewWords() {
        var p = ProgressData()
        p.settings.newPerDay = 5
        let now = Date()
        let core = content.ordered[.core]!
        for item in core.prefix(4) {
            var s = CardState()
            s.status = .review
            s.interval = 3
            s.due = now.addingTimeInterval(-60)
            p.cards[item.key] = s
        }
        let e = SessionEngine(content: content, progress: p, now: now, decks: [.core], seed: 1)
        XCTAssertEqual(e.remaining, 9)
        XCTAssertEqual(e.queue.prefix(3).map(\.introduced), [true, true, true])
        XCTAssertEqual(e.queue.filter { !$0.introduced }.count, 5)
        // New items follow learning order, skipping the reviewed ones.
        XCTAssertEqual(e.queue.first { !$0.introduced }?.key, core[4].key)
    }

    func testNewItemIsIntroducedThenPracticedUntilGraduated() {
        var p = ProgressData()
        p.settings.newPerDay = 1
        let now = Date()
        let e = SessionEngine(content: content, progress: p, now: now, decks: [.core], seed: 2)
        let first = e.current(progress: p)
        XCTAssertEqual(first?.kind, .intro)
        e.introduced()
        var guardCount = 0
        while let ex = e.current(progress: p), guardCount < 10 {
            XCTAssertNotEqual(ex.kind, .intro)
            p.record(ex.item.key, grade: .good, now: now)
            e.answered(.good, newState: p.state(ex.item.key))
            guardCount += 1
        }
        XCTAssertTrue(e.isFinished)
        XCTAssertEqual(guardCount, 2)  // two learning steps
        XCTAssertEqual(p.state(content.ordered[.core]![0].key).status, .review)
    }

    func testWrongAnswerComesBackInSession() {
        var p = ProgressData()
        p.settings.newPerDay = 3
        let now = Date()
        let e = SessionEngine(content: content, progress: p, now: now, decks: [.core], seed: 3)
        e.introduced()
        let key = e.queue[0].key
        p.record(key, grade: .again, now: now)
        e.answered(.again, newState: p.state(key))
        XCTAssertTrue(e.queue.contains { $0.key == key })
    }

    func testMultipleChoiceHasFourDistinctOptionsWithTheAnswer() {
        let p = ProgressData()
        let e = SessionEngine(content: content, progress: p, now: Date(), decks: [.core], seed: 4)
        for item in (content.ordered[.core] ?? []).filter({ $0.pos == "n" }).prefix(60) {
            for kind in [ExerciseKind.wordToMeaning, .meaningToWord, .listen, .gapChoice] {
                let ex = e.make(kind, for: item)
                XCTAssertEqual(ex.options.count, 4, "\(item.headword) \(kind)")
                XCTAssertEqual(Set(ex.options.map { $0.lowercased() }).count, ex.options.count)
                XCTAssertTrue(ex.options.indices.contains(ex.answerIndex))
            }
        }
    }

    func testPhrasalDistractors() {
        let e = SessionEngine(content: content, progress: ProgressData(), now: Date(), decks: [.phrasal], seed: 5)
        let item = content.ordered[.phrasal]![0]
        let ex = e.make(.gapChoice, for: item)
        XCTAssertEqual(ex.options[ex.answerIndex], item.answer)
        XCTAssertEqual(ex.options.count, 4)
    }

    func testKindProgressesWithKnowledge() {
        let e = SessionEngine(content: content, progress: ProgressData(), now: Date(), decks: [.core], seed: 6)
        let item = content.ordered[.core]![100]
        XCTAssertEqual(e.chooseKind(for: CardState(), item: item), .wordToMeaning)
        var s = CardState()
        s.status = .review
        s.interval = 30
        for _ in 0..<20 {
            XCTAssertTrue([.typeWord, .gapChoice, .meaningToWord].contains(e.chooseKind(for: s, item: item)))
        }
    }

    func testPlacementMarksPassedBands() {
        let test = Placement(content: content, meaning: .english, seed: 9)
        XCTAssertGreaterThanOrEqual(test.questions.count, 30)
        var results: [UUID: Bool] = [:]
        for q in test.questions { results[q.id] = q.band < 2 }
        XCTAssertEqual(test.passedBands(results), 2)
        let keys = test.knownKeys(passed: 2, content: content)
        XCTAssertEqual(keys.count, test.bands[1].range.upperBound + 1)
        XCTAssertEqual(test.knownKeys(passed: 0, content: content).count, 0)
        for q in test.questions {
            XCTAssertTrue(q.options.indices.contains(q.answerIndex))
            XCTAssertEqual(Set(q.options).count, q.options.count)
        }
    }

    func testCoverageGrowsWithKnownWords() {
        var p = ProgressData()
        XCTAssertEqual(p.coverage(content), 0)
        let core = content.ordered[.core]!
        p.markKnown(core.prefix(149).map(\.key), now: Date())  // basics + top 100
        XCTAssertGreaterThan(p.coverage(content), 40)
        XCTAssertLessThan(p.coverage(content), 70)
    }

    func testSpokenMatch() {
        let item = content.ordered[.core]!.first { $0.headword == "go" }!
        XCTAssertTrue(AnswerCheck.spoken("I said go", matches: item))
        XCTAssertTrue(AnswerCheck.spoken("went", matches: item))
        XCTAssertFalse(AnswerCheck.spoken("good", matches: item))
    }
}
