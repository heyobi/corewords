import AVFoundation
import Speech
import SwiftUI

/// Text-to-speech with the best installed en-US / en-GB voices. Nothing is downloaded; iOS ships these voices,
/// and higher-quality ones can be added in Settings › Accessibility › Spoken Content › Voices.
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    private let synth = AVSpeechSynthesizer()
    private var voices: [String: AVSpeechSynthesisVoice] = [:]

    override init() {
        super.init()
        synth.delegate = self
    }

    func voice(for accent: Settings.Accent) -> AVSpeechSynthesisVoice? {
        let lang = accent == .us ? "en-US" : "en-GB"
        if let v = voices[lang] { return v }
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == lang }
        // Prefer premium, then enhanced, then default quality; skip novelty voices.
        let novelty: Set<String> = ["Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos", "Good News", "Jester",
                                    "Organ", "Superstar", "Trinoids", "Whisper", "Wobble", "Zarvox", "Grandma", "Grandpa",
                                    "Rocko", "Shelley", "Flo", "Eddy", "Reed", "Sandy"]
        let ranked = all.filter { !novelty.contains($0.name) }.sorted { a, b in
            a.quality.rawValue != b.quality.rawValue ? a.quality.rawValue > b.quality.rawValue : a.name < b.name
        }
        let v = ranked.first ?? AVSpeechSynthesisVoice(language: lang)
        voices[lang] = v
        return v
    }

    func hasEnhancedVoice(_ accent: Settings.Accent) -> Bool {
        (voice(for: accent)?.quality.rawValue ?? 0) >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue
    }

    func speak(_ text: String, accent: Settings.Accent, rate: Double, slow: Bool = false) {
        guard !text.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = voice(for: accent)
        let r = slow ? rate * 0.6 : rate
        u.rate = Float(AVSpeechUtteranceMinimumSpeechRate + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * r)
        u.preUtteranceDelay = 0.02
        speaking = true
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}

/// On-device speech recognition for the "Say it" check. Audio never leaves the phone: if the device can't
/// recognize English offline, the feature reports itself unavailable instead of using a server.
@MainActor
final class Listener: ObservableObject {
    enum State: Equatable { case idle, listening, denied, unavailable }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    var isAvailableOffline: Bool {
        let r = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        return r?.supportsOnDeviceRecognition ?? false
    }

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { state = .denied; return false }
        let mic = await AVAudioApplication.requestRecordPermission()
        if !mic { state = .denied }
        return mic
    }

    func start(accent: Settings.Accent) async {
        guard state != .listening else { return }
        guard await requestPermission() else { return }
        let r = SFSpeechRecognizer(locale: Locale(identifier: accent == .us ? "en-US" : "en-GB"))
        guard let r, r.isAvailable, r.supportsOnDeviceRecognition else { state = .unavailable; return }
        recognizer = r
        transcript = ""
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true
        req.shouldReportPartialResults = true
        request = req
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in req?.append(buffer) }
            engine.prepare()
            try engine.start()
            state = .listening
            task = r.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil || (result?.isFinal ?? false) { self?.stop() }
                }
            }
        } catch {
            stop()
            state = .unavailable
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if state == .listening { state = .idle }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
}
