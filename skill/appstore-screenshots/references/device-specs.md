# Device specs — sizes App Store Connect accepts

Portrait pixel sizes. Only the two marked **required** must be uploaded;
Apple scales them for the smaller classes. Add others only when the user asks
(they let you show device-specific layouts).

| id           | Device class                        | Pixels      | Status   | Simulator to capture on         |
|--------------|-------------------------------------|-------------|----------|---------------------------------|
| `iphone-6.9` | iPhone 6.9" (16/17 Pro Max)         | 1320 × 2868 | required | iPhone 17 Pro Max               |
| `iphone-6.7` | iPhone 6.7" (14/15 Plus, Pro Max)   | 1290 × 2796 | optional | iPhone 15 Pro Max               |
| `iphone-6.5` | iPhone 6.5" (11 Pro Max, XS Max)    | 1284 × 2778 | optional | iPhone 11 Pro Max               |
| `iphone-6.3` | iPhone 6.3" (16/17 Pro)             | 1206 × 2622 | optional | iPhone 17 Pro                   |
| `iphone-6.1` | iPhone 6.1" (14/15 Pro)             | 1179 × 2556 | optional | iPhone 15 Pro                   |
| `iphone-5.5` | iPhone 5.5" (8 Plus)                | 1242 × 2208 | optional | iPhone 8 Plus (old runtime)     |
| `ipad-13`    | iPad 13" (Pro M4/M5)                | 2064 × 2752 | required | iPad Pro 13-inch (M5)           |
| `ipad-12.9`  | iPad 12.9" (Pro 2nd–6th gen)        | 2048 × 2732 | optional | iPad Pro (12.9-inch) (6th gen)  |
| `ipad-11`    | iPad 11" (Pro M4, Air)              | 1668 × 2420 | optional | iPad Pro 11-inch (M4)           |

`shotkit devices` prints the same table from the binary's own list, which is
what `verify` checks against.

Notes

- `xcrun simctl io <udid> screenshot` captures at exact device pixels, so a
  capture from the right simulator is already the right size. `verify`
  flags anything that isn't.
- App Store Connect rejects PNGs with an alpha channel. `shotkit` renders
  without one; raw simulator captures *do* carry alpha, which is one reason
  not to upload raws directly.
- Landscape variants exist for every class; this kit renders portrait only,
  which is what the App Store shows by default for these apps.
- Apple revises this list with new hardware. When a size here isn't accepted
  or a new "required" class appears, check
  https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
  and update `Device.all` in `Sources/shotkit/Spec.swift`.
