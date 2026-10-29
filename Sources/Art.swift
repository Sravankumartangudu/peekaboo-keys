// Drawn-in-code artwork for the play screen: chunky outlined letters, emoji stickers, bubbles,
// clouds, a rainbow, sparkles and shape paths. Rendered at 2× into SpriteKit textures and cached.
import AppKit
import CoreText
import SpriteKit

enum Art {
    static let scale: CGFloat = 2
    private static var cache: [String: (SKTexture, CGSize)] = [:]

    /// Renders `size` points into a texture. The drawing uses bottom-left origin points.
    static func texture(_ key: String?, size: CGSize, _ draw: (CGContext) -> Void) -> (SKTexture, CGSize) {
        if let key, let hit = cache[key] { return hit }
        let pw = max(1, Int(ceil(size.width * scale))), ph = max(1, Int(ceil(size.height * scale)))
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        draw(ctx)
        NSGraphicsContext.restoreGraphicsState()
        let tex = SKTexture(cgImage: ctx.makeImage()!)
        tex.filteringMode = .linear
        let out = (tex, size)
        if let key {
            if cache.count > 400 { cache.removeAll() }
            cache[key] = out
        }
        return out
    }

    static func sprite(_ t: (SKTexture, CGSize)) -> SKSpriteNode {
        SKSpriteNode(texture: t.0, size: t.1)
    }

