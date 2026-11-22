import SwiftUI

enum Tab: Hashable { case today, words, lessons, sounds, progress }

/// App-wide state: content, the learner's progress (saved as JSON in Application Support), the store and audio.
@MainActor
final class AppModel: ObservableObject {
    @Published var progress: ProgressData {
        didSet { scheduleSave() }
    }
    @Published var tab: Tab = .today
    @Published var studying: StudyRequest?
    @Published var showPaywall = false
    @Published var showSettings = false
    @Published var showPlacement = false

    let content: ContentStore
    let store = Store()
    let speaker = Speaker()
    let listener = Listener()
    private var saveTask: Task<Void, Never>?

    struct StudyRequest: Identifiable {
        let id = UUID()
        let decks: [Deck]
        /// nil = today's normal session; a number = extra new items ("learn more").
        let extraNew: Int?
    }

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    init(content: ContentStore = ContentStore()) {
        self.content = content
        if ShotsTour.active {
            progress = ShotsTour.demoProgress(content)
        } else if let d = try? Data(contentsOf: Self.fileURL), let p = try? JSONDecoder().decode(ProgressData.self, from: d) {
            progress = p
        } else {
            progress = ProgressData()
        }
    }

    private func scheduleSave() {
        guard !ShotsTour.active else { return }
        saveTask?.cancel()
        let snapshot = progress
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let d = try? JSONEncoder().encode(snapshot) else { return }
            try? d.write(to: AppModel.fileURL, options: .atomic)
        }
    }

    func saveNow() {
        guard !ShotsTour.active, let d = try? JSONEncoder().encode(progress) else { return }
        try? d.write(to: Self.fileURL, options: .atomic)
    }

    var settings: Settings {
        get { progress.settings }
        set { progress.settings = newValue }
    }

    /// Decks the learner studies, limited to what they own.
    var activeDecks: [Deck] {
        let chosen = progress.settings.decks.isEmpty ? [.core] : progress.settings.decks
        return chosen.filter { $0 == .core || store.isPro }
    }

    func isUnlocked(_ deck: Deck) -> Bool { deck == .core || store.isPro }

    func speak(_ text: String, slow: Bool = false) {
        guard settings.sound else { return }
        speaker.speak(text, accent: settings.accent, rate: settings.speechRate, slow: slow)
    }

    func speak(_ text: String, accent: Settings.Accent, slow: Bool = false) {
        speaker.speak(text, accent: accent, rate: settings.speechRate, slow: slow)
    }

    func startSession(decks: [Deck]? = nil, extraNew: Int? = nil) {
        let d = decks ?? activeDecks
        if d.contains(where: { !isUnlocked($0) }) { showPaywall = true; return }
        studying = StudyRequest(decks: d, extraNew: extraNew)
    }

    func dueCount(now: Date = Date()) -> Int {
        progress.dueKeys(now: now, decks: Set(activeDecks), content: content).count
    }

    func newAvailableToday(now: Date = Date()) -> Int {
        min(progress.newRemaining(now: now), progress.nextNew(progress.newRemaining(now: now), decks: activeDecks, content: content).count)
    }

    func didEnterBackground() {
        saveNow()
        Reminders.reschedule(progress)
    }
}
