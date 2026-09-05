# ASO rules for screenshots — what converts, and why

## 1. Start from the objection, not the feature list

Every buyer arrives with one question that decides the purchase. For a
utility it's usually "does this actually do the thing correctly?"; for a
consumer app "will this be a hassle?"; for a subscription "what's the catch?".
Name it in one sentence before drafting captions. Then:

- **Shot 1 (hero)** — identity + promise. Who this is for and what they get,
  in the buyer's own words. It is the screenshot shown in search results and
  it carries the tap-through.
- **Shot 2** — the objection, answered with something *visible*. A result
  that matches a known answer, a "no account" screen, an offline indicator.
  Also shown in search results on most devices.
- **Shots 3–6** — one idea each, in descending order of buyer value. Stop
  when the next shot would be "and also…". Apple allows 10; conversion for
  utilities flattens after about five.

## 2. Captions

- ≤ 6 words for the title, ≤ 10 for the subcaption. Big type at 1320 px
  wide fits about 22 characters per line; two lines maximum.
- Lead with the benefit ("Mortgage payment in four entries"), not the
  feature ("TVM solver"). Feature names belong in the subcaption if at all.
- Put the payoff phrase in the accent color (`**like this**`). One accent
  per caption; keep it on one line.
- Match the searcher's words. Captions aren't indexed, but a person who
  typed "amortization" and sees "amortization" in shot 3 converts.
- Every claim must be true in that exact screenshot. "214 examples verified"
  needs a screenshot that shows it, or it goes in the description instead.
- Numbers beat adjectives. "Six regressions" beats "powerful statistics".
- Same voice across the set: all fragments or all sentences, never mixed.

## 3. What's on screen

- Real app state with real-looking data — a populated result, not an empty
  form. The display should show the *answer*, not the input.
- Status bar: 9:41, full battery (not charging), Wi-Fi. This is Apple's own
  convention and reads as "finished".
- No keyboard unless the shot is about typing. No debug overlays, no
  simulator artifacts, no personal data.
- Show the same theme (light/dark) across the set unless a shot's point is
  the theme.

## 4. Composition

- Caption above, device below, device cropped at the bottom (`caption-top`)
  is the highest-converting default because it puts the words where the eye
  lands first and makes the phone feel large.
- Keep the device at the same position in every shot (the kit's uniform
  caption band does this). A set that "jumps" while swiping reads as
  amateur.
- If every shot shows the same chrome (a keypad, a map, a table) and the
  difference between shots is one small region, the set reads as "the same
  picture six times" at thumbnail size. Use `callout` to lift that region
  into its own card; the chrome becomes context instead of the subject.
- Use `full` or `tilt` for one shot at most, usually the hero, never the
  whole set.
- Background from the app's palette. A dark, slightly gradient background
  with a soft glow behind the device is the safe default for dark UIs; for
  light UIs use an off-white/light-tint background with dark captions.
- Contrast: captions must pass at a glance on a 3-inch thumbnail — check the
  contact sheet, not the full-size file.

## 5. What Apple rejects or that ages badly

- Star ratings, review quotes, "5 stars", "#1", awards, "featured by Apple".
- Prices or "free" (prices vary by storefront and change).
- Competitor names or logos; Android/other-platform devices.
- Mockups of features that aren't in the build (Guideline 2.3.3: screenshots
  show the app in use).
- Title art / splash screens as screenshots (also 2.3.3).
- Text small enough to be unreadable at thumbnail size.

## 6. After launch

- **Product Page Optimization** (App Store Connect ▸ app ▸ Product Page
  Optimization) A/B-tests alternate screenshot sets against the original
  with real traffic. Test one variable: a different hero caption, or a
  light vs dark theme. Needs a few hundred impressions a day to conclude.
- Refresh screenshots when the hero feature changes, not on every point
  release — but do re-render from the spec whenever the UI shifts so the
  set never shows a stale interface.
- If localizing the listing, localize the captions too; a translated
  description over English screenshots halves the credibility of both.
