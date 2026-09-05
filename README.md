# appstore-screenshot-kit

Beautiful, ASO-optimized App Store screenshots from a JSON shot list — and a
Claude Code skill that runs the whole workflow: plan the shots from the
app's value proposition, capture them reproducibly from the simulator,
compose captions and device frames, verify against App Store Connect's specs.

```
raw simulator capture  +  shots.json  ──shotkit──▶  out/iphone-6.9/01-hero.png  (1320×2868, no alpha)
                                                    out/ipad-13/01-hero.png     (2064×2752, no alpha)
```

- **`shotkit`** — a zero-dependency Swift CLI. Native AppKit rendering, so
  captions are set in San Francisco (or any installed font) with real
  wrapping and kerning; output is exact device pixels with no alpha channel,
  which is what App Store Connect requires.
- **`scripts/capture.sh`** — one reproducible simulator screenshot: boots the
  device, sets the 9:41 / full-battery status bar, launches the app with a
  given environment, captures.
- **`skill/appstore-screenshots`** — the Claude Code skill: the workflow,
  the ASO rules, the device specs, and the spec reference.

## Install

```bash
git clone https://github.com/kevinbrowncodes/appstore-screenshot-kit
cd appstore-screenshot-kit && ./install.sh
```

That symlinks the skill into `~/.claude/skills/`, builds the binary, and
links it to `~/.local/bin/shotkit`. Requires Xcode (Swift 5.9+, macOS 13+).

## Quick start

```bash
shotkit init appstore/screenshots          # starter shots.json + raw/ folders
# drop simulator captures into raw/iphone and raw/ipad, edit the captions, then:
shotkit render  appstore/screenshots/shots.json
shotkit contact appstore/screenshots/out   # one PNG tiling the whole set
shotkit verify  appstore/screenshots/out   # sizes, alpha, counts
```

Or, in Claude Code: *"make App Store screenshots for this app"* — the skill
plans the captions with you before anything is captured.

## The spec

```json
{
  "app": "Ten BII Pro",
  "devices": ["iphone-6.9", "ipad-13"],
  "theme": {
    "background": { "colors": ["#0B1626", "#1B3050"], "angle": 160, "glow": "#F28C2838" },
    "caption":    { "color": "#FFFFFF", "accent": "#F5A94A" },
    "frame":      { "color": "#0A0A0C", "shadow": true }
  },
  "shots": [
    {
      "id": "mortgage",
      "caption": "The 10bII+ **you already know**",
      "subcaption": "Same keys. Same shifts. Same answers — verified.",
      "captionOverrides": { "ipad-13": "Buy once. **iPhone and iPad.**" },
      "source": { "iphone-6.9": "raw/iphone/01-mortgage.png", "ipad-13": "raw/ipad/01-mortgage.png" }
    }
  ]
}
```

`**bold**` marks the accent phrase; `\n` forces a line break; every field is
documented in [spec-reference.md](skill/appstore-screenshots/references/spec-reference.md).
Layouts: `caption-top` (default), `caption-bottom`, `full`, `tilt`.

Two things the compositor does that matter more than they sound:

- **Uniform caption band.** The tallest caption in a set sets the band for
  every shot on that device, so the phone sits at the same y in every frame
  and the set doesn't jump as a shopper swipes.
- **No alpha, exact pixels.** Raw simulator captures carry an alpha channel;
  App Store Connect rejects them. `verify` checks every output against the
  device table and fails on anything off.

## Example

[`examples/ten-bii-pro/`](examples/ten-bii-pro/) is a complete set for a
financial calculator: four iPhone shots, two iPad shots, per-device hero
captions. `shotkit render examples/ten-bii-pro/shots.json` regenerates it.

## Why ASO here

Screenshots are the largest conversion lever on the product page — the first
two iPhone shots appear in search results before anyone taps. The skill's
[aso-rules.md](skill/appstore-screenshots/references/aso-rules.md) is the
playbook: start from the buyer's one objection, hero = identity, shot 2 =
proof, one idea per shot, ≤ 6-word captions, benefits over features, and the
list of things Apple rejects (ratings, prices, competitor names, mockups of
features that don't exist).

## Device frames

Frames are drawn procedurally (rounded body, bezel, hairline highlight,
shadow) rather than from Apple's bezel artwork, so there's nothing to license
and nothing that goes stale with next year's hardware. Sizes come from
Apple's screenshot specifications; see
[device-specs.md](skill/appstore-screenshots/references/device-specs.md).

## License

MIT — see [LICENSE](LICENSE).
