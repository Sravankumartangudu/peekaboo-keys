// The grown-up side: what the keys show, the voice, family photos, the lock and the shortcut.
import AppKit
import AVFoundation
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

enum AppInfo {
    static let name = "Peekaboo Keys"
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    static let repo = URL(string: "https://github.com/Sravankumartangudu/peekaboo-keys")!
}

final class SettingsWindow {
    private var window: NSWindow?

    func show(tab: SettingsTab? = nil) {
        if let tab { SettingsModel.shared.tab = tab }
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = AppInfo.name
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 680, height: 560)
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.orderOut(nil) }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case play, sound, family, safety, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .play: return "🎈 Play"
        case .sound: return "🔊 Sound"
        case .family: return "👨‍👩‍👧 Family"
        case .safety: return "🔒 Safety"
        case .general: return "⚙️ General"
        }
    }
}

final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    @Published var tab = SettingsTab.play
}

// MARK: - Look

private let candy: [Color] = [Color(nsColor: Palette.pink), Color(nsColor: Palette.purple), Color(nsColor: Palette.blue)]
private let accent = Color(nsColor: Palette.purple)

private struct Card<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                    if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary) }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.07)))
    }
}

private struct Row<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let detail { Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(accent.opacity(0.14)))
            .foregroundStyle(accent)
    }
}

// MARK: - Window

struct SettingsView: View {
    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var model = SettingsModel.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    if !prefs.welcomed { Welcome() }
                    tabs
                    switch model.tab {
                    case .play: PlayTab()
                    case .sound: SoundTab()
                    case .family: FamilyTab()
                    case .safety: SafetyTab()
                    case .general: GeneralTab()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppInfo.name).font(.system(size: 24, weight: .heavy, design: .rounded))
                Text("Safe keyboard play that teaches letters, numbers, animals and colours")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button { PlayController.shared.start() } label: {
                    Label("Start playing", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(accent)
                HStack(spacing: 4) {
                    Text("or press").font(.system(size: 11)).foregroundStyle(.secondary)
                    Chip(text: prefs.currentShortcut.label)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 16)
        .background(LinearGradient(colors: candy.map { $0.opacity(0.16) }, startPoint: .leading, endPoint: .trailing))
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { t in
                Button { model.tab = t } label: {
                    Text(t.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(Capsule().fill(model.tab == t ? accent : Color.primary.opacity(0.06)))
                        .foregroundStyle(model.tab == t ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

private struct Welcome: View {
    @ObservedObject private var prefs = Prefs.shared
    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Text("🧸").font(.system(size: 44))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hello! This is Boo.").font(.system(size: 17, weight: .heavy, design: .rounded))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• When your little one comes over, press **\(prefs.currentShortcut.label)** (or open the app). The whole screen becomes a play world.")
                        Text("• Every key does something: letters show a picture and say it, numbers count, Space blows bubbles, Return makes a rainbow, Tab plays peekaboo.")
                        Text("• To get back to work, press **\(prefs.currentShortcut.label)** again. Or hold esc for 3 seconds and answer the grown-up sum. Your work stays safe underneath.")
                        Text("• For the best lock, allow Accessibility in 🔒 Safety, so ⌘Tab, ⌘Q and Mission Control can't be pressed by accident.")
                    }
                    .font(.system(size: 12.5))
                    .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Got it") { prefs.welcomed = true }
                            .buttonStyle(.borderedProminent).tint(accent)
                        Button("Open Safety") { prefs.welcomed = true; SettingsModel.shared.tab = .safety }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.4), lineWidth: 2))
    }
}

// MARK: - 🎈 Play

private struct PlayTab: View {
    @ObservedObject private var prefs = Prefs.shared
    private let limits = [0, 5, 10, 15, 20, 30]

