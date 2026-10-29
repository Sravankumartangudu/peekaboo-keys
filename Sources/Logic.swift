// Small pure pieces: which key was pressed, the grown-up question, and a seedable dice for demos.
import Foundation

enum Arrow { case left, right, down, up }

enum Press: Equatable {
    case letter(Character)
    case digit(Int)
    case space, enter, delete, tab, escape
    case arrow(Arrow)
    case other
}

enum Keys {
    // Virtual key codes for the ANSI letter and digit keys, used when the keyboard layout
    // doesn't type Latin letters (Telugu, Hindi, …) so every key still means something.
    private static let ansi: [UInt16: Character] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L",
        46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W",
        7: "X", 16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
    ]

    static func classify(keyCode: UInt16, characters: String?) -> Press {
        switch keyCode {
        case 49: return .space
        case 36, 76: return .enter
        case 51, 117: return .delete
        case 48: return .tab
        case 53: return .escape
        case 123: return .arrow(.left)
        case 124: return .arrow(.right)
        case 125: return .arrow(.down)
        case 126: return .arrow(.up)
        default: break
        }
        if let c = characters?.uppercased().first, c.isASCII {
            if c.isLetter { return .letter(c) }
            if let n = c.wholeNumberValue { return .digit(n) }
        }
        if let c = ansi[keyCode] {
            if let n = c.wholeNumberValue { return .digit(n) }
            return .letter(c)
        }
        return .other
    }
}

/// The sum a grown-up answers to finish playing. Always two digits (11–18), so a toddler
/// mashing one number key and Return can't get it right.
struct GateQuestion: Equatable {
    let a: Int, b: Int
    var answer: Int { a + b }
    var text: String { "\(a) + \(b)" }

    static func make<G: RandomNumberGenerator>(using g: inout G) -> GateQuestion {
        let a = Int.random(in: 4...9, using: &g)
        let b = Int.random(in: max(2, 11 - a)...9, using: &g)
        return GateQuestion(a: a, b: b)
    }

    func check(_ typed: String) -> Bool { Int(typed) == answer }
}

/// Random numbers that are truly random when playing, and repeatable for README screenshots.
struct Dice: RandomNumberGenerator {
    private var state: UInt64?
    init(seed: UInt64? = nil) { state = seed }
    mutating func next() -> UInt64 {
        guard var s = state else { var sys = SystemRandomNumberGenerator(); return sys.next() }
        s = s &* 6364136223846793005 &+ 1442695040888963407
        state = s
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
