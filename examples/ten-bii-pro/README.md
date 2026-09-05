# Ten BII Pro — example shot set

Six iPhone 6.9" and three iPad 13" shots for a financial calculator, with a
per-device hero caption and a "proof" shot that puts a manual-verified answer
on screen.

`shots.json` is the source of truth; `raw/` holds the simulator captures;
`out/<device>/` holds the files to upload, numbered in upload order.

Layout is `caption-top` (the device's own display, keypad running off the
bottom). The `callout` layout was tried on this set and rejected as too loud
for a calculator whose display is already the top of the screen.

## Shot list

| # | File          | Caption                                          | On screen                                    |
|---|---------------|--------------------------------------------------|----------------------------------------------|
| 1 | `01-mortgage` | The 10bII+ **you already know** *(iPad: Buy once. iPhone and iPad.)* | 30-yr $400k @ 6.5% → PMT −2,528.27 |
| 2 | `02-proof`    | Manual says 133,006.39. **So does this.**        | Manual Table 6-5: $930/mo @ 7.5% → PV 133,006.39 |
| 3 | `03-npv`      | NPV & IRR on **uneven cash flows**               | −10k, 3k, 4k, 5k, 6k @ 10% → NPV 3,887.71     |
| 4 | `04-amort`    | Full **amortization** schedules                  | AMORT months 1–12, INT phase → −25,868.38    |
| 5 | `05-regr`     | Six regressions, **plus Best Fit**               | REGR menu on `0--BEST FIT`                   |
| 6 | `06-bonds`    | Bond price, YTM, **yield to call**               | Manual Table 10-3 → yield to call 5.72       |

iPhone 6.9" gets all six; iPad 13" gets 1–3. Shots 1–2 are what App Store
search results show.

## How each raw was captured

Simulators: **iPhone 17 Pro Max** and **iPad Pro 13-inch (M5)**, both iOS 26.5.
Debug build launched with the `DEMO_KEYS` environment hook
(`Support/DemoKeystrokes.swift`), one token per key press, `o:`/`b:` = orange/blue shift:

| Raw            | `DEMO_KEYS` |
|----------------|-------------|
| `01-mortgage`  | `3 6 0 N 6 . 5 I/YR 4 0 0 0 0 0 PV 0 FV PMT` |
| `02-proof`     | `1 2 o:P/YR 3 0 o:xP/YR 0 FV 7 . 5 I/YR 9 3 0 +/− PMT PV` |
| `03-npv`       | `1 o:P/YR 1 0 0 0 0 +/− CFj 3 0 0 0 CFj 4 0 0 0 CFj 5 0 0 0 CFj 6 0 0 0 CFj 1 0 I/YR o:NPV` |
| `04-amort`     | `3 6 0 N 6 . 5 I/YR 4 0 0 0 0 0 PV 0 FV PMT 1 INPUT 1 2 o:AMORT = =` |
| `05-regr`      | `3 2 INPUT 4 1 5 Σ+ 3 5 INPUT 5 1 5 Σ+ 3 8 INPUT 7 2 5 Σ+ b:REGR −` |
| `06-bonds`     | `b:Semi/Ann 5 . 5 b:CPN% 1 0 4 b:CALL 1 0 1 b:PRICE 1 0 . 1 5 2 0 2 0 b:MatDate 4 . 1 5 2 0 1 2 b:SetDate b:YTM` |

```bash
KIT=~/Documents/GitHub/kevinbrowncodes/appstore-screenshot-kit
"$KIT/scripts/capture.sh" --sim "iPhone 17 Pro Max" --bundle-id kevinbrowncodes.TenBiiProCalculator \
  --app "$APP" --env DEMO_KEYS="3 6 0 N 6 . 5 I/YR 4 0 0 0 0 0 PV 0 FV PMT" --out raw/iphone/01-mortgage.png
```
