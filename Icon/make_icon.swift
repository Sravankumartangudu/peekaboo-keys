// Renders the app icon: Boo the teddy playing peekaboo (one paw over an eye, one eye peeking)
// on a sky-to-lilac-to-pink tile with sparkles.
//   swift Icon/make_icon.swift   → writes Icon/AppIcon.icns and Icon/AppIcon.png
import AppKit

let size = 1024.0

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let fur = hex(0xC98B59), light = hex(0xF6DCC0), line = hex(0x5B3A29), earPink = hex(0xF7A1B5)
let cheek = hex(0xFF8FA8, 0.6), blue = hex(0x3AA0FF), white = hex(0xFFFFFF)

func renderFull(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    cg.scaleBy(x: CGFloat(px) / size, y: CGFloat(px) / size)
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Every size is shrunk from one full-size drawing. Shadow and glow blur are measured in device pixels, so
// drawing straight at 16–64 px would spill them over the whole image as a faint grey square.
enum Full {
    static let png = renderFull(1024)
    static let image = NSBitmapImageRep(data: png)!.cgImage!
}

func render(_ px: Int) -> Data {
    if px == Full.image.width { return Full.png }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.interpolationQuality = .high
    ctx.draw(Full.image, in: CGRect(x: 0, y: 0, width: px, height: px))
    return rep.representation(using: .png, properties: [:])!
}

func oval(_ cg: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: CGColor, outline: CGFloat = 0) {
    let r = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    if outline > 0 {
        cg.setFillColor(line)
        cg.fillEllipse(in: r.insetBy(dx: -outline, dy: -outline))
    }
    cg.setFillColor(fill)
    cg.fillEllipse(in: r)
}

func sparkle(_ cg: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: CGColor) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: cy + r))
    p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.16, y: cy + r * 0.16))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx + r * 0.16, y: cy - r * 0.16))
    p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.16, y: cy - r * 0.16))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx - r * 0.16, y: cy + r * 0.16))
    cg.addPath(p)
    cg.setFillColor(color)
    cg.fillPath()
}

func draw(_ cg: CGContext) {
    // Body follows Apple's icon grid: 824pt squircle centred in a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: hex(0x000000, 0.3))
    cg.addPath(squircle)
    cg.setFillColor(white)
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(squircle)
    cg.clip()
    let sky = CGGradient(colorsSpace: nil, colors: [hex(0x7FD3FF), hex(0xB9A7FF), hex(0xFF9FCB)] as CFArray,
                         locations: [0, 0.55, 1])!
    cg.drawLinearGradient(sky, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

    sparkle(cg, 238, 800, 46, white)
    sparkle(cg, 812, 812, 34, hex(0xFFE27A))
    sparkle(cg, 846, 650, 22, white)
    sparkle(cg, 196, 640, 20, hex(0xFFE27A))

    // Shoulders and bow tie.
    oval(cg, 512, 150, 640, 330, fur, outline: 14)
    oval(cg, 512, 140, 380, 220, light)

    // Head.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: hex(0x5B3A29, 0.35))
    for sx: CGFloat in [-1, 1] { oval(cg, 512 + sx * 205, 718, 190, 190, fur, outline: 14) }
    oval(cg, 512, 520, 540, 480, fur, outline: 14)
    cg.restoreGState()
    for sx: CGFloat in [-1, 1] { oval(cg, 512 + sx * 205, 718, 100, 100, earPink) }
    oval(cg, 512, 430, 236, 166, light)
    for sx: CGFloat in [-1, 1] { oval(cg, 512 + sx * 178, 448, 86, 52, cheek) }
    oval(cg, 512, 468, 96, 64, line)
    oval(cg, 498, 480, 30, 16, hex(0xFFFFFF, 0.65))
    cg.setStrokeColor(line)
    cg.setLineWidth(15)
    cg.setLineCap(.round)
    cg.addArc(center: CGPoint(x: 512, y: 448), radius: 44, startAngle: -0.12 * .pi, endAngle: -0.88 * .pi, clockwise: true)
    cg.strokePath()
    // The peeking eye.
    oval(cg, 616, 588, 54, 70, line)
    oval(cg, 628, 604, 22, 22, white)

    // Bow tie over the neck.
    for sx: CGFloat in [-1, 1] {
        let wing = CGMutablePath()
        wing.move(to: CGPoint(x: 512, y: 282))
        wing.addLine(to: CGPoint(x: 512 + sx * 98, y: 330))
        wing.addLine(to: CGPoint(x: 512 + sx * 98, y: 234))
        wing.closeSubpath()
        cg.addPath(wing)
        cg.setLineJoin(.round)
        cg.setLineWidth(24)
        cg.setStrokeColor(line)
        cg.strokePath()
        cg.addPath(wing)
        cg.setLineWidth(1)
        cg.setFillColor(blue)
        cg.setStrokeColor(blue)
        cg.drawPath(using: .fillStroke)
    }
    oval(cg, 512, 282, 54, 54, blue, outline: 12)

    // Arms up to the face: the left paw hides an eye, the right paw has slipped down a little.
    let arms: [(CGPoint, CGPoint)] = [(CGPoint(x: 300, y: 250), CGPoint(x: 406, y: 572)),
                                      (CGPoint(x: 724, y: 250), CGPoint(x: 660, y: 498))]
    for (from, to) in arms {
        let p = CGMutablePath()
        p.move(to: from)
        p.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2 + (from.x < 512 ? -60 : 60), y: (from.y + to.y) / 2))
        cg.addPath(p); cg.setLineWidth(150); cg.setStrokeColor(line); cg.strokePath()
        oval(cg, to.x, to.y, 176, 156, fur, outline: 14)
        cg.addPath(p); cg.setLineWidth(122); cg.setStrokeColor(fur); cg.strokePath()
        oval(cg, to.x, to.y, 176, 156, fur)
        oval(cg, to.x, to.y + 24, 92, 46, hex(0xFFFFFF, 0.16))
    }
    cg.restoreGState()
}

let iconset = URL(fileURLWithPath: "Icon/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
try! Full.png.write(to: URL(fileURLWithPath: "Icon/AppIcon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Icon/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("✓ Icon/AppIcon.icns")
