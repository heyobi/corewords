import Foundation

/// What happened on one study day.
struct DayLog: Codable, Equatable {
    var answers = 0
    var correct = 0
    var newItems = 0
    var seconds: Double = 0
}

struct Settings: Codable, Equatable {
    enum Accent: String, Codable, CaseIterable { case us, uk }
    /// Language of the meaning shown next to each word.
    enum Meaning: String, Codable, CaseIterable { case turkish, english }

    var newPerDay = 10
    /// Exercises per day that count as meeting the daily goal (and keep the streak).
    var dailyGoal = 30
    var accent: Accent = .us
    var meaning: Meaning = Settings.defaultMeaning
    var speechRate: Double = 0.45
    var autoplay = true
    var sayItEnabled = true
    var remindersOn = false
    var reminderHour = 19
    var reminderMinute = 0
    var decks: [Deck] = [.core]
    var sound = true
    var haptics = true
    /// Show and play both accents next to every word (otherwise only the chosen accent, with a slow button).
    var showBothAccents = false

    static var defaultMeaning: Meaning {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("tr") ? .turkish : .english
    }

    init() {}

    // Tolerant decoding so new settings can be added without losing old ones.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        newPerDay = (try? c.decode(Int.self, forKey: .newPerDay)) ?? d.newPerDay
        dailyGoal = (try? c.decode(Int.self, forKey: .dailyGoal)) ?? d.dailyGoal
        accent = (try? c.decode(Accent.self, forKey: .accent)) ?? d.accent
        meaning = (try? c.decode(Meaning.self, forKey: .meaning)) ?? d.meaning
        speechRate = (try? c.decode(Double.self, forKey: .speechRate)) ?? d.speechRate
        autoplay = (try? c.decode(Bool.self, forKey: .autoplay)) ?? d.autoplay
        sayItEnabled = (try? c.decode(Bool.self, forKey: .sayItEnabled)) ?? d.sayItEnabled
        remindersOn = (try? c.decode(Bool.self, forKey: .remindersOn)) ?? d.remindersOn
        reminderHour = (try? c.decode(Int.self, forKey: .reminderHour)) ?? d.reminderHour
        reminderMinute = (try? c.decode(Int.self, forKey: .reminderMinute)) ?? d.reminderMinute
        decks = (try? c.decode([Deck].self, forKey: .decks)) ?? d.decks
        sound = (try? c.decode(Bool.self, forKey: .sound)) ?? d.sound
        haptics = (try? c.decode(Bool.self, forKey: .haptics)) ?? d.haptics
        showBothAccents = (try? c.decode(Bool.self, forKey: .showBothAccents)) ?? d.showBothAccents
    }
}

