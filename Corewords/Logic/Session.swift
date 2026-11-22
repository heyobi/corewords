import Foundation

/// The kinds of active-recall exercise.
enum ExerciseKind: String, Codable, CaseIterable {
    /// First meeting: the word card with meaning, IPA, audio and an example.
    case intro
    /// See the word, pick its meaning.
    case wordToMeaning
    /// See the meaning, pick the word.
    case meaningToWord
    /// Hear the word, pick it.
    case listen
    /// Pick the word that fills the gap in a sentence.
    case gapChoice
    /// Type the word into the gap.
    case typeWord
    /// Say the word; on-device speech recognition checks it.
    case sayIt
}

struct Exercise: Identifiable, Equatable {
    let id = UUID()
    let item: StudyItem
    let kind: ExerciseKind
    /// Options for multiple-choice kinds (texts shown on the buttons) and the index of the right one.
    let options: [String]
    let answerIndex: Int

    static func == (a: Exercise, b: Exercise) -> Bool { a.id == b.id }
}

/// A small seedable random generator so sessions are reproducible in tests and screenshots.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Builds and runs one study session: due reviews first, then new items (each introduced, then practiced until it
/// leaves the learning steps), with a different exercise kind depending on how well the item is known.
final class SessionEngine {
    struct Entry: Equatable {
        let key: String
        var introduced: Bool
        /// The learner said "I know this": one quick check decides whether the word is skipped or learned.
        var checking = false
    }

    let content: ContentStore
    private(set) var queue: [Entry] = []
    private(set) var reviewed = 0
    private(set) var correct = 0
    private(set) var wrong = 0
    private(set) var newIntroduced = 0
    private(set) var knownByCheck = 0
    /// Items that left the learning steps during this session (newly learned), in order.
    private(set) var learnedKeys: [String] = []
    let meaning: Settings.Meaning
    let sayItAvailable: Bool
    private var rng: SeededRandom

    init(content: ContentStore, progress: ProgressData, now: Date, decks: [Deck], reviewLimit: Int = 150,
         newLimit: Int? = nil, sayItAvailable: Bool = false, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        self.content = content
        self.meaning = progress.settings.meaning
        self.sayItAvailable = sayItAvailable
        rng = SeededRandom(seed: seed)
        let due = progress.dueKeys(now: now, decks: Set(decks), content: content).prefix(reviewLimit)
        let newCount = newLimit ?? progress.newRemaining(now: now)
        let fresh = progress.nextNew(newCount, decks: decks, content: content)
        // Reviews first so the forgetting curve is respected; new items mixed in after every few reviews.
        var q: [Entry] = []
        var dueIter = due.makeIterator()
        var newIter = fresh.makeIterator()
        var pending = true
        while pending {
            pending = false
            for _ in 0..<3 {
                if let k = dueIter.next() { q.append(Entry(key: k, introduced: true)); pending = true }
            }
            if let n = newIter.next() { q.append(Entry(key: n.key, introduced: false)); pending = true }
        }
        queue = q
    }

    var isFinished: Bool { queue.isEmpty }
    var remaining: Int { queue.count }

    /// The next exercise for the item at the front of the queue.
    func current(progress: ProgressData) -> Exercise? {
        guard let e = queue.first, let item = content.item(e.key) else { return nil }
        if !e.introduced { return Exercise(item: item, kind: .intro, options: [], answerIndex: 0) }
        if e.checking { return make(.wordToMeaning, for: item) }
        let kind = chooseKind(for: progress.state(e.key), item: item)
        return make(kind, for: item)
    }

    /// Picks the exercise kind from the item's state: recognition first, then recall, then production.
    func chooseKind(for s: CardState, item: StudyItem) -> ExerciseKind {
        let phrasal = item.deck == .phrasal
        switch s.status {
        case .new, .known:
            return .wordToMeaning
        case .learning:
            if s.step == 0 { return Bool.random(using: &rng) ? .wordToMeaning : .listen }
            if phrasal { return .gapChoice }
            var kinds: [ExerciseKind] = [.meaningToWord, .listen, .gapChoice]
            if sayItAvailable { kinds.append(.sayIt) }
            return kinds.randomElement(using: &rng) ?? .meaningToWord
        case .relearning:
            return .meaningToWord
        case .review:
            if s.interval < 4 {
                var kinds: [ExerciseKind] = [.gapChoice, .meaningToWord, .listen, .typeWord]
                if sayItAvailable && !phrasal { kinds.append(.sayIt) }
                return kinds.randomElement(using: &rng) ?? .gapChoice
            }
            var kinds: [ExerciseKind] = [.typeWord, .typeWord, .gapChoice, .meaningToWord]
            if sayItAvailable && !phrasal { kinds.append(.sayIt) }
            return kinds.randomElement(using: &rng) ?? .typeWord
        }
    }

    func meaningText(_ item: StudyItem) -> String { meaning == .turkish ? item.tr : item.def }

    /// Builds the exercise with options and distractors.
    func make(_ kind: ExerciseKind, for item: StudyItem) -> Exercise {
        switch kind {
        case .intro, .typeWord, .sayIt:
            return Exercise(item: item, kind: kind, options: [], answerIndex: 0)
        case .wordToMeaning:
            let others = distractors(for: item, count: 3).map(meaningText)
            return shuffled(kind, item, right: meaningText(item), wrong: others)
        case .meaningToWord, .listen:
            let others = distractors(for: item, count: 3, similarSpelling: kind == .listen).map(\.headword)
            return shuffled(kind, item, right: item.headword, wrong: others)
        case .gapChoice:
            // Match the answer's capitalization so a capital letter at the start of a sentence gives nothing away.
            let capital = item.answer.first?.isUppercase ?? false
            let others = distractors(for: item, count: 3).map { d -> String in
                capital ? d.answer.prefix(1).uppercased() + d.answer.dropFirst() : d.answer
            }
            return shuffled(kind, item, right: item.answer, wrong: others)
        }
    }

