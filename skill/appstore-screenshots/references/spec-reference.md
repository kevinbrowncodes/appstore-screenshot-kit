# shots.json — every field

Paths are relative to the spec file. Every field except `shots[].id`,
`shots[].caption` and `shots[].source` is optional.

```jsonc
{
  "app": "Ten BII Pro",                 // used in log output only
  "devices": ["iphone-6.9", "ipad-13"], // ids from `shotkit devices`; default = these two
  "output": "out",                      // output dir; files land in out/<device-id>/NN-<shot-id>.png

  "theme": {
    "background": {
      "colors": ["#0B1626", "#1B3050"], // 1 color = solid; 2+ = linear gradient
      "angle": 160,                     // CSS convention: 0 = to top, 90 = to right, 180 = to bottom
      "glow": "#F28C2838"               // soft radial light behind the device; "none" to disable
    },
    "caption": {
      "color": "#FFFFFF",               // title color
      "accent": "#F5A94A",              // color for **accented** words; defaults to `color`
      "subColor": "#FFFFFFB8",          // subcaption color (8-digit hex = with alpha)
      "font": "system",                 // "system" (SF Pro) | "system-rounded" | "system-serif" | any installed family
      "weight": "bold",                 // black | heavy | bold | semibold | medium | regular | light
      "size": 0.078,                    // title size as a fraction of canvas width; default 0.078 phone / 0.058 pad
      "align": "center",                // center | left
      "maxLines": 2,                    // title auto-shrinks (to 60%) until it fits this many lines
      "band": "uniform"                 // uniform = reserve the tallest caption's height on every shot
                                        //           so the device sits at the same y across the set; or "fit"
    },
    "zoom": {                           // callout crop per device id ("default" = any), fractions of the raw
      "iphone-6.9": { "x": 0, "y": 0.0994, "w": 1, "h": 0.1757 },
      "ipad-13":    { "x": 0, "y": 0.0472, "w": 1, "h": 0.1842 }
    },
    "card": { "scale": 0.88, "radius": 0.035 },  // callout card width / corner radius, as fractions of canvas / card width
    "frame": {
      "color": "#0A0A0C",               // device body color
      "highlight": "#FFFFFF33",         // hairline along the bezel edge
      "shadow": true,
      "scale": 0.88,                    // frame width as a fraction of canvas width; default 0.88 phone / 0.86 pad / 0.76 callout
      "scaleByDevice": { "ipad-13": 0.66 }  // per-device frame width; wins over `scale`. For callout, tune it so the
                                        // card's bottom edge lands on a seam in the UI beneath (a row gap), not through content
    }
  },

  "shots": [
    {
      "id": "mortgage",                 // unique; becomes part of the filename
      "layout": "callout",              // caption-top (default) | caption-bottom | full | tilt | callout
      "caption": "The 10bII+ **you already know**",   // **…** = accent color; "\n" forces a line break
      "subcaption": "Same keys. Same shifts. Same answers — verified.",
      "captionOverrides":    { "ipad-13": "Buy once. **iPhone and iPad.**" },  // per-device text
      "subcaptionOverrides": { "ipad-13": "Universal — one purchase, both devices" },
      "source": {                       // raw capture per device; a device with no source is skipped
        "iphone-6.9": "raw/iphone/01-mortgage.png",
        "ipad-13":    "raw/ipad/01-mortgage.png"
      },
      "background": { "colors": ["#1A1A2E", "#16213E"] },  // per-shot override of any background field
      "zoom": { "default": { "x": 0, "y": 0.1, "w": 1, "h": 0.18 } },  // per-shot callout crop override
      "cardScale": 0.9,                 // per-shot callout card width override
      "frameScale": 0.9,                // per-shot frame width override
      "captionSize": 0.075              // per-shot title size override
    }
  ]
}
```

## Layouts

| layout           | What it does                                                                 | Use for                    |
|------------------|------------------------------------------------------------------------------|----------------------------|
| `caption-top`    | Caption band at the top; device below, running off the bottom edge.          | Almost every shot          |
| `caption-bottom` | Device runs off the top edge; caption at the bottom.                         | A shot whose point is at the bottom of the screen |
| `full`           | Entire device visible below the caption, scaled to fit.                      | Hero when the whole UI matters |
| `tilt`           | Like `full`, device rotated −6° with shadow.                                 | One shot per set, at most  |
| `callout`        | The `zoom` region of the capture lifted into a card (`card.scale` wide) floating over the device, which sits behind so its head (status bar) shows above the card and the body below. | Apps whose story lives in one small region — a readout, a result row, a chart. Measure `zoom` from the raw; don't eyeball it. |

Sizing a callout: the card's bottom edge should land on a seam in the UI
beneath it. Card width and the seam you choose together fix the device
width — `frame.scaleByDevice = card.scale × zoom.h ÷ (seam − zoom.y)`, all as
fractions, then ÷ (1 − 2 × bezel) for the frame. A shallow seam (just below
the first row under the region) with `card.scale` ≈ 0.88 gives a subtle
~1.1× lift with a near-full-width device; a deep seam with 0.94 gives a loud
1.4× magnifier over a small device. Start subtle.

## CLI

```
shotkit render  shots.json [--only SHOT_ID] [--device DEVICE_ID] [--out DIR]
shotkit contact OUT_DIR [--out FILE.png]     tile every output for review (Read the PNG)
shotkit verify  OUT_DIR                      sizes, alpha, ≤10 per device; exit 1 on any problem
shotkit devices                              device ids and pixel sizes
shotkit init    DIR                          starter shots.json + raw/ folders
```

Warnings go to stderr: a raw capture whose aspect ratio doesn't match its
device (it would render stretched), and a font family that isn't installed.
