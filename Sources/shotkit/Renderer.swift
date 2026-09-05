//
//  Renderer.swift — composes one App Store screenshot.
//
//  Everything is drawn into a CoreGraphics bitmap with a top-left origin so
//  the layout math reads like a design tool. Text goes through AppKit's
//  string drawing (which is how we get San Francisco and proper wrapping for
//  free); everything else is plain CoreGraphics.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Canvas

final class Canvas {
    let width: Int
    let height: Int
    let cg: CGContext
    private let ns: NSGraphicsContext

    var W: CGFloat { CGFloat(width) }
    var H: CGFloat { CGFloat(height) }

    init(width: Int, height: Int) throws {
        self.width = width
        self.height = height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                 bytesPerRow: 0, space: space,
                                 // No alpha channel: App Store Connect rejects transparent PNGs.
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ShotError.message("Could not create a \(width)×\(height) bitmap") }
        cg.translateBy(x: 0, y: CGFloat(height))
        cg.scaleBy(x: 1, y: -1)
        cg.setShouldAntialias(true)
        cg.interpolationQuality = .high
        self.cg = cg
        self.ns = NSGraphicsContext(cgContext: cg, flipped: true)
    }

    /// Runs AppKit drawing (string drawing, NSImage) against this canvas.
    func withAppKit(_ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    func pngData() throws -> Data {
        guard let image = cg.makeImage() else { throw ShotError.message("Could not rasterize canvas") }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw ShotError.message("Could not create PNG encoder") }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ShotError.message("PNG encode failed") }
        return data as Data
    }

    // MARK: Primitives

    func fill(_ rect: CGRect, _ color: CGColor) {
        cg.setFillColor(color)
        cg.fill(rect)
    }

    func drawBackground(_ bg: Background) {
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        guard bg.colors.count > 1 else { fill(rect, bg.colors[0]); return }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let locations = (0..<bg.colors.count).map { CGFloat($0) / CGFloat(bg.colors.count - 1) }
        guard let gradient = CGGradient(colorsSpace: space, colors: bg.colors as CFArray, locations: locations)
        else { fill(rect, bg.colors[0]); return }
        // CSS convention: 0° = to top, 90° = to right, 180° = to bottom.
        let a = bg.angle * .pi / 180
        let dir = CGVector(dx: sin(a), dy: -cos(a))
        let half = (abs(dir.dx) * W + abs(dir.dy) * H) / 2
        let c = CGPoint(x: W / 2, y: H / 2)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: c.x - dir.dx * half, y: c.y - dir.dy * half),
            end: CGPoint(x: c.x + dir.dx * half, y: c.y + dir.dy * half),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    /// Soft radial light behind the device — the cheap trick that separates
    /// "a screenshot on a color" from "a product shot".
    func drawGlow(center: CGPoint, radius: CGFloat, color: CGColor) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let clear = color.copy(alpha: 0),
              let gradient = CGGradient(colorsSpace: space, colors: [color, clear] as CFArray, locations: [0, 1])
        else { return }
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                              endCenter: center, endRadius: radius, options: [])
    }

    /// Draws an image right-side up into a rect in top-left coordinates.
    func drawImage(_ image: CGImage, in rect: CGRect) {
        cg.saveGState()
        cg.translateBy(x: rect.minX, y: rect.maxY)
        cg.scaleBy(x: 1, y: -1)
        cg.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        cg.restoreGState()
    }

    func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        let rad = min(radius, r.width / 2, r.height / 2)
        return CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
    }

    func drawDevice(_ image: CGImage, geometry g: FrameGeometry, style: FrameStyle, rotation: CGFloat) {
        cg.saveGState()
        if rotation != 0 {
            let c = CGPoint(x: g.outer.midX, y: g.outer.midY)
            cg.translateBy(x: c.x, y: c.y)
            cg.rotate(by: rotation)
            cg.translateBy(x: -c.x, y: -c.y)
        }
        if style.shadow {
            cg.saveGState()
            // Shadow offsets are in base space (y up), so negative = downward.
            cg.setShadow(offset: CGSize(width: 0, height: -g.outer.width * 0.035),
                         blur: g.outer.width * 0.10,
                         color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55))
            cg.addPath(roundedPath(g.outer, g.outerRadius))
            cg.setFillColor(style.color)
            cg.fillPath()
            cg.restoreGState()
        }
        // Body
        cg.addPath(roundedPath(g.outer, g.outerRadius))
        cg.setFillColor(style.color)
        cg.fillPath()
        // Edge highlight — a hairline of light along the bezel
        let lw = max(2, g.outer.width * 0.0035)
        cg.addPath(roundedPath(g.outer.insetBy(dx: lw / 2, dy: lw / 2), g.outerRadius - lw / 2))
        cg.setStrokeColor(style.highlight)
        cg.setLineWidth(lw)
        cg.strokePath()
        // Screen
        cg.saveGState()
        cg.addPath(roundedPath(g.screen, g.screenRadius))
        cg.clip()
        drawImage(image, in: g.screen)
        cg.restoreGState()
        cg.restoreGState()
    }
}