    private func shuffled(_ kind: ExerciseKind, _ item: StudyItem, right: String, wrong: [String]) -> Exercise {
        var opts = [right]
        for w in wrong where !opts.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) { opts.append(w) }
        opts.shuffle(using: &rng)
        return Exercise(item: item, kind: kind, options: opts, answerIndex: opts.firstIndex(of: right) ?? 0)
    }

    /// Other items of the same deck, preferably the same part of speech and a similar frequency, never with the
    /// same meaning. For listening, words that look or sound alike are preferred.
    func distractors(for item: StudyItem, count: Int, similarSpelling: Bool = false) -> [StudyItem] {
        let pool = content.ordered[item.deck] ?? []
        let window = 250
        let idx = min(max(0, item.order), pool.count)
        let lo = max(0, idx - window), hi = max(lo, min(pool.count, idx + window))
        var candidates = Array(pool[lo..<hi]).filter {
            $0.key != item.key && $0.tr != item.tr && $0.def != item.def && $0.headword.lowercased() != item.headword.lowercased()
                && $0.answer.lowercased() != item.answer.lowercased()
        }
        if item.deck != .phrasal {
            let samePos = candidates.filter { $0.pos == item.pos }
            if samePos.count >= count * 2 { candidates = samePos }
        }
        if similarSpelling {
            let target = item.headword.lowercased()
            let alike = candidates.filter {
                let w = $0.headword.lowercased()
                return w.first == target.first || w.suffix(2) == target.suffix(2)
            }
            if alike.count >= count { candidates = alike }
        }
        candidates.shuffle(using: &rng)
        return Array(candidates.prefix(count))
    }

    /// The learner dismissed the intro card: from now on the item is practiced.
    func introduced() {
        guard !queue.isEmpty else { return }
        queue[0].introduced = true
        newIntroduced += 1
    }

    /// Removes the item at the front without practicing it.
    func skipCurrent() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }

    /// "I know this word": test it once instead of teaching it.
    func startKnownCheck() {
        guard !queue.isEmpty else { return }
        queue[0].introduced = true
        queue[0].checking = true
    }

    /// Whether the exercise on screen is a known-word check.
    var isChecking: Bool { queue.first?.checking ?? false }

    /// Result of a known-word check: passed words leave the session; failed ones are taught from the start.
    func checked(passed: Bool) {
        guard !queue.isEmpty else { return }
        reviewed += 1
        if passed {
            correct += 1
            knownByCheck += 1
            queue.removeFirst()
        } else {
            wrong += 1
            var e = queue.removeFirst()
            e.checking = false
            e.introduced = false
            queue.insert(e, at: min(1, queue.count))
        }
    }

    /// Takes an item out of this session (e.g. after "Too easy").
    func remove(_ key: String) {
        queue.removeAll { $0.key == key }
    }

    /// Records the result of the current exercise and requeues the item if it is still being learned.
    func answered(_ grade: Grade, newState: CardState) {
        guard !queue.isEmpty else { return }
        let entry = queue.removeFirst()
        reviewed += 1
        if grade == .again { wrong += 1 } else { correct += 1 }
        if newState.status == .review && newState.reps <= 3 && !learnedKeys.contains(entry.key) { learnedKeys.append(entry.key) }
        switch newState.status {
        case .learning, .relearning:
            // Come back after a few other items (sooner after a mistake), within this session.
            let gap = grade == .again ? 3 : 6
            queue.insert(entry, at: min(gap, queue.count))
        default:
            break
        }
    }
}

/// Grades a typed answer: exact (ignoring case and punctuation) is good, one small typo is hard, else again.
enum AnswerCheck {
    static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let kept = folded.unicodeScalars.filter { CharacterSet.letters.contains($0) || $0 == " " || $0 == "'" || $0 == "-" }
        return String(String.UnicodeScalarView(kept)).split(separator: " ").joined(separator: " ")
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }

    /// `accepted`: the gap answer plus the headword and its forms.
    static func grade(_ typed: String, accepted: [String]) -> Grade {
        let t = normalize(typed)
        guard !t.isEmpty else { return .again }
        let targets = accepted.map(normalize).filter { !$0.isEmpty }
        if targets.contains(t) { return .good }
        if let best = targets.map({ distance(t, $0) }).min(), let len = targets.first?.count, len >= 5, best <= 1 { return .hard }
        return .again
    }

    /// Whether recognized speech contains the word (or one of its forms).
    static func spoken(_ transcript: String, matches item: StudyItem) -> Bool {
        heard(transcript, word: item.headword, forms: item.forms)
    }

    /// Whether `word` (or a form) was heard, and `not` (the other word of a minimal pair) wasn't.
    static func heard(_ transcript: String, word: String, forms: [String] = [], not: String? = nil) -> Bool {
        let t = normalize(transcript)
        let words = Set(t.split(separator: " ").map(String.init))
        func has(_ w: String) -> Bool {
            let n = normalize(w)
            return n.contains(" ") ? t.contains(n) : words.contains(n)
        }
        if let not, has(not) { return false }
        return ([word] + forms).contains(where: has)
    }
}
