// The friendly voice: says the words, counts along with things popping in, and plays family
// voice clips. A new key always cuts the old sentence short, so every press gets an answer.
import AVFoundation

final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speech()

    private let synth = AVSpeechSynthesizer()
    private var pending: DispatchWorkItem?
    private var onWord: ((Int) -> Void)?
    private var onEnd: (() -> Void)?
    private var wordIndex = 0
    private var player: AVAudioPlayer?
    private let prefs = Prefs.shared

    override init() {
        super.init()
        synth.delegate = self
    }

    static var englishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    /// The chosen voice, or the best English voice for this Mac's region (Indian English in India).
    var voice: AVSpeechSynthesisVoice? {
        if !prefs.voiceId.isEmpty, let v = AVSpeechSynthesisVoice(identifier: prefs.voiceId) { return v }
        let region = Locale.current.region?.identifier ?? "US"
        let wanted = ["en-\(region)", AVSpeechSynthesisVoice.currentLanguageCode(), "en-US"]
        let all = Speech.englishVoices
        for lang in wanted { if let v = all.first(where: { $0.language == lang }) { return v } }
        return all.first
    }

    /// British-style accents say "zed".
    var zed: Bool {
        let lang = voice?.language ?? "en-US"
        return ["en-GB", "en-IN", "en-AU", "en-IE", "en-NZ", "en-ZA"].contains(lang)
    }

    /// Says `text` after a short pause, unless another key comes first. `onWord` gets each word's
    /// index as it is spoken; `onEnd` runs when the sentence finishes or is cut short.
    func say(_ text: String, after delay: Double = 0.12, onWord: ((Int) -> Void)? = nil, onEnd: (() -> Void)? = nil) {
        stop()
        guard prefs.voiceOn else { onEnd?(); return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let u = AVSpeechUtterance(string: text)
            u.voice = self.voice
            u.rate = Float(self.prefs.speechRate)
            u.pitchMultiplier = 1.12
            u.volume = Float(max(0.2, self.prefs.volume))
            self.wordIndex = 0
            self.onWord = onWord
            self.onEnd = onEnd
            self.synth.speak(u)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        if onEnd != nil { self.onEnd = onEnd }
    }

    func play(clip url: URL) {
        stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = Float(max(0.3, prefs.volume))
        player?.play()
    }

    func stop() {
        pending?.cancel(); pending = nil
        let end = onEnd
        onWord = nil; onEnd = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        player?.stop()
        end?()
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString r: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.onWord?(self.wordIndex)
            self.wordIndex += 1
        }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            let end = self.onEnd
            self.onWord = nil; self.onEnd = nil
            end?()
        }
    }
}