extension Canvas {
    /// A cropped region of the capture, enlarged into a floating card.
    func drawCallout(_ image: CGImage, crop: CGRect, in rect: CGRect, style: FrameStyle, radiusFraction: CGFloat = 0.035) {
        guard let sub = image.cropping(to: crop) else { return }
        let radius = rect.width * radiusFraction
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -rect.width * 0.03), blur: rect.width * 0.09,
                     color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6))
        cg.addPath(roundedPath(rect, radius))
        cg.setFillColor(style.color)
        cg.fillPath()
        cg.restoreGState()
        cg.saveGState()
        cg.addPath(roundedPath(rect, radius))
        cg.clip()
        drawImage(sub, in: rect)
        cg.restoreGState()
        let lw = max(2, rect.width * 0.003)
        cg.addPath(roundedPath(rect.insetBy(dx: lw / 2, dy: lw / 2), radius - lw / 2))
        cg.setStrokeColor(style.highlight)
        cg.setLineWidth(lw)
        cg.strokePath()
    }
}

// MARK: - Device frame geometry

struct FrameGeometry {
    let outer: CGRect
    let screen: CGRect
    let outerRadius: CGFloat
    let screenRadius: CGFloat

    static func bezelFraction(_ kind: DeviceKind) -> CGFloat { kind == .phone ? 0.022 : 0.030 }

    /// Frame height for a given frame width (linear, so scaling is exact).
    static func height(forWidth w: CGFloat, kind: DeviceKind, aspect: CGFloat) -> CGFloat {
        let b = w * bezelFraction(kind)
        return (w - 2 * b) * aspect + 2 * b
    }

    static func make(kind: DeviceKind, frameWidth: CGFloat, top: CGFloat, centerX: CGFloat, aspect: CGFloat) -> FrameGeometry {
        let bezel = frameWidth * bezelFraction(kind)
        let screenW = frameWidth - 2 * bezel
        let outer = CGRect(x: centerX - frameWidth / 2, y: top,
                           width: frameWidth, height: screenW * aspect + 2 * bezel)
        let screen = outer.insetBy(dx: bezel, dy: bezel)
        let screenRadius = screenW * (kind == .phone ? 0.118 : 0.020)
        return FrameGeometry(outer: outer, screen: screen,
                             outerRadius: screenRadius + bezel, screenRadius: screenRadius)
    }
}

// MARK: - Captions

struct CaptionBlock {
    let title: NSAttributedString
    let subtitle: NSAttributedString?
    let subGap: CGFloat
    let titleHeight: CGFloat
    let subtitleHeight: CGFloat

    var height: CGFloat { titleHeight + (subtitle == nil ? 0 : subGap + subtitleHeight) }

    static let drawingOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    static func measure(_ s: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(s.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                            options: drawingOptions).height)
    }

    /// Draws the block vertically centered in `rect` (which may be taller
    /// than the block when a uniform caption band is in use).
    func draw(in rect: CGRect, on canvas: Canvas) {
        let y0 = rect.minY + max(0, (rect.height - height) / 2)
        canvas.withAppKit {
            title.draw(with: NSRect(x: rect.minX, y: y0, width: rect.width, height: titleHeight + 4),
                       options: Self.drawingOptions)
            if let subtitle {
                subtitle.draw(with: NSRect(x: rect.minX, y: y0 + titleHeight + subGap,
                                           width: rect.width, height: subtitleHeight + 4),
                              options: Self.drawingOptions)
            }
        }
    }
}

enum Fonts {
    static func weight(_ name: String) -> NSFont.Weight {
        switch name.lowercased() {
        case "black": return .black
        case "heavy": return .heavy
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        default: return .regular
        }
    }

