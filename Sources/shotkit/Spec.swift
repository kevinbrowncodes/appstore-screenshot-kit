//
//  Spec.swift — the shots.json format.
//
//  Two layers: the Codable *File structs mirror the JSON with every field
//  optional so a spec can be three lines long, and the resolved structs
//  below them carry the defaults the renderer actually draws with.
//

import Foundation
import CoreGraphics

enum ShotError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        if case .message(let m) = self { return m }
        return "error"
    }
}

// MARK: - Devices

enum DeviceKind { case phone, pad }

struct Device {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let kind: DeviceKind
    /// Required by App Store Connect today; the others are optional extras.
    let required: Bool

    var size: CGSize { CGSize(width: width, height: height) }

    // Portrait sizes from Apple's "Screenshot specifications" page. Verify
    // against developer.apple.com before relying on a size not marked required.
    static let all: [Device] = [
        Device(id: "iphone-6.9", name: "iPhone 6.9\" (16/17 Pro Max)", width: 1320, height: 2868, kind: .phone, required: true),
        Device(id: "iphone-6.7", name: "iPhone 6.7\" (14/15 Plus, Pro Max)", width: 1290, height: 2796, kind: .phone, required: false),
        Device(id: "iphone-6.5", name: "iPhone 6.5\" (11 Pro Max, XS Max)", width: 1284, height: 2778, kind: .phone, required: false),
        Device(id: "iphone-6.3", name: "iPhone 6.3\" (16/17 Pro)", width: 1206, height: 2622, kind: .phone, required: false),
        Device(id: "iphone-6.1", name: "iPhone 6.1\" (14/15 Pro)", width: 1179, height: 2556, kind: .phone, required: false),
        Device(id: "iphone-5.5", name: "iPhone 5.5\" (8 Plus)", width: 1242, height: 2208, kind: .phone, required: false),
        Device(id: "ipad-13", name: "iPad 13\" (Pro M4/M5)", width: 2064, height: 2752, kind: .pad, required: true),
        Device(id: "ipad-12.9", name: "iPad 12.9\" (Pro 2nd–6th gen)", width: 2048, height: 2732, kind: .pad, required: false),
        Device(id: "ipad-11", name: "iPad 11\" (Pro M4, Air)", width: 1668, height: 2420, kind: .pad, required: false),
    ]

    static func find(_ id: String) -> Device? { all.first { $0.id == id } }
    static func match(width: Int, height: Int) -> Device? {
        all.first { $0.width == width && $0.height == height }
    }
}

// MARK: - Raw (Codable) spec

struct SpecFile: Codable {
    var app: String?
    var devices: [String]?
    var output: String?
    var theme: ThemeFile?
    var shots: [ShotFile]
}

struct ThemeFile: Codable {
    var background: BackgroundFile?
    var caption: CaptionFile?
    var frame: FrameFile?
    /// Callout crop per device id ("default" applies to any device).
    var zoom: [String: ZoomFile]?
}

struct BackgroundFile: Codable {
    var colors: [String]?
    var angle: Double?
    var glow: String?
}

struct CaptionFile: Codable {
    var color: String?
    var accent: String?
    var subColor: String?
    var font: String?
    var weight: String?
    var size: Double?
    var align: String?
    var maxLines: Int?
    var band: String?
}

/// A region of the raw capture, as fractions of its width/height.
struct ZoomFile: Codable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

struct FrameFile: Codable {
    var color: String?
    var highlight: String?
    var shadow: Bool?
    var scale: Double?
    /// Per-device frame width, e.g. {"ipad-13": 0.66}; wins over `scale`.
    var scaleByDevice: [String: Double]?
}

struct ShotFile: Codable {
    var id: String
    var caption: String
    var subcaption: String?
    var layout: String?
    var source: [String: String]
    var captionOverrides: [String: String]?
    var subcaptionOverrides: [String: String]?
    var background: BackgroundFile?
    var frameScale: Double?
    var captionSize: Double?
    var zoom: [String: ZoomFile]?
}

// MARK: - Resolved spec

enum LayoutKind: String, CaseIterable {
    case captionTop = "caption-top"
    case captionBottom = "caption-bottom"
    case full
    case tilt
    /// The `zoom` region of the capture, enlarged into a card that floats
    /// over the device — for apps whose story lives in one small area.
    case callout
}

struct Zoom {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat

    static func resolve(_ f: [String: ZoomFile]?) throws -> [String: Zoom] {
        var out: [String: Zoom] = [:]
        for (k, z) in f ?? [:] {
            guard (0...1).contains(z.x), (0...1).contains(z.y), z.w > 0, z.h > 0,
                  z.x + z.w <= 1.0001, z.y + z.h <= 1.0001 else {
                throw ShotError.message("zoom \"\(k)\" must be fractions of the capture with x+w and y+h ≤ 1")
            }
            out[k] = Zoom(x: z.x, y: z.y, w: z.w, h: z.h)
        }
        return out
    }
}

struct Background {
    var colors: [CGColor]
    var angle: CGFloat
    var glow: CGColor?
}

struct CaptionStyle {
    var color: CGColor
    var accent: CGColor
    var subColor: CGColor
    var font: String
    var weight: String
    var size: CGFloat?
    var align: String
    var maxLines: Int
    /// "uniform" reserves the tallest caption's height for every shot on a
    /// device so the frame sits at the same y across the set; "fit" doesn't.
    var band: String
}

struct FrameStyle {
    var color: CGColor
    var highlight: CGColor
    var shadow: Bool
    var scale: CGFloat?
    var scaleByDevice: [String: CGFloat]

    func scale(for deviceID: String) -> CGFloat? { scaleByDevice[deviceID] ?? scale }
}

struct Theme {
    var background: Background
    var caption: CaptionStyle
    var frame: FrameStyle
    var zoom: [String: Zoom]
}

