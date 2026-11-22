import XCTest
@testable import Corewords

/// Regression and behavior tests for the learning flow added after the first TestFlight feedback.
final class LearningFlowTests: XCTestCase {
    var content: ContentStore { ContentTests.content }

    /// Every exercise kind must build for every item of every deck (the Extended deck used to crash when picking
    /// distractors because its positions ran past the end of the deck).
    func testEveryKindBuildsForEveryDeck() {
        let e = SessionEngine(content: content, progress: ProgressData(), now: Date(), decks: Deck.allCases, seed: 11)
        for deck in Deck.allCases {
            let items = content.ordered[deck] ?? []
            XCTAssertFalse(items.isEmpty)
            for (i, item) in items.enumerated() where i % 7 == 0 || i == items.count - 1 {
                XCTAssertEqual(item.order, i, "order must be the position inside its deck")
                for kind in ExerciseKind.allCases {
                    let ex = e.make(kind, for: item)
                    if [.wordToMeaning, .meaningToWord, .listen, .gapChoice].contains(kind) {
                        XCTAssertGreaterThanOrEqual(ex.options.count, 3, "\(deck) \(item.headword) \(kind)")
                        XCTAssertTrue(ex.options.indices.contains(ex.answerIndex))
                    }
                }
            }
        }
    }

    func testExtraPhrasalSessionOnly() {
        var p = ProgressData()
        p.settings.decks = [.phrasal]
        p.settings.newPerDay = 10
        for item in (content.ordered[.core] ?? []).prefix(10) { p.record(item.key, grade: .good, now: Date()) }
        let e = SessionEngine(content: content, progress: p, now: Date(), decks: [.phrasal], newLimit: 5, seed: 12)
        XCTAssertEqual(e.remaining, 5)
        var guardCount = 0
        while let ex = e.current(progress: p), guardCount < 40 {
            if ex.kind == .intro { e.introduced(); guardCount += 1; continue }
            XCTAssertEqual(ex.item.deck, .phrasal)
            p.record(ex.item.key, grade: .good, now: Date())
            e.answered(.good, newState: p.state(ex.item.key))
            guardCount += 1
        }
        XCTAssertTrue(e.isFinished)
        XCTAssertEqual(e.learnedKeys.count, 5)
    }

    func testKnownCheckPassedSkipsTheWord() {
        var p = ProgressData()
        p.settings.newPerDay = 2
        let now = Date()
        let e = SessionEngine(content: content, progress: p, now: now, decks: [.core], seed: 13)
        let key = e.queue[0].key
        e.startKnownCheck()
        XCTAssertTrue(e.isChecking)
        XCTAssertEqual(e.current(progress: p)?.kind, .wordToMeaning)
        p.passKnownCheck(key, now: now)
        e.checked(passed: true)
        XCTAssertFalse(e.queue.contains { $0.key == key })
        XCTAssertEqual(e.knownByCheck, 1)
        let s = p.state(key)
        XCTAssertEqual(s.status, .review)
        XCTAssertEqual(s.interval, ProgressData.knownCheckInterval)
        XCTAssertTrue(p.isMastered(s))
        XCTAssertGreaterThan(s.due, now.addingTimeInterval(19 * 86400))
    }

    func testKnownCheckFailedTeachesTheWord() {
        let p = ProgressData()
        let e = SessionEngine(content: content, progress: p, now: Date(), decks: [.core], newLimit: 2, seed: 14)
        let key = e.queue[0].key
        e.startKnownCheck()
        e.checked(passed: false)
        XCTAssertFalse(e.isChecking)
        let entry = e.queue.first { $0.key == key }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.introduced, false)
    }

    func testTooEasyPushesTheReviewFurther() {
        var p = ProgressData()
        let key = content.ordered[.core]![200].key
        var s = CardState()
        s.status = .review
        s.interval = 6
        s.ease = 2.5
        s.lastReview = Date().addingTimeInterval(-6 * 86400)
        p.cards[key] = s
        p.record(key, grade: .good, now: Date())
        let good = p.state(key).interval
        p.upgradeToEasy(key, previous: s, now: Date())
        XCTAssertGreaterThan(p.state(key).interval, good)
        XCTAssertEqual(p.state(key).reps, 1)
    }

    func testCountsSplitMasteredAndLearned() {
        var p = ProgressData()
        let core = content.ordered[.core]!
        var a = CardState(); a.status = .review; a.interval = 30
        var b = CardState(); b.status = .review; b.interval = 3
        var c = CardState(); c.status = .learning
        p.cards[core[0].key] = a
        p.cards[core[1].key] = b
        p.cards[core[2].key] = c
        p.markKnown([core[3].key], now: Date())
        let counts = p.counts()
        XCTAssertEqual(counts.mastered, 2)
        XCTAssertEqual(counts.learned, 1)
        XCTAssertEqual(counts.learning, 1)
        XCTAssertEqual(counts.known, 3)
    }

    func testHeardChecksMinimalPairs() {
        XCTAssertTrue(AnswerCheck.heard("ship", word: "ship", not: "sheep"))
        XCTAssertFalse(AnswerCheck.heard("sheep", word: "ship", not: "sheep"))
        XCTAssertTrue(AnswerCheck.heard("Three.", word: "three", not: "tree"))
        XCTAssertFalse(AnswerCheck.heard("", word: "three"))
    }

    func testSayItOffersWhenAvailable() {
        let e = SessionEngine(content: content, progress: ProgressData(), now: Date(), decks: [.core], sayItAvailable: true, seed: 15)
        let item = content.ordered[.core]![300]
        var s = CardState()
        s.status = .review
        s.interval = 2
        var kinds = Set<ExerciseKind>()
        for _ in 0..<200 { kinds.insert(e.chooseKind(for: s, item: item)) }
        XCTAssertTrue(kinds.contains(.sayIt))
    }

    func testLessonsHaveBothGroups() {
        XCTAssertEqual(content.lessons.filter { $0.group == "grammar" }.count, 12)
        XCTAssertEqual(content.lessons.filter { $0.group == "words" }.count, 18)
    }
}

final class GapCapitalizationTests: XCTestCase {
    func testDistractorsMatchSentenceStartCapital() {
        let content = ContentTests.content
        let item = content.ordered[.phrasal]!.first { $0.headword == "look up" }!
        XCTAssertTrue(item.answer.first!.isUppercase)  // "[Look up] the word in a dictionary."
        let e = SessionEngine(content: content, progress: ProgressData(), now: Date(), decks: [.phrasal], seed: 21)
        for _ in 0..<10 {
            let ex = e.make(.gapChoice, for: item)
            XCTAssertTrue(ex.options.allSatisfy { $0.first!.isUppercase }, "\(ex.options)")
        }
    }
}
