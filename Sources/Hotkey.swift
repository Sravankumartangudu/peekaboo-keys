// The system-wide "start playing" shortcut, via Carbon hot keys (no permission needed).
import AppKit
import Carbon

struct Shortcut {
    let id: String
    let label: String
    let keyCode: UInt32
    let carbon: UInt32
    let flags: NSEvent.ModifierFlags
    /// For the menu item's key equivalent.
    let key: String

    static let presets: [Shortcut] = [
        Shortcut(id: "ctrlOptCmdK", label: "⌃⌥⌘K", keyCode: UInt32(kVK_ANSI_K),
                 carbon: UInt32(controlKey | optionKey | cmdKey), flags: [.control, .option, .command], key: "k"),
        Shortcut(id: "ctrlOptK", label: "⌃⌥K", keyCode: UInt32(kVK_ANSI_K),
                 carbon: UInt32(controlKey | optionKey), flags: [.control, .option], key: "k"),
        Shortcut(id: "ctrlCmdK", label: "⌃⌘K", keyCode: UInt32(kVK_ANSI_K),
                 carbon: UInt32(controlKey | cmdKey), flags: [.control, .command], key: "k"),
        Shortcut(id: "ctrlOptCmdP", label: "⌃⌥⌘P", keyCode: UInt32(kVK_ANSI_P),
                 carbon: UInt32(controlKey | optionKey | cmdKey), flags: [.control, .option, .command], key: "p"),
        Shortcut(id: "ctrlOptSpace", label: "⌃⌥Space", keyCode: UInt32(kVK_Space),
                 carbon: UInt32(controlKey | optionKey), flags: [.control, .option], key: " "),
    ]

    func matches(_ e: NSEvent) -> Bool {
        UInt32(e.keyCode) == keyCode
            && e.modifierFlags.intersection([.control, .option, .command, .shift]) == flags
    }
}

final class Hotkey {
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register(_ id: String) {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        let s = Shortcut.presets.first { $0.id == id } ?? Shortcut.presets[0]
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, user in
                let me = Unmanaged<Hotkey>.fromOpaque(user!).takeUnretainedValue()
                DispatchQueue.main.async { me.onPress?() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        let hkID = EventHotKeyID(signature: OSType(0x504B_4559), id: 1) // 'PKEY'
        RegisterEventHotKey(s.keyCode, s.carbon, hkID, GetApplicationEventTarget(), 0, &ref)
    }
}
