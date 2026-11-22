import XCTest
@testable import Corewords

final class SRSTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    /// 2026-11-22 15:00 Istanbul time.
    var noon: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 15))! }

    func testNewCardGoesThroughLearningSteps() {
        var s = CardState()
        s = SRS.schedule(s, grade: .good, now: noon, calendar: cal)
        XCTAssertEqual(s.status, .learning)
        XCTAssertEqual(s.step, 1)
        XCTAssertEqual(s.due.timeIntervalSince(noon), 600, accuracy: 1)
        s = SRS.schedule(s, grade: .good, now: noon.addingTimeInterval(600), calendar: cal)
        XCTAssertEqual(s.status, .review)
        XCTAssertEqual(s.interval, 1)
        // Due at the start of tomorrow's study day (4 AM), not 24 hours later.
        let expected = cal.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 4))!
        XCTAssertEqual(s.due, expected)
    }

    func testAgainResetsLearningStep() {
        var s = SRS.schedule(CardState(), grade: .good, now: noon, calendar: cal)
        s = SRS.schedule(s, grade: .again, now: noon, calendar: cal)
        XCTAssertEqual(s.status, .learning)
        XCTAssertEqual(s.step, 0)
        XCTAssertEqual(s.due.timeIntervalSince(noon), 60, accuracy: 1)
        XCTAssertEqual(s.wrong, 1)
        XCTAssertEqual(s.correct, 1)
    }

    func testEasyGraduatesImmediately() {
        let s = SRS.schedule(CardState(), grade: .easy, now: noon, calendar: cal)
        XCTAssertEqual(s.status, .review)
        XCTAssertEqual(s.interval, SRS.easyInterval)
    }

    func testReviewIntervalsGrowByEase() {
        var s = CardState()
        s.status = .review
        s.interval = 10
        s.ease = 2.5
        s.lastReview = noon.addingTimeInterval(-10 * 86400)
        let n = SRS.schedule(s, grade: .good, now: noon, calendar: cal)
        XCTAssertEqual(n.interval, 25, accuracy: 0.001)
        XCTAssertEqual(n.ease, 2.5)
        let hard = SRS.schedule(s, grade: .hard, now: noon, calendar: cal)
        XCTAssertEqual(hard.interval, 12, accuracy: 0.001)
        XCTAssertEqual(hard.ease, 2.35, accuracy: 0.0001)
        let easy = SRS.schedule(s, grade: .easy, now: noon, calendar: cal)
        XCTAssertGreaterThan(easy.interval, n.interval)
        XCTAssertEqual(easy.ease, 2.65, accuracy: 0.0001)
    }

    func testLapseGoesToRelearningAndLowersEase() {
        var s = CardState()
        s.status = .review
        s.interval = 20
        s.ease = 2.5
        s.lastReview = noon.addingTimeInterval(-20 * 86400)
        var n = SRS.schedule(s, grade: .again, now: noon, calendar: cal)
        XCTAssertEqual(n.status, .relearning)
        XCTAssertEqual(n.lapses, 1)
        XCTAssertEqual(n.ease, 2.3, accuracy: 0.0001)
        XCTAssertEqual(n.interval, 10)
        n = SRS.schedule(n, grade: .good, now: noon.addingTimeInterval(600), calendar: cal)
        XCTAssertEqual(n.status, .review)
        XCTAssertEqual(n.interval, 10)
    }

    func testEaseNeverDropsBelowMinimum() {
        var s = CardState()
        s.status = .review
        s.interval = 5
        s.ease = 1.35
        s.lastReview = noon
        for _ in 0..<5 {
            s = SRS.schedule(s, grade: .again, now: noon, calendar: cal)
            s = SRS.schedule(s, grade: .good, now: noon, calendar: cal)
        }
        XCTAssertGreaterThanOrEqual(s.ease, SRS.minEase)
    }

    func testIntervalCapped() {
        var s = CardState()
        s.status = .review
        s.interval = 3000
        s.ease = 3
        s.lastReview = noon
        let n = SRS.schedule(s, grade: .easy, now: noon, calendar: cal)
        XCTAssertLessThanOrEqual(n.interval, SRS.maxInterval)
    }

    func testStudyDayStartsAt4AM() {
        let late = cal.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 1))!
        let day = SRS.studyDay(late, calendar: cal)
        XCTAssertEqual(day, cal.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 4))!)
    }

    func testFuzzIsSmallAndDeterministic() {
        let a = SRS.fuzz(100, key: "w:1"), b = SRS.fuzz(100, key: "w:1")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, 100, accuracy: 5.0001)
        XCTAssertEqual(SRS.fuzz(2, key: "w:1"), 2)
    }

    func testIsDue() {
        var s = CardState()
        XCTAssertFalse(SRS.isDue(s, now: noon))
        s.status = .review
        s.due = noon.addingTimeInterval(-1)
        XCTAssertTrue(SRS.isDue(s, now: noon))
        s.status = .known
        XCTAssertFalse(SRS.isDue(s, now: noon))
    }

    func testStreakCountsDaysMeetingGoal() {
        var p = ProgressData()
        p.settings.dailyGoal = 5
        for off in 1...3 {
            let d = cal.date(byAdding: .day, value: -off, to: noon)!
            for _ in 0..<5 { p.record("w:\(off)", grade: .good, now: d, calendar: cal) }
        }
        // Today not done yet: streak still counts the last three days.
        XCTAssertEqual(p.streak(now: noon, calendar: cal), 3)
        for _ in 0..<5 { p.record("w:9", grade: .good, now: noon, calendar: cal) }
        XCTAssertEqual(p.streak(now: noon, calendar: cal), 4)
        XCTAssertEqual(p.bestStreak(calendar: cal), 4)
    }

    func testDayLogCountsNewItemsOnce() {
        var p = ProgressData()
        p.record("w:1", grade: .good, now: noon, calendar: cal)
        p.record("w:1", grade: .good, now: noon.addingTimeInterval(600), calendar: cal)
        XCTAssertEqual(p.log(on: noon, calendar: cal).newItems, 1)
        XCTAssertEqual(p.log(on: noon, calendar: cal).answers, 2)
    }

    func testProgressRoundTripsAndToleratesMissingKeys() throws {
        var p = ProgressData()
        p.record("w:1", grade: .good, now: noon, calendar: cal)
        p.settings.newPerDay = 20
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(ProgressData.self, from: data)
        XCTAssertEqual(back, p)
        let partial = try JSONDecoder().decode(ProgressData.self, from: Data(#"{"onboarded":true,"settings":{"newPerDay":15}}"#.utf8))
        XCTAssertTrue(partial.onboarded)
        XCTAssertEqual(partial.settings.newPerDay, 15)
        XCTAssertEqual(partial.settings.dailyGoal, Settings().dailyGoal)
    }
}

final class AnswerCheckTests: XCTestCase {
    func testExactAndCaseInsensitive() {
        XCTAssertEqual(AnswerCheck.grade("Journey", accepted: ["journey"]), .good)
        XCTAssertEqual(AnswerCheck.grade("  went ", accepted: ["went", "go"]), .good)
    }

    func testOneTypoIsHardForLongWords() {
        XCTAssertEqual(AnswerCheck.grade("jorney", accepted: ["journey"]), .hard)
        XCTAssertEqual(AnswerCheck.grade("cst", accepted: ["cat"]), .again)
    }

    func testWrongAndEmpty() {
        XCTAssertEqual(AnswerCheck.grade("travel", accepted: ["journey"]), .again)
        XCTAssertEqual(AnswerCheck.grade("", accepted: ["journey"]), .again)
    }

    func testPhrasalAnswers() {
        XCTAssertEqual(AnswerCheck.grade("pick up", accepted: ["pick up"]), .good)
        XCTAssertEqual(AnswerCheck.grade("Pick  up", accepted: ["pick up"]), .good)
    }

    func testDistance() {
        XCTAssertEqual(AnswerCheck.distance("kitten", "sitting"), 3)
        XCTAssertEqual(AnswerCheck.distance("", "abc"), 3)
    }
}
