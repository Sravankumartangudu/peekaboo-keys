// Starts and stops play: one full-screen window per display (the one with the pointer does the
// talking), the lock, the keys, the play-time timer and the grown-up way out
// (the start shortcut again, or hold esc for 3 seconds and answer a sum).
import AppKit
import SpriteKit
import SwiftUI

final class PlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class PlayView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }
    // Keys are handled by the controller; swallow them here so nothing beeps.
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
}

final class PlayController {
    static let shared = PlayController()
    private(set) var playing = false
    /// Called when play starts or stops (menu bar, beacon).
    var onChange: (() -> Void)?

    private let prefs = Prefs.shared
    private var windows: [PlayWindow] = []
    private var scenes: [PlayScene] = []
    private weak var primary: PlayScene?
    private weak var primaryWindow: PlayWindow?
    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var flags: NSEvent.ModifierFlags = []
    private var escDown: CFTimeInterval?
    private var escTimer: Timer?
    private var limitTimer: Timer?
    private var gate: GateModel?
    private var gateView: NSView?
    private var gateTimer: Timer?
    private var demo = false
    private var cursorHidden = false
    private var dice = Dice()

    // MARK: - Start and stop

    func start() {
        guard !playing else { return }
        playing = true
        demo = false
        flags = NSEvent.modifierFlags.intersection(Self.modifierKeys)
        Speech.shared.stop()
        Synth.shared.volume = prefs.volume
        Synth.shared.start()
        NSApp.activate(ignoringOtherApps: true)
        buildWindows()

        Lock.shared.onKey = { [weak self] e in self?.handle(e) }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] e in
            guard let self, self.playing else { return e }
            self.handle(e)
            return nil
        }
        Lock.shared.engage(strong: prefs.strongLock)
        setCursor(hidden: true)

        let nc = NotificationCenter.default
        // If anything steals focus, come straight back.
        observers.append(nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.playing else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard self.playing else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.primaryWindow?.makeKeyAndOrderFront(nil)
            }
        })
        observers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.playing else { return }
            self.closeGate()
            self.buildWindows()
        })

        if prefs.timeLimit > 0 {
            limitTimer = Timer.scheduledTimer(withTimeInterval: Double(prefs.timeLimit) * 60, repeats: false) { [weak self] _ in
                self?.scenes.forEach { $0.allDone() }
            }
        }
        onChange?()
    }

    func stop() {
        guard playing else { return }
        playing = false
        closeGate()
        endEsc()
        limitTimer?.invalidate(); limitTimer = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        Lock.shared.onKey = nil
        if !demo { Lock.shared.release() }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        Speech.shared.stop()
        Synth.shared.stop()
        tearDownWindows()
        setCursor(hidden: false)
        onChange?()
        if demo { NSApp.terminate(nil) }
    }

    private func buildWindows() {
        tearDownWindows()
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let mouse = NSEvent.mouseLocation
        let main = screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? screens[0]
        for s in screens {
            let w = PlayWindow(contentRect: s.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            w.setFrame(s.frame, display: false)
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.isReleasedWhenClosed = false
            w.hasShadow = false
            w.backgroundColor = .black
            w.acceptsMouseMovedEvents = true
            let scene = PlayScene(size: s.frame.size, primary: s == main, dice: Dice())
            present(scene, in: w)
            windows.append(w)
            scenes.append(scene)
            if s == main { primary = scene; primaryWindow = w }
            w.orderFrontRegardless()
        }
        primaryWindow?.makeKeyAndOrderFront(nil)
        primary?.start()
    }

    private func present(_ scene: PlayScene, in w: NSWindow) {
        let box = NSView(frame: NSRect(origin: .zero, size: w.frame.size))
        let v = PlayView(frame: box.bounds)
        v.autoresizingMask = [.width, .height]
        v.ignoresSiblingOrder = false
        v.preferredFramesPerSecond = 60
        box.addSubview(v)
        w.contentView = box
        v.presentScene(scene)
        w.makeFirstResponder(v)
    }

    private func tearDownWindows() {
        for w in windows {
            (w.contentView?.subviews.first as? SKView)?.presentScene(nil)
            w.orderOut(nil)
            w.close()
        }
        windows = []
        scenes = []
    }

    private func setCursor(hidden: Bool) {
        guard hidden != cursorHidden, !demo else { return }
        cursorHidden = hidden
        hidden ? NSCursor.hide() : NSCursor.unhide()
    }

    // MARK: - Keys

    private static let modifierKeys: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .function, .capsLock]

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .keyDown:
            // The grown-up shortcut goes straight back to work, even with the sum showing.
            if prefs.currentShortcut.matches(e) { stop(); return }
            if let gate {
                if !e.isARepeat { gate.key(Keys.classify(keyCode: e.keyCode, characters: e.charactersIgnoringModifiers)) }
                return
            }
            if e.keyCode == 53 {
                if !e.isARepeat { beginEsc() }
                return
            }
            guard !e.isARepeat else { return }
            send(Keys.classify(keyCode: e.keyCode, characters: e.charactersIgnoringModifiers))
        case .keyUp:
            if e.keyCode == 53 { endEsc() }
        case .flagsChanged:
            let now = e.modifierFlags.intersection(Self.modifierKeys)
            let added = !now.subtracting(flags).isEmpty
            flags = now
            if added, gate == nil { primary?.modifier() }
        default:
            break
        }
    }

    private func send(_ p: Press) {
        primary?.press(p)
        for s in scenes where s !== primary { s.echo(p) }
    }

    private func beginEsc() {
        escDown = CACurrentMediaTime()
        escTimer?.invalidate()
        escTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self, let d = self.escDown else { return }
            let f = (CACurrentMediaTime() - d) / 3
            self.primary?.escProgress(CGFloat(f))
            if f >= 1 { self.endEsc(); self.openGate() }
        }
    }

    private func endEsc() {
        escDown = nil
        escTimer?.invalidate(); escTimer = nil
        primary?.escProgress(nil)
    }

    // MARK: - The grown-up gate

    /// Shows the sum after the 3-second esc hold.
    func openGate(typed: String = "") {
        guard playing, gate == nil, let box = primaryWindow?.contentView else { return }
        let model = GateModel(question: GateQuestion.make(using: &dice))
        model.typed = typed
        model.onClose = { [weak self] in self?.closeGate() }
        model.onPass = { [weak self] in self?.stop() }
        let host = NSHostingView(rootView: GateView(model: model))
        host.frame = box.bounds
        host.autoresizingMask = [.width, .height]
        box.addSubview(host)
        gate = model
        gateView = host
        setCursor(hidden: false)
        if !demo {
            gateTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.closeGate() }
        }
    }

    private func closeGate() {
        gateTimer?.invalidate(); gateTimer = nil
        gateView?.removeFromSuperview()
        gateView = nil
        guard gate != nil else { return }
        gate = nil
        if playing { setCursor(hidden: true) }
    }

    // MARK: - README screenshots

    /// `--demo [day|night|gate]`: a normal window (no lock, no sound), a scripted few presses with
    /// fixed dice, then it prints its window number for `screencapture -l` and quits by itself.
    func startDemo(_ mode: String) {
        demo = true
        playing = true
        let size = CGSize(width: 1440, height: 900)
        let w = PlayWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        w.title = "Peekaboo Keys"
        w.isReleasedWhenClosed = false
        w.center()
        let scene = PlayScene(size: size, primary: true, dice: Dice(seed: 7), night: mode == "night")
        scene.demo = true
        present(scene, in: w)
        windows = [w]
        scenes = [scene]
        primary = scene
        primaryWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let script: [(Double, Press)] = mode == "night"
            ? [(0.4, .letter("M")), (1.0, .digit(4)), (1.6, .other), (2.2, .letter("O")), (2.8, .space)]
            : [(0.4, .letter("B")), (1.0, .digit(3)), (1.6, .other), (2.2, .letter("D")), (2.6, .space), (3.0, .enter)]
        for (t, p) in script {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in self?.send(p) }
        }
        let ready = (script.last?.0 ?? 0) + 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + ready) { [weak self] in
            if mode == "gate" { self?.openGate(typed: "1") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                print("WINDOW \(w.windowNumber)")
                fflush(stdout)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ready + 8) { NSApp.terminate(nil) }
    }
}

