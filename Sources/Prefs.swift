// Settings, saved in UserDefaults (com.stangudu.peekabookeys). Shared by the menu and the Settings window.
import AppKit
import Combine

enum Focus: String, CaseIterable, Identifiable {
    case everything, animals, shapes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .everything: return "Everything"
        case .animals: return "Animals"
        case .shapes: return "Colours & shapes"
        }
    }
    var blurb: String {
        switch self {
        case .everything: return "Letters show a picture word, numbers count, other keys make shapes."
        case .animals: return "Every key brings an animal friend, and many say their sound: “Cow! The cow says moo!”"
        case .shapes: return "Every key makes a coloured shape friend: “Blue star!”"
        }
    }
    var emoji: String {
        switch self {
        case .everything: return "🔤"
        case .animals: return "🐮"
        case .shapes: return "🔷"
        }
    }
}

enum SceneLook: String, CaseIterable, Identifiable {
    case appearance, day, night, clock
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appearance: return "Follow appearance"
        case .day: return "Sunny day"
        case .night: return "Starry night"
        case .clock: return "By the clock"
        }
    }
}

final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var focus: Focus { didSet { d.set(focus.rawValue, forKey: "focus") } }
    @Published var sayLetter: Bool { didSet { d.set(sayLetter, forKey: "sayLetter") } }
    @Published var voiceOn: Bool { didSet { d.set(voiceOn, forKey: "voiceOn") } }
    @Published var voiceId: String { didSet { d.set(voiceId, forKey: "voiceId") } }
    /// AVSpeechUtterance rate: 0.3 is slow and clear, 0.5 is normal speech.
    @Published var speechRate: Double { didSet { d.set(speechRate, forKey: "speechRate") } }
    @Published var music: Bool { didSet { d.set(music, forKey: "music") } }
    @Published var volume: Double { didSet { d.set(volume, forKey: "volume") } }
    @Published var childName: String { didSet { d.set(childName, forKey: "childName") } }
    /// Minutes of play before the gentle "All done" ending. 0 = no limit.
    @Published var timeLimit: Int { didSet { d.set(timeLimit, forKey: "timeLimit") } }
    @Published var calm: Bool { didSet { d.set(calm, forKey: "calm") } }
    @Published var look: SceneLook { didSet { d.set(look.rawValue, forKey: "look") } }
    @Published var showFamily: Bool { didSet { d.set(showFamily, forKey: "showFamily") } }
    @Published var shortcut: String { didSet { d.set(shortcut, forKey: "shortcut") } }
    @Published var strongLock: Bool { didSet { d.set(strongLock, forKey: "strongLock") } }
    @Published var openStartsPlay: Bool { didSet { d.set(openStartsPlay, forKey: "openStartsPlay") } }
    @Published var welcomed: Bool { didSet { d.set(welcomed, forKey: "welcomed") } }
    /// system | light | dark. Missing means system, like every other app in the fleet.
    @Published var appearance: String { didSet { d.set(appearance, forKey: "appearance"); applyAppearance() } }

    private init() {
        let d = UserDefaults.standard
        func bool(_ k: String, _ def: Bool) -> Bool { d.object(forKey: k) == nil ? def : d.bool(forKey: k) }
        focus = Focus(rawValue: d.string(forKey: "focus") ?? "") ?? .everything
        sayLetter = bool("sayLetter", true)
        voiceOn = bool("voiceOn", true)
        voiceId = d.string(forKey: "voiceId") ?? ""
        speechRate = d.object(forKey: "speechRate") == nil ? 0.4 : d.double(forKey: "speechRate")
        music = bool("music", true)
        volume = d.object(forKey: "volume") == nil ? 0.7 : d.double(forKey: "volume")
        childName = d.string(forKey: "childName") ?? ""
        timeLimit = d.object(forKey: "timeLimit") == nil ? 15 : d.integer(forKey: "timeLimit")
        calm = bool("calm", false)
        look = SceneLook(rawValue: d.string(forKey: "look") ?? "") ?? .appearance
        showFamily = bool("showFamily", true)
        shortcut = d.string(forKey: "shortcut") ?? Shortcut.presets[0].id
        strongLock = bool("strongLock", true)
        openStartsPlay = bool("openStartsPlay", true)
        welcomed = bool("welcomed", false)
        appearance = d.string(forKey: "appearance") ?? "system"
    }

    func applyAppearance() {
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    var child: String { childName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Whether this play session uses the starry-night scene.
    var nightNow: Bool {
        switch look {
        case .day: return false
        case .night: return true
        case .clock:
            let h = Calendar.current.component(.hour, from: Date())
            return h >= 19 || h < 6
        case .appearance:
            return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
    }

    var currentShortcut: Shortcut { Shortcut.presets.first { $0.id == shortcut } ?? Shortcut.presets[0] }
}
