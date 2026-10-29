// Boo the bear: the play screen's friend. Watches the pointer, blinks, hops on the arrow keys,
// claps on modifier keys, cheers on Return, plays peekaboo on Tab, and falls asleep when play ends.
// Drawn from SpriteKit shapes; bear-local units, feet at (0, 0), about 290 tall.
import SpriteKit

final class Bear: SKNode {
    private let fur = NSColor(hex: 0xC98B59)
    private let light = NSColor(hex: 0xF6DCC0)
    private let earPink = NSColor(hex: 0xF7A1B5)
    private let line = NSColor(hex: 0x5B3A29)
    private let cheekPink = NSColor(hex: 0xFF8FA8)

    private let head = SKNode()
    private let eyes = SKNode()
    private var eyeNodes: [SKNode] = []
    private let armL = SKNode(), armR = SKNode()
    private let smile = SKShapeNode()
    private let open = SKNode()
    private let closedEyes = SKNode()
    private(set) var busy = false
    private(set) var asleep = false
    /// Resting scale; squishes and jumps always spring back to this.
    var base: CGFloat = 1 { didSet { setScale(base) } }

    override init() {
        super.init()
        build()
        blinkLoop()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func ellipse(_ w: CGFloat, _ h: CGFloat, _ fill: NSColor, outline: Bool = true) -> SKShapeNode {
        let n = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        n.fillColor = fill
        n.strokeColor = outline ? line : .clear
        n.lineWidth = outline ? 5 : 0
        return n
    }

    private func build() {
        for sx: CGFloat in [-1, 1] {
            let leg = ellipse(66, 46, fur); leg.position = CGPoint(x: sx * 40, y: 22); leg.zPosition = 0
            let pad = ellipse(32, 20, light, outline: false); pad.position = CGPoint(x: sx * 40, y: 18); pad.zPosition = 0.1
            addChild(leg); addChild(pad)
        }
        let body = ellipse(152, 150, fur); body.position = CGPoint(x: 0, y: 92); body.zPosition = 1
        let belly = ellipse(98, 92, light, outline: false); belly.position = CGPoint(x: 0, y: 80); belly.zPosition = 2
        addChild(body); addChild(belly)

        // Bow tie.
        let bow = SKNode(); bow.position = CGPoint(x: 0, y: 150); bow.zPosition = 3
        for sx: CGFloat in [-1, 1] {
            let wing = SKShapeNode(path: Art.roundedPolygon([.zero, CGPoint(x: sx * 26, y: 14), CGPoint(x: sx * 26, y: -14)], radius: 4))
            wing.fillColor = Palette.blue; wing.strokeColor = line; wing.lineWidth = 4
            bow.addChild(wing)
        }
        let knot = ellipse(14, 14, Palette.blue); bow.addChild(knot)
        addChild(bow)

        head.position = CGPoint(x: 0, y: 208); head.zPosition = 4
        addChild(head)
        for sx: CGFloat in [-1, 1] {
            let ear = ellipse(56, 56, fur); ear.position = CGPoint(x: sx * 56, y: 52)
            let inner = ellipse(28, 28, earPink, outline: false); inner.position = ear.position
            head.addChild(ear); head.addChild(inner)
        }
        let face = ellipse(150, 140, fur); face.zPosition = 0.2
        head.addChild(face)
        let muzzle = ellipse(76, 54, light); muzzle.position = CGPoint(x: 0, y: -24); muzzle.zPosition = 0.3
        head.addChild(muzzle)
        let nose = ellipse(28, 19, line, outline: false); nose.position = CGPoint(x: 0, y: -12); nose.zPosition = 0.5
        let shine = ellipse(9, 5, .white.withAlphaComponent(0.7), outline: false); shine.position = CGPoint(x: -4, y: -9); shine.zPosition = 0.6
        head.addChild(nose); head.addChild(shine)
        for sx: CGFloat in [-1, 1] {
            let cheek = ellipse(26, 16, cheekPink.withAlphaComponent(0.55), outline: false)
            cheek.position = CGPoint(x: sx * 48, y: -24); cheek.zPosition = 0.4
            head.addChild(cheek)
        }

        let sp = CGMutablePath()
        sp.addArc(center: CGPoint(x: 0, y: -22), radius: 13, startAngle: -0.1 * .pi, endAngle: -0.9 * .pi, clockwise: true)
        smile.path = sp; smile.strokeColor = line; smile.lineWidth = 4.5; smile.lineCap = .round; smile.zPosition = 0.5
        head.addChild(smile)
        let mouth = ellipse(24, 20, line, outline: false); mouth.position = CGPoint(x: 0, y: -36)
        let tongue = ellipse(14, 8, NSColor(hex: 0xFF7E94), outline: false); tongue.position = CGPoint(x: 0, y: -41)
        open.addChild(mouth); open.addChild(tongue); open.zPosition = 0.5; open.isHidden = true
        head.addChild(open)

        eyes.zPosition = 0.5
        head.addChild(eyes)
        for sx: CGFloat in [-1, 1] {
            let eye = SKNode(); eye.position = CGPoint(x: sx * 30, y: 12)
            let ball = ellipse(18, 24, line, outline: false)
            let glint = ellipse(7, 7, .white, outline: false); glint.position = CGPoint(x: 3, y: 5)
            eye.addChild(ball); eye.addChild(glint)
            eyes.addChild(eye)
            eyeNodes.append(eye)
            let lid = SKShapeNode()
            let lp = CGMutablePath()
            lp.addArc(center: CGPoint(x: sx * 30, y: 16), radius: 10, startAngle: -0.15 * .pi, endAngle: -0.85 * .pi, clockwise: true)
            lid.path = lp; lid.strokeColor = line; lid.lineWidth = 4.5; lid.lineCap = .round
            closedEyes.addChild(lid)
        }
        closedEyes.zPosition = 0.5; closedEyes.isHidden = true
        head.addChild(closedEyes)

        for (arm, sx) in [(armL, CGFloat(-1)), (armR, CGFloat(1))] {
            arm.position = CGPoint(x: sx * 64, y: 130); arm.zPosition = 6
            let limb = ellipse(46, 80, fur); limb.position = CGPoint(x: 0, y: -34)
            let paw = ellipse(30, 24, light, outline: false); paw.position = CGPoint(x: 0, y: -60)
            arm.addChild(limb); arm.addChild(paw)
            arm.zRotation = sx * 0.3
            addChild(arm)
        }
    }

    // MARK: - Moods

    private func mouthOpen(_ on: Bool) { smile.isHidden = on; open.isHidden = !on }

    private func blinkLoop() {
        let wait = SKAction.wait(forDuration: 3.2, withRange: 2.4)
        let blink = SKAction.run { [weak self] in
            guard let self, !self.asleep else { return }
            for e in self.eyeNodes { e.run(.sequence([.scaleY(to: 0.1, duration: 0.06), .scaleY(to: 1, duration: 0.09)])) }
        }
        run(.repeatForever(.sequence([wait, blink])), withKey: "blink")
    }

    /// Eyes follow a point in scene coordinates.
    func look(at p: CGPoint) {
        guard !asleep, let scene else { return }
        let c = head.convert(CGPoint(x: 0, y: 12), to: scene)
        let dx = p.x - c.x, dy = p.y - c.y
        let len = max(1, hypot(dx, dy))
        let k = min(1, len / 300) * 6
        eyes.position = CGPoint(x: dx / len * k, y: dy / len * k)
        if !head.hasActions() { head.zRotation = max(-0.08, min(0.08, -dx / 4000)) }
    }

    private func arms(_ l: CGFloat, _ r: CGFloat, stretch: CGFloat = 1, _ t: TimeInterval) -> SKAction {
        .run { [armL, armR] in
            armL.run(.group([.rotate(toAngle: l, duration: t, shortestUnitArc: false), .scaleY(to: stretch, duration: t)]))
            armR.run(.group([.rotate(toAngle: r, duration: t, shortestUnitArc: false), .scaleY(to: stretch, duration: t)]))
        }
    }

    private var rest: SKAction { arms(-0.3, 0.3, 0.22) }

    func wave() {
        guard !busy, !asleep else { return }
        armR.removeAllActions()
        armR.run(.sequence([
            .rotate(toAngle: 2.5, duration: 0.2),
            .repeat(.sequence([.rotate(toAngle: 2.1, duration: 0.16), .rotate(toAngle: 2.6, duration: 0.16)]), count: 3),
            .rotate(toAngle: 0.3, duration: 0.25),
        ]))
    }

    func cheer() {
        guard !busy, !asleep else { return }
        mouthOpen(true)
        removeAction(forKey: "cheer")
        run(.sequence([
            arms(-2.7, 2.7, 0.15),
            .repeat(.sequence([.moveBy(x: 0, y: 26, duration: 0.14), .moveBy(x: 0, y: -26, duration: 0.14)]), count: 2),
            .wait(forDuration: 0.4),
            rest,
            .run { [weak self] in self?.mouthOpen(false) },
        ]), withKey: "cheer")
    }

    func clap() {
        guard !busy, !asleep else { return }
        removeAction(forKey: "clap")
        run(.sequence([
            .repeat(.sequence([arms(1.0, -1.0, 0.08), .wait(forDuration: 0.1), arms(0.2, -0.2, 0.08), .wait(forDuration: 0.1)]), count: 2),
            rest,
        ]), withKey: "clap")
    }

    func giggle() {
        guard !busy, !asleep else { return }
        mouthOpen(true)
        head.run(.sequence([
            .repeat(.sequence([.rotate(toAngle: 0.13, duration: 0.07), .rotate(toAngle: -0.13, duration: 0.07)]), count: 4),
            .rotate(toAngle: 0, duration: 0.07),
            .run { [weak self] in self?.mouthOpen(false) },
        ]))
    }

    func hop(to p: CGPoint) {
        guard !busy, !asleep else { return }
        removeAction(forKey: "move")
        let top = max(position.y, p.y) + 40 * base
        let up = SKAction.moveTo(y: top, duration: 0.16); up.timingMode = .easeOut
        let down = SKAction.moveTo(y: p.y, duration: 0.16); down.timingMode = .easeIn
        setScale(base)
        run(.sequence([
            .group([.moveTo(x: p.x, duration: 0.32), .sequence([up, down])]),
            .scaleY(to: base * 0.86, duration: 0.06), .scaleY(to: base, duration: 0.1),
        ]), withKey: "move")
    }

    func jump() {
        guard !busy, !asleep else { return }
        removeAction(forKey: "move")
        let up = SKAction.moveBy(x: 0, y: 210 * base, duration: 0.3); up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -210 * base, duration: 0.3); down.timingMode = .easeIn
        setScale(base)
        zRotation = 0
        mouthOpen(true)
        run(.sequence([
            .group([.sequence([up, down]), .rotate(byAngle: .pi * 2, duration: 0.6)]),
            .scaleY(to: base * 0.82, duration: 0.07), .scaleY(to: base, duration: 0.12),
            .run { [weak self] in self?.mouthOpen(false) },
        ]), withKey: "move")
    }

