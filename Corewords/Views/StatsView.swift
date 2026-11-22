import Charts
import SwiftUI

/// Coverage, progress by frequency band, activity and the review forecast.
struct StatsView: View {
    @EnvironmentObject var model: AppModel

    struct Band: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let items: [StudyItem]
    }

    private var bands: [Band] {
        let core = model.content.ordered[.core] ?? []
        let ext = model.content.ordered[.extended] ?? []
        func slice(_ a: Int, _ b: Int) -> [StudyItem] { Array(core[min(a, core.count)..<min(b, core.count)]) }
        return [
            Band(id: "basic", title: "Basics: days, months, numbers", items: slice(0, 49)),
            Band(id: "1", title: "Top 500", items: slice(49, 549)),
            Band(id: "2", title: "501–1,000", items: slice(549, 1049)),
            Band(id: "3", title: "1,001–2,000", items: slice(1049, 2049)),
            Band(id: "4", title: "2,001–2,809", items: slice(2049, core.count)),
            Band(id: "5", title: "Extended 2,810–5,000", items: ext),
            Band(id: "6", title: "Phrasal verbs", items: model.content.ordered[.phrasal] ?? []),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Adaptive {
                        coverage
                        streaks
                    } second: {
                        activity
                        forecast
                    }
                    bandsPanel
                }
                .padding(20)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Progress")
        }
    }

    private var coverage: some View {
        let cov = model.progress.coverage(model.content)
        let known = model.progress.cards.values.filter(\.isLearned).count
        return Panel {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(value: cov / 100, lineWidth: 14, color: .brandTeal)
                    VStack(spacing: 0) {
                        Text("\(Int(cov.rounded()))%").font(.rounded(28, .bold))
                        Text("coverage").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(known) words known").font(.title3.bold())
                    Text("Words are ordered by how often they appear. The words you know cover about \(Int(cov.rounded()))% of the words in everyday English text.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(nextMilestone(cov)).font(.footnote.weight(.semibold)).foregroundStyle(Color.brandTeal)
                }
            }
        }
    }

    private func nextMilestone(_ cov: Double) -> LocalizedStringKey {
        for m in [50, 70, 80, 85, 90, 95] where cov < Double(m) {
            return "Next milestone: \(m)%"
        }
        return "You know the words in 95% of everyday English!"
    }

    private var streaks: some View {
        let total = model.progress.days.values.reduce(0) { $0 + $1.answers }
        let minutes = Int(model.progress.days.values.reduce(0) { $0 + $1.seconds } / 60)
        return Panel {
            HStack {
                metric("\(model.progress.streak(now: Date()))", "day streak", "flame.fill", .orange)
                metric("\(model.progress.bestStreak())", "best streak", "trophy.fill", .yellow)
                metric("\(total)", "exercises", "checkmark.circle.fill", .good)
                metric("\(minutes)", "minutes", "clock.fill", .brandIndigo)
            }
        }
    }

    private func metric(_ v: String, _ label: LocalizedStringKey, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(v).font(.rounded(22, .bold)).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private struct DayPoint: Identifiable {
        let id: Date
        let value: Int
    }

    private var activity: some View {
        let cal = Calendar.current
        let today = SRS.studyDay(Date())
        let points: [DayPoint] = (0..<14).reversed().compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: today) else { return nil }
            return DayPoint(id: d, value: model.progress.log(on: d.addingTimeInterval(3600)).answers)
        }
        return Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Last 14 days").font(.headline)
                Chart(points) { p in
                    BarMark(x: .value("Day", p.id, unit: .day), y: .value("Exercises", p.value))
                        .foregroundStyle(p.value >= model.settings.dailyGoal ? Color.orange : Color.orange.opacity(0.4))
                        .cornerRadius(4)
                    RuleMark(y: .value("Goal", model.settings.dailyGoal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.day()) } }
                .frame(height: 140)
            }
        }
    }

    private var forecast: some View {
        let cal = Calendar.current
        let today = SRS.studyDay(Date())
        var points: [DayPoint] = []
        var prev = 0
        for off in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: off, to: today) else { continue }
            let c = model.progress.dueCount(on: d.addingTimeInterval(3600))
            points.append(DayPoint(id: d, value: max(0, c - (off == 0 ? 0 : prev))))
            prev = c
        }
        return Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reviews coming up").font(.headline)
                Chart(points) { p in
                    BarMark(x: .value("Day", p.id, unit: .day), y: .value("Reviews", p.value))
                        .foregroundStyle(Color.brandIndigo.gradient)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                .frame(height: 140)
            }
        }
    }

    private var bandsPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("By frequency").font(.headline)
                ForEach(bands) { b in
                    let learned = model.progress.learnedCount(in: b.items)
                    let learning = b.items.filter { let s = model.progress.state($0.key); return s.status == .learning || s.status == .relearning }.count
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(b.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(learned)/\(b.items.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        GeometryReader { g in
                            let total = Double(max(1, b.items.count))
                            HStack(spacing: 0) {
                                Rectangle().fill(Color.good).frame(width: g.size.width * Double(learned) / total)
                                Rectangle().fill(Color.orange).frame(width: g.size.width * Double(learning) / total)
                                Rectangle().fill(Color.secondary.opacity(0.15))
                            }
                            .clipShape(Capsule())
                        }
                        .frame(height: 10)
                    }
                }
                HStack(spacing: 14) {
                    Label("Learned", systemImage: "circle.fill").foregroundStyle(Color.good)
                    Label("Learning", systemImage: "circle.fill").foregroundStyle(.orange)
                }
                .font(.caption)
            }
        }
    }
}
