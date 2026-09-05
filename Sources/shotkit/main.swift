//
//  main.swift — shotkit CLI.
//
//    shotkit render  shots.json [--only ID] [--device ID] [--out DIR]
//    shotkit contact OUT_DIR    [--out FILE.png]
//    shotkit verify  OUT_DIR
//    shotkit devices
//    shotkit init    DIR
//

import Foundation

struct CLI {
    var positional: [String] = []
    var options: [String: String] = [:]
    var flags: Set<String> = []

    init(_ args: [String]) {
        var i = 0
        while i < args.count {
            let a = args[i]
            if a.hasPrefix("--") {
                let key = String(a.dropFirst(2))
                if i + 1 < args.count, !args[i + 1].hasPrefix("--") {
                    options[key] = args[i + 1]; i += 2
                } else {
                    flags.insert(key); i += 1
                }
            } else {
                positional.append(a); i += 1
            }
        }
    }
}

func usage() -> Never {
    print("""
    shotkit — App Store screenshot compositor (captions + device frames + verified sizes)

    USAGE
      shotkit render  <shots.json> [--only SHOT_ID] [--device DEVICE_ID] [--out DIR]
      shotkit contact <OUT_DIR> [--out FILE.png]      tile every output for review
      shotkit verify  <OUT_DIR>                       check sizes, alpha, and counts
      shotkit devices                                 list device ids and pixel sizes
      shotkit init    <DIR>                           write a starter shots.json

    The spec format is documented in skill/appstore-screenshots/references/spec-reference.md
    """)
    exit(2)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

let starterSpec = """
{
  "app": "My App",
  "devices": ["iphone-6.9", "ipad-13"],
  "output": "out",
  "theme": {
    "background": { "colors": ["#0F172A", "#1E293B"], "angle": 160, "glow": "#FFFFFF22" },
    "caption":    { "color": "#FFFFFF", "accent": "#7DD3FC", "subColor": "#FFFFFFB3", "font": "system", "weight": "bold" },
    "frame":      { "color": "#0B0B0D", "shadow": true }
  },
  "shots": [
    {
      "id": "hero",
      "layout": "caption-top",
      "caption": "The one line that **sells the app**",
      "subcaption": "A supporting sentence, in the buyer's words",
      "source": { "iphone-6.9": "raw/iphone/01.png", "ipad-13": "raw/ipad/01.png" }
    }
  ]
}

"""

let cli = CLI(Array(CommandLine.arguments.dropFirst()))
guard let command = cli.positional.first else { usage() }

do {
    switch command {
    case "render":
        guard cli.positional.count >= 2 else { usage() }
        var spec = try Spec.load(URL(fileURLWithPath: cli.positional[1]))
        if let out = cli.options["out"] { spec.outputDir = URL(fileURLWithPath: out) }
        let renderer = Renderer(spec: spec)
        let devices = cli.options["device"].map { id in spec.devices.filter { $0.id == id } } ?? spec.devices
        if devices.isEmpty { fail("--device \(cli.options["device"]!) is not in the spec's device list") }
        let shots = cli.options["only"].map { id in spec.shots.filter { $0.id == id } } ?? spec.shots
        if shots.isEmpty { fail("--only \(cli.options["only"]!) matches no shot id") }

        print("\(spec.app): \(shots.count) shot\(shots.count == 1 ? "" : "s") × \(devices.count) device\(devices.count == 1 ? "" : "s") → \(spec.outputDir.path)")
        var rendered = 0
        for device in devices {
            // Uniform band: the frame sits at the same y in every shot of the set.
            let band: CGFloat? = spec.theme.caption.band.lowercased() == "fit" ? nil :
                shots.filter { $0.source[device.id] != nil }
                     .map { renderer.captionBlock(for: $0, on: device).height }.max()
            for shot in shots {
                guard shot.source[device.id] != nil else {
                    print("  – \(device.id)/\(shot.fileStem)  (no source for this device, skipped)")
                    continue
                }
                let url = try renderer.render(shot, on: device, captionBand: band)
                print("  ✓ \(device.id)/\(url.lastPathComponent)  \(device.width)×\(device.height)")
                rendered += 1
            }
        }
        print("rendered \(rendered) file\(rendered == 1 ? "" : "s")")

    case "contact":
        guard cli.positional.count >= 2 else { usage() }
        let dir = URL(fileURLWithPath: cli.positional[1])
        let out = cli.options["out"].map { URL(fileURLWithPath: $0) } ?? dir.appendingPathComponent("contact-sheet.png")
        try ContactSheet.make(dir: dir, out: out)
        print("wrote \(out.path)")

    case "verify":
        guard cli.positional.count >= 2 else { usage() }
        let dir = URL(fileURLWithPath: cli.positional[1])
        let fm = FileManager.default
        var folders = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if folders.isEmpty { folders = [dir] }
        var problems = 0
        for folder in folders {
            let files = ContactSheet.pngFiles(in: folder).filter { $0.lastPathComponent != "contact-sheet.png" }
            guard !files.isEmpty else { continue }
            print("\(folder.lastPathComponent)/")
            if files.count > 10 {
                print("  ✗ \(files.count) screenshots — App Store Connect accepts at most 10 per device"); problems += 1
            }
            for f in files {
                let img = try Images.load(f)
                var notes: [String] = []
                if let d = Device.match(width: img.width, height: img.height) {
                    notes.append(d.required ? "\(d.id)" : "\(d.id) (optional size)")
                } else {
                    notes.append("NOT an App Store size"); problems += 1
                }
                if Images.hasAlpha(img) { notes.append("HAS ALPHA CHANNEL"); problems += 1 }
                let bytes = (try? fm.attributesOfItem(atPath: f.path)[.size] as? Int) ?? 0
                let ok = !notes.contains { $0.hasPrefix("NOT") || $0.hasPrefix("HAS") }
                print("  \(ok ? "✓" : "✗") \(f.lastPathComponent)  \(img.width)×\(img.height)  \(bytes / 1024) KB  \(notes.joined(separator: ", "))")
            }
        }
        if problems > 0 { fail("\(problems) problem\(problems == 1 ? "" : "s") found") }
        print("all screenshots pass")

    case "devices":
        func pad(_ s: String, _ n: Int) -> String { s + String(repeating: " ", count: max(1, n - s.count)) }
        print(pad("id", 12) + pad("device", 37) + pad("pixels", 12) + "status")
        for d in Device.all {
            print(pad(d.id, 12) + pad(d.name, 37) + pad("\(d.width)×\(d.height)", 12) + (d.required ? "required" : "optional"))
        }

    case "init":
        guard cli.positional.count >= 2 else { usage() }
        let dir = URL(fileURLWithPath: cli.positional[1])
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("raw/iphone"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("raw/ipad"), withIntermediateDirectories: true)
        let spec = dir.appendingPathComponent("shots.json")
        guard !FileManager.default.fileExists(atPath: spec.path) else { fail("\(spec.path) already exists") }
        try starterSpec.write(to: spec, atomically: true, encoding: .utf8)
        print("wrote \(spec.path)\nput raw captures in \(dir.path)/raw/{iphone,ipad}/ then: shotkit render \(spec.path)")

    case "-h", "--help", "help":
        usage()
    default:
        fail("unknown command \"\(command)\"")
    }
} catch {
    fail("\(error)")
}
