import AppKit
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let prefs = Prefs.shared
    private let play = PlayController.shared
    private let settings = SettingsWindow()
    private let hotkey = Hotkey()
    private var statusItem: NSStatusItem!
    private var bag = Set<AnyCancellable>()
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // A login item is opened with this flag; don't start play by itself at login.
        if let e = NSAppleEventManager.shared().currentAppleEvent,
           e.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            launchedAtLogin = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        prefs.applyAppearance()

        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--demo") {
            let mode = i + 1 < args.count ? args[i + 1] : "day"
            play.startDemo(mode)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧸"
        statusItem.button?.toolTip = AppInfo.name
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        NexusBeacon.start(name: AppInfo.name) { [weak self] in
            guard let self else { return ("ok", "") }
            if self.play.playing { return ("ok", "playing") }
            return ("ok", "ready · \(self.prefs.currentShortcut.label) to play")
        }
        NexusBeacon.attach(statusItem)

        hotkey.onPress = { [weak self] in
            guard let self else { return }
            self.play.playing ? self.play.stop() : self.startPlay()
        }
        hotkey.register(prefs.shortcut)
        prefs.$shortcut.dropFirst().removeDuplicates().sink { [weak self] id in self?.hotkey.register(id) }.store(in: &bag)

        play.onChange = { [weak self] in
            guard let self else { return }
            self.statusItem.button?.title = self.play.playing ? "🎈" : "🧸"
            NexusBeacon.beat()
            // The first time back from play, show the grown-up welcome.
            if !self.play.playing && !self.prefs.welcomed { self.settings.show() }
        }

        // Opening the app locks the screen into play straight away. A login launch only waits in the menu bar.
        if prefs.openStartsPlay && !launchedAtLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.startPlay() }
        } else if !prefs.welcomed {
            settings.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !play.playing else { return false }
        if prefs.openStartsPlay { startPlay() } else { settings.show() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        play.stop()
    }

    private func startPlay() {
        settings.close()
        play.start()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = prefs.currentShortcut

        let start = item(play.playing ? "Playing… (\(s.label) to finish)" : "Start playing", #selector(startTapped))
        start.isEnabled = !play.playing
        start.keyEquivalent = s.key
        start.keyEquivalentModifierMask = s.flags
        menu.addItem(start)
        menu.addItem(.separator())

        let focus = NSMenu()
        for f in Focus.allCases {
            let i = item("\(f.emoji)  \(f.title)", #selector(pickFocus(_:)))
            i.representedObject = f.rawValue
            i.state = prefs.focus == f ? .on : .off
            focus.addItem(i)
        }
        menu.addItem(submenu("What the keys show", focus))

        let time = NSMenu()
        for m in [0, 5, 10, 15, 20, 30] {
            let i = item(m == 0 ? "No limit" : "\(m) minutes", #selector(pickTime(_:)))
            i.tag = m
            i.state = prefs.timeLimit == m ? .on : .off
            time.addItem(i)
        }
        menu.addItem(submenu("Play time", time))

        menu.addItem(toggle("Talk", prefs.voiceOn, #selector(toggleVoice)))
        menu.addItem(toggle("Sounds", prefs.music, #selector(toggleMusic)))
        menu.addItem(toggle("Calm mode", prefs.calm, #selector(toggleCalm)))
        menu.addItem(.separator())

        let settingsItem = item("Settings…", #selector(openSettings))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)

        let look = NSMenu()
        for (id, title) in [("system", "System"), ("light", "Light"), ("dark", "Dark")] {
            let i = item(title, #selector(pickAppearance(_:)))
            i.representedObject = id
            i.state = prefs.appearance == id ? .on : .off
            look.addItem(i)
        }
        menu.addItem(submenu("Appearance", look))
        menu.addItem(toggle("Open at login", SMAppService.mainApp.status == .enabled, #selector(toggleLogin)))
        menu.addItem(.separator())
        menu.addItem(item("About \(AppInfo.name) \(AppInfo.version)", #selector(openAbout)))
        let quit = item("Quit", #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let i = item(title, action)
        i.state = on ? .on : .off
        return i
    }

    private func submenu(_ title: String, _ sub: NSMenu) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.submenu = sub
        return i
    }

    @objc private func startTapped() { startPlay() }
    @objc private func pickFocus(_ i: NSMenuItem) { if let f = Focus(rawValue: i.representedObject as? String ?? "") { prefs.focus = f } }
    @objc private func pickTime(_ i: NSMenuItem) { prefs.timeLimit = i.tag }
    @objc private func toggleVoice() { prefs.voiceOn.toggle() }
    @objc private func toggleMusic() { prefs.music.toggle() }
    @objc private func toggleCalm() { prefs.calm.toggle() }
    @objc private func openSettings() { settings.show() }
    @objc private func openAbout() { settings.show(tab: .general) }
    @objc private func pickAppearance(_ i: NSMenuItem) { prefs.appearance = i.representedObject as? String ?? "system" }
    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        do { svc.status == .enabled ? try svc.unregister() : try svc.register() } catch {}
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
