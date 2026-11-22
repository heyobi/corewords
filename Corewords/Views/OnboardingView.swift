import SwiftUI

/// First launch: what the app does, meaning language and accent, daily pace, optional placement test, reminders.
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State private var step = 0
    @State private var placing = false

    var body: some View {
        if placing {
            PlacementView(onFinish: finish)
        } else {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    welcome.tag(0)
                    preferences.tag(1)
                    pace.tag(2)
                    level.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
    }

    private func page<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            VStack(spacing: 22) { content() }
                .padding(28)
                .padding(.bottom, 40)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
    }

    private var welcome: some View {
        page {
            Image("Logo").resizable().frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.top, 30)
            Text("Corewords").font(.rounded(38, .bold))
            Text("Learn the English words you'll actually meet, most useful first.")
                .font(.title3).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                point("chart.bar.fill", "2,800 core words cover about 92% of everyday English text.")
                point("brain.head.profile", "Spaced repetition brings each word back just before you'd forget it.")
                point("waveform", "US and UK pronunciation with IPA for every word.")
                point("wifi.slash", "Works offline. No account, no ads, no tracking.")
            }
            .padding(.vertical, 8)
            Button { withAnimation { step = 1 } } label: { Text("Get started") }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func point(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.accentColor).frame(width: 30)
            Text(text).font(.body)
        }
    }

    private var preferences: some View {
        page {
            Text("How should we teach you?").font(.rounded(28, .bold)).multilineTextAlignment(.center).padding(.top, 30)
            VStack(alignment: .leading, spacing: 10) {
                Text("Meanings").font(.headline)
                choice(model.settings.meaning == .turkish, "Turkish + English", "Turkish translation and English definition") { model.settings.meaning = .turkish }
                choice(model.settings.meaning == .english, "English only", "Simple English definitions") { model.settings.meaning = .english }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Accent").font(.headline)
                choice(model.settings.accent == .us, "American", "/ˈwɔːtɚ/") { model.settings.accent = .us; model.speak("water", accent: .us) }
                choice(model.settings.accent == .uk, "British", "/ˈwɔːtə/") { model.settings.accent = .uk; model.speak("water", accent: .uk) }
                Text("You can always hear both. Tap to listen.").font(.footnote).foregroundStyle(.secondary)
            }
            Button { withAnimation { step = 2 } } label: { Text("Continue") }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func choice(_ on: Bool, _ title: LocalizedStringKey, _ sub: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(sub).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(on ? Color.accentColor : .secondary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var pace: some View {
        page {
            Text("Your daily pace").font(.rounded(28, .bold)).padding(.top, 30)
            Text("New words each day. Reviews are added automatically.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            paceChoice(5, "5 words · Relaxed", "About 5 minutes a day")
            paceChoice(10, "10 words · Steady", "About 10 minutes a day")
            paceChoice(20, "20 words · Intensive", "About 20 minutes a day")
            Toggle(isOn: Binding(get: { model.settings.remindersOn }, set: { on in
                if on {
                    Task {
                        let ok = await Reminders.requestPermission()
                        model.settings.remindersOn = ok
                    }
                } else {
                    model.settings.remindersOn = false
                }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me every evening").font(.headline)
                    Text("A local notification at 19:00. Change it any time.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button { withAnimation { step = 3 } } label: { Text("Continue") }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func paceChoice(_ n: Int, _ title: LocalizedStringKey, _ sub: LocalizedStringKey) -> some View {
        Button {
            model.settings.newPerDay = n
            model.settings.dailyGoal = n * 3
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(sub).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                let on = model.settings.newPerDay == n
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(on ? Color.accentColor : .secondary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var level: some View {
        page {
            Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 60)).foregroundStyle(Color.brandIndigo).padding(.top, 30)
            Text("Where should you start?").font(.rounded(28, .bold)).multilineTextAlignment(.center)
            Text("A quick test (about 40 questions, 3 minutes) finds the words you already know so you don't waste time on them.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { placing = true } label: { Text("Take the placement test") }.buttonStyle(PrimaryButtonStyle())
            Button { finish() } label: { Text("I'm a beginner, start from the first word") }.buttonStyle(SecondaryButtonStyle())
        }
    }

    private func finish() {
        model.progress.onboarded = true
        Reminders.reschedule(model.progress)
    }
}
