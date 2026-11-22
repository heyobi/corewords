import SwiftUI

/// The placement test: about 40 "what does it mean?" questions from easy to hard. It stops early once two bands
/// in a row are clearly unknown.
struct PlacementView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var onFinish: (() -> Void)? = nil

    @State private var test: Placement?
    @State private var index = 0
    @State private var results: [UUID: Bool] = [:]
    @State private var done = false
    @State private var chosen: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { close() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 36, height: 36).background(Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                if let test, !done {
                    ProgressView(value: Double(index), total: Double(max(1, test.questions.count)))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            if let test {
                if done || index >= test.questions.count { result(test) } else { question(test.questions[index], test) }
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            if test == nil { test = Placement(content: model.content, meaning: model.settings.meaning) }
        }
    }

    private func question(_ q: Placement.Question, _ test: Placement) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Do you know this word?").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 20)
                Text(q.item.headword).font(.rounded(44, .bold))
                SpeakButton(text: q.item.headword)
                VStack(spacing: 12) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { i, opt in
                        OptionButton(text: opt, state: chosen == nil ? .idle : (i == q.answerIndex ? .right : (i == chosen ? .wrong : .dimmed)), big: false) {
                            pick(i, q, test)
                        }
                    }
                    Button("I don't know this word") { pick(-1, q, test) }
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary).padding(.top, 6)
                }
            }
            .padding(20)
        }
        .id(q.id)
    }

    private func pick(_ i: Int, _ q: Placement.Question, _ test: Placement) {
        guard chosen == nil else { return }
        chosen = i
        results[q.id] = i == q.answerIndex
        Task {
            try? await Task.sleep(for: .milliseconds(i == q.answerIndex ? 350 : 700))
            chosen = nil
            index += 1
            // Stop early when the current band is clearly failed and the previous one was too.
            let band = q.band
            let qs = test.questions.filter { $0.band == band }
            let answered = qs.filter { results[$0.id] != nil }
            let wrong = answered.filter { results[$0.id] == false }.count
            if wrong > qs.count - Placement.passMark && answered.count == qs.count && band > 0 {
                let prev = test.questions.filter { $0.band == band - 1 }
                if prev.filter({ results[$0.id] == false }).count > prev.count - Placement.passMark { done = true }
            }
            if wrong > qs.count - Placement.passMark && answered.count == qs.count && band == 0 { done = true }
        }
    }

    private func result(_ test: Placement) -> some View {
        let passed = test.passedBands(results)
        let keys = test.knownKeys(passed: passed, content: model.content)
        let all = (model.content.ordered[.core] ?? []) + (model.content.ordered[.extended] ?? [])
        let cov = keys.compactMap { model.content.item($0)?.share }.reduce(0, +)
        return ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundStyle(Color.good).padding(.top, 30)
                if passed == 0 {
                    Text("Let's start from the beginning").font(.rounded(28, .bold)).multilineTextAlignment(.center)
                    Text("You'll learn the most frequent words first. They make the biggest difference.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                } else {
                    Text("You already know about \(keys.count) words").font(.rounded(28, .bold)).multilineTextAlignment(.center)
                    Text("That's roughly \(Int(cov.rounded()))% of everyday English. We'll mark them as known and start you at word \(min(keys.count + 1, all.count)).")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Text("Unsure about a word later? Find it in Words and reset it.").font(.footnote).foregroundStyle(.secondary)
                }
                Button {
                    model.progress.markKnown(keys, now: Date())
                    model.progress.placementDone = true
                    close()
                } label: { Text("Start learning") }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
    }

    private func close() {
        if let onFinish { onFinish() } else { dismiss() }
    }
}
