// The play screen: a sunny meadow (or a starry night) where every key does something friendly.
//   letters  → a big letter, a picture word and "B is for bear! Grr!"
//   numbers  → the number, then that many things popping in as the voice counts them
//   space    → bubbles to pop        return → a rainbow and a cheer      delete → whoosh, all gone
//   tab      → peekaboo (with family photos, if added)   arrows → Boo hops, jumps and squishes
//   anything else → a coloured shape friend: "Blue star!"
// Palm-smashes turn into one confetti burst instead of a pile of things. Clicks make fireworks,
// dragging paints, and the pointer is a twinkling star that pops bubbles it touches.
import SpriteKit

final class PlayScene: SKScene {
    let primary: Bool
    /// README screenshots: no voice, no sounds, no names or family photos.
    var demo = false
    private(set) var finished = false

    private var dice: Dice
    private let prefs = Prefs.shared
    private let night: Bool
    private var u: CGFloat = 1
    private var built = false
    private var echoing = false

    private let bear = Bear()
    private let cursor = SKNode()
    private var items: [SKNode] = []
    private var bubbles: [SKNode] = []
    private var paint: [SKNode] = []
    private weak var rainbowNode: SKNode?
    private var hint: SKSpriteNode?
    private let ring = SKShapeNode()

    private var counter = 0
    private var wordTurn: [Character: Int] = [:]
    private var animalTurn = 0
    private var shapeTurn = 0
    private var countTurn = 0
    private var familyTurn = 0
    private var lastPress: CFTimeInterval = 0
    private var lastSmash: CFTimeInterval = 0
    private var lastActivity = CACurrentMediaTime()
    private var lastNudge: CFTimeInterval = 0
    private var lastBubbleWord: CFTimeInterval = 0
    private var lastMouse = CGPoint(x: -9999, y: -9999)
    private var lastTrail: CFTimeInterval = 0
    private var lastPaint = CGPoint(x: -9999, y: -9999)
    private var paintHue: CGFloat = 0

    init(size: CGSize, primary: Bool, dice: Dice, night: Bool? = nil) {
        self.primary = primary
        self.dice = dice
        self.night = night ?? Prefs.shared.nightNow
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = self.night ? NSColor(hex: 0x141A46) : NSColor(hex: 0x6EC6FF)
        animalTurn = Int.random(in: 0..<max(1, Content.animals.count), using: &self.dice)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        u = max(0.6, min(size.width, size.height) / 900)
        addChild(makeBackdrop(night: night))
        if primary {
            bear.base = 0.8 * u
            let x = size.width * 0.15
            bear.position = CGPoint(x: x, y: ground(x) - 6 * u)
            bear.zPosition = 20
            addChild(bear)
            addHint()
        }
        buildCursor()
        if !night {
            run(.repeatForever(.sequence([.wait(forDuration: 22, withRange: 16),
                                          .run { [weak self] in self?.butterfly() }])), withKey: "butterflies")
        }
    }

    // MARK: - Public

    /// Boo waves hello when play starts.
    func start() {
        guard primary else { return }
        bear.wave()
        let text = child.isEmpty ? "Hi!" : "Hi, \(child)!"
        let hi = Art.label(text, size: 120 * u, fill: Palette.pink, width: 10 * u)
        let n = SKNode(); n.addChild(hi)
        show(n, say: nil, life: 3.2)
        speak(Content.greeting(child: child))
        sfx { Synth.shared.run([0, 2, 4, 7], gap: 0.1, tone: .mallet, amp: 0.35) }
    }

    func press(_ p: Press) {
        lastActivity = CACurrentMediaTime()
        if finished { twinkle(); return }
        let now = CACurrentMediaTime()
        defer { lastPress = now }
        if now - lastPress < 0.06 { smash(now); return }

        switch p {
        case .space: blowBubbles()
        case .enter: hooray()
        case .delete: whoosh()
        case .tab: peekaboo()
        case .escape: break
        case .arrow(let a): moveBear(a)
        case .letter(let c):
            switch prefs.focus {
            case .everything: letter(c)
            case .animals: animal()
            case .shapes: shape()
            }
        case .digit(let d):
            switch prefs.focus {
            case .everything: count(d)
            case .animals: animal()
            case .shapes: shape()
            }
        case .other:
            if prefs.focus == .animals { animal() } else { shape() }
        }
    }

    /// Shift, Control, Option, Command, Fn or Caps Lock: Boo claps along.
    func modifier() {
        lastActivity = CACurrentMediaTime()
        guard !finished else { return }
        bear.clap()
        sfx { Synth.shared.play(.drum, amp: 0.6) }
    }

    /// The other screens join in with pictures only (the main screen does the talking).
    func echo(_ p: Press) {
        echoing = true
        defer { echoing = false }
        if finished { twinkle(); return }
        switch p {
        case .space: blowBubbles()
        case .enter: hooray()
        case .delete: whoosh()
        case .escape: break
        default:
            burst(at: CGPoint(x: rnd(size.width * 0.15...size.width * 0.85), y: rnd(size.height * 0.35...size.height * 0.85)),
                  texture: Art.starTexture, colors: Palette.all, count: 30, speed: 300 * u, size: 22 * u, gravity: -300 * u)
        }
    }

