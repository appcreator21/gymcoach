import AVFoundation

/// Spoken cues for guided classes ("Next: burpees", "three, two, one").
@MainActor
final class VoiceCoach {
    static let shared = VoiceCoach()
    private let synth = AVSpeechSynthesizer()
    private var configured = false

    func speak(_ text: String) {
        guard Prefs.bool(Prefs.voiceCues, default: true) else { return }
        if !configured {
            // Duck other audio (music) while speaking, and keep playing with the screen locked.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            configured = true
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