    static func rounded(_ size: CGFloat, _ weight: NSFont.Weight = .black) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { return f }
        return base
    }

    /// The outline of a string as a path, so it can get a thick, round-cornered sticker outline.
    static func textPath(_ s: String, font: NSFont) -> CGPath {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attrs = CTRunGetAttributes(run) as NSDictionary
            let runFont = attrs[kCTFontAttributeName as String] as! CTFont
            let n = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: n)
            var pos = [CGPoint](repeating: .zero, count: n)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &pos)
            for i in 0..<n {
                if let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                    path.addPath(g, transform: CGAffineTransform(translationX: pos[i].x, y: pos[i].y))
                }
            }
        }
        return path
    }

    /// Chunky rounded text with a white sticker outline and a soft drop shadow.
    static func label(_ s: String, size: CGFloat, fill: NSColor, outline: NSColor = .white,
                      width: CGFloat? = nil, weight: NSFont.Weight = .black) -> SKSpriteNode {
        let w = width ?? max(3, size * 0.09)
        let key = "label|\(s)|\(Int(size))|\(fill.hexKey)|\(outline.hexKey)|\(Int(w))|\(weight.rawValue)"
        let path = textPath(s, font: rounded(size, weight))
        let b = path.boundingBoxOfPath
        let pad = w + size * 0.12
        let canvas = CGSize(width: b.width + pad * 2, height: b.height + pad * 2)
        return sprite(texture(key, size: canvas) { cg in
            cg.translateBy(x: pad - b.minX, y: pad - b.minY)
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -size * 0.04), blur: size * 0.08,
                         color: NSColor.black.withAlphaComponent(0.22).cgColor)
            cg.addPath(path)
            cg.setLineWidth(w * 2)
            cg.setLineJoin(.round)
            cg.setStrokeColor(outline.cgColor)
            cg.strokePath()
            cg.restoreGState()
            cg.addPath(path)
            cg.setFillColor(fill.cgColor)
            cg.fillPath()
            // A little shine across the top of the letters.
            cg.saveGState()
            cg.addPath(path)
            cg.clip()
            let shine = CGGradient(colorsSpace: nil, colors: [NSColor.white.withAlphaComponent(0.35).cgColor,
                                                              NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 1])!
            cg.drawLinearGradient(shine, start: CGPoint(x: 0, y: b.maxY), end: CGPoint(x: 0, y: b.midY), options: [])
            cg.restoreGState()
        })
    }

    /// Plain small text for the grown-up hint.
    static func hint(_ s: String, size: CGFloat, color: NSColor) -> SKSpriteNode {
        let font = rounded(size, .semibold)
        let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
        let r = str.boundingRect(with: CGSize(width: 2000, height: 200), options: [.usesLineFragmentOrigin])
        return sprite(texture("hint|\(s)|\(Int(size))|\(color.hexKey)", size: CGSize(width: ceil(r.width) + 4, height: ceil(r.height) + 4)) { _ in
            str.draw(at: CGPoint(x: 2, y: 2))
        })
    }

    static func emoji(_ s: String, size: CGFloat) -> SKSpriteNode {
        let font = NSFont(name: "Apple Color Emoji", size: size) ?? NSFont.systemFont(ofSize: size)
        let str = NSAttributedString(string: s, attributes: [.font: font])
        let r = str.boundingRect(with: CGSize(width: size * 4, height: size * 4), options: [.usesLineFragmentOrigin])
        let canvas = CGSize(width: ceil(r.width) + 8, height: ceil(r.height) + 8)
        return sprite(texture("emoji|\(s)|\(Int(size))", size: canvas) { _ in
            str.draw(at: CGPoint(x: 4 - r.minX, y: 4 - r.minY))
        })
    }

    /// A round white sticker with a coloured rim, for pictures to sit on.
    static func sticker(diameter d: CGFloat, ring: NSColor) -> SKSpriteNode {
        let pad = d * 0.12
        let size = CGSize(width: d + pad * 2, height: d + pad * 2)
        return sprite(texture("sticker|\(Int(d))|\(ring.hexKey)", size: size) { cg in
            let r = CGRect(x: pad, y: pad, width: d, height: d)
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -d * 0.03), blur: d * 0.08,
                         color: NSColor.black.withAlphaComponent(0.25).cgColor)
            cg.setFillColor(ring.cgColor)
            cg.fillEllipse(in: r)
            cg.restoreGState()
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillEllipse(in: r.insetBy(dx: d * 0.06, dy: d * 0.06))
            cg.setFillColor(ring.withAlphaComponent(0.13).cgColor)
            cg.fillEllipse(in: r.insetBy(dx: d * 0.1, dy: d * 0.1))
        })
    }

    /// A family photo cut into a circle with a white and coloured rim.
    static func photo(_ url: URL, diameter d: CGFloat, ring: NSColor) -> SKSpriteNode? {
        guard let img = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let pad = d * 0.1
        let size = CGSize(width: d + pad * 2, height: d + pad * 2)
        return sprite(texture(nil, size: size) { cg in
            let r = CGRect(x: pad, y: pad, width: d, height: d)
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -d * 0.03), blur: d * 0.08,
                         color: NSColor.black.withAlphaComponent(0.3).cgColor)
            cg.setFillColor(ring.cgColor)
            cg.fillEllipse(in: r)
            cg.restoreGState()
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillEllipse(in: r.insetBy(dx: d * 0.05, dy: d * 0.05))
            cg.saveGState()
            cg.addEllipse(in: r.insetBy(dx: d * 0.085, dy: d * 0.085))
            cg.clip()
            cg.interpolationQuality = .high
            cg.draw(img, in: r.insetBy(dx: d * 0.085, dy: d * 0.085))
            cg.restoreGState()
        })
    }

    // MARK: - Particles and scenery

    /// Soft white dot; tinted per particle.
    static var dot: SKTexture {
        texture("dot", size: CGSize(width: 32, height: 32)) { cg in
            let g = CGGradient(colorsSpace: nil, colors: [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0.9).cgColor,
                                                          NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                               locations: [0, 0.55, 1])!
            cg.drawRadialGradient(g, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                  endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
        }.0
    }

    static var starTexture: SKTexture {
        texture("star", size: CGSize(width: 48, height: 48)) { cg in
            cg.translateBy(x: 24, y: 24)
            cg.addPath(shapePath(.star, size: 44))
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillPath()
        }.0
    }

    static var heartTexture: SKTexture {
        texture("heart", size: CGSize(width: 48, height: 48)) { cg in
            cg.translateBy(x: 24, y: 24)
            cg.addPath(shapePath(.heart, size: 42))
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillPath()
        }.0
    }

    static var confettiTexture: SKTexture {
        texture("confetti", size: CGSize(width: 20, height: 12)) { cg in
            cg.addPath(CGPath(roundedRect: CGRect(x: 1, y: 1, width: 18, height: 10), cornerWidth: 4, cornerHeight: 4, transform: nil))
            cg.setFillColor(NSColor.white.cgColor)
            cg.fillPath()
        }.0
    }

    static func bubble(_ d: CGFloat) -> SKSpriteNode {
        sprite(texture("bubble|\(Int(d))", size: CGSize(width: d, height: d)) { cg in
            let r = CGRect(x: 1, y: 1, width: d - 2, height: d - 2)
            let c = CGPoint(x: d / 2, y: d / 2)
            let g = CGGradient(colorsSpace: nil, colors: [
                NSColor(hex: 0xFFFFFF, alpha: 0.05).cgColor, NSColor(hex: 0xBDE7FF, alpha: 0.18).cgColor,
                NSColor(hex: 0xFFB8E6, alpha: 0.45).cgColor, NSColor(hex: 0x9EF0FF, alpha: 0.7).cgColor,
            ] as CFArray, locations: [0, 0.6, 0.85, 1])!
            cg.addEllipse(in: r); cg.clip()
            cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: d / 2, options: [])
            cg.resetClip()
            cg.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
            cg.setLineWidth(max(1.5, d * 0.025))
            cg.strokeEllipse(in: r)
            cg.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            cg.fillEllipse(in: CGRect(x: d * 0.24, y: d * 0.62, width: d * 0.2, height: d * 0.13))
            cg.fillEllipse(in: CGRect(x: d * 0.5, y: d * 0.76, width: d * 0.07, height: d * 0.07))
        })
    }

    static func cloud(_ w: CGFloat, night: Bool) -> SKSpriteNode {
        let h = w * 0.55
        return sprite(texture("cloud|\(Int(w))|\(night)", size: CGSize(width: w, height: h)) { cg in
            // (centre x as a fraction of width, centre y as a fraction of height, diameter as a fraction of width)
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(0.22, 0.32, 0.3), (0.42, 0.5, 0.4), (0.64, 0.45, 0.36),
                                                        (0.8, 0.32, 0.26), (0.5, 0.25, 0.34)]
            func blob(_ dy: CGFloat, _ color: NSColor) {
                cg.setFillColor(color.cgColor)
                for (x, y, d) in puffs {
                    cg.fillEllipse(in: CGRect(x: w * x - w * d / 2, y: h * y - w * d / 2 + dy, width: w * d, height: w * d))
                }
            }
            blob(-h * 0.06, night ? NSColor(hex: 0x6A5FA8, alpha: 0.5) : NSColor(hex: 0xBFD9F2))
            blob(0, night ? NSColor(hex: 0x9B90D0, alpha: 0.55) : .white)
        })
    }

    static func rainbow(_ w: CGFloat) -> SKSpriteNode {
        let h = w * 0.52
        return sprite(texture("rainbow|\(Int(w))", size: CGSize(width: w, height: h)) { cg in
            let band = w * 0.045
            let c = CGPoint(x: w / 2, y: band)
            cg.setLineCap(.round)
            cg.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(band * 7 + band * 0.8)
            cg.addArc(center: c, radius: w / 2 - band * 4, startAngle: .pi, endAngle: 0, clockwise: true)
            cg.strokePath()
            for (i, col) in Palette.all.enumerated() {
                cg.setStrokeColor(col.cgColor)
                cg.setLineWidth(band + 0.5)
                cg.addArc(center: c, radius: w / 2 - band * 1 - CGFloat(i) * band, startAngle: .pi, endAngle: 0, clockwise: true)
                cg.strokePath()
            }
        })
    }

    /// Gradient for skies: colours run top → bottom.
    static func gradient(_ colors: [NSColor], size: CGSize) -> SKSpriteNode {
        sprite(texture("grad|\(colors.map(\.hexKey).joined())", size: CGSize(width: 8, height: 256)) { cg in
            let g = CGGradient(colorsSpace: nil, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            cg.drawLinearGradient(g, start: CGPoint(x: 0, y: 256), end: .zero, options: [])
        }).then { $0.size = size }
    }

    // MARK: - Shapes

    static func shapePath(_ kind: ShapeKind, size s: CGFloat) -> CGPath {
        let r = s / 2
        switch kind {
        case .circle:
            return CGPath(ellipseIn: CGRect(x: -r, y: -r, width: s, height: s), transform: nil)
        case .square:
            let q = s * 0.86
            return CGPath(roundedRect: CGRect(x: -q / 2, y: -q / 2, width: q, height: q), cornerWidth: q * 0.2, cornerHeight: q * 0.2, transform: nil)
        case .triangle:
            let pts = (0..<3).map { i -> CGPoint in
                let a = CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 3
                return CGPoint(x: cos(a) * r * 1.08, y: sin(a) * r * 1.08 - r * 0.12)
            }
            return roundedPolygon(pts, radius: s * 0.1)
        case .star:
            let pts = (0..<10).map { i -> CGPoint in
                let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let rr = i % 2 == 0 ? r : r * 0.48
                return CGPoint(x: cos(a) * rr, y: sin(a) * rr - r * 0.04)
            }
            return roundedPolygon(pts, radius: s * 0.045)
        case .heart:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: -r * 0.9))
            p.addCurve(to: CGPoint(x: -r, y: r * 0.25), control1: CGPoint(x: -r * 0.55, y: -r * 0.45), control2: CGPoint(x: -r, y: -r * 0.1))
            p.addCurve(to: CGPoint(x: 0, y: r * 0.55), control1: CGPoint(x: -r, y: r * 0.85), control2: CGPoint(x: -r * 0.2, y: r * 0.95))
            p.addCurve(to: CGPoint(x: r, y: r * 0.25), control1: CGPoint(x: r * 0.2, y: r * 0.95), control2: CGPoint(x: r, y: r * 0.85))
            p.addCurve(to: CGPoint(x: 0, y: -r * 0.9), control1: CGPoint(x: r, y: -r * 0.1), control2: CGPoint(x: r * 0.55, y: -r * 0.45))
            p.closeSubpath()
            return p
        }
    }

    static func roundedPolygon(_ pts: [CGPoint], radius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let n = pts.count
        let start = CGPoint(x: (pts[n - 1].x + pts[0].x) / 2, y: (pts[n - 1].y + pts[0].y) / 2)
        p.move(to: start)
        for i in 0..<n {
            p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % n], radius: radius)
        }
        p.closeSubpath()
        return p
    }
}

extension NSColor {
    var hexKey: String {
        guard let c = usingColorSpace(.sRGB) else { return "x" }
        return String(format: "%02X%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255), Int(c.alphaComponent * 255))
    }

    func mixed(with other: NSColor, _ t: CGFloat) -> NSColor {
        blended(withFraction: t, of: other) ?? self
    }
}

protocol Then {}
extension Then where Self: AnyObject {
    @discardableResult func then(_ f: (Self) -> Void) -> Self { f(self); return self }
}
extension SKNode: Then {}