    var body: some View {
        VStack(spacing: 14) {
            Card(title: "What the keys show", subtitle: "Pick what fits your child today. You can change it any time from the 🧸 menu.") {
                HStack(spacing: 10) {
                    ForEach(Focus.allCases) { f in
                        Button { prefs.focus = f } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(f.emoji).font(.system(size: 30))
                                Text(f.title).font(.system(size: 13.5, weight: .bold, design: .rounded))
                                Text(f.blurb).font(.system(size: 11)).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(prefs.focus == f ? accent.opacity(0.13) : Color.primary.opacity(0.035)))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(prefs.focus == f ? accent : Color.clear, lineWidth: 2))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                Row(title: "Say the letter first", detail: "“B… B is for Ball!” Turn off for just “Ball!”") {
                    Toggle("", isOn: $prefs.sayLetter).labelsHidden().toggleStyle(.switch)
                }
            }

            Card(title: "Your child") {
                Row(title: "Name", detail: "Boo says hello and cheers by name. Leave empty for “Hello!”") {
                    TextField("e.g. Aarav", text: $prefs.childName)
                        .textFieldStyle(.roundedBorder).frame(width: 180)
                }
                Divider()
                Row(title: "Play time", detail: "When time is up, the sky turns to night, Boo falls asleep and says “All done”. Keys stay locked until a grown-up finishes.") {
                    Picker("", selection: $prefs.timeLimit) {
                        ForEach(limits, id: \.self) { m in Text(m == 0 ? "No limit" : "\(m) minutes").tag(m) }
                    }
                    .labelsHidden().frame(width: 130)
                }
                Divider()
                Row(title: "Calm mode", detail: "Fewer things on screen, slower and softer. Nice before naps.") {
                    Toggle("", isOn: $prefs.calm).labelsHidden().toggleStyle(.switch)
                }
            }

            Card(title: "Scene") {
                Row(title: "Sky", detail: "Sunny day with clouds, or a starry night with fireflies.") {
                    Picker("", selection: $prefs.look) {
                        ForEach(SceneLook.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 170)
                }
            }
        }
    }
}

// MARK: - 🔊 Sound

private struct SoundTab: View {
    @ObservedObject private var prefs = Prefs.shared
    private let voices = Speech.englishVoices

