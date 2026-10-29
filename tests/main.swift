// Checks the pure parts: every key means something, the words, the counting sentence and the grown-up sum.
//   swiftc -o /tmp/peekaboo-tests tests/main.swift Sources/Content.swift Sources/Logic.swift && /tmp/peekaboo-tests
import Foundation

var fails = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    if !ok { fails += 1 }
    print(ok ? "✓" : "✗", label, ok ? "" : detail)
}

// Every letter has at least one word with a picture, and the word starts with that letter.
for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
    let words = Content.letters[c] ?? []
    check("\(c) has words", !words.isEmpty)
    for w in words {
        check("\(c): \(w.name) starts with \(c)", w.name.uppercased().first == c, w.name)
        check("\(c): \(w.name) has a picture", !w.emoji.isEmpty)
    }
}
check("there are animals for the Animals focus", Content.animals.count >= 10, "\(Content.animals.count)")
check("most animals have a sound", Content.animals.filter { $0.sound != nil }.count * 2 >= Content.animals.count)
check("ten things to count", Content.countables.count == 10)

// Keys: letters, digits (top row and keypad) and the special keys, on any keyboard layout.
check("a → letter A", Keys.classify(keyCode: 0, characters: "a") == .letter("A"))
check("7 → digit 7", Keys.classify(keyCode: 26, characters: "7") == .digit(7))
check("keypad 3 → digit 3", Keys.classify(keyCode: 85, characters: "3") == .digit(3))
check("shift-1 key still counts 1", Keys.classify(keyCode: 18, characters: "!") == .digit(1))
check("Telugu layout K key → letter K", Keys.classify(keyCode: 40, characters: "క") == .letter("K"))
check("space", Keys.classify(keyCode: 49, characters: " ") == .space)
check("return and enter", Keys.classify(keyCode: 36, characters: "\r") == .enter && Keys.classify(keyCode: 76, characters: nil) == .enter)
check("delete", Keys.classify(keyCode: 51, characters: nil) == .delete)
check("tab", Keys.classify(keyCode: 48, characters: "\t") == .tab)
check("esc", Keys.classify(keyCode: 53, characters: nil) == .escape)
check("arrows", Keys.classify(keyCode: 126, characters: nil) == .arrow(.up) && Keys.classify(keyCode: 123, characters: nil) == .arrow(.left))
check("F5 → shape", Keys.classify(keyCode: 96, characters: nil) == .other)
check("comma → shape", Keys.classify(keyCode: 43, characters: ",") == .other)

// The voice.
let ball = Word("Ball", "⚽️", .thing)
let cow = Word("Cow", "🐮", .animal, "Moo!")
check("letter phrase", Content.letterPhrase("B", ball, sayLetter: true, zed: false) == "B is for ball!")
check("letter phrase with sound", Content.letterPhrase("C", cow, sayLetter: true, zed: false) == "C is for cow! Moo!")
check("word only", Content.letterPhrase("C", cow, sayLetter: false, zed: false) == "Cow! Moo!")
check("A is said Ay", Content.letterName("A", zed: false) == "Ay")
check("zed or zee", Content.letterName("Z", zed: true) == "Zed" && Content.letterName("Z", zed: false) == "Zee")
check("animal phrase", Content.animalPhrase(cow) == "Cow! The cow says moo!")
let duck = Content.countables[0]
check("count 3", Content.countingPhrase(3, duck) == "One, two, three. Three ducks!", Content.countingPhrase(3, duck))
check("count 1", Content.countingPhrase(1, duck) == "One duck!")
check("count 0", Content.countingPhrase(0, duck) == "Zero! No ducks.")
// The scene pops one thing per spoken word, so the first n words must be the counting.
for n in 1...9 {
    let words = Content.countingPhrase(n, duck).split(separator: " ").prefix(n)
    let said = words.map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
    check("count \(n) words line up", said == Array(Content.numberWords[1...n]), said.joined(separator: " "))
}
check("greeting by name", Content.greeting(child: "Aarav") == "Hi Aarav! Let's play!")
check("greeting without name", Content.greeting(child: "") == "Hello! Let's play!")

// The grown-up gate: always a two-digit answer, so mashing one number and Return can't finish.
var dice = Dice(seed: 1)
var answers = Set<Int>()
for _ in 0..<2000 {
    let q = GateQuestion.make(using: &dice)
    answers.insert(q.answer)
    if q.answer < 11 || q.answer > 18 || q.a < 2 || q.b < 2 || q.a > 9 || q.b > 9 {
        check("gate \(q.text)", false, "= \(q.answer)")
    }
}
check("gate answers are 11…18", answers.min()! >= 11 && answers.max()! <= 18, "\(answers.sorted())")
check("gate uses many answers", answers.count >= 6, "\(answers.sorted())")
let q = GateQuestion(a: 7, b: 6)
check("gate right", q.check("13"))
check("gate wrong", !q.check("1") && !q.check("") && !q.check("31"))

// Seeded dice repeat (README screenshots), unseeded dice don't.
var d1 = Dice(seed: 7), d2 = Dice(seed: 7)
check("seeded dice repeat", (0..<5).map { _ in d1.next() } == (0..<5).map { _ in d2.next() })

print(fails == 0 ? "\nAll good." : "\n\(fails) failed.")
exit(fails == 0 ? 0 : 1)
