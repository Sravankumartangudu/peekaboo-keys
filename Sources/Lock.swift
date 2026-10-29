// Keeps little hands inside the play screen.
//
// Always on while playing: kiosk presentation options (no Dock, menu bar, ⌘Tab, Mission Control,
// Force Quit, Log Out or ⌘H) and a "keep the display awake" assertion.
// Strong lock (needs Accessibility): an event tap that swallows every key, media key and trackpad
// gesture before macOS sees it — so ⌘Space, Siri, volume/brightness keys and swipes do nothing —
// and hands the keys to the play screen instead. If the app ever stalls, macOS disables the tap by
// itself, and quitting or crashing removes it, so the keyboard can't stay captured.
import AppKit
import ApplicationServices
import IOKit.pwr_mgt

final class Lock {
    static let shared = Lock()
    /// Receives every swallowed key event (keyDown / keyUp / flagsChanged).
    var onKey: ((NSEvent) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var awake: IOPMAssertionID = 0
    private var engageTimer: Timer?

    var trusted: Bool { AXIsProcessTrusted() }
    var strongActive: Bool { tap != nil }

    func askForAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static let kiosk: NSApplication.PresentationOptions = [
        .hideDock, .hideMenuBar, .disableProcessSwitching, .disableForceQuit,
        .disableSessionTermination, .disableHideApplication, .disableAppleMenu,
    ]

    func engage(strong: Bool) {
        NSApp.presentationOptions = Lock.kiosk
        if awake == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "Peekaboo Keys is playing" as CFString, &awake)
        }
        guard strong, trusted else { return }
        // Wait until the start shortcut's modifier keys are let go, so their key-up isn't swallowed.
        var waited = 0
        engageTimer?.invalidate()
        engageTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            waited += 1
            let held = NSEvent.modifierFlags.intersection([.control, .option, .command, .shift])
            if held.isEmpty || waited > 30 { t.invalidate(); self?.installTap() }
        }
    }

    func release() {
        engageTimer?.invalidate(); engageTimer = nil
        removeTap()
        NSApp.presentationOptions = []
        if awake != 0 { IOPMAssertionRelease(awake); awake = 0 }
    }

    private func installTap() {
        guard tap == nil else { return }
        var mask: CGEventMask = 0
        for t in [CGEventType.keyDown, .keyUp, .flagsChanged] { mask |= 1 << CGEventMask(t.rawValue) }
        // NX_SYSDEFINED (media, volume, brightness keys) and the trackpad gesture event types.
        for raw in [14, 18, 19, 20, 29, 30, 31, 32, 33, 34] as [UInt64] { mask |= 1 << raw }
        let me = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, user in
            let lock = Unmanaged<Lock>.fromOpaque(user!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = lock.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown || type == .keyUp || type == .flagsChanged, let ns = NSEvent(cgEvent: event) {
                lock.onKey?(ns)
            }
            return nil
        }
        let made = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                     eventsOfInterest: mask, callback: callback, userInfo: me)
            ?? CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                 eventsOfInterest: mask, callback: callback, userInfo: me)
        guard let made else { return }
        tap = made
        source = CFMachPortCreateRunLoopSource(nil, made, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: made, enable: true)
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil; source = nil
    }
}