    var body: some View {
        VStack(spacing: 14) {
            Card(title: "Voice", subtitle: "Words are said slowly and clearly, the way toddlers learn them.") {
                Row(title: "Talk", detail: "Say letters, words, numbers and animal sounds out loud.") {
                    Toggle("", isOn: $prefs.voiceOn).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                Row(title: "Voice", detail: "Automatic picks the best English voice for your region.") {
                    HStack {
                        Picker("", selection: $prefs.voiceId) {
                            Text("Automatic").tag("")
                            ForEach(voices, id: \.identifier) { v in
                                Text("\(v.name) (\(v.language))\(v.quality == .premium ? " ✦" : v.quality == .enhanced ? " +" : "")").tag(v.identifier)
                            }
                        }
                        .labelsHidden().frame(width: 220)
                        Button("Try it") {
                            Speech.shared.say("\(Content.greeting(child: prefs.child)) B is for Ball!")
                        }
                        .disabled(!prefs.voiceOn)
                    }
                }
                Divider()
                Row(title: "Speed", detail: nil) {
                    HStack(spacing: 8) {
                        Text("🐢")
                        Slider(value: $prefs.speechRate, in: 0.25...0.5).frame(width: 180)
                        Text("🐇")
                    }
                }
                Text("Tip: nicer voices are free in System Settings › Accessibility › Spoken Content › System voice › Manage Voices. Pick an English voice marked Enhanced or Premium.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Card(title: "Music and sounds") {
                Row(title: "Sounds", detail: "Xylophone notes, bubble pops and drum taps, all in a happy scale that never sounds wrong.") {
                    Toggle("", isOn: $prefs.music).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                Row(title: "Volume", detail: "For the app only. Little ears like it soft.") {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $prefs.volume, in: 0.1...1).frame(width: 180)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 👨‍👩‍👧 Family

private struct FamilyTab: View {
    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var store = FamilyStore.shared
    @State private var pending: URL?
    @State private var pendingName = ""
    @State private var message: String?
    private let cols = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(spacing: 14) {
            Card(title: "Family faces", subtitle: "Tab plays peekaboo: Boo covers both eyes, then a family photo pops up and says the name. Clicking a photo says it again.") {
                Row(title: "Show family in peekaboo", detail: "Off: peekaboo shows animals instead.") {
                    Toggle("", isOn: $prefs.showFamily).labelsHidden().toggleStyle(.switch)
                }
                if !store.members.isEmpty {
                    Divider()
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(store.members) { m in MemberCard(member: m, message: $message) }
                    }
                }
                if let message {
                    Text(message).font(.system(size: 12)).foregroundStyle(Color(nsColor: Palette.red))
                }
                Divider()
                if let pending {
                    HStack(spacing: 12) {
                        if let img = NSImage(contentsOf: pending) {
                            Image(nsImage: img).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle())
                        }
                        TextField("Who is this? e.g. Amma, Nanna, Grandpa", text: $pendingName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addPending)
                        Button("Add", action: addPending)
                            .buttonStyle(.borderedProminent).tint(accent)
                            .disabled(pendingName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel") { self.pending = nil; pendingName = "" }
                    }
                } else {
                    Button { pick() } label: { Label("Add a photo…", systemImage: "plus.circle.fill") }
                        .controlSize(.large)
                }
            }
            Card(title: "Private by design") {
                Text("Photos are copied (as small square pictures) and voice clips are kept only on this Mac, in a folder only you can open. Nothing is uploaded, and the app never connects to the internet.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Show the folder in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.folder]) }
            }
        }
    }

    private func pick() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.image]
        p.allowsMultipleSelection = false
        p.message = "Pick a clear, close-up photo of someone your child knows"
        if p.runModal() == .OK, let u = p.url {
            pending = u
            pendingName = ""
            message = nil
        }
    }

    private func addPending() {
        let name = pendingName.trimmingCharacters(in: .whitespaces)
        guard let u = pending, !name.isEmpty else { return }
        if store.add(photo: u, name: name) {
            pending = nil; pendingName = ""; message = nil
        } else {
            message = "Couldn't read that picture. Try a JPEG or PNG."
        }
    }
}

private struct MemberCard: View {
    let member: FamilyMember
    @Binding var message: String?
    @ObservedObject private var store = FamilyStore.shared
    @State private var name = ""

    var body: some View {
        VStack(spacing: 8) {
            if let img = NSImage(contentsOf: store.url(member.photo)) {
                Image(nsImage: img).resizable().scaledToFill()
                    .frame(width: 86, height: 86).clipShape(Circle())
                    .overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 3))
            }
            TextField("Name", text: $name)
                .textFieldStyle(.plain).multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .onSubmit(save)
                .onChange(of: name) { _, _ in save() }
            HStack(spacing: 6) {
                if store.recordingId == member.id {
                    Label("Recording…", systemImage: "record.circle").foregroundStyle(Color(nsColor: Palette.red))
                        .font(.system(size: 11, weight: .semibold))
                } else {
                    Button { store.record(member.id) { message = $0 } } label: { Image(systemName: "mic.fill") }
                        .help("Record your voice saying the name (3 seconds)")
                    if let v = member.voice {
                        Button { Speech.shared.play(clip: store.url(v)) } label: { Image(systemName: "play.fill") }
                            .help("Play the recording")
                        Button { store.removeVoice(member.id) } label: { Image(systemName: "mic.slash") }
                            .help("Use the app's voice instead")
                    } else {
                        Button { Speech.shared.say(member.phrase) } label: { Image(systemName: "speaker.wave.2.fill") }
                            .help("Hear it")
                    }
                    Button { store.remove(member.id) } label: { Image(systemName: "trash") }
                        .help("Remove")
                }
            }
            .buttonStyle(.borderless)
            Text(member.voice == nil ? "App voice" : "Your voice 🎙")
                .font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.035)))
        .onAppear { name = member.name }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty, n != member.name { store.rename(member.id, to: n) }
    }
}

// MARK: - 🔒 Safety

private struct SafetyTab: View {
    @ObservedObject private var prefs = Prefs.shared
    @State private var trusted = Lock.shared.trusted
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            Card(title: "Lock", subtitle: "While playing, the screen is covered and keys only reach the play world.") {
                Row(title: "Strong lock", detail: "Also catches ⌘Tab, ⌘Q, ⌘Space, Mission Control and the media keys. Needs Accessibility permission.") {
                    Toggle("", isOn: $prefs.strongLock).labelsHidden().toggleStyle(.switch)
                }
                if prefs.strongLock {
                    HStack(spacing: 10) {
                        Image(systemName: trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(trusted ? Color(nsColor: Palette.green) : Color(nsColor: Palette.orange))
                        Text(trusted ? "Accessibility is allowed. The strong lock is ready."
                                     : "Accessibility isn't allowed yet. Play still works, but some system shortcuts get through.")
                            .font(.system(size: 12))
                        Spacer()
                        if !trusted {
                            Button("Allow…") { Lock.shared.askForAccess() }.buttonStyle(.borderedProminent).tint(accent)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                }
                Text("Always blocked: the Dock, the menu bar, app switching (the app comes straight back), the screen going to sleep. With the strong lock: every keyboard shortcut. The power button and Touch ID can't be blocked by any app.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Card(title: "Finishing play") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Quickest: press **\(prefs.currentShortcut.label)** again and you're straight back to work.", systemImage: "bolt.circle.fill")
                    Label("Or hold **esc** for 3 seconds (a ring fills up), type the answer to the sum (always 11–18) and press Return.", systemImage: "lock.circle.fill")
                    Label("At the sum, any other key, a wrong answer or 20 seconds of nothing goes back to play.", systemImage: "arrow.uturn.backward.circle.fill")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(.primary)
            }
            Card(title: "Little tips") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🌙 Turn on Do Not Disturb so notifications don't pop up over play.")
                    Text("🤝 Play together: name things, make the animal sounds, count out loud. That's where the learning happens.")
                    Text("⏳ Short and sweet: under 2 years, health groups advise very little screen time, best shared with a grown-up. The play-time ending helps.")
                    Text("🧽 A keyboard cover keeps sticky fingers and snacks out.")
                }
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onReceive(poll) { _ in trusted = Lock.shared.trusted }
    }
}

// MARK: - ⚙️ General

private struct GeneralTab: View {
    @ObservedObject private var prefs = Prefs.shared
    @State private var login = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 14) {
            Card(title: "Start") {
                Row(title: "Shortcut", detail: "Starts play from any app. Press it again to get back to work.") {
                    Picker("", selection: $prefs.shortcut) {
                        ForEach(Shortcut.presets, id: \.id) { Text($0.label).tag($0.id) }
                    }
                    .labelsHidden().frame(width: 130)
                }
                Divider()
                Row(title: "Opening the app starts play", detail: "Clicking Peekaboo Keys in the Dock folder, Launchpad or Spotlight goes straight to play.") {
                    Toggle("", isOn: $prefs.openStartsPlay).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                Row(title: "Open at login", detail: "Keeps 🧸 in the menu bar so the shortcut is always ready. It won't start play by itself.") {
                    Toggle("", isOn: Binding(get: { login }, set: { on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() } catch {}
                        login = SMAppService.mainApp.status == .enabled
                    }))
                    .labelsHidden().toggleStyle(.switch)
                }
            }
            Card(title: "Appearance", subtitle: "For this window and the menu. The play world has its own sky in 🎈 Play.") {
                Picker("", selection: $prefs.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 260)
            }
            Card(title: "About") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(AppInfo.name) \(AppInfo.version)").font(.system(size: 13, weight: .bold))
                        Text("Free and open source (MIT). No ads, no tracking, no internet.")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("GitHub") { NSWorkspace.shared.open(AppInfo.repo) }
                }
            }
        }
        .onAppear { login = SMAppService.mainApp.status == .enabled }
    }
}
