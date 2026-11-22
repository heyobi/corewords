import SwiftUI

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Adaptive {
                        startCard
                    } second: {
                        goalCard
                        coverageCard
                    }
                    if !model.progress.placementDone && model.progress.learnedCount(in: model.content.ordered[.core] ?? []) < 30 {
                        placementCard
                    }
                    decksSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(Text("Settings"))
                }
            }
        }
    }

    private var due: Int { model.dueCount() }
    private var fresh: Int { model.newAvailableToday() }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(greeting).font(.rounded(26, .bold))
                Spacer()
                streakBadge
            }
            HStack(spacing: 12) {
                stat("\(due)", "to review", "arrow.clockwise", .brandIndigo)
                stat("\(fresh)", "new words", "sparkles", .brandTeal)
            }
            if due + fresh > 0 {
                Button { model.startSession() } label: {
                    Label("Start today's session", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("All done for today", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Color.good)
                    Text("Come back tomorrow for your reviews, or learn a few more words now.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Button { model.startSession(extraNew: 5) } label: { Label("Learn 5 more words", systemImage: "plus") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.brandIndigo.opacity(0.16), Color.brandTeal.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var greeting: LocalizedStringKey {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var streakBadge: some View {
        let s = model.progress.streak(now: Date())
        return Label("\(s)", systemImage: "flame.fill")
            .font(.rounded(17, .bold))
            .foregroundStyle(s > 0 ? Color.orange : Color.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background((s > 0 ? Color.orange : Color.secondary).opacity(0.12), in: Capsule())
            .accessibilityLabel(Text("\(s)-day streak"))
    }

    private func stat(_ value: String, _ label: LocalizedStringKey, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.rounded(30, .bold)).contentTransition(.numericText())
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var goalCard: some View {
        let log = model.progress.log(on: Date())
        let goal = max(1, model.settings.dailyGoal)
        return Panel {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(value: Double(log.answers) / Double(goal), lineWidth: 10, color: .orange)
                    Image(systemName: log.answers >= goal ? "checkmark" : "target").font(.title3.bold()).foregroundStyle(.orange)
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily goal").font(.headline)
                    Text("\(min(log.answers, goal)) of \(goal) exercises").font(.subheadline).foregroundStyle(.secondary)
                    if log.answers > 0 {
                        Text("\(Int((Double(log.correct) / Double(max(1, log.answers)) * 100).rounded()))% correct today")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private var coverageCard: some View {
        let cov = model.progress.coverage(model.content)
        let known = model.progress.cards.values.filter(\.isLearned).count
        return Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Everyday English you can read").font(.headline)
                    Spacer()
                    Text("\(Int(cov.rounded()))%").font(.rounded(22, .bold)).foregroundStyle(Color.brandTeal)
                }
                ProgressView(value: cov, total: 100).tint(.brandTeal)
                Text("The \(known) words you know cover about \(Int(cov.rounded()))% of the words in everyday English text.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var placementCard: some View {
        Panel {
            HStack(spacing: 14) {
                Image(systemName: "gauge.with.dots.needle.67percent").font(.largeTitle).foregroundStyle(Color.brandIndigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not a beginner?").font(.headline)
                    Text("Take a 3-minute test and skip the words you already know.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Start") { model.showPlacement = true }.buttonStyle(.borderedProminent)
            }
        }
    }

    private var decksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your decks").font(.title3.bold()).padding(.top, 6)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                deckCard(.core, "Core 2,800", "The NGSL: the most frequent words, about 92% of everyday English.", "star.fill", .brandIndigo)
                deckCard(.extended, "Extended 5,000", "2,200 more words for reading news, books and work email.", "books.vertical.fill", .brandTeal)
                deckCard(.phrasal, "Phrasal verbs", "205 everyday phrasal verbs like get up, look after, put up with.", "arrow.triangle.branch", .orange)
            }
        }
    }

    private func deckCard(_ deck: Deck, _ title: LocalizedStringKey, _ blurb: LocalizedStringKey, _ icon: String, _ color: Color) -> some View {
        let items = model.content.ordered[deck] ?? []
        let learned = model.progress.learnedCount(in: items)
        let active = model.activeDecks.contains(deck)
        return Button {
            if !model.isUnlocked(deck) { model.showPaywall = true; return }
            var decks = model.settings.decks
            if decks.contains(deck) { if decks.count > 1 { decks.removeAll { $0 == deck } } } else { decks.append(deck) }
            model.settings.decks = decks
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).font(.title3).foregroundStyle(color)
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if !model.isUnlocked(deck) { ProBadge() }
                    Spacer()
                    Image(systemName: active ? "checkmark.circle.fill" : "circle")
                        .font(.title3).foregroundStyle(active ? color : .secondary)
                }
                Text(blurb).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                ProgressView(value: Double(learned), total: Double(max(1, items.count))).tint(color)
                Text("\(learned) of \(items.count) learned").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(active ? color.opacity(0.5) : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Tap to include or leave out this deck in your daily session"))
    }
}
