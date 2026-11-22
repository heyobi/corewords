import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: Store
    @EnvironmentObject var speaker: Speaker
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: model.settings.reminderHour, minute: model.settings.reminderMinute, second: 0, of: Date()) ?? Date()
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            model.settings.reminderHour = c.hour ?? 19
            model.settings.reminderMinute = c.minute ?? 0
            Reminders.reschedule(model.progress)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: Binding(get: { model.settings.newPerDay }, set: { model.settings.newPerDay = $0 }), in: 0...50, step: 5) {
                        LabeledContent("New words per day", value: "\(model.settings.newPerDay)")
                    }
                    Stepper(value: Binding(get: { model.settings.dailyGoal }, set: { model.settings.dailyGoal = $0 }), in: 10...200, step: 10) {
                        LabeledContent("Daily goal (exercises)", value: "\(model.settings.dailyGoal)")
                    }
                } header: {
                    Text("Daily study")
                } footer: {
                    Text("10 new words a day is about 3,600 a year. Reviews come on top and are what make words stick.")
                }

                Section("Meaning and pronunciation") {
                    Picker("Show meanings in", selection: Binding(get: { model.settings.meaning }, set: { model.settings.meaning = $0 })) {
                        Text("Turkish + English").tag(Settings.Meaning.turkish)
                        Text("English only").tag(Settings.Meaning.english)
                    }
                    Picker("Accent", selection: Binding(get: { model.settings.accent }, set: { model.settings.accent = $0 })) {
                        Text("American (US)").tag(Settings.Accent.us)
                        Text("British (UK)").tag(Settings.Accent.uk)
                    }
                    Toggle("Show both accents", isOn: Binding(get: { model.settings.showBothAccents }, set: { model.settings.showBothAccents = $0 }))
                    VStack(alignment: .leading) {
                        Text("Speaking speed")
                        Slider(value: Binding(get: { model.settings.speechRate }, set: { model.settings.speechRate = $0 }), in: 0.25...0.6) {
                            Text("Speaking speed")
                        } minimumValueLabel: { Image(systemName: "tortoise") } maximumValueLabel: { Image(systemName: "hare") }
                    }
                    Button { model.speak("The most useful words come first.") } label: { Label("Test the voice", systemImage: "speaker.wave.2") }
                    Toggle("Play words automatically", isOn: Binding(get: { model.settings.autoplay }, set: { model.settings.autoplay = $0 }))
                    if !speaker.hasEnhancedVoice(model.settings.accent) {
                        Text("Tip: for a more natural voice, download an Enhanced or Premium English voice in iOS Settings › Accessibility › Spoken Content › Voices.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle(isOn: Binding(get: { model.settings.sayItEnabled }, set: { model.settings.sayItEnabled = $0 })) {
                        HStack { Text("\"Say it\" exercises"); if !store.isPro { ProBadge() } }
                    }
                    .disabled(!store.isPro)
                } footer: {
                    Text("Speech is recognized on your iPhone only. Nothing is recorded or uploaded.")
                }

                Section("Reminders") {
                    Toggle("Daily reminder", isOn: Binding(get: { model.settings.remindersOn }, set: { on in
                        if on {
                            Task {
                                let ok = await Reminders.requestPermission()
                                model.settings.remindersOn = ok
                                Reminders.reschedule(model.progress)
                            }
                        } else {
                            model.settings.remindersOn = false
                            Reminders.reschedule(model.progress)
                        }
                    }))
                    if model.settings.remindersOn {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Feedback") {
                    Toggle("Sound", isOn: Binding(get: { model.settings.sound }, set: { model.settings.sound = $0 }))
                    Toggle("Haptics", isOn: Binding(get: { model.settings.haptics }, set: { model.settings.haptics = $0 }))
                }

                Section("Corewords Pro") {
                    if store.isPro {
                        Label("Pro is unlocked. Thank you!", systemImage: "checkmark.seal.fill").foregroundStyle(Color.good)
                    } else {
                        Button { model.showSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.showPaywall = true } } label: {
                            Label("Unlock Pro", systemImage: "sparkles")
                        }
                    }
                    Button("Restore purchase") { Task { await store.restore() } }
                }

                Section("Level") {
                    Button("Take the placement test again") {
                        model.showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.showPlacement = true }
                    }
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }

                Section("About") {
                    NavigationLink("Sources and licenses") { CreditsView() }
                    Link("Privacy: no data is collected", destination: URL(string: "https://github.com/heyobi/corewords/blob/main/PRIVACY.md")!)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Reset all progress?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) {
                    let s = model.progress.settings
                    model.progress = ProgressData()
                    model.progress.settings = s
                    model.progress.onboarded = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every word goes back to new and your streak starts again. This can't be undone.")
            }
            .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            }
        }
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section("Word lists") {
                credit("New General Service List (NGSL) 1.2",
                       "Browne, C., Culligan, B., & Phillips, J. (2013). The New General Service List. newgeneralservicelist.com. Licensed under CC BY-SA 4.0.")
                credit("NGSL-GR 1.0 (Graded Reader)",
                       "Browne, C., & Culligan, B. (2024). The New General Service List – Graded Reader Edition. newgeneralservicelist.com. Licensed under CC BY-SA 4.0.")
                Text("Word order and frequency bands come from these lists. Coverage figures are approximate.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Pronunciation") {
                credit("CMU Pronouncing Dictionary", "Copyright © 1993–2015 Carnegie Mellon University. BSD-style license. Converted to IPA for the US transcriptions.")
                credit("Britfone", "Copyright © 2017 Jose Llarena. MIT License. Source of the UK transcriptions.")
                Text("Audio is spoken by the voices built into iOS. No recordings are included.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Meanings and examples") {
                Text("Definitions, example sentences, Turkish translations, lessons and phrasal verb selections were written for Corewords. Together with the word lists they are shared under CC BY-SA 4.0 at github.com/heyobi/corewords.")
                    .font(.subheadline)
            }
            Section("App") {
                Text("The Corewords source code is open source under the MIT License.").font(.subheadline)
            }
        }
        .navigationTitle("Sources and licenses")
    }

    private func credit(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct PaywallView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "sparkles").font(.system(size: 54)).foregroundStyle(
                        LinearGradient(colors: [.brandIndigo, .brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(.top, 24)
                    Text("Corewords Pro").font(.rounded(32, .bold))
                    Text("One purchase, yours forever. No subscription, no ads, no account.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        feature("books.vertical.fill", "Extended list: 2,200 more words", "Go from 92% to about 98% of everyday English, with meanings and examples.", .brandTeal)
                        feature("arrow.triangle.branch", "205 phrasal verbs", "get over, put up with, figure out… drilled with spaced repetition.", .orange)
                        feature("ear.and.waveform", "Pronunciation trainer", "All 70 minimal pairs for the sounds Turkish speakers find hardest.", .brandIndigo)
                        feature("mic.fill", "Say it", "Pronounce words out loud and get checked on your device.", .pink)
                    }
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text("Free forever: the 2,800 core words, all grammar lessons, the 44-sound chart, the placement test, reminders and progress.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        Task { await store.buy(); if store.isPro { dismiss() } }
                    } label: {
                        if store.busy { ProgressView().tint(.white) } else if let price = store.priceText { Text("Unlock for \(price)") } else { Text("Unlock Pro") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.busy)
                    Button("Restore purchase") { Task { await store.restore() } }.font(.subheadline)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
            .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil; if store.isPro { dismiss() } }
            }
        }
    }

    private func feature(_ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
