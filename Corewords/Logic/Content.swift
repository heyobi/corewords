import Foundation

/// The three study decks. Core (NGSL basics + NGSL 1.2) is free; Extended (NGSL-GR extension) and phrasal verbs
/// are part of Pro.
enum Deck: String, Codable, CaseIterable, Identifiable {
    case core, extended, phrasal
    var id: String { rawValue }
}

/// A word from the bundled list (Resources/words.json, built by tools/content/build.py).
struct Word: Codable, Identifiable, Hashable {
    let id: Int
    let w: String
    let pos: String
    let tr: String
    let def: String
    let ex: String
    let us: String
    let uk: String
    let band: String
    let rank: Int
    let cov: Double
    let forms: [String]
}

/// A phrasal verb (Resources/phrasal.json). `type`: s = separable, i = inseparable, n = no object.
struct Phrasal: Codable, Identifiable, Hashable {
    let id: Int
    let w: String
    let tr: String
    let def: String
    let ex: String
    let type: String
    let us: String
    let uk: String
}

struct Lesson: Codable, Identifiable, Hashable {
    struct Point: Codable, Hashable {
        let en: String
        let tr: String
        let examples: [[String]]
    }
    struct Question: Codable, Hashable {
        let q: String
        let options: [String]
        let answer: Int
    }
    let id: String
    /// "words" (function-word lessons) or "grammar" (tenses and structures).
    let group: String?
    let title: String
    let titleTr: String
    let words: [String]
    let intro: String
    let introTr: String
    let points: [Point]
    let quiz: [Question]
}

struct Phonetics: Codable {
    struct Example: Codable, Hashable {
        let w: String
        let us: String
        let uk: String
    }
    struct Sound: Codable, Identifiable, Hashable {
        let ipa: String
        let kind: String
        let tip: String
        let tipTr: String
        let hard: Bool
        let examples: [Example]
        var id: String { ipa }
    }
    struct Pair: Codable, Identifiable, Hashable {
        let focus: String
        let a: Example
        let b: Example
        var id: String { a.w + "/" + b.w }
    }
    let sounds: [Sound]
    let pairs: [Pair]
}

/// One thing to study, whatever deck it comes from. `key` is stable across app versions ("w:123", "p:7").
struct StudyItem: Identifiable, Hashable {
    let key: String
    let deck: Deck
    let headword: String
    let pos: String
    let tr: String
    let def: String
    /// The example sentence with the target in [brackets]; phrasal verbs may have two bracketed parts.
    let example: String
    let us: String
    let uk: String
    let forms: [String]
    /// Position in the learning order inside its deck (frequency rank for words).
    let order: Int
    /// Share of everyday English this word adds (percentage points), 0 for phrasal verbs.
    let share: Double
    var id: String { key }

    /// The example with the bracketed target replaced by a gap.
    var gapped: String { Self.replaceTargets(in: example, with: "_____") }
    /// The example as plain text.
    var plainExample: String { example.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "") }
    /// The bracketed parts, e.g. ["went"] or ["pick", "up"].
    var targets: [String] { Self.targets(in: example) }
    /// What the learner must type or pick in a gap: the bracketed parts joined by spaces.
    var answer: String { targets.joined(separator: " ") }

    static func targets(in s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inside = false
        for ch in s {
            if ch == "[" { inside = true; cur = "" } else if ch == "]" { inside = false; out.append(cur) } else if inside { cur.append(ch) }
        }
        return out
    }

    static func replaceTargets(in s: String, with gap: String) -> String {
        var out = ""
        var inside = false
        for ch in s {
            if ch == "[" { inside = true; out += gap } else if ch == "]" { inside = false } else if !inside { out.append(ch) }
        }
        return out
    }

    /// Splits the example into (text, isTarget) runs for highlighting.
    var exampleRuns: [(String, Bool)] {
        var runs: [(String, Bool)] = []
        var cur = ""
        for ch in example {
            if ch == "[" || ch == "]" {
                if !cur.isEmpty { runs.append((cur, ch == "]")) }
                cur = ""
            } else {
                cur.append(ch)
            }
        }
        if !cur.isEmpty { runs.append((cur, false)) }
        return runs
    }
}

/// Loads and indexes the bundled content once.
final class ContentStore {
    let words: [Word]
    let phrasals: [Phrasal]
    let lessons: [Lesson]
    let phonetics: Phonetics
    let items: [String: StudyItem]
    /// Items of each deck in learning order.
    let ordered: [Deck: [StudyItem]]

    init(bundle: Bundle = .main) {
        func load<T: Decodable>(_ name: String, _ type: T.Type) -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                fatalError("Missing or invalid \(name).json in the app bundle")
            }
            return value
        }
        words = load("words", [Word].self)
        phrasals = load("phrasal", [Phrasal].self)
        lessons = load("lessons", [Lesson].self)
        phonetics = load("phonetics", Phonetics.self)

        var items: [String: StudyItem] = [:]
        var core: [StudyItem] = [], ext: [StudyItem] = [], phr: [StudyItem] = []
        // Basics (days, months, numbers) come first in the core deck, then NGSL in frequency order.
        let sorted = words.sorted { a, b in
            let ba = a.band == "basic" ? 0 : a.band == "core" ? 1 : 2
            let bb = b.band == "basic" ? 0 : b.band == "core" ? 1 : 2
            return ba != bb ? ba < bb : a.rank < b.rank
        }
        var prevCov = 0.0
        for w in sorted {
            let deck: Deck = w.band == "ext" ? .extended : .core
            var share = 0.0
            if w.band != "basic" {
                share = max(0, w.cov - prevCov)
                prevCov = w.cov
            }
            // `order` is the position inside the item's own deck (used to pick distractors of similar frequency).
            let item = StudyItem(key: "w:\(w.id)", deck: deck, headword: w.w, pos: w.pos, tr: w.tr, def: w.def, example: w.ex,
                                 us: w.us, uk: w.uk, forms: w.forms, order: deck == .core ? core.count : ext.count, share: share)
            items[item.key] = item
            if deck == .core { core.append(item) } else { ext.append(item) }
        }
        for p in phrasals {
            let item = StudyItem(key: "p:\(p.id)", deck: .phrasal, headword: p.w, pos: "phr", tr: p.tr, def: p.def, example: p.ex,
                                 us: p.us, uk: p.uk, forms: [], order: phr.count, share: 0)
            items[item.key] = item
            phr.append(item)
        }
        self.items = items
        ordered = [.core: core, .extended: ext, .phrasal: phr]
    }

    func item(_ key: String) -> StudyItem? { items[key] }

    func word(for item: StudyItem) -> Word? {
        guard item.key.hasPrefix("w:"), let id = Int(item.key.dropFirst(2)) else { return nil }
        return words.first { $0.id == id }
    }
}