    /// The "hold esc" ring; nil hides it.
    func escProgress(_ f: CGFloat?) {
        guard primary else { return }
        guard let f else { ring.path = nil; hint?.alpha = 0.55; return }
        hint?.alpha = 1
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: 11 * u, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi * min(1, max(0.001, f)), clockwise: true)
        ring.path = p
    }

    /// Play time is up: night falls, Boo goes to sleep and the voice says goodbye.
    func allDone() {
        guard !finished else { return }
        finished = true
        removeAction(forKey: "butterflies")
        for n in items { retire(n) }
        for b in bubbles { popBubble(b, sound: false) }
        if !night {
            let nb = makeBackdrop(night: true)
            nb.zPosition = 5
            nb.alpha = 0
            addChild(nb)
            nb.run(.fadeIn(withDuration: 2.5))
        }
        guard primary else { return }
        bear.sleep()
        speak(Content.allDone(child: child))
        sfx { Synth.shared.run([9, 7, 4, 2, 0], gap: 0.4, tone: .mallet, amp: 0.28) }
    }

    // MARK: - Keys

    private func letter(_ c: Character) {
        let list = Content.letters[c] ?? [Word(String(c), "🔤", .thing)]
        let turn = wordTurn[c, default: 0]
        wordTurn[c] = turn + 1
        let word = list[turn % list.count]
        let n = letterItem(c, word)
        let text = Content.letterPhrase(c, word, sayLetter: prefs.sayLetter, zed: Speech.shared.zed)
        show(n, say: text)
        let idx = Int((c.asciiValue ?? 65) - 65)
        if word.kind == .music && c == "X" {
            sfx { Synth.shared.run([0, 1, 2, 3, 4, 5, 6, 7], gap: 0.08, tone: .mallet, amp: 0.35) }
        } else {
            sfx { Synth.shared.note(idx, tone: .mallet, amp: 0.45) }
        }
        let wordAt = prefs.sayLetter ? 3 : 0
        speak(text) { [weak self, weak n] i in
            guard let self, let n else { return }
            if i == 0, self.prefs.sayLetter, let l = n.childNode(withName: "letter") { self.pulse(l) }
            if i == wordAt, let s = n.childNode(withName: "sticker") { self.wiggle(s) }
        }
    }

    private func animal() {
        let list = Content.animals
        guard !list.isEmpty else { return }
        let word = list[animalTurn % list.count]
        animalTurn += 1
        let n = animalItem(word)
        let text = Content.animalPhrase(word)
        show(n, say: text)
        sfx { Synth.shared.note(self.animalTurn, tone: .bloop, amp: 0.4) }
        speak(text) { [weak self, weak n] i in
            guard let self, let n, i == 0 || i == 4, let s = n.childNode(withName: "sticker") else { return }
            self.wiggle(s)
        }
    }

    private func shape() {
        let kinds = ShapeKind.allCases
        let kind = kinds[shapeTurn % kinds.count]
        let colour = Palette.colours[(shapeTurn * 3 + shapeTurn / kinds.count) % Palette.colours.count]
        shapeTurn += 1
        let n = shapeItem(kind, colour)
        let text = Content.shapePhrase(colour: colour.name, kind)
        show(n, say: text)
        sfx { Synth.shared.note(self.shapeTurn * 2, tone: .bloop, amp: 0.4) }
        speak(text) { [weak self, weak n] i in
            guard let self, let n, i == 0, let s = n.childNode(withName: "sticker") else { return }
            self.wiggle(s)
        }
    }

    private func count(_ d: Int) {
        let thing = Content.countables[countTurn % Content.countables.count]
        countTurn += 1
        let (n, dots) = digitItem(d, thing)
        let text = Content.countingPhrase(d, thing)
        show(n, say: text)
        for e in dots { e.setScale(0) }
        sfx { Synth.shared.note(d, tone: .twinkle, amp: 0.35) }
        speak(text) { [weak self, weak n] i in
            guard let self, n?.parent != nil, i < dots.count else { return }
            self.popCount(dots[i], i)
        }
        // Without the voice (or if it's slow), the things still pop in one by one.
        var steps: [SKAction] = [.wait(forDuration: 1.2)]
        for (i, e) in dots.enumerated() {
            steps.append(.run { [weak self, weak e] in if let self, let e { self.popCount(e, i) } })
            steps.append(.wait(forDuration: 0.45))
        }
        n.run(.sequence(steps), withKey: "count")
    }

    private func smash(_ now: CFTimeInterval) {
        guard now - lastSmash > 0.35 else { return }
        lastSmash = now
        let p = CGPoint(x: rnd(size.width * 0.2...size.width * 0.8), y: rnd(size.height * 0.4...size.height * 0.8))
        burst(at: p, texture: Art.confettiTexture, colors: Palette.all, count: 60, speed: 420 * u, size: 16 * u,
              gravity: -500 * u, spin: true)
        if primary { bear.giggle() }
        sfx { for (k, i) in [0, 4, 7].enumerated() { Synth.shared.note(i, tone: .mallet, amp: 0.25, after: Double(k) * 0.02) } }
    }

    private func moveBear(_ a: Arrow) {
        guard primary else { return }
        switch a {
        case .left, .right:
            let dx = (a == .left ? -1 : 1) * size.width * 0.12
            let x = min(max(bear.position.x + dx, size.width * 0.08), size.width * 0.92)
            bear.hop(to: CGPoint(x: x, y: ground(x) - 6 * u))
            speak("Hop!")
            sfx { Synth.shared.play(.bloop, freq: 330, amp: 0.4) }
        case .up:
            bear.jump()
            speak("Jump!")
            sfx { Synth.shared.play(.bloop, freq: 520, amp: 0.45) }
        case .down:
            bear.squish()
            speak("Squish!")
            sfx { Synth.shared.play(.drum, amp: 0.5) }
        }
    }

    private func hooray() {
        rainbow()
        if primary { bear.cheer() }
        speak(Content.cheer(child: child))
        for x in [size.width * 0.1, size.width * 0.9] {
            burst(at: CGPoint(x: x, y: size.height * 0.95), texture: Art.confettiTexture, colors: Palette.all, count: 40,
                  speed: 260 * u, size: 15 * u, gravity: -260 * u, spin: true, life: 2.2)
        }
    }

    private func peekaboo() {
        guard primary, !bear.busy else { return }
        let family = prefs.showFamily && !demo ? FamilyStore.shared.members : []
        let member = family.isEmpty ? nil : family[familyTurn % family.count]
        familyTurn += 1
        speak(member == nil ? "Where's Boo?" : "Who's that?")
        sfx { Synth.shared.run([7, 4, 2], gap: 0.22, tone: .bloop, amp: 0.25) }
        bear.peekaboo { [weak self] in
            guard let self else { return }
            self.sfx { Synth.shared.run([0, 4, 7, 9], gap: 0.06, tone: .twinkle, amp: 0.35) }
            let store = FamilyStore.shared
            if let m = member, let photo = Art.photo(store.url(m.photo), diameter: 300 * self.u, ring: self.pick(Palette.all)) {
                let n = SKNode()
                n.addChild(photo)
                let name = Art.label(m.name, size: 58 * self.u, fill: Palette.ink, width: 7 * self.u)
                name.position = CGPoint(x: 0, y: -photo.size.height / 2 - name.size.height / 2 + 14 * self.u)
                n.addChild(name)
                self.show(n, say: m.phrase, life: 6)
                if let v = m.voice {
                    n.userData?["clip"] = v
                    if !self.demo { Speech.shared.play(clip: store.url(v)) }
                } else {
                    self.speak(m.phrase)
                }
                let c = n.calculateAccumulatedFrame()
                self.burst(at: CGPoint(x: c.midX, y: c.midY), texture: Art.heartTexture, colors: [Palette.pink, Palette.red],
                           count: 24, speed: 260 * self.u, size: 26 * self.u, gravity: -120 * self.u)
            } else {
                self.speak("Peekaboo! I see you!")
                let head = CGPoint(x: self.bear.position.x, y: self.bear.position.y + 220 * self.bear.base)
                self.burst(at: head, texture: Art.starTexture, colors: Palette.all, count: 36, speed: 320 * self.u,
                           size: 20 * self.u, gravity: -240 * self.u)
            }
        }
    }

    private func blowBubbles() {
        let now = CACurrentMediaTime()
        if now - lastBubbleWord > 4 { lastBubbleWord = now; speak("Bubbles! Pop pop pop!") }
        sfx { Synth.shared.play(.bloop, freq: Synth.scale[Int.random(in: 0...4)], amp: 0.4) }
        let origin = primary
            ? CGPoint(x: bear.position.x + 70 * u, y: bear.position.y + 200 * bear.base)
            : CGPoint(x: rnd(size.width * 0.2...size.width * 0.8), y: size.height * 0.2)
        for k in 0..<(prefs.calm ? 3 : 6) {
            guard bubbles.count < 40 else { break }
            let d = rnd(56...130) * u
            let b = Art.bubble(d)
            b.position = CGPoint(x: origin.x + rnd(-30...30) * u, y: origin.y)
            b.zPosition = 40
            b.setScale(0.2)
            b.alpha = 0
            addChild(b)
            bubbles.append(b)
            let rise = size.height - b.position.y + d
            let t = Double(rise / (rnd(70...140) * u))
            let drift = rnd(-0.1...0.35) * size.width
            let delay = Double(k) * 0.14
            b.run(.sequence([.wait(forDuration: delay), .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.4)])]))
            let wob = SKAction.sequence([.scaleX(to: 1.07, duration: 0.5), .scaleX(to: 0.95, duration: 0.5)])
            b.run(.sequence([.wait(forDuration: delay + 0.4), .repeatForever(wob)]))
            b.run(.sequence([.wait(forDuration: delay), .moveBy(x: drift, y: rise, duration: t),
                             .run { [weak self, weak b] in if let self, let b { self.popBubble(b, sound: false) } }]))
        }
    }

    private func whoosh() {
        speak("Whoosh! Bye-bye!")
        sfx { Synth.shared.play(.whoosh, amp: 0.7) }
        for i in 0..<(prefs.calm ? 4 : 9) {
            let len = rnd(140...320) * u
            let s = SKShapeNode(rectOf: CGSize(width: len, height: 7 * u), cornerRadius: 3.5 * u)
            s.fillColor = .white
            s.strokeColor = .clear
            s.alpha = 0.85
            s.position = CGPoint(x: -len, y: rnd(size.height * 0.25...size.height * 0.92))
            s.zPosition = 31
            addChild(s)
            s.run(.sequence([.wait(forDuration: Double(i) * 0.04),
                             .group([.moveBy(x: size.width + len * 2, y: 0, duration: 0.55),
                                     .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.25)])]),
                             .removeFromParent()]))
        }
        for n in items + bubbles {
            n.removeAllActions()
            let t = 0.6 + Double(rnd(0...0.25))
            n.run(.sequence([.group([.moveBy(x: size.width * 0.9, y: rnd(40...200) * u, duration: t),
                                     .rotate(byAngle: -.pi * 1.5, duration: t),
                                     .scale(to: 0.3, duration: t), .fadeOut(withDuration: t)]),
                             .removeFromParent()]))
        }
        items.removeAll()
        bubbles.removeAll()
        for p in paint { p.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()])) }
        paint.removeAll()
        if primary { bear.squish() }
    }

    // MARK: - Pictures

    private func letterColour(_ c: Character) -> NSColor { Palette.all[Int(c.asciiValue ?? 65) % Palette.all.count] }

    private func letterItem(_ c: Character, _ w: Word) -> SKNode {
        let colour = letterColour(c)
        let n = SKNode()
        let bigSize = 210 * u, smallSize = 104 * u
        let big = Art.label(String(c), size: bigSize, fill: colour, width: 12 * u)
        big.name = "letter"
        let small = Art.label(String(c).lowercased(), size: smallSize, fill: colour.mixed(with: .white, 0.2), width: 8 * u)
        let d = 150 * u
        let st = stickerNode(w.emoji, d: d, ring: colour)
        let stW = d * 1.24
        let gap = 16 * u
        let total = big.size.width + small.size.width - 22 * u + gap + stW
        var x = -total / 2
        big.position = CGPoint(x: x + big.size.width / 2, y: 18 * u)
        x += big.size.width - 22 * u
        // Line both letters up on the same baseline (their outlines are padded differently).
        let padDiff = (12 * u + bigSize * 0.12) - (8 * u + smallSize * 0.12)
        small.position = CGPoint(x: x + small.size.width / 2,
                                 y: big.position.y - big.size.height / 2 + small.size.height / 2 + padDiff)
        x += small.size.width + gap
        st.position = CGPoint(x: x + stW / 2, y: 34 * u)
        let name = Art.label(w.name, size: 50 * u, fill: Palette.ink, width: 7 * u)
        name.position = CGPoint(x: st.position.x, y: st.position.y - stW / 2 - name.size.height / 2 + 16 * u)
        n.addChild(big); n.addChild(small); n.addChild(st); n.addChild(name)
        if let s = w.sound { n.addChild(soundTag(s, at: CGPoint(x: st.position.x + stW * 0.42, y: st.position.y + stW * 0.46))) }
        return n
    }

    private func animalItem(_ w: Word) -> SKNode {
        let n = SKNode()
        let d = 200 * u
        let st = stickerNode(w.emoji, d: d, ring: Palette.all[w.name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Palette.all.count])
        n.addChild(st)
        let name = Art.label(w.name, size: 60 * u, fill: Palette.ink, width: 8 * u)
        name.position = CGPoint(x: 0, y: -d * 0.62 - name.size.height / 2 + 14 * u)
        n.addChild(name)
        if let s = w.sound { n.addChild(soundTag(s, at: CGPoint(x: d * 0.52, y: d * 0.55))) }
        return n
    }

    private func shapeItem(_ kind: ShapeKind, _ colour: (name: String, color: NSColor)) -> SKNode {
        let n = SKNode()
        let s = 180 * u
        let path = Art.shapePath(kind, size: s)
        let shadow = SKShapeNode(path: path)
        shadow.fillColor = NSColor.black.withAlphaComponent(0.13)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -9 * u)
        let friend = SKNode()
        friend.name = "sticker"
        let body = SKShapeNode(path: path)
        body.fillColor = colour.color
        body.strokeColor = .white
        body.lineWidth = 9 * u
        body.lineJoin = .round
        let shine = SKShapeNode(path: path)
        shine.fillColor = NSColor.white.withAlphaComponent(0.2)
        shine.strokeColor = .clear
        shine.setScale(0.55)
        shine.position = CGPoint(x: -s * 0.07, y: s * 0.1)
        let f = face(kind == .star ? 0.72 * u : u)
        f.position = CGPoint(x: 0, y: kind == .triangle ? -s * 0.14 : (kind == .heart ? s * 0.04 : 0))
        friend.addChild(body); friend.addChild(shine); friend.addChild(f)
        let label = Art.label("\(colour.name) \(kind.name)", size: 46 * u, fill: colour.color, width: 6 * u)
        label.position = CGPoint(x: 0, y: -s / 2 - label.size.height / 2 + 4 * u)
        n.addChild(shadow); n.addChild(friend); n.addChild(label)
        return n
    }

    private func digitItem(_ d: Int, _ thing: Countable) -> (SKNode, [SKNode]) {
        let n = SKNode()
        let big = Art.label("\(d)", size: 200 * u, fill: Palette.all[(d + 3) % Palette.all.count], width: 12 * u)
        big.name = "letter"
        let rows = d > 5 ? [Int((Double(d) / 2).rounded(.up)), d / 2] : [d]
        big.position = CGPoint(x: 0, y: 0)
        n.addChild(big)
        var dots: [SKNode] = []
        let e0 = 72 * u, step = 84 * u
        var y = big.position.y - big.size.height / 2 - e0 * 0.42
        for r in rows where r > 0 {
            for j in 0..<r {
                let e = Art.emoji(thing.emoji, size: e0)
                e.position = CGPoint(x: (CGFloat(j) - CGFloat(r - 1) / 2) * step, y: y)
                n.addChild(e)
                dots.append(e)
            }
            y -= step
        }
        if d == 0 {
            let none = Art.label("no \(thing.many)", size: 44 * u, fill: Palette.ink, width: 6 * u)
            none.position = CGPoint(x: 0, y: y + 8 * u)
            n.addChild(none)
        }
        return (n, dots)
    }

    private func stickerNode(_ emoji: String, d: CGFloat, ring: NSColor) -> SKNode {
        let n = SKNode()
        n.name = "sticker"
        n.addChild(Art.sticker(diameter: d, ring: ring))
        let e = Art.emoji(emoji, size: d * 0.64)
        e.position = CGPoint(x: 0, y: d * 0.02)
        n.addChild(e)
        return n
    }

    private func soundTag(_ s: String, at p: CGPoint) -> SKNode {
        let tag = Art.label(s, size: 38 * u, fill: Palette.orange, width: 6 * u)
        tag.position = CGPoint(x: p.x + tag.size.width * 0.3, y: p.y)
        tag.zRotation = 0.12
        tag.run(.repeatForever(.sequence([.rotate(toAngle: -0.05, duration: 0.6), .rotate(toAngle: 0.12, duration: 0.6)])))
        return tag
    }

    /// Two eyes with a sparkle, rosy cheeks and a smile (or closed, sleepy eyes).
    private func face(_ s: CGFloat, sleepy: Bool = false) -> SKNode {
        let f = SKNode()
        for sx: CGFloat in [-1, 1] {
            let cheek = SKShapeNode(ellipseOf: CGSize(width: 18 * s, height: 11 * s))
            cheek.fillColor = NSColor(hex: 0xFF8FA8, alpha: 0.55)
            cheek.strokeColor = .clear
            cheek.position = CGPoint(x: sx * 36 * s, y: -10 * s)
            f.addChild(cheek)
            if sleepy {
                let lid = SKShapeNode()
                let p = CGMutablePath()
                p.addArc(center: CGPoint(x: sx * 20 * s, y: 10 * s), radius: 8 * s, startAngle: -0.15 * .pi,
                         endAngle: -0.85 * .pi, clockwise: true)
                lid.path = p
                lid.strokeColor = Palette.ink
                lid.lineWidth = 4 * s
                lid.lineCap = .round
                f.addChild(lid)
            } else {
                let eye = SKShapeNode(ellipseOf: CGSize(width: 12 * s, height: 17 * s))
                eye.name = "eye"
                eye.fillColor = Palette.ink
                eye.strokeColor = .clear
                eye.position = CGPoint(x: sx * 20 * s, y: 8 * s)
                let glint = SKShapeNode(circleOfRadius: 2.6 * s)
                glint.fillColor = .white
                glint.strokeColor = .clear
                glint.position = CGPoint(x: 2 * s, y: 4 * s)
                eye.addChild(glint)
                f.addChild(eye)
            }
        }
        let smile = SKShapeNode()
        let p = CGMutablePath()
        p.addArc(center: CGPoint(x: 0, y: -2 * s), radius: 14 * s, startAngle: -0.15 * .pi, endAngle: -0.85 * .pi, clockwise: true)
        smile.path = p
        smile.strokeColor = Palette.ink
        smile.lineWidth = 4.5 * s
        smile.lineCap = .round
        f.addChild(smile)
        if !sleepy {
            let blink = SKAction.run { [weak f] in
                f?.children.filter { $0.name == "eye" }.forEach {
                    $0.run(.sequence([.scaleY(to: 0.1, duration: 0.06), .scaleY(to: 1, duration: 0.09)]))
                }
            }
            f.run(.repeatForever(.sequence([.wait(forDuration: 3, withRange: 3), blink])))
        }
        return f
    }

    // MARK: - Showing and tidying

    private func show(_ n: SKNode, say text: String?, life: Double? = nil) {
        let limit = prefs.calm ? 4 : 7
        while items.count >= limit { retire(items[0]) }
        var (c, clear) = place(n)
        // No clear spot: the oldest things float away early to make room.
        var tries = 0
        while !clear, !items.isEmpty, tries < 3 {
            retire(items[0])
            (c, clear) = place(n)
            tries += 1
        }
        counter += 1
        n.zPosition = 10 + CGFloat(counter % 1000) * 0.002
        // The full-size box, kept because counted things start shrunk to nothing and pop in later.
        n.userData = NSMutableDictionary(dictionary: ["say": text ?? "", "box": NSValue(rect: c)])
        addChild(n)
        items.append(n)
        n.setScale(0)
        let up = SKAction.scale(to: 1.12, duration: 0.18)
        up.timingMode = .easeOut
        n.run(.sequence([up, .scale(to: 0.96, duration: 0.09), .scale(to: 1, duration: 0.08)]))
        let bob = SKAction.moveBy(x: 0, y: 9 * u, duration: 1.3)
        bob.timingMode = .easeInEaseOut
        n.run(.repeatForever(.sequence([bob, bob.reversed()])))
        keepAlive(n, life ?? (prefs.calm ? 6 : 8))
        burst(at: CGPoint(x: c.midX, y: c.midY), texture: Art.starTexture, colors: [Palette.yellow, .white, Palette.pink],
              count: 16, speed: 240 * u, size: 18 * u, gravity: -80 * u, life: 0.9)
    }

    private func keepAlive(_ n: SKNode, _ seconds: Double) {
        n.run(.sequence([.wait(forDuration: seconds),
                         .run { [weak self, weak n] in if let self, let n { self.retire(n) } }]), withKey: "life")
    }

    private func retire(_ n: SKNode) {
        items.removeAll { $0 === n }
        n.removeAllActions()
        n.run(.sequence([.group([.scale(to: 0, duration: 0.28), .fadeOut(withDuration: 0.28)]), .removeFromParent()]))
    }

    /// Finds a roomy spot: away from other things, Boo and the sun. Returns the item's box there
    /// and whether it is clear of everything else on screen.
    private func place(_ n: SKNode) -> (CGRect, Bool) {
        // Measure from the origin: a second try must not add the first try's position again.
        n.position = .zero
        let f = n.calculateAccumulatedFrame()
        let w = size.width, h = size.height
        let hw = f.width / 2 + 14 * u, hh = f.height / 2 + 14 * u
        let xr: ClosedRange<CGFloat> = hw < w - hw ? hw...(w - hw) : (w / 2)...(w / 2)
        let lo = h * 0.2 + hh, hi = h - hh - 10 * u
        let yr: ClosedRange<CGFloat> = lo < hi ? lo...hi : ((lo + hi) / 2)...((lo + hi) / 2)
        let bearBox = primary ? bear.calculateAccumulatedFrame().insetBy(dx: -20 * u, dy: -20 * u) : .null
        let sunBox = CGRect(x: w * 0.86 - 120 * u, y: h * 0.82 - 120 * u, width: 240 * u, height: 240 * u)
        var best = CGPoint(x: w / 2, y: (yr.lowerBound + yr.upperBound) / 2)
        var bestScore = -CGFloat.infinity
        for _ in 0..<40 {
            let c = CGPoint(x: rnd(xr), y: rnd(yr))
            let box = CGRect(x: c.x - hw, y: c.y - hh, width: hw * 2, height: hh * 2)
            var score: CGFloat = 0
            var nearest = CGFloat.infinity
            for it in items {
                let o = (it.userData?["box"] as? NSValue)?.rectValue ?? it.calculateAccumulatedFrame()
                nearest = min(nearest, hypot(o.midX - c.x, o.midY - c.y))
                let i = o.intersection(box)
                // Any overlap costs far more than being further away gains.
                if !i.isNull { score -= 1500 + i.width * i.height / (hw * hh) * 3000 }
            }
            if nearest < .infinity { score += nearest }
            if box.intersects(bearBox) { score -= 3000 }
            if box.intersects(sunBox) { score -= 500 }
            if score > bestScore { bestScore = score; best = c }
        }
        n.position = CGPoint(x: best.x - f.midX, y: best.y - f.midY)
        return (CGRect(x: best.x - f.width / 2, y: best.y - f.height / 2, width: f.width, height: f.height), bestScore > -1000)
    }

    private func pulse(_ n: SKNode) {
        n.run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1, duration: 0.18)]), withKey: "pulse")
    }

    private func wiggle(_ n: SKNode) {
        n.run(.sequence([.group([.scale(to: 1.12, duration: 0.1), .rotate(toAngle: 0.12, duration: 0.1)]),
                         .rotate(toAngle: -0.12, duration: 0.12), .rotate(toAngle: 0.07, duration: 0.1),
                         .group([.scale(to: 1, duration: 0.12), .rotate(toAngle: 0, duration: 0.12)])]), withKey: "wiggle")
    }

    private func popCount(_ e: SKNode, _ i: Int) {
        guard e.name != "on", let parent = e.parent else { return }
        e.name = "on"
        let up = SKAction.scale(to: 1.3, duration: 0.14)
        up.timingMode = .easeOut
        e.run(.sequence([up, .scale(to: 1, duration: 0.12)]))
        sfx { Synth.shared.note(i, tone: .mallet, amp: 0.35) }
        burst(at: parent.convert(e.position, to: self), texture: Art.dot, colors: [.white, Palette.yellow], count: 10,
              speed: 150 * u, size: 10 * u, gravity: 0, life: 0.6)
    }

    private func popBubble(_ b: SKNode, sound: Bool = true) {
        guard let i = bubbles.firstIndex(where: { $0 === b }) else { return }
        bubbles.remove(at: i)
        b.removeAllActions()
        if sound {
            sfx { Synth.shared.play(.pop, amp: 0.5) }
            burst(at: b.position, texture: Art.dot, colors: [NSColor(hex: 0x9EF0FF), NSColor(hex: 0xFFB8E6), .white],
                  count: 12, speed: 150 * u, size: 10 * u, gravity: -200 * u, life: 0.6)
        }
        b.run(.sequence([.group([.scale(by: 1.35, duration: 0.09), .fadeOut(withDuration: 0.09)]), .removeFromParent()]))
    }

    private func rainbow() {
        rainbowNode?.removeFromParent()
        sfx { Synth.shared.run([0, 1, 2, 3, 4, 5, 6, 7], gap: 0.07, tone: .mallet, amp: 0.35) }
        let rw = min(size.width * 0.78, size.height * 0.78 / 0.52)
        let r = Art.rainbow(rw)
        let crop = SKCropNode()
        let mask = SKSpriteNode(color: .white, size: CGSize(width: rw, height: r.size.height))
        mask.anchorPoint = CGPoint(x: 0, y: 0.5)
        mask.position = CGPoint(x: -rw / 2, y: 0)
        mask.xScale = 0.001
        crop.maskNode = mask
        crop.addChild(r)
        crop.position = CGPoint(x: size.width / 2, y: size.height * 0.17 + r.size.height / 2)
        crop.zPosition = 2.5
        addChild(crop)
        rainbowNode = crop
        let grow = SKAction.scaleX(to: 1, duration: 0.8)
        grow.timingMode = .easeOut
        mask.run(grow)
        crop.run(.sequence([.wait(forDuration: 3.6), .fadeOut(withDuration: 0.7), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in
            guard let self else { return }
            for x in [self.size.width / 2 - rw * 0.42, self.size.width / 2 + rw * 0.42] {
                self.burst(at: CGPoint(x: x, y: self.size.height * 0.2), texture: Art.starTexture, colors: Palette.all,
                           count: 20, speed: 200 * self.u, size: 18 * self.u, gravity: -150 * self.u)
            }
        }]))
    }

    private func twinkle(at p: CGPoint? = nil) {
        let q = p ?? CGPoint(x: CGFloat.random(in: size.width * 0.05...size.width * 0.95),
                             y: CGFloat.random(in: size.height * 0.45...size.height * 0.95))
        let s = SKSpriteNode(texture: Art.starTexture, size: CGSize(width: 30 * u, height: 30 * u))
        s.color = NSColor(hex: 0xFFF3B0)
        s.colorBlendFactor = 1
        s.position = q
        s.zPosition = 30
        s.setScale(0)
        addChild(s)
        s.run(.sequence([.scale(to: 1.2, duration: 0.25), .scale(to: 0.9, duration: 0.2), .wait(forDuration: 1.2),
                         .fadeOut(withDuration: 0.8), .removeFromParent()]))
        sfx { Synth.shared.note(Int.random(in: 5...11), tone: .twinkle, amp: 0.15) }
    }

    private func firework(_ p: CGPoint) {
        let i = Int(p.x / max(1, size.width) * CGFloat(Synth.scale.count))
        sfx { Synth.shared.note(i, tone: .twinkle, amp: 0.4) }
        let colours = [pick(Palette.all), pick(Palette.all), Palette.yellow]
        burst(at: p, texture: Art.starTexture, colors: colours, count: 36, speed: 320 * u, size: 22 * u, gravity: -300 * u)
        burst(at: p, texture: Art.dot, colors: [.white], count: 12, speed: 160 * u, size: 14 * u, gravity: 0, life: 0.7)
    }

    /// A one-shot spray of particles; split into one emitter per colour.
    private func burst(at p: CGPoint, texture: SKTexture, colors: [NSColor], count: Int, speed: CGFloat, size s: CGFloat,
                       gravity: CGFloat, spin: Bool = false, life: CGFloat = 1.3) {
        let total = prefs.calm ? max(4, count / 2) : count
        let per = max(1, total / max(1, colors.count))
        let scale = s / max(1, texture.size().width)
        for c in colors {
            let e = SKEmitterNode()
            e.particleTexture = texture
            e.particleBirthRate = 4000
            e.numParticlesToEmit = per
            e.particleLifetime = life
            e.particleLifetimeRange = life * 0.4
            e.emissionAngleRange = .pi * 2
            e.particleSpeed = speed
            e.particleSpeedRange = speed * 0.7
            e.yAcceleration = gravity
            e.particleAlpha = 1
            e.particleAlphaSpeed = -1 / life
            e.particleScale = scale
            e.particleScaleRange = scale * 0.5
            e.particleScaleSpeed = -scale * 0.3
            e.particleColor = c
            e.particleColorBlendFactor = 1
            e.particleRotationRange = .pi * 2
            e.particleRotationSpeed = spin ? 5 : 0.5
            e.position = p
            e.zPosition = 30
            addChild(e)
            e.run(.sequence([.wait(forDuration: Double(life) * 1.6 + 0.2), .removeFromParent()]))
        }
    }

    // MARK: - Mouse and trackpad

    override func mouseDown(with event: NSEvent) { tap(event.location(in: self)) }
    override func rightMouseDown(with event: NSEvent) { tap(event.location(in: self)) }
    override func mouseDragged(with event: NSEvent) { paintAt(event.location(in: self)) }

    private func tap(_ p: CGPoint) {
        lastActivity = CACurrentMediaTime()
        if finished { twinkle(at: p); return }
        if let b = bubbles.last(where: { hypot($0.position.x - p.x, $0.position.y - p.y) < $0.frame.width / 2 + 6 * u }) {
            popBubble(b)
            return
        }
        if primary, bear.calculateAccumulatedFrame().contains(p) {
            bear.giggle()
            speak("Hee hee! That tickles!")
            sfx { Synth.shared.run([7, 9, 7, 9], gap: 0.08, tone: .bloop, amp: 0.3) }
            return
        }
        if let n = items.last(where: { $0.calculateAccumulatedFrame().contains(p) }) {
            if let s = n.childNode(withName: "sticker") ?? n.childNode(withName: "letter") { wiggle(s) }
            keepAlive(n, prefs.calm ? 6 : 8)
            sfx { Synth.shared.note(Int(p.x / max(1, self.size.width) * 12), tone: .mallet, amp: 0.4) }
            if let clip = n.userData?["clip"] as? String {
                if !demo && primary { Speech.shared.play(clip: FamilyStore.shared.url(clip)) }
            } else if let s = n.userData?["say"] as? String, !s.isEmpty {
                speak(s)
            }
            return
        }
        firework(p)
    }

    private func paintAt(_ p: CGPoint) {
        lastActivity = CACurrentMediaTime()
        guard !finished, hypot(p.x - lastPaint.x, p.y - lastPaint.y) > 9 * u else { return }
        lastPaint = p
        paintHue = (paintHue + 0.012).truncatingRemainder(dividingBy: 1)
        let d = SKSpriteNode(texture: Art.dot, size: CGSize(width: 30 * u, height: 30 * u))
        d.color = NSColor(hue: paintHue, saturation: 0.65, brightness: 1, alpha: 1)
        d.colorBlendFactor = 1
        d.position = p
        d.zPosition = 9.95
        addChild(d)
        paint.append(d)
        if paint.count > 500 { paint.removeFirst().removeFromParent() }
        d.run(.sequence([.wait(forDuration: 6), .fadeOut(withDuration: 1.2), .removeFromParent(),
                         .run { [weak self, weak d] in self?.paint.removeAll { $0 === d } }]))
        if Int(paintHue * 1000) % 8 == 0 { sfx { Synth.shared.note(Int(p.y / max(1, self.size.height) * 12), tone: .twinkle, amp: 0.12) } }
    }

    private func buildCursor() {
        let back = SKSpriteNode(texture: Art.starTexture, size: CGSize(width: 52 * u, height: 52 * u))
        back.color = .white
        back.colorBlendFactor = 1
        let front = SKSpriteNode(texture: Art.starTexture, size: CGSize(width: 38 * u, height: 38 * u))
        front.color = Palette.yellow
        front.colorBlendFactor = 1
        cursor.addChild(back)
        cursor.addChild(front)
        cursor.zPosition = 60
        cursor.isHidden = true
        cursor.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 6)))
        addChild(cursor)
    }

    private func trail(_ p: CGPoint) {
        let s = SKSpriteNode(texture: Art.dot, size: CGSize(width: 16 * u, height: 16 * u))
        s.color = pick(Palette.all)
        s.colorBlendFactor = 1
        s.position = CGPoint(x: p.x + rnd(-8...8) * u, y: p.y + rnd(-8...8) * u)
        s.zPosition = 59
        addChild(s)
        s.run(.sequence([.group([.scale(to: 0.1, duration: 0.6), .fadeOut(withDuration: 0.6),
                                 .moveBy(x: 0, y: -20 * u, duration: 0.6)]), .removeFromParent()]))
    }

    override func update(_ currentTime: TimeInterval) {
        if primary, !finished, CACurrentMediaTime() - lastActivity > 30, CACurrentMediaTime() - lastNudge > 30 {
            lastNudge = CACurrentMediaTime()
            bear.wave()
            speak("Let's play! Press a key!")
        }
        guard let view, let window = view.window else { return }
        let p = convertPoint(fromView: view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil))
        let inside = CGRect(origin: .zero, size: size).contains(p)
        cursor.isHidden = !inside
        guard inside else {
            if primary, let last = items.last { let f = last.calculateAccumulatedFrame(); bear.look(at: CGPoint(x: f.midX, y: f.midY)) }
            return
        }
        cursor.position = p
        if hypot(p.x - lastMouse.x, p.y - lastMouse.y) > 3 * u {
            if currentTime - lastTrail > 0.03 { lastTrail = currentTime; trail(p) }
            for b in bubbles where hypot(b.position.x - p.x, b.position.y - p.y) < b.frame.width / 2 { popBubble(b) }
            lastMouse = p
        }
        if primary { bear.look(at: p) }
    }

    // MARK: - Scenery

    private func ground(_ x: CGFloat) -> CGFloat {
        size.height * (0.15 + 0.025 * sin(2 * .pi * x / max(1, size.width) * 1.1 + 0.8))
    }

    private func backHill(_ x: CGFloat) -> CGFloat {
        size.height * (0.25 + 0.05 * sin(2 * .pi * x / max(1, size.width) * 0.8 + 2.2))
    }

    private func hillPath(_ f: (CGFloat) -> CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -10, y: -10))
        var x: CGFloat = -10
        while x <= size.width + 10 { p.addLine(to: CGPoint(x: x, y: f(x))); x += 12 }
        p.addLine(to: CGPoint(x: size.width + 10, y: f(size.width + 10)))
        p.addLine(to: CGPoint(x: size.width + 10, y: -10))
        p.closeSubpath()
        return p
    }

    private func makeBackdrop(night: Bool) -> SKNode {
        let root = SKNode()
        let w = size.width, h = size.height
        let sky = Art.gradient(night ? [NSColor(hex: 0x141A46), NSColor(hex: 0x3A2C70)]
                                     : [NSColor(hex: 0x6EC6FF), NSColor(hex: 0xBDE6FF), NSColor(hex: 0xFFE6F7)], size: size)
        sky.position = CGPoint(x: w / 2, y: h / 2)
        root.addChild(sky)

        if night {
            for _ in 0..<(prefs.calm ? 30 : 55) {
                let s = SKSpriteNode(texture: Art.starTexture)
                let d = rnd(8...22) * u
                s.size = CGSize(width: d, height: d)
                s.color = Bool.random(using: &dice) ? .white : NSColor(hex: 0xFFF3B0)
                s.colorBlendFactor = 1
                s.position = CGPoint(x: rnd(0...w), y: rnd(h * 0.38...h))
                s.zPosition = 0.5
                s.alpha = rnd(0.4...1)
                s.zRotation = rnd(0...1)
                let t = Double(rnd(0.8...2.2))
                s.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: t), .fadeAlpha(to: 1, duration: t)])))
                root.addChild(s)
            }
            root.addChild(moon(at: CGPoint(x: w * 0.86, y: h * 0.82)))
        } else {
            root.addChild(sun(at: CGPoint(x: w * 0.86, y: h * 0.82)))
        }

        for i in 0..<(night ? 3 : 4) {
            let cw = rnd(170...280) * u
            let c = Art.cloud(cw, night: night)
            c.position = CGPoint(x: w * (0.1 + CGFloat(i) * 0.27) + rnd(-40...40) * u, y: rnd(h * 0.58...h * 0.86))
            c.zPosition = 2
            c.alpha = night ? 0.8 : 0.95
            let speed = rnd(7...14) * u
            c.run(.sequence([
                .moveTo(x: -cw / 2, duration: Double((c.position.x + cw / 2) / speed)),
                .repeatForever(.sequence([.run { [weak c] in c?.position.x = w + cw / 2 },
                                          .moveTo(x: -cw / 2, duration: Double((w + cw) / speed))])),
            ]))
            root.addChild(c)
        }

        let back = SKShapeNode(path: hillPath(backHill))
        back.fillColor = night ? NSColor(hex: 0x2E3A78) : NSColor(hex: 0x8EE07A)
        back.strokeColor = .clear
        back.zPosition = 3
        root.addChild(back)
        let front = SKShapeNode(path: hillPath(ground))
        front.fillColor = night ? NSColor(hex: 0x23305F) : NSColor(hex: 0x5CC96B)
        front.strokeColor = night ? NSColor(hex: 0x34437C) : NSColor(hex: 0xA6EE8E)
        front.lineWidth = 6 * u
        front.zPosition = 4
        root.addChild(front)

        let flowers = ["🌷", "🌼", "🌸", "🌻", "🌺", "🍄"]
        for i in 0..<9 {
            let x = w * (0.04 + CGFloat(i) * 0.115) + rnd(-20...20) * u
            let f = Art.emoji(pick(flowers), size: rnd(34...46) * u)
            f.anchorPoint = CGPoint(x: 0.5, y: 0.15)
            f.position = CGPoint(x: x, y: ground(x) - 10 * u)
            f.zPosition = 4.5
            f.alpha = night ? 0.5 : 1
            let t = Double(rnd(1.4...2.4))
            f.run(.repeatForever(.sequence([.rotate(toAngle: 0.09, duration: t), .rotate(toAngle: -0.09, duration: t)])))
            root.addChild(f)
        }

        if night {
            for _ in 0..<(prefs.calm ? 6 : 12) {
                let ff = SKSpriteNode(texture: Art.dot, size: CGSize(width: 14 * u, height: 14 * u))
                ff.color = NSColor(hex: 0xD8FF7A)
                ff.colorBlendFactor = 1
                ff.position = CGPoint(x: rnd(0...w), y: rnd(h * 0.12...h * 0.45))
                ff.zPosition = 4.8
                let t = Double(rnd(0.7...1.6))
                ff.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: t), .fadeAlpha(to: 1, duration: t)])))
                let wander = SKAction.run { [weak ff, weak self] in
                    guard let ff, let self else { return }
                    let to = CGPoint(x: min(max(ff.position.x + CGFloat.random(in: -90...90) * self.u, 0), w),
                                     y: min(max(ff.position.y + CGFloat.random(in: -50...50) * self.u, h * 0.1), h * 0.5))
                    let m = SKAction.move(to: to, duration: 2.8)
                    m.timingMode = .easeInEaseOut
                    ff.run(m)
                }
                ff.run(.repeatForever(.sequence([wander, .wait(forDuration: 3)])))
                root.addChild(ff)
            }
        }
        return root
    }

    private func sun(at p: CGPoint) -> SKNode {
        let n = SKNode()
        n.position = p
        n.zPosition = 1
        let glow = SKSpriteNode(texture: Art.dot, size: CGSize(width: 340 * u, height: 340 * u))
        glow.color = Palette.yellow
        glow.colorBlendFactor = 1
        glow.alpha = 0.4
        n.addChild(glow)
        let rays = SKNode()
        for i in 0..<12 {
            let r = SKShapeNode(rectOf: CGSize(width: 22 * u, height: 44 * u), cornerRadius: 11 * u)
            r.fillColor = NSColor(hex: 0xFFC53D)
            r.strokeColor = .clear
            let a = CGFloat(i) / 12 * 2 * .pi
            r.position = CGPoint(x: cos(a) * 106 * u, y: sin(a) * 106 * u)
            r.zRotation = a - .pi / 2
            rays.addChild(r)
        }
        rays.run(.repeatForever(.rotate(byAngle: -2 * .pi, duration: 40)))
        rays.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 1.6), .scale(to: 1, duration: 1.6)])))
        n.addChild(rays)
        let disc = SKShapeNode(circleOfRadius: 76 * u)
        disc.fillColor = Palette.yellow
        disc.strokeColor = NSColor(hex: 0xFFF3B0)
        disc.lineWidth = 6 * u
        n.addChild(disc)
        n.addChild(face(1.1 * u))
        return n
    }

    private func moon(at p: CGPoint) -> SKNode {
        let n = SKNode()
        n.position = p
        n.zPosition = 1
        let glow = SKSpriteNode(texture: Art.dot, size: CGSize(width: 300 * u, height: 300 * u))
        glow.color = NSColor(hex: 0xFFF3C4)
        glow.colorBlendFactor = 1
        glow.alpha = 0.28
        n.addChild(glow)
        let disc = SKShapeNode(circleOfRadius: 66 * u)
        disc.fillColor = NSColor(hex: 0xFFF1B8)
        disc.strokeColor = NSColor(hex: 0xFFFBE6)
        disc.lineWidth = 5 * u
        n.addChild(disc)
        for (x, y, r) in [(-30.0, 30.0, 10.0), (32.0, -30.0, 7.0), (36.0, 26.0, 6.0)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = SKShapeNode(circleOfRadius: r * u)
            c.fillColor = NSColor(hex: 0xEAD98F, alpha: 0.7)
            c.strokeColor = .clear
            c.position = CGPoint(x: x * u, y: y * u)
            n.addChild(c)
        }
        n.addChild(face(0.95 * u, sleepy: true))
        n.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8 * u, duration: 2.5), .moveBy(x: 0, y: -8 * u, duration: 2.5)])))
        return n
    }

    private func butterfly() {
        let b = Art.emoji("🦋", size: 46 * u)
        b.zPosition = 6
        let w = size.width, h = size.height
        let fromLeft = Bool.random()
        let y0 = CGFloat.random(in: h * 0.35...h * 0.6)
        let x0: CGFloat = fromLeft ? -60 : w + 60, x1: CGFloat = fromLeft ? w + 60 : -60
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0, y: y0))
        path.addCurve(to: CGPoint(x: x1, y: y0 + CGFloat.random(in: -80...120) * u),
                      control1: CGPoint(x: w * 0.33, y: y0 + 170 * u), control2: CGPoint(x: w * 0.66, y: y0 - 150 * u))
        b.position = CGPoint(x: x0, y: y0)
        addChild(b)
        b.run(.repeatForever(.sequence([.scaleX(to: 0.45, duration: 0.14), .scaleX(to: 1, duration: 0.14)])))
        b.run(.sequence([.follow(path, asOffset: false, orientToPath: false, duration: 16), .removeFromParent()]))
    }

    private func addHint() {
        let h = Art.hint("Grown-ups: \(prefs.currentShortcut.label) or hold esc to finish", size: 15 * u, color: .white)
        h.alpha = 0.55
        h.position = CGPoint(x: size.width - h.size.width / 2 - 22 * u, y: 18 * u + h.size.height / 2)
        h.zPosition = 70
        addChild(h)
        hint = h
        let back = SKShapeNode(circleOfRadius: 11 * u)
        back.strokeColor = NSColor.white.withAlphaComponent(0.35)
        back.lineWidth = 3 * u
        back.position = CGPoint(x: h.position.x - h.size.width / 2 - 18 * u, y: h.position.y)
        back.zPosition = 70
        addChild(back)
        ring.strokeColor = .white
        ring.lineWidth = 3.5 * u
        ring.lineCap = .round
        ring.position = back.position
        ring.zPosition = 71
        addChild(ring)
    }

    // MARK: - Helpers

    private func speak(_ text: String, onWord: ((Int) -> Void)? = nil) {
        guard primary, !demo, !echoing else { return }
        Speech.shared.say(text, onWord: onWord)
    }

    private func sfx(_ f: () -> Void) {
        guard !demo, !echoing, prefs.music else { return }
        f()
    }

    private var child: String { demo ? "" : prefs.child }

    private func rnd(_ r: ClosedRange<CGFloat>) -> CGFloat { CGFloat.random(in: r, using: &dice) }
    private func pick<T>(_ a: [T]) -> T { a[Int.random(in: 0..<a.count, using: &dice)] }
}