    static func managerWeight(_ name: String) -> Int {
        switch name.lowercased() {
        case "black": return 12
        case "heavy": return 11
        case "bold": return 9
        case "semibold": return 8
        case "medium": return 6
        case "light": return 3
        default: return 5
        }
    }

    /// "system" (SF Pro), "system-rounded", "system-serif" (New York), or any
    /// installed family name.
    static func make(_ family: String, size: CGFloat, weight: String) -> NSFont {
        let system = NSFont.systemFont(ofSize: size, weight: Self.weight(weight))
        switch family.lowercased() {
        case "", "system", "sf", "sf pro":
            return system
        case "system-rounded", "rounded":
            return NSFont(descriptor: system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor, size: size) ?? system
        case "system-serif", "serif", "new york":
            return NSFont(descriptor: system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor, size: size) ?? system
        default:
            if let f = NSFontManager.shared.font(withFamily: family, traits: [], weight: managerWeight(weight), size: size) { return f }
            if let f = NSFont(name: family, size: size) { return f }
            FileHandle.standardError.write("warning: font \"\(family)\" not found, using system font\n".data(using: .utf8)!)
            return system
        }
    }
}

struct CaptionBuilder {
    let style: CaptionStyle

    /// `**word**` inside a caption is set in the accent color.
    private func attributed(_ text: String, font: NSFont, color: CGColor, accent: CGColor,
                            lineHeight: CGFloat, tracking: CGFloat) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = style.align.lowercased() == "left" ? .left : .center
        para.lineBreakMode = .byWordWrapping
        para.lineHeightMultiple = lineHeight
        let out = NSMutableAttributedString()
        for (i, part) in text.components(separatedBy: "**").enumerated() where !part.isEmpty {
            let fg = NSColor(cgColor: i % 2 == 1 ? accent : color) ?? .white
            out.append(NSAttributedString(string: part, attributes: [
                .font: font, .foregroundColor: fg, .paragraphStyle: para, .kern: tracking,
            ]))
        }
        return out
    }

    /// Builds the block, shrinking the title until it fits `maxLines`.
    func build(title: String, subtitle: String?, baseSize: CGFloat, width: CGFloat) -> CaptionBlock {
        var size = baseSize
        var titleAttr: NSAttributedString
        var titleH: CGFloat
        let minSize = baseSize * 0.6
        while true {
            let font = Fonts.make(style.font, size: size, weight: style.weight)
            titleAttr = attributed(title, font: font, color: style.color, accent: style.accent,
                                   lineHeight: 0.94, tracking: -size * 0.025)
            titleH = CaptionBlock.measure(titleAttr, width: width)
            let lineH = ceil(font.ascender - font.descender + font.leading) * 0.94
            let lines = Int((titleH / lineH).rounded())
            if lines <= style.maxLines || size <= minSize { break }
            size *= 0.94
        }
        var subAttr: NSAttributedString?
        var subH: CGFloat = 0
        if let subtitle, !subtitle.isEmpty {
            let subSize = size * 0.46
            let font = Fonts.make(style.font, size: subSize, weight: "medium")
            subAttr = attributed(subtitle, font: font, color: style.subColor, accent: style.accent,
                                 lineHeight: 1.08, tracking: 0)
            subH = CaptionBlock.measure(subAttr!, width: width)
        }
        return CaptionBlock(title: titleAttr, subtitle: subAttr, subGap: size * 0.32,
                            titleHeight: titleH, subtitleHeight: subH)
    }
}

// MARK: - Layout

struct Placement {
    let captionRect: CGRect
    let frame: FrameGeometry
    let rotation: CGFloat
    var card: CGRect? = nil
}