    func squish() {
        guard !busy, !asleep else { return }
        run(.sequence([
            .group([.scaleX(to: base * 1.18, duration: 0.1), .scaleY(to: base * 0.72, duration: 0.1)]),
            .group([.scaleX(to: base * 0.94, duration: 0.12), .scaleY(to: base * 1.08, duration: 0.12)]),
            .group([.scaleX(to: base, duration: 0.1), .scaleY(to: base, duration: 0.1)]),
        ]), withKey: "squish")
    }

    /// Covers the eyes, then pops out. `reveal` runs at the "boo!".
    func peekaboo(reveal: @escaping () -> Void) {
        guard !busy, !asleep else { return }
        busy = true
        run(.sequence([
            arms(2.75, -2.75, stretch: 1.6, 0.25),
            .run { [weak self] in self?.eyes.isHidden = true; self?.closedEyes.isHidden = false },
            .wait(forDuration: 1.1),
            .run { [weak self] in
                guard let self else { return }
                self.eyes.isHidden = false; self.closedEyes.isHidden = true
                self.eyes.run(.sequence([.scale(to: 1.3, duration: 0.1), .scale(to: 1, duration: 0.3)]))
                self.mouthOpen(true)
                reveal()
            },
            arms(-2.7, 2.7, 0.18),
            .moveBy(x: 0, y: 30, duration: 0.12), .moveBy(x: 0, y: -30, duration: 0.14),
            .wait(forDuration: 0.5),
            rest,
            .run { [weak self] in self?.mouthOpen(false); self?.busy = false },
        ]))
    }

    func sleep() {
        asleep = true
        removeAction(forKey: "cheer"); removeAction(forKey: "clap")
        run(rest)
        mouthOpen(false)
        eyes.isHidden = true
        closedEyes.isHidden = false
        head.run(.rotate(toAngle: 0.14, duration: 1.2))
        let z = SKAction.run { [weak self] in
            guard let self, let scene = self.scene else { return }
            let label = Art.label("z", size: 44, fill: Palette.purple)
            label.position = self.head.convert(CGPoint(x: 70, y: 70), to: scene)
            label.setScale(self.base * 1.2)
            label.zPosition = 50
            scene.addChild(label)
            label.run(.sequence([
                .group([.moveBy(x: 60, y: 120, duration: 2.2), .fadeOut(withDuration: 2.2), .scale(by: 1.6, duration: 2.2)]),
                .removeFromParent(),
            ]))
        }
        run(.repeatForever(.sequence([z, .wait(forDuration: 1.1)])), withKey: "zzz")
    }
}