/// Everything the learner has done, saved as one JSON file.
struct ProgressData: Codable, Equatable {
    var cards: [String: CardState] = [:]
    var days: [String: DayLog] = [:]
    var settings = Settings()
    var onboarded = false
    var placementDone = false
    /// Lessons (function words) whose quiz was finished, with the best score.
    var lessonScores: [String: Int] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cards = (try? c.decode([String: CardState].self, forKey: .cards)) ?? [:]
        days = (try? c.decode([String: DayLog].self, forKey: .days)) ?? [:]
        settings = (try? c.decode(Settings.self, forKey: .settings)) ?? Settings()
        onboarded = (try? c.decode(Bool.self, forKey: .onboarded)) ?? false
        placementDone = (try? c.decode(Bool.self, forKey: .placementDone)) ?? false
        lessonScores = (try? c.decode([String: Int].self, forKey: .lessonScores)) ?? [:]
    }

    func state(_ key: String) -> CardState { cards[key] ?? CardState() }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let d = SRS.studyDay(date, calendar: calendar)
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func log(on date: Date, calendar: Calendar = .current) -> DayLog { days[Self.dayKey(date, calendar: calendar)] ?? DayLog() }

    mutating func record(_ key: String, grade: Grade, now: Date, seconds: Double = 0, calendar: Calendar = .current) {
        let before = state(key)
        cards[key] = SRS.schedule(before, grade: grade, now: now, key: key, calendar: calendar)
        let dk = Self.dayKey(now, calendar: calendar)
        var log = days[dk] ?? DayLog()
        log.answers += 1
        if grade != .again { log.correct += 1 }
        if before.status == .new { log.newItems += 1 }
        log.seconds += min(seconds, 120)
        days[dk] = log
    }

    mutating func markKnown(_ keys: [String], now: Date) {
        for k in keys where !state(k).isStarted || state(k).status == .known {
            cards[k] = SRS.markKnown(state(k), now: now)
        }
    }

    /// Days after which a passed "I know this" check comes back once to confirm it.
    static let knownCheckInterval: Double = 21

    /// The learner said they know a new word and picked the right meaning: skip the learning steps and check it
    /// again in three weeks. If that check passes too, the interval grows quickly and the word is mastered.
    mutating func passKnownCheck(_ key: String, now: Date, calendar: Calendar = .current) {
        var s = state(key)
        s.status = .review
        s.step = 0
        s.interval = Self.knownCheckInterval
        s.ease = 2.7
        s.reps += 1
        s.correct += 1
        s.lastReview = now
        s.firstSeen = s.firstSeen ?? now
        s.due = SRS.dueDate(after: SRS.fuzz(s.interval, key: key), from: now, calendar: calendar)
        cards[key] = s
        let dk = Self.dayKey(now, calendar: calendar)
        var log = days[dk] ?? DayLog()
        log.answers += 1
        log.correct += 1
        days[dk] = log
    }

    /// Replaces the last answer's "good" with "easy" (the learner tapped "Too easy").
    mutating func upgradeToEasy(_ key: String, previous: CardState, now: Date, calendar: Calendar = .current) {
        var n = SRS.schedule(previous, grade: .easy, now: now, key: key, calendar: calendar)
        let cur = state(key)
        n.reps = cur.reps
        n.correct = cur.correct
        n.wrong = cur.wrong
        cards[key] = n
    }

    /// Words with a review interval of three weeks or more, or marked known: long-term memory.
    static let masteredInterval: Double = 21

    func isMastered(_ s: CardState) -> Bool {
        s.status == .known || (s.status == .review && s.interval >= Self.masteredInterval)
    }

    struct Counts: Equatable {
        var learning = 0
        var learned = 0  // graduated but not yet mastered
        var mastered = 0
        var known: Int { learned + mastered }
    }

    func counts(in items: [StudyItem]? = nil) -> Counts {
        var c = Counts()
        let states: [CardState] = items.map { $0.map { state($0.key) } } ?? Array(cards.values)
        for s in states {
            switch s.status {
            case .learning, .relearning: c.learning += 1
            case .review, .known: if isMastered(s) { c.mastered += 1 } else { c.learned += 1 }
            case .new: break
            }
        }
        return c
    }

    /// Words learned for the first time today (graduated or checked as known).
    func learnedToday(now: Date, calendar: Calendar = .current) -> Int {
        let start = SRS.studyDay(now, calendar: calendar)
        return cards.values.filter { s in
            guard s.status == .review, let first = s.firstSeen else { return false }
            return first >= start
        }.count
    }

    /// Days in a row (ending today, or yesterday if today isn't done yet) on which the daily goal was met.
    func streak(now: Date, calendar: Calendar = .current) -> Int {
        let goal = max(1, settings.dailyGoal)
        var day = SRS.studyDay(now, calendar: calendar)
        if (days[Self.dayKey(day, calendar: calendar)]?.answers ?? 0) < goal {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var n = 0
        while (days[Self.dayKey(day, calendar: calendar)]?.answers ?? 0) >= goal {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    func bestStreak(calendar: Calendar = .current) -> Int {
        let goal = max(1, settings.dailyGoal)
        let met = days.filter { $0.value.answers >= goal }.keys.sorted()
        var best = 0, cur = 0
        var prev: Date?
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        for k in met {
            guard let d = f.date(from: k) else { continue }
            if let p = prev, let next = calendar.date(byAdding: .day, value: 1, to: p), calendar.isDate(next, inSameDayAs: d) {
                cur += 1
            } else {
                cur = 1
            }
            best = max(best, cur)
            prev = d
        }
        return best
    }

    /// Items learned or known per deck.
    func learnedCount(in items: [StudyItem]) -> Int { items.filter { state($0.key).isLearned }.count }

    /// Approximate share of everyday English covered by the words you know (percent).
    func coverage(_ content: ContentStore) -> Double {
        var total = 0.0
        for (key, s) in cards where s.isLearned {
            total += content.item(key)?.share ?? 0
        }
        return min(98, total)
    }

    /// Items whose review is due now, most overdue first.
    func dueKeys(now: Date, decks: Set<Deck>, content: ContentStore) -> [String] {
        cards.filter { key, s in
            SRS.isDue(s, now: now) && (content.item(key).map { decks.contains($0.deck) } ?? false)
        }
        .sorted { $0.value.due < $1.value.due }
        .map(\.key)
    }

    /// The next new items in learning order, skipping anything already started.
    func nextNew(_ count: Int, decks: [Deck], content: ContentStore) -> [StudyItem] {
        guard count > 0 else { return [] }
        var out: [StudyItem] = []
        for d in decks {
            for item in content.ordered[d] ?? [] where !state(item.key).isStarted {
                out.append(item)
                if out.count >= count { return out }
            }
        }
        return out
    }

    /// New items still allowed today.
    func newRemaining(now: Date, calendar: Calendar = .current) -> Int {
        max(0, settings.newPerDay - log(on: now, calendar: calendar).newItems)
    }

    /// How many reviews will be due on the study day of `date` (for reminders and the forecast chart).
    func dueCount(on date: Date, calendar: Calendar = .current) -> Int {
        let end = calendar.date(byAdding: .day, value: 1, to: SRS.studyDay(date, calendar: calendar)) ?? date
        return cards.values.filter { ($0.status == .review || $0.status == .learning || $0.status == .relearning) && $0.due < end }.count
    }
}
