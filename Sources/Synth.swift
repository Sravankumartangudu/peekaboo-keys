// Tiny sound synth: soft marimba notes, bloops, pops, a drum and a whoosh — all generated, no sound files.
// Notes come from a pentatonic scale, so any mash of keys still sounds like music, and the
// same key always plays the same note (a toddler can find "their" sound again).
import AVFoundation
import os

enum Tone { case mallet, bloop, pop, drum, whoosh, twinkle }

final class Synth {
    static let shared = Synth()

    static let scale: [Double] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25,
                                  783.99, 880.00, 1046.50, 1174.66]

    private struct Voice {
        var tone: Tone
        var freq: Double
        var amp: Double
        var delay: Int          // samples to wait before starting
        var t: Double = 0
        var phase: Double = 0
        var phase2: Double = 0
        var phase3: Double = 0
        var lp: Double = 0      // low-pass state for the whoosh
        var noise: UInt32 = 22222
        var length: Double {
            switch tone {
            case .mallet: return 1.6
            case .twinkle: return 1.0
            case .bloop: return 0.35
            case .pop: return 0.15
            case .drum: return 0.45
            case .whoosh: return 0.7
            }
        }
    }

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private let pending = OSAllocatedUnfairLock(initialState: [Voice]())
    private var voices: [Voice] = []          // touched only on the audio thread
    private var sampleRate: Double = 44100
    private let master = OSAllocatedUnfairLock(initialState: 0.5)

    var volume: Double {
        get { master.withLock { $0 } }
        set { master.withLock { $0 = max(0, min(1, newValue)) } }
    }

    func start() {
        if node == nil {
            let out = engine.outputNode.inputFormat(forBus: 0)
            sampleRate = out.sampleRate > 0 ? out.sampleRate : 44100
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let n = AVAudioSourceNode(format: format) { [unowned self] _, _, frames, abl in
                self.render(frames: Int(frames), abl: abl)
                return noErr
            }
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: format)
            node = n
        }
        if !engine.isRunning { try? engine.start() }
    }

    func stop() {
        pending.withLock { $0.removeAll() }
        engine.pause()
    }

    func play(_ tone: Tone, freq: Double = 440, amp: Double = 0.5, after: Double = 0) {
        let v = Voice(tone: tone, freq: freq, amp: amp, delay: Int(after * sampleRate))
        pending.withLock { $0.append(v) }
    }

    func note(_ index: Int, tone: Tone = .mallet, amp: Double = 0.5, after: Double = 0) {
        let i = ((index % Synth.scale.count) + Synth.scale.count) % Synth.scale.count
        play(tone, freq: Synth.scale[i], amp: amp, after: after)
    }

    /// Notes going up, one after another (rainbows, all-done, the xylophone).
    func run(_ indices: [Int], gap: Double = 0.09, tone: Tone = .mallet, amp: Double = 0.4) {
        for (k, i) in indices.enumerated() { note(i, tone: tone, amp: amp, after: Double(k) * gap) }
    }

    private func render(frames: Int, abl: UnsafeMutablePointer<AudioBufferList>) {
        let incoming = pending.withLock { p -> [Voice] in let v = p; p.removeAll(); return v }
        voices.append(contentsOf: incoming)
        if voices.count > 24 { voices.removeFirst(voices.count - 24) }
        let gain = master.withLock { $0 } * 0.55
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return }
        let dt = 1 / sampleRate
        let twoPi = 2 * Double.pi
        for f in 0..<frames {
            var sum = 0.0
            for i in voices.indices {
                if voices[i].delay > 0 { voices[i].delay -= 1; continue }
                var v = voices[i]
                let t = v.t
                let attack = min(1, t / 0.004)
                var s = 0.0
                switch v.tone {
                case .mallet, .twinkle:
                    let f0 = v.tone == .twinkle ? v.freq * 2 : v.freq
                    v.phase += twoPi * f0 * dt
                    v.phase2 += twoPi * f0 * 3.93 * dt
                    v.phase3 += twoPi * f0 * 9.2 * dt
                    let decay = v.tone == .twinkle ? 6.0 : 3.6
                    s = sin(v.phase) * exp(-t * decay) + 0.28 * sin(v.phase2) * exp(-t * 14)
                        + 0.07 * sin(v.phase3) * exp(-t * 35)
                case .bloop:
                    let f0 = v.freq * pow(2, min(t / 0.18, 1))   // slides up an octave
                    v.phase += twoPi * f0 * dt
                    s = sin(v.phase) * exp(-t * 9)
                case .pop:
                    let f0 = 300 + 1100 * exp(-t * 40)
                    v.phase += twoPi * f0 * dt
                    s = sin(v.phase) * exp(-t * 30)
                case .drum:
                    let f0 = 65 + 120 * exp(-t * 14)
                    v.phase += twoPi * f0 * dt
                    s = 1.3 * sin(v.phase) * exp(-t * 8)
                case .whoosh:
                    v.noise = v.noise &* 1664525 &+ 1013904223
                    let white = Double(v.noise >> 8) / Double(1 << 24) * 2 - 1
                    let sweep = sin(Double.pi * min(t / v.length, 1))
                    let k = 0.02 + 0.25 * sweep
                    v.lp += k * (white - v.lp)
                    s = v.lp * 2.2 * sweep
                }
                sum += s * v.amp * attack
                v.t = t + dt
                voices[i] = v
            }
            out[f] = Float(tanh(sum * gain))
        }
        voices.removeAll { $0.delay <= 0 && $0.t > $0.length }
        for b in buffers.dropFirst() { b.mData?.copyMemory(from: out, byteCount: Int(b.mDataByteSize)) }
    }
}
