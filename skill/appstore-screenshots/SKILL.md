---
name: appstore-screenshots
description: Produce beautiful, ASO-optimized App Store screenshots for an iOS/iPadOS app — plan the shot list from the app's value proposition and the buyer's top objection, capture reproducible raw screenshots from the simulator, compose captions and device frames with the shotkit compositor, verify against App Store Connect specs, and review the result visually. Use when Kevin asks for App Store screenshots, store/marketing screenshots, screenshot captions, or to refresh screenshots for a release.
---

# App Store Screenshots — plan, capture, compose, verify

The kit lives in the `appstore-screenshot-kit` repo: `shotkit` (a zero-dependency
Swift compositor) and `scripts/capture.sh`. This skill is the workflow around
them. Five phases; each ends with something the user can look at. Screenshots
are the single biggest conversion lever on the product page — the first two
iPhone shots appear *in search results* before anyone taps — so the planning
phase is not optional.

## 0. Locate the kit

```bash
KIT="$(cd "$(dirname "$(readlink ~/.claude/skills/appstore-screenshots)")/../.." && pwd)"
SHOTKIT="$KIT/.build/release/shotkit"
[ -x "$SHOTKIT" ] || (cd "$KIT" && swift build -c release)
"$SHOTKIT" devices     # sanity check + the device id list
```

## 1. Plan the shot list — before capturing anything

1. Read the app's store copy first: `appstore/ASO.md` or `appstore/SUBMISSION.md`
   if present, else the README. Captions must agree with the description's
   claims — a screenshot that promises something the listing doesn't is a
   review risk and a refund risk.
2. Name the buyer and their **one objection** (references/aso-rules.md §1).
   Every set has a hero that states the identity/promise and a second shot
   that answers the objection with something visible.
3. Draft 4–6 shots as a table — `#`, what's on screen (exact app state),
   caption (≤ 6 words, `**accent**` on the payoff phrase), subcaption
   (≤ 10 words, optional), layout. One idea per shot. Benefits, not menus.
   Every word in a caption must be true *in that screenshot*.
4. **Checkpoint: show the user the table and get a nod before capturing.**
   Captions are cheap to change now and expensive after.

## 2. Capture raw screenshots

- Required classes: **iPhone 6.9" (1320×2868)** and **iPad 13" (2064×2752)**.
  Apple scales these down for smaller devices; only add other sizes if the
  user asks. Simulators: `iPhone 17 Pro Max`, `iPad Pro 13-inch (M5)` — check
  `xcrun simctl list devices available`.
- **Reproducibility over hand-tapping.** Prefer a DEBUG-only launch-environment
  hook in the app that drives the UI into the state (Ten BII Pro's `DEMO_KEYS`
  replays a key sequence; see `Support/DemoKeystrokes.swift` there). If the
  app has none, add one, compiled out of release. Record the exact
  environment for each shot in the spec directory's README so the set can be
  regenerated next release.
- Build for the simulator, then capture:

```bash
xcodebuild -scheme <Scheme> -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build | tail -1
APP="$(xcodebuild -scheme <Scheme> -configuration Debug -sdk iphonesimulator \
  -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/<Name>.app"
"$KIT/scripts/capture.sh" --sim "iPhone 17 Pro Max" --bundle-id <bundle.id> --app "$APP" \
  --env DEMO_KEYS="360 N 6.5 I/YR 400000 PV 0 FV PMT" --out raw/iphone/01-hero.png
```

  `capture.sh` sets the Apple-style status bar (9:41, full battery, Wi-Fi) and
  captures at exact device pixels.
- **Read every raw capture before compositing.** Wrong state, keyboard up,
  empty display, debug overlay, wrong device size → recapture. The compositor
  can't fix a bad capture.

## 3. Write shots.json

- Location, in the *app's* repo: `appstore/screenshots/shots.json`, raw
  captures in `appstore/screenshots/raw/{iphone,ipad}/`, output to
  `appstore/screenshots/out/`. Commit the spec, the raws, and the rendered
  device folders (they are the submitted artifacts); never commit
  `contact-sheet.png`. `"$SHOTKIT" init appstore/screenshots` writes a starter.
- Theme from the app, not from taste: background dark for dark UIs, light for
  light UIs; `accent` = the app's accent color (check `Assets.xcassets` and the
  key UI colors in the capture); one theme across the whole set.
- Use `\n` in a caption to control wrapping. Never let an accent phrase split
  across lines. Per-device caption overrides exist for the iPad hero (a
  "buy once, both devices" message earns its place there).
- Every field: references/spec-reference.md.

## 4. Render and review

```bash
"$SHOTKIT" render appstore/screenshots/shots.json
"$SHOTKIT" contact appstore/screenshots/out      # writes out/contact-sheet.png
```

Then **Read the contact sheet and each hero at full resolution** and check,
in this order: caption ≤ 2 lines and accent phrase unbroken · device top edge
at the same y in every shot (the uniform band does this; if one shot differs,
its caption is too long) · nothing that matters cropped by the bottom edge ·
status bar reads 9:41 with a full battery · caption/background contrast ·
typos · each caption is literally true in its shot. Fix the spec, re-render;
never touch the PNGs.

## 5. Verify and deliver

```bash
"$SHOTKIT" verify appstore/screenshots/out      # must end with "all screenshots pass"
```

Then: record the final shot table in the app's `SUBMISSION.md`; commit to the
app repo; tell the user the upload order (files are numbered `01-…`), that
shots 1–2 are the ones search results show, and where to drop them:
App Store Connect ▸ app ▸ version ▸ *iPhone 6.9" Display* and *iPad 13" Display*.
If the listing is live, mention Product Page Optimization for A/B-testing a
second hero (references/aso-rules.md §6).

## Non-negotiables

- **Real UI only** (Guideline 2.3.3): every screenshot is the app running.
  Captions and frames decorate; they are never the content. No splash
  screens, no mockups of features that don't exist.
- Exact pixel sizes, no alpha channel, portrait for both classes, ≤ 10 per
  class. `verify` enforces all but portrait.
- Nothing in the image that Apple rejects or that dates: star ratings,
  review quotes, prices, "#1", awards, competitor names, other platforms'
  devices, real personal data, placeholder "Lorem".
- One theme, one status bar style, one caption voice across the set.
- Never commit `out/` into the kit repo — the app repo owns its screenshots.
- No GitHub Actions / hosted CI (Kevin's standing rule). Everything here is a
  local script.