enum Layout {
    static func place(_ kind: LayoutKind, canvas W: CGFloat, _ H: CGFloat, device: Device,
                      captionHeight: CGFloat, frameFraction: CGFloat, aspect: CGFloat,
                      zoom: Zoom? = nil, cardScale: CGFloat = 0.94) -> Placement {
        let padTop = H * 0.055
        let padSide = W * 0.07
        let padBottom = H * 0.06
        let gap = H * 0.035
        let textW = W - 2 * padSide

        switch kind {
        case .captionTop:
            let cap = CGRect(x: padSide, y: padTop, width: textW, height: captionHeight)
            let g = FrameGeometry.make(kind: device.kind, frameWidth: W * frameFraction,
                                       top: cap.maxY + gap, centerX: W / 2, aspect: aspect)
            return Placement(captionRect: cap, frame: g, rotation: 0)

        case .captionBottom:
            let cap = CGRect(x: padSide, y: H - padTop - captionHeight, width: textW, height: captionHeight)
            let fw = W * frameFraction
            let fh = FrameGeometry.height(forWidth: fw, kind: device.kind, aspect: aspect)
            let g = FrameGeometry.make(kind: device.kind, frameWidth: fw,
                                       top: cap.minY - gap - fh, centerX: W / 2, aspect: aspect)
            return Placement(captionRect: cap, frame: g, rotation: 0)

        case .full, .tilt:
            let cap = CGRect(x: padSide, y: padTop, width: textW, height: captionHeight)
            let availTop = cap.maxY + gap
            let availH = H - availTop - padBottom
            var fw = W * frameFraction
            let fhFull = FrameGeometry.height(forWidth: fw, kind: device.kind, aspect: aspect)
            if fhFull > availH { fw *= availH / fhFull }
            if kind == .tilt { fw *= 0.93 }
            let fh = FrameGeometry.height(forWidth: fw, kind: device.kind, aspect: aspect)
            let g = FrameGeometry.make(kind: device.kind, frameWidth: fw,
                                       top: availTop + (availH - fh) / 2, centerX: W / 2, aspect: aspect)
            return Placement(captionRect: cap, frame: g, rotation: kind == .tilt ? -6 * .pi / 180 : 0)

        case .callout:
            // Card = the zoom region at 94% canvas width. The device sits
            // behind it, positioned so the card covers exactly that region on
            // the device's own screen (its head — status bar — shows above).
            let z = zoom ?? Zoom(x: 0, y: 0, w: 1, h: 0.2)
            let cap = CGRect(x: padSide, y: padTop, width: textW, height: captionHeight)
            let cardW = W * cardScale
            let cardH = cardW * (z.h / z.w) * aspect
            let g0 = FrameGeometry.make(kind: device.kind, frameWidth: W * frameFraction,
                                        top: 0, centerX: W / 2, aspect: aspect)
            let head = (g0.screen.minY - g0.outer.minY) + z.y * g0.screen.height
            let frameTop = cap.maxY + gap
            let g = FrameGeometry.make(kind: device.kind, frameWidth: W * frameFraction,
                                       top: frameTop, centerX: W / 2, aspect: aspect)
            let card = CGRect(x: (W - cardW) / 2, y: frameTop + head, width: cardW, height: cardH)
            return Placement(captionRect: cap, frame: g, rotation: 0, card: card)
        }
    }
}

// MARK: - Images

enum Images {
    static func load(_ url: URL) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { throw ShotError.message("Cannot read image \(url.path)") }
        return img
    }

    static func hasAlpha(_ img: CGImage) -> Bool {
        switch img.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }
}

// MARK: - Renderer

struct Renderer {
    let spec: Spec

    /// The caption as it will be typeset for this device — used to size a
    /// uniform band across the set before anything is rendered.
    func captionBlock(for shot: Shot, on device: Device) -> CaptionBlock {
        let W = CGFloat(device.width)
        let baseSize = (shot.captionSize ?? spec.theme.caption.size ?? (device.kind == .phone ? 0.078 : 0.058)) * W
        return CaptionBuilder(style: spec.theme.caption).build(
            title: shot.caption(for: device.id), subtitle: shot.subcaption(for: device.id),
            baseSize: baseSize, width: W - 2 * W * 0.07)
    }

