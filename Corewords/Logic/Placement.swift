import Foundation

/// A short vocabulary test that finds where to start. Words are sampled from frequency bands; a band counts as
/// known when at least 5 of its 6 words are answered correctly. All words in the known bands (and the basics)
/// are marked as known, so learning starts at the first band that isn't.
struct Placement {
    struct Band: Equatable {
        let range: ClosedRange<Int>  // positions in the core + extended learning order
    }

    struct Question: Identifiable, Equatable {
        let id = UUID()
        let band: Int
        let item: StudyItem
        let options: [String]
        let answerIndex: Int

        static func == (a: Question, b: Question) -> Bool { a.id == b.id }
    }

    static let perBand = 6
    static let passMark = 5

    let bands: [Band]
    let questions: [Question]

    /// Bands over the combined order: basics + NGSL (core deck) followed by the extended deck.
    init(content: ContentStore, meaning: Settings.Meaning, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        var rng = SeededRandom(seed: seed)
        let all = (content.ordered[.core] ?? []) + (content.ordered[.extended] ?? [])
        let edges = [49, 300, 800, 1500, 2200, 2858, 3700, all.count]
        var bands: [Band] = []
        for i in 0..<(edges.count - 1) where edges[i] < edges[i + 1] {
            bands.append(Band(range: edges[i]...(edges[i + 1] - 1)))
        }
        self.bands = bands
        func meaningText(_ s: StudyItem) -> String { meaning == .turkish ? s.tr : s.def }
        var qs: [Question] = []
        for (b, band) in bands.enumerated() {
            let slice = Array(all[band.range])
            // Skip pure function words: their "meaning" is a grammar note, not a fair test question.
            let testable = slice.filter { !["det", "prep", "conj", "pron", "modal", "num"].contains($0.pos) }
            for item in testable.shuffled(using: &rng).prefix(Self.perBand) {
                var opts = [meaningText(item)]
                for d in slice.shuffled(using: &rng) where d.key != item.key && d.pos == item.pos {
                    let t = meaningText(d)
                    if !opts.contains(t) { opts.append(t) }
                    if opts.count == 4 { break }
                }
                for d in slice.shuffled(using: &rng) where opts.count < 4 && d.key != item.key {
                    let t = meaningText(d)
                    if !opts.contains(t) { opts.append(t) }
                }
                opts.shuffle(using: &rng)
                qs.append(Question(band: b, item: item, options: opts, answerIndex: opts.firstIndex(of: meaningText(item)) ?? 0))
            }
        }
        questions = qs
    }

    /// Number of bands passed in a row from the start, given right/wrong per question id.
    func passedBands(_ results: [UUID: Bool]) -> Int {
        var passed = 0
        for b in bands.indices {
            let qs = questions.filter { $0.band == b }
            let right = qs.filter { results[$0.id] == true }.count
            if right >= min(Self.passMark, qs.count) && !qs.isEmpty { passed += 1 } else { break }
        }
        return passed
    }

    /// Keys of the items to mark known after passing `passed` bands (the basics are always included once any band
    /// is passed).
    func knownKeys(passed: Int, content: ContentStore) -> [String] {
        guard passed > 0 else { return [] }
        let all = (content.ordered[.core] ?? []) + (content.ordered[.extended] ?? [])
        let end = bands[passed - 1].range.upperBound
        return all.prefix(end + 1).map(\.key)
    }
}