struct Shot {
    var id: String
    var index: Int
    var caption: String
    var subcaption: String?
    var layout: LayoutKind
    var source: [String: URL]
    var captionOverrides: [String: String]
    var subcaptionOverrides: [String: String]
    var background: Background?
    var frameScale: CGFloat?
    var captionSize: CGFloat?
    var zoom: [String: Zoom]

    func caption(for deviceID: String) -> String { captionOverrides[deviceID] ?? caption }
    func subcaption(for deviceID: String) -> String? { subcaptionOverrides[deviceID] ?? subcaption }

    /// Zero-padded ordinal so the files sort in upload order.
    var fileStem: String { String(format: "%02d-%@", index + 1, id) }
}

struct Spec {
    var app: String
    var devices: [Device]
    var outputDir: URL
    var theme: Theme
    var shots: [Shot]

    static func load(_ url: URL) throws -> Spec {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ShotError.message("Cannot read \(url.path): \(error.localizedDescription)") }

        let file: SpecFile
        do { file = try JSONDecoder().decode(SpecFile.self, from: data) }
        catch let DecodingError.keyNotFound(key, ctx) {
            throw ShotError.message("Spec is missing \"\(key.stringValue)\" at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch {
            throw ShotError.message("Spec is not valid JSON: \(error)")
        }

        let base = url.deletingLastPathComponent()
        let deviceIDs = file.devices ?? ["iphone-6.9", "ipad-13"]
        let devices = try deviceIDs.map { id -> Device in
            guard let d = Device.find(id) else {
                throw ShotError.message("Unknown device \"\(id)\". Known: \(Device.all.map(\.id).joined(separator: ", "))")
            }
            return d
        }

        let theme = try Theme.resolve(file.theme)
        let shots = try file.shots.enumerated().map { i, s -> Shot in
            guard let layout = LayoutKind(rawValue: s.layout ?? "caption-top") else {
                throw ShotError.message("Shot \"\(s.id)\": unknown layout \"\(s.layout!)\". Known: \(LayoutKind.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            var source: [String: URL] = [:]
            for (dev, path) in s.source {
                source[dev] = URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
            }
            return Shot(
                id: s.id, index: i, caption: s.caption, subcaption: s.subcaption, layout: layout,
                source: source,
                captionOverrides: s.captionOverrides ?? [:],
                subcaptionOverrides: s.subcaptionOverrides ?? [:],
                background: try s.background.map { try Background.resolve($0, fallback: theme.background) },
                frameScale: s.frameScale.map { CGFloat($0) },
                captionSize: s.captionSize.map { CGFloat($0) },
                zoom: try Zoom.resolve(s.zoom)
            )
        }

        let ids = shots.map(\.id)
        if Set(ids).count != ids.count {
            throw ShotError.message("Shot ids must be unique: \(ids)")
        }

        return Spec(
            app: file.app ?? url.deletingLastPathComponent().lastPathComponent,
            devices: devices,
            outputDir: URL(fileURLWithPath: file.output ?? "out", relativeTo: base).standardizedFileURL,
            theme: theme,
            shots: shots
        )
    }
}

extension Theme {
    static func resolve(_ f: ThemeFile?) throws -> Theme {
        let defaultBG = Background(
            colors: [try Color.parse("#0F172A"), try Color.parse("#1E293B")],
            angle: 160,
            glow: try Color.parse("#FFFFFF1F")
        )
        return Theme(
            background: try Background.resolve(f?.background, fallback: defaultBG),
            caption: CaptionStyle(
                color: try Color.parse(f?.caption?.color ?? "#FFFFFF"),
                accent: try Color.parse(f?.caption?.accent ?? f?.caption?.color ?? "#FFFFFF"),
                subColor: try Color.parse(f?.caption?.subColor ?? "#FFFFFFB3"),
                font: f?.caption?.font ?? "system",
                weight: f?.caption?.weight ?? "bold",
                size: f?.caption?.size.map { CGFloat($0) },
                align: f?.caption?.align ?? "center",
                maxLines: f?.caption?.maxLines ?? 2,
                band: f?.caption?.band ?? "uniform"
            ),
            frame: FrameStyle(
                color: try Color.parse(f?.frame?.color ?? "#0B0B0D"),
                highlight: try Color.parse(f?.frame?.highlight ?? "#FFFFFF33"),
                shadow: f?.frame?.shadow ?? true,
                scale: f?.frame?.scale.map { CGFloat($0) },
                scaleByDevice: (f?.frame?.scaleByDevice ?? [:]).mapValues { CGFloat($0) }
            ),
            zoom: try Zoom.resolve(f?.zoom)
        )
    }
}

extension Background {
    static func resolve(_ f: BackgroundFile?, fallback: Background) throws -> Background {
        guard let f else { return fallback }
        var bg = fallback
        if let colors = f.colors, !colors.isEmpty { bg.colors = try colors.map(Color.parse) }
        if let angle = f.angle { bg.angle = CGFloat(angle) }
        if let glow = f.glow { bg.glow = glow.lowercased() == "none" ? nil : try Color.parse(glow) }
        return bg
    }
}

// MARK: - Colors

enum Color {
    /// "#RGB", "#RRGGBB" or "#RRGGBBAA" → sRGB CGColor.
    static func parse(_ s: String) throws -> CGColor {
        var hex = s.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6 || hex.count == 8, let v = UInt64(hex, radix: 16) else {
            throw ShotError.message("Bad color \"\(s)\" — use #RRGGBB or #RRGGBBAA")
        }
        let hasAlpha = hex.count == 8
        let r = CGFloat((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = CGFloat((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = CGFloat((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? CGFloat(v & 0xFF) / 255 : 1
        return CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
