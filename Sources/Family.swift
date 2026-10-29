// Family faces: photos of the people a toddler knows, with their name said aloud — or recorded
// in a grown-up's own voice. Everything stays in ~/Library/Application Support/Peekaboo Keys/Family
// (folder 0700, files 0600). Nothing is uploaded anywhere.
import AppKit
import AVFoundation
import Combine

struct FamilyMember: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var photo: String           // file name inside the Family folder
    var voice: String?          // recorded clip, if any

    /// What the voice says when the photo pops up.
    var phrase: String { "It's \(name)!" }
}

final class FamilyStore: ObservableObject {
    static let shared = FamilyStore()

    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var recordingId: UUID?

    let folder: URL
    private var listFile: URL { folder.appendingPathComponent("family.json") }
    private var recorder: AVAudioRecorder?

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Peekaboo Keys/Family", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        if let data = try? Data(contentsOf: listFile),
           let list = try? JSONDecoder().decode([FamilyMember].self, from: data) {
            members = list.filter { FileManager.default.fileExists(atPath: url($0.photo).path) }
        }
    }

    func url(_ file: String) -> URL { folder.appendingPathComponent(file) }

    private func save() {
        guard let data = try? JSONEncoder().encode(members) else { return }
        try? data.write(to: listFile, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: listFile.path)
    }

    /// Copies the photo in as a 720 px square JPEG (centre crop) so the original stays untouched.
    @discardableResult
    func add(photo source: URL, name: String) -> Bool {
        guard let image = NSImage(contentsOf: source), let jpeg = FamilyStore.squareJPEG(image) else { return false }
        let m = FamilyMember(name: name, photo: "\(UUID().uuidString).jpg")
        do {
            try jpeg.write(to: url(m.photo), options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url(m.photo).path)
        } catch { return false }
        members.append(m)
        save()
        return true
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = members.firstIndex(where: { $0.id == id }) else { return }
        members[i].name = name
        save()
    }

    func remove(_ id: UUID) {
        guard let i = members.firstIndex(where: { $0.id == id }) else { return }
        let m = members.remove(at: i)
        try? FileManager.default.removeItem(at: url(m.photo))
        if let v = m.voice { try? FileManager.default.removeItem(at: url(v)) }
        save()
    }

    func removeVoice(_ id: UUID) {
        guard let i = members.firstIndex(where: { $0.id == id }), let v = members[i].voice else { return }
        try? FileManager.default.removeItem(at: url(v))
        members[i].voice = nil
        save()
    }

    // MARK: - Recording a name

    /// Records about three seconds from the microphone ("Amma!"), asking for permission first.
    func record(_ id: UUID, done: @escaping (String?) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: startRecording(id, done: done)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                DispatchQueue.main.async {
                    ok ? self.startRecording(id, done: done) : done("Microphone access was not allowed.")
                }
            }
        default:
            done("Allow the microphone in System Settings › Privacy & Security › Microphone.")
        }
    }

    private func startRecording(_ id: UUID, done: @escaping (String?) -> Void) {
        guard members.contains(where: { $0.id == id }) else { return done(nil) }
        let file = "\(id.uuidString)-voice.m4a"
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
                                       AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        guard let r = try? AVAudioRecorder(url: url(file), settings: settings), r.record(forDuration: 3) else {
            return done("Couldn't start recording. Is a microphone connected?")
        }
        recorder = r
        recordingId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
            guard let self else { return }
            self.recorder?.stop(); self.recorder = nil
            self.recordingId = nil
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.url(file).path)
            if let j = self.members.firstIndex(where: { $0.id == id }) {
                self.members[j].voice = file
                self.save()
            }
            done(nil)
        }
    }

    static func squareJPEG(_ image: NSImage, side: Int = 720) -> Data? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = cg.width, h = cg.height, s = min(w, h)
        guard s > 0, let crop = cg.cropping(to: CGRect(x: (w - s) / 2, y: (h - s) / 2, width: s, height: s)) else { return nil }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: side, height: side))
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
