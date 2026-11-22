import Foundation

/// How well the learner did on one exercise.
enum Grade: Int, Codable, CaseIterable {
    case again = 0, hard, good, easy
}

/// Spaced-repetition state of one item. A variant of SM-2 (the algorithm behind SuperMemo 2 and Anki):
/// new items go through short learning steps, then graduate to day-based reviews whose interval grows by the
/// item's ease factor; a lapse sends a review back to relearning and lowers the ease.
struct CardState: Codable, Equatable {
    enum Status: String, Codable { case new, learning, review, relearning, known }

    var status: Status = .new
    /// Index into the learning steps while learning or relearning.
    var step = 0
    /// Current review interval in days (also the interval to return to after relearning).
    var interval: Double = 0
    var ease: Double = 2.5
    var due: Date = .distantPast
    var reps = 0
    var lapses = 0
    var correct = 0
    var wrong = 0
    var lastReview: Date?
    var firstSeen: Date?

    /// Graduated (or marked known): counts as a word you know for progress and coverage.
    var isLearned: Bool { status == .review || status == .known }
    var isStarted: Bool { status != .new }
}

enum SRS {
    /// Learning steps for new items and relearning steps after a lapse.
    static let learningSteps: [TimeInterval] = [60, 10 * 60]
    static let relearningSteps: [TimeInterval] = [10 * 60]
    static let graduatingInterval: Double = 1
    static let easyInterval: Double = 4
    static let minEase = 1.3
    static let maxInterval: Double = 3650
    /// The study day starts at 4 AM, so late-night reviews count for the day before.
    static let dayStartHour = 4

    /// The start of the study day containing `date`.
    static func studyDay(_ date: Date, calendar: Calendar = .current) -> Date {
        let shifted = date.addingTimeInterval(-Double(dayStartHour) * 3600)
        let start = calendar.startOfDay(for: shifted)
        return start.addingTimeInterval(Double(dayStartHour) * 3600)
    }

    /// The moment a review interval of `days` becomes due: the start of that study day.
    static func dueDate(after days: Double, from now: Date, calendar: Calendar = .current) -> Date {
        let whole = max(1, Int(days.rounded()))
        let day = studyDay(now, calendar: calendar)
        return calendar.date(byAdding: .day, value: whole, to: day) ?? day.addingTimeInterval(Double(whole) * 86400)
    }

    /// A small deterministic spread (±5%) so items learned together don't all come back on the same day.
    static func fuzz(_ interval: Double, key: String) -> Double {
        guard interval >= 3 else { return interval }
        var h: UInt64 = 1469598103934665603
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let f = Double(h % 1000) / 1000 * 0.1 - 0.05
        return interval * (1 + f)
    }

    static func isDue(_ s: CardState, now: Date) -> Bool {
        switch s.status {
        case .new, .known: return false
        case .learning, .relearning, .review: return s.due <= now
        }
    }

    /// The next state after answering with `grade` at `now`.
    static func schedule(_ s: CardState, grade: Grade, now: Date, key: String = "", calendar: Calendar = .current) -> CardState {
        var n = s
        n.reps += 1
        n.lastReview = now
        if n.firstSeen == nil { n.firstSeen = now }
        if grade == .again { n.wrong += 1 } else { n.correct += 1 }

        func graduate(_ days: Double) {
            n.status = .review
            n.step = 0
            n.interval = min(maxInterval, max(1, days))
            n.due = dueDate(after: fuzz(n.interval, key: key), from: now, calendar: calendar)
        }

        switch s.status {
        case .new, .learning, .known:
            if s.status != .learning { n.step = 0 }
            let steps = learningSteps
            switch grade {
            case .again:
                n.status = .learning
                n.step = 0
                n.due = now.addingTimeInterval(steps[0])
            case .hard:
                n.status = .learning
                let cur = steps[min(n.step, steps.count - 1)]
                let next = n.step + 1 < steps.count ? steps[n.step + 1] : cur * 2
                n.due = now.addingTimeInterval((cur + next) / 2)
            case .good:
                if n.step + 1 >= steps.count {
                    graduate(graduatingInterval)
                } else {
                    n.status = .learning
                    n.step += 1
                    n.due = now.addingTimeInterval(steps[n.step])
                }
            case .easy:
                graduate(easyInterval)
            }

        case .relearning:
            switch grade {
            case .again:
                n.step = 0
                n.due = now.addingTimeInterval(relearningSteps[0])
            case .hard:
                n.due = now.addingTimeInterval(relearningSteps[min(n.step, relearningSteps.count - 1)] * 1.5)
            case .good, .easy:
                if n.step + 1 >= relearningSteps.count || grade == .easy {
                    graduate(max(1, s.interval))
                } else {
                    n.step += 1
                    n.due = now.addingTimeInterval(relearningSteps[n.step])
                }
            }

        case .review:
            let elapsed = max(0, now.timeIntervalSince(s.lastReview ?? now) / 86400)
            switch grade {
            case .again:
                n.lapses += 1
                n.ease = max(minEase, s.ease - 0.2)
                n.interval = max(1, (s.interval * 0.5).rounded(.down))
                n.status = .relearning
                n.step = 0
                n.due = now.addingTimeInterval(relearningSteps[0])
            case .hard:
                n.ease = max(minEase, s.ease - 0.15)
                graduate(max(s.interval + 1, s.interval * 1.2))
            case .good:
                // Reviewing late and still remembering earns part of the extra time.
                let base = s.interval + max(0, elapsed - s.interval) / 2
                graduate(max(s.interval + 1, base * s.ease))
            case .easy:
                n.ease = s.ease + 0.15
                let base = s.interval + max(0, elapsed - s.interval)
                graduate(max(s.interval + 2, base * s.ease * 1.3))
            }
        }
        return n
    }

    /// Marks an item as already known (from the placement test or "I know this word").
    static func markKnown(_ s: CardState, now: Date) -> CardState {
        var n = s
        n.status = .known
        n.firstSeen = n.firstSeen ?? now
        return n
    }
}
