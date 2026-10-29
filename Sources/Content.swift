// Everything the keys can show: words for each letter, things to count, colours and shapes.
// Pure data plus the sentences the voice says, so tests/main.swift can check it without a screen.
import AppKit

enum Kind { case animal, vehicle, food, thing, nature, body, music }

struct Word {
    let name: String
    let emoji: String
    let kind: Kind
    /// What it says or does ("Woof woof!"). Animals and vehicles mostly have one.
    let sound: String?

    init(_ name: String, _ emoji: String, _ kind: Kind, _ sound: String? = nil) {
        self.name = name; self.emoji = emoji; self.kind = kind; self.sound = sound
    }
}

struct Countable { let emoji: String; let one: String; let many: String }

enum ShapeKind: CaseIterable {
    case circle, square, triangle, star, heart
    var name: String {
        switch self {
        case .circle: return "circle"
        case .square: return "square"
        case .triangle: return "triangle"
        case .star: return "star"
        case .heart: return "heart"
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

enum Palette {
    static let red = NSColor(hex: 0xFF5A5F)
    static let orange = NSColor(hex: 0xFF9F1C)
    static let yellow = NSColor(hex: 0xFFD23F)
    static let green = NSColor(hex: 0x3DCB6C)
    static let blue = NSColor(hex: 0x3AA0FF)
    static let purple = NSColor(hex: 0xA66BFF)
    static let pink = NSColor(hex: 0xFF7EB6)
    /// Deep plum used for words, outlines of faces and the bear's features.
    static let ink = NSColor(hex: 0x3B2E5A)

    static let colours: [(name: String, color: NSColor)] = [
        ("Red", red), ("Orange", orange), ("Yellow", yellow), ("Green", green),
        ("Blue", blue), ("Purple", purple), ("Pink", pink),
    ]
    static var all: [NSColor] { colours.map(\.color) }
}

enum Content {
    static let letters: [Character: [Word]] = [
        "A": [Word("Apple", "🍎", .food), Word("Ant", "🐜", .animal), Word("Airplane", "✈️", .vehicle, "Zoom!"),
              Word("Avocado", "🥑", .food)],
        "B": [Word("Ball", "⚽️", .thing), Word("Bear", "🐻", .animal, "Grr!"), Word("Banana", "🍌", .food),
              Word("Bus", "🚌", .vehicle, "Beep beep!"), Word("Bee", "🐝", .animal, "Buzz buzz!"),
              Word("Balloon", "🎈", .thing), Word("Bird", "🐦", .animal, "Tweet tweet!")],
        "C": [Word("Cat", "🐱", .animal, "Meow!"), Word("Car", "🚗", .vehicle, "Beep beep!"),
              Word("Cow", "🐮", .animal, "Moo!"), Word("Cake", "🎂", .food), Word("Carrot", "🥕", .food)],
        "D": [Word("Dog", "🐶", .animal, "Woof woof!"), Word("Duck", "🦆", .animal, "Quack quack!"),
              Word("Dinosaur", "🦕", .animal, "Roar!"), Word("Drum", "🥁", .music, "Boom boom!")],
        "E": [Word("Elephant", "🐘", .animal), Word("Egg", "🥚", .food), Word("Eyes", "👀", .body)],
        "F": [Word("Fish", "🐟", .animal, "Blub blub!"), Word("Frog", "🐸", .animal, "Ribbit!"),
              Word("Flower", "🌸", .nature), Word("Fire engine", "🚒", .vehicle, "Nee-naw!")],
        "G": [Word("Giraffe", "🦒", .animal), Word("Grapes", "🍇", .food), Word("Goat", "🐐", .animal, "Maa!"),
              Word("Guitar", "🎸", .music)],
        "H": [Word("Horse", "🐴", .animal, "Neigh!"), Word("House", "🏠", .thing),
              Word("Hen", "🐔", .animal, "Cluck cluck!"), Word("Hat", "👒", .thing)],
        "I": [Word("Ice cream", "🍦", .food)],
        "J": [Word("Juice", "🧃", .food), Word("Jacket", "🧥", .thing)],
        "K": [Word("Kite", "🪁", .thing), Word("Key", "🔑", .thing),
              Word("Kangaroo", "🦘", .animal, "Boing boing!"), Word("Koala", "🐨", .animal)],
        "L": [Word("Lion", "🦁", .animal, "Roar!"), Word("Lemon", "🍋", .food), Word("Leaf", "🍃", .nature),
              Word("Ladybug", "🐞", .animal)],
        "M": [Word("Monkey", "🐵", .animal, "Ooh ooh, ah ah!"), Word("Moon", "🌙", .nature), Word("Milk", "🥛", .food),
              Word("Mouse", "🐭", .animal, "Squeak squeak!"), Word("Mango", "🥭", .food)],
        "N": [Word("Nose", "👃", .body), Word("Nest", "🪺", .nature), Word("Noodles", "🍜", .food)],
        "O": [Word("Orange", "🍊", .food), Word("Owl", "🦉", .animal, "Hoot hoot!"), Word("Octopus", "🐙", .animal)],
        "P": [Word("Penguin", "🐧", .animal), Word("Pig", "🐷", .animal, "Oink oink!"), Word("Pizza", "🍕", .food),
              Word("Panda", "🐼", .animal), Word("Parrot", "🦜", .animal, "Hello! Hello!")],
        "Q": [Word("Queen", "👸", .thing)],
        "R": [Word("Rabbit", "🐰", .animal, "Hop hop!"), Word("Rainbow", "🌈", .nature),
              Word("Rocket", "🚀", .vehicle, "Whoosh!"), Word("Rooster", "🐓", .animal, "Cock-a-doodle-doo!")],
        "S": [Word("Sun", "☀️", .nature), Word("Star", "⭐️", .nature), Word("Snake", "🐍", .animal, "Hiss!"),
              Word("Sheep", "🐑", .animal, "Baa!"), Word("Shoe", "👟", .thing), Word("Strawberry", "🍓", .food)],
        "T": [Word("Tiger", "🐯", .animal, "Roar!"), Word("Train", "🚂", .vehicle, "Choo choo!"),
              Word("Tree", "🌳", .nature), Word("Turtle", "🐢", .animal), Word("Truck", "🚚", .vehicle, "Vroom!")],
        "U": [Word("Umbrella", "☂️", .thing), Word("Unicorn", "🦄", .animal)],
        "V": [Word("Van", "🚐", .vehicle, "Beep beep!"), Word("Violin", "🎻", .music), Word("Volcano", "🌋", .nature)],
        "W": [Word("Whale", "🐳", .animal, "Splash!"), Word("Watermelon", "🍉", .food),
              Word("Wolf", "🐺", .animal, "Awoo!"), Word("Worm", "🪱", .animal)],
        // No xylophone emoji exists; the scene plays a xylophone run instead of a single note.
        "X": [Word("Xylophone", "🎶", .music)],
        "Y": [Word("Yo-yo", "🪀", .thing)],
        "Z": [Word("Zebra", "🦓", .animal)],
    ]

    /// Every animal word, for the "Animals" focus.
    static let animals: [Word] = letters.keys.sorted().flatMap { letters[$0]! }.filter { $0.kind == .animal }

    static let countables: [Countable] = [
        Countable(emoji: "🦆", one: "duck", many: "ducks"),
        Countable(emoji: "🍎", one: "apple", many: "apples"),
        Countable(emoji: "⭐️", one: "star", many: "stars"),
        Countable(emoji: "🐞", one: "ladybug", many: "ladybugs"),
        Countable(emoji: "🎈", one: "balloon", many: "balloons"),
        Countable(emoji: "🐟", one: "fish", many: "fish"),
        Countable(emoji: "🍓", one: "strawberry", many: "strawberries"),
        Countable(emoji: "🚗", one: "car", many: "cars"),
        Countable(emoji: "🌸", one: "flower", many: "flowers"),
        Countable(emoji: "🍌", one: "banana", many: "bananas"),
    ]

    static let numberWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]

    // MARK: - What the voice says

    /// How the letter itself is spoken. "A" alone is often read as "uh", and Z depends on the accent.
    static func letterName(_ letter: Character, zed: Bool) -> String {
        switch letter {
        case "A": return "Ay"
        case "Z": return zed ? "Zed" : "Zee"
        default: return String(letter)
        }
    }

    /// "B is for bear! Grr!" or, with the letter turned off, "Bear! Grr!".
    static func letterPhrase(_ letter: Character, _ word: Word, sayLetter: Bool, zed: Bool) -> String {
        let sound = word.sound.map { " \($0)" } ?? ""
        if sayLetter { return "\(letterName(letter, zed: zed)) is for \(word.name.lowercased())!\(sound)" }
        return "\(word.name)!\(sound)"
    }

    /// "Cow! The cow says moo!" — used when the keys only show animals.
    static func animalPhrase(_ word: Word) -> String {
        guard let sound = word.sound else { return "\(word.name)!" }
        return "\(word.name)! The \(word.name.lowercased()) says \(sound.lowercased())"
    }

    /// "One, two, three. Three ducks!" The first `n` words are the counting, one word per thing.
    static func countingPhrase(_ n: Int, _ thing: Countable) -> String {
        if n == 0 { return "Zero! No \(thing.many)." }
        if n == 1 { return "One \(thing.one)!" }
        let counting = numberWords[1...n].map { $0 }.joined(separator: ", ")
        return "\(counting.prefix(1).uppercased() + counting.dropFirst()). \(numberWords[n].capitalized) \(thing.many)!"
    }

    static func shapePhrase(colour: String, _ shape: ShapeKind) -> String { "\(colour) \(shape.name)!" }

    static func greeting(child: String) -> String { child.isEmpty ? "Hello! Let's play!" : "Hi \(child)! Let's play!" }
    static func cheer(child: String) -> String { child.isEmpty ? "Yay! Hooray!" : "Yay, \(child)! Hooray!" }
    static func allDone(child: String) -> String {
        child.isEmpty ? "All done! Great playing. Bye-bye!" : "All done! Great playing, \(child). Bye-bye!"
    }
}
