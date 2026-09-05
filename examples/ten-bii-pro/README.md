# Ten BII Pro — example shot set

Four iPhone 6.9" shots and two iPad 13" shots for a financial calculator,
with per-device hero captions. Regenerate with:

```bash
shotkit render examples/ten-bii-pro/shots.json
shotkit contact examples/ten-bii-pro/out && open examples/ten-bii-pro/out/contact-sheet.png
```

## How the raw captures were made

Captured with `xcrun simctl` on **iPhone 17 Pro Max** and **iPad Pro 13-inch
(M5)**, status bar overridden to 9:41, app launched with the debug-only
`DEMO_KEYS` environment hook (`Support/DemoKeystrokes.swift` in the app repo)
that replays a key sequence at launch. Tokens are key labels; `o:` / `b:`
prefix the orange / blue shift.

| Raw file            | State                              | `DEMO_KEYS`                                  |
|---------------------|------------------------------------|----------------------------------------------|
| `01-mortgage.png`   | 30-yr, $400k @ 6.5% → PMT −2,528.27 | `360 N 6.5 I/YR 400000 PV 0 FV PMT`          |
| `02-npv.png`        | NPV of a cash-flow list → 18,528.69 | *not recorded — capture again and note it*   |
| `03-amort.png`      | AMORT, INT phase → −2,144.53        | *not recorded — capture again and note it*   |
| `04-stats.png`      | Statistics editor, 2 points         | *not recorded — capture again and note it*   |

These raws predate the kit; the three unrecorded sequences are the reason
the skill insists on writing the sequence down at capture time. Next
recapture, run e.g.:

```bash
scripts/capture.sh --sim "iPhone 17 Pro Max" --bundle-id kevinbrowncodes.TenBiiProCalculator \
  --app "$APP" --env DEMO_KEYS="360 N 6.5 I/YR 400000 PV 0 FV PMT" --out raw/iphone/01-mortgage.png
```

Note the existing raws show a *charging* battery; `capture.sh` now uses a
full, discharging battery, which is Apple's convention.
