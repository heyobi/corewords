import SwiftUI

@main
struct CorewordsApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.store)
                .environmentObject(model.speaker)
                .tint(Color.accentColor)
                .task {
                    if ShotsTour.active { await ShotsTour(model: model).run() }
                }
        }
        .onChange(of: phase) { _, p in
            if p == .background { model.didEnterBackground() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView(selection: $model.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(Tab.today)
            WordsView()
                .tabItem { Label("Words", systemImage: "character.book.closed.fill") }
                .tag(Tab.words)
            LessonsView()
                .tabItem { Label("Lessons", systemImage: "text.book.closed.fill") }
                .tag(Tab.lessons)
            SoundsView()
                .tabItem { Label("Sounds", systemImage: "waveform") }
                .tag(Tab.sounds)
            StatsView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(Tab.progress)
        }
        .fullScreenCover(item: $model.studying) { req in
            StudySessionView(request: req)
                .environmentObject(model)
                .environmentObject(model.store)
                .environmentObject(model.speaker)
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView().environmentObject(model).environmentObject(model.store)
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model).environmentObject(model.store).environmentObject(model.speaker)
        }
        .fullScreenCover(isPresented: $model.showPlacement) {
            PlacementView().environmentObject(model).environmentObject(model.speaker)
        }
        .fullScreenCover(isPresented: Binding(get: { !model.progress.onboarded && !ShotsTour.active },
                                              set: { if !$0 { model.progress.onboarded = true } })) {
            OnboardingView().environmentObject(model).environmentObject(model.speaker)
        }
    }
}
