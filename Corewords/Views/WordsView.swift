import SwiftUI

/// Browse every word and phrasal verb in learning order, search in English or Turkish, see status.
struct WordsView: View {
    @EnvironmentObject var model: AppModel
    @State private var deck: Deck = .core
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var selection: String?

    enum Filter: String, CaseIterable, Identifiable {
        case all, learning, learned, notStarted
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .all: "All"
            case .learning: "Learning"
            case .learned: "Learned"
            case .notStarted: "New"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            list
                .navigationTitle("Words")
                .searchable(text: $query, prompt: Text("Search English or Turkish"))
        } detail: {
            if let key = selection, let item = model.content.item(key) {
                WordDetailView(item: item)
            } else {
                ContentUnavailableView("Pick a word", systemImage: "character.book.closed",
                                       description: Text("Every word has US and UK pronunciation, a meaning and an example."))
            }
        }
    }

    private var items: [StudyItem] {
        let base = model.content.ordered[deck] ?? []
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return base.filter { item in
            let s = model.progress.state(item.key)
            let passes: Bool
            switch filter {
            case .all: passes = true
            case .learning: passes = s.status == .learning || s.status == .relearning
            case .learned: passes = s.isLearned
            case .notStarted: passes = s.status == .new
            }
            guard passes else { return false }
            guard !q.isEmpty else { return true }
            return item.headword.lowercased().hasPrefix(q) || item.tr.lowercased().contains(q)
                || item.forms.contains { $0.lowercased() == q } || (q.count > 3 && item.def.lowercased().contains(q))
        }
    }

    private var list: some View {
        List(selection: $selection) {
            Section {
                Picker("Deck", selection: $deck) {
                    Text("Core").tag(Deck.core)
                    Text("Extended").tag(Deck.extended)
                    Text("Phrasal").tag(Deck.phrasal)
                }
                .pickerStyle(.segmented)
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                if !model.isUnlocked(deck) {
                    Button { model.showPaywall = true } label: {
                        HStack {
                            ProBadge()
                            Text("Browse freely. Studying this deck is part of Pro.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            let list = items
            Section {
                ForEach(list) { item in
                    NavigationLink(value: item.key) { WordRow(item: item, state: model.progress.state(item.key)) }
                }
            } header: {
                Text("\(list.count) words")
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct WordRow: View {
    @EnvironmentObject var model: AppModel
    let item: StudyItem
    let state: CardState

    var body: some View {
        HStack(spacing: 12) {
            Text(item.deck == .phrasal ? "" : "\(rankLabel)")
                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 38, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.headword).font(.body.weight(.semibold))
                Text(model.settings.meaning == .turkish ? item.tr : item.def).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            statusDot
        }
    }

    private var rankLabel: String {
        guard let w = model.content.word(for: item) else { return "" }
        return w.band == "basic" ? "·" : "\(w.rank)"
    }

    @ViewBuilder private var statusDot: some View {
        switch state.status {
        case .review, .known: Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.good)
        case .learning, .relearning: Image(systemName: "circle.lefthalf.filled").foregroundStyle(.orange)
        case .new: EmptyView()
        }
    }
}

struct WordDetailView: View {
    @EnvironmentObject var model: AppModel
    let item: StudyItem

    var body: some View {
        let state = model.progress.state(item.key)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.headword).font(.rounded(40, .bold))
                        POSBadge(pos: item.pos)
                    }
                    IPARow(text: item.headword, us: item.us, uk: item.uk)
                }
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Label { Text(item.tr).font(.rounded(20, .semibold)) } icon: { Text("🇹🇷") }
                        Text(item.def).font(.body)
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Example").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 10) {
                            SpeakButton(text: item.plainExample, size: 15)
                            ExampleText(item: item)
                        }
                        HStack {
                            Spacer()
                            SpeakButton(text: item.plainExample, size: 13, slow: true)
                        }
                    }
                }
                if !item.forms.isEmpty {
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Word forms").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(item.forms.joined(separator: " · ")).font(.body)
                        }
                    }
                }
                if let w = model.content.word(for: item), w.band != "basic" {
                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Frequency").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text("#\(w.rank) of the most common English words").font(.body)
                            Text("Knowing the top \(w.rank) words covers about \(Int(w.cov.rounded()))% of everyday English.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your progress").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(statusText(state)).font(.body)
                        if state.reps > 0 {
                            Text("\(state.correct) right, \(state.wrong) wrong").font(.footnote).foregroundStyle(.secondary)
                        }
                        HStack {
                            if state.status != .known && state.status != .review {
                                Button("I know this word") { model.progress.markKnown([item.key], now: Date()) }
                                    .buttonStyle(.bordered)
                            }
                            if state.isStarted {
                                Button("Reset", role: .destructive) { model.progress.cards[item.key] = nil }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(item.headword)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusText(_ s: CardState) -> LocalizedStringKey {
        switch s.status {
        case .new: return "Not studied yet"
        case .learning, .relearning: return "Learning"
        case .known: return "Marked as known"
        case .review:
            let days = Int(s.interval.rounded())
            return "Learned · next review in \(max(0, Calendar.current.dateComponents([.day], from: Date(), to: s.due).day ?? 0)) days (interval \(days) days)"
        }
    }
}