    /// Renders one shot for one device and returns the output URL.
    /// `captionBand`, when given, is the height reserved for the caption.
    func render(_ shot: Shot, on device: Device, captionBand: CGFloat? = nil) throws -> URL {
        guard let srcURL = shot.source[device.id] else {
            throw ShotError.message("Shot \"\(shot.id)\" has no source for \(device.id)")
        }
        let image = try Images.load(srcURL)
        let imgAspect = CGFloat(image.height) / CGFloat(image.width)
        let devAspect = CGFloat(device.height) / CGFloat(device.width)
        if abs(imgAspect - devAspect) / devAspect > 0.02 {
            FileHandle.standardError.write(
                "warning: \(srcURL.lastPathComponent) is \(image.width)×\(image.height); \(device.id) expects the \(device.width)×\(device.height) aspect — the screen will look stretched\n".data(using: .utf8)!)
        }

        let canvas = try Canvas(width: device.width, height: device.height)
        let W = canvas.W, H = canvas.H
        let bg = shot.background ?? spec.theme.background
        canvas.drawBackground(bg)

        let block = captionBlock(for: shot, on: device)

        let zoom = shot.zoom[device.id] ?? shot.zoom["default"] ?? spec.theme.zoom[device.id] ?? spec.theme.zoom["default"]
        if shot.layout == .callout, zoom == nil {
            throw ShotError.message("Shot \"\(shot.id)\" uses the callout layout but no zoom region is set for \(device.id) (theme.zoom or shot.zoom)")
        }
        let frameFraction = shot.frameScale ?? spec.theme.frame.scale(for: device.id)
            ?? (shot.layout == .callout ? 0.76 : (device.kind == .phone ? 0.88 : 0.86))
        let p = Layout.place(shot.layout, canvas: W, H, device: device, captionHeight: max(block.height, captionBand ?? 0),
                             frameFraction: frameFraction, aspect: imgAspect, zoom: zoom,
                             cardScale: shot.cardScale ?? spec.theme.card.scale)

        if let glow = bg.glow {
            let focus = p.card ?? p.frame.outer
            canvas.drawGlow(center: CGPoint(x: focus.midX, y: p.card == nil ? focus.minY + focus.width * 0.45 : focus.midY),
                            radius: W * 0.85, color: glow)
        }
        canvas.drawDevice(image, geometry: p.frame, style: spec.theme.frame, rotation: p.rotation)
        if let card = p.card, let z = zoom {
            let crop = CGRect(x: z.x * CGFloat(image.width), y: z.y * CGFloat(image.height),
                              width: z.w * CGFloat(image.width), height: z.h * CGFloat(image.height))
            canvas.drawCallout(image, crop: crop, in: card, style: spec.theme.frame,
                               radiusFraction: spec.theme.card.radius)
        }
        block.draw(in: p.captionRect, on: canvas)

        let dir = spec.outputDir.appendingPathComponent(device.id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent(shot.fileStem + ".png")
        try canvas.pngData().write(to: out)
        return out
    }
}

// MARK: - Contact sheet

enum ContactSheet {
    /// Tiles every PNG under `dir` (one row per device folder) so a whole set
    /// can be reviewed at a glance — including by Claude, via Read.
    static func make(dir: URL, out: URL) throws {
        let fm = FileManager.default
        var rows: [(label: String, files: [URL])] = []
        let subdirs = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        for sub in subdirs {
            let pngs = pngFiles(in: sub)
            if !pngs.isEmpty { rows.append((sub.lastPathComponent, pngs)) }
        }
        let loose = pngFiles(in: dir).filter { $0.lastPathComponent != out.lastPathComponent }
        if !loose.isEmpty { rows.append((dir.lastPathComponent, loose)) }
        guard !rows.isEmpty else { throw ShotError.message("No PNGs found under \(dir.path)") }

        let thumbH: CGFloat = 640, gap: CGFloat = 28, labelH: CGFloat = 44
        var images: [[CGImage]] = []
        var rowWidths: [CGFloat] = []
        for row in rows {
            let imgs = try row.files.map(Images.load)
            images.append(imgs)
            let w = imgs.reduce(0) { $0 + thumbH * CGFloat($1.width) / CGFloat($1.height) } + gap * CGFloat(imgs.count + 1)
            rowWidths.append(w)
        }
        let sheetW = Int(rowWidths.max()!.rounded(.up))
        let sheetH = Int((CGFloat(rows.count) * (thumbH + labelH + gap) + gap).rounded(.up))
        let canvas = try Canvas(width: sheetW, height: sheetH)
        canvas.fill(CGRect(x: 0, y: 0, width: canvas.W, height: canvas.H), CGColor(gray: 0.12, alpha: 1))

        var y = gap
        for (r, row) in rows.enumerated() {
            let label = NSAttributedString(string: "\(row.label)  —  \(row.files.count) screenshot\(row.files.count == 1 ? "" : "s")", attributes: [
                .font: NSFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: NSColor(white: 0.85, alpha: 1),
            ])
            canvas.withAppKit { label.draw(at: NSPoint(x: gap, y: y)) }
            y += labelH
            var x = gap
            for img in images[r] {
                let w = thumbH * CGFloat(img.width) / CGFloat(img.height)
                canvas.drawImage(img, in: CGRect(x: x, y: y, width: w, height: thumbH))
                x += w + gap
            }
            y += thumbH + gap
        }
        try canvas.pngData().write(to: out)
    }

    static func pngFiles(in dir: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