// MARK: - Gate

final class GateModel: ObservableObject {
    enum State { case asking, wrong, right }
    let question: GateQuestion
    @Published var typed = ""
    @Published var state = State.asking
    @Published var shakes: CGFloat = 0
    var onClose: () -> Void = {}
    var onPass: () -> Void = {}

    init(question: GateQuestion) { self.question = question }

    /// Digits type, delete rubs out, Return checks. Any other key (a toddler!) goes back to play.
    func key(_ p: Press) {
        guard state == .asking else { return }
        switch p {
        case .digit(let d):
            if typed.count < 2 { typed += "\(d)" }
        case .delete:
            typed = String(typed.dropLast())
        case .enter:
            if question.check(typed) {
                state = .right
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.onPass() }
            } else {
                state = .wrong
                shakes += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.onClose() }
            }
        default:
            onClose()
        }
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 12 * sin(animatableData * .pi * 6), y: 0))
    }
}

struct GateView: View {
    @ObservedObject var model: GateModel
    private let purple = Color(nsColor: Palette.purple)

    var body: some View {
        ZStack {
            Color(nsColor: Palette.ink).opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🔒").font(.system(size: 50))
                Text("Grown-ups only")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                Text("Type the answer, then press Return")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Text("\(model.question.a) + \(model.question.b) =")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.ink))
                    box(0)
                    box(1)
                }
                .padding(.vertical, 6)
                Text(status)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.state == .wrong ? Color(nsColor: Palette.red)
                                     : model.state == .right ? Color(nsColor: Palette.green) : .secondary)
                    .frame(height: 20)
                Button { model.onClose() } label: {
                    Label("Keep playing", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(purple)
            }
            .padding(.horizontal, 54)
            .padding(.vertical, 38)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(purple.opacity(0.35), lineWidth: 4))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            .modifier(Shake(animatableData: model.shakes))
            .animation(.linear(duration: 0.45), value: model.shakes)
        }
        .environment(\.colorScheme, .light)
    }

    private var status: String {
        switch model.state {
        case .asking: return "Any other key goes back to play"
        case .wrong: return "Not quite. Back to play!"
        case .right: return "Bye-bye! 👋"
        }
    }

    private func box(_ i: Int) -> some View {
        let chars = Array(model.typed)
        return Text(i < chars.count ? String(chars[i]) : " ")
            .font(.system(size: 48, weight: .black, design: .rounded))
            .foregroundStyle(purple)
            .frame(width: 64, height: 78)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(purple.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(i == chars.count && model.state == .asking ? purple : .clear, lineWidth: 3))
    }
}
