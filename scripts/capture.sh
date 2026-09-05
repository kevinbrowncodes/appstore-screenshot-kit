#!/usr/bin/env bash
#
# capture.sh — one reproducible simulator screenshot at exact device pixels.
#
#   capture.sh --sim "iPhone 17 Pro Max" --bundle-id com.example.app --out raw/iphone/01-hero.png \
#              [--app /path/To.app] [--env KEY=VALUE ...] [--wait 2.5] [--time 9:41] [--no-launch]
#
# Boots the simulator if needed, sets the Apple-style status bar (9:41, full
# battery, Wi-Fi), optionally installs the app, launches it with the given
# environment (delivered via SIMCTL_CHILD_*), waits, and captures a PNG.
# Works with macOS's stock bash 3.2.
#
set -euo pipefail

usage() {
  sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

SIM=""; BUNDLE=""; OUT=""; APP=""; WAIT="2.5"; TIME="9:41"; LAUNCH=1
ENVS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim)        SIM="$2"; shift 2 ;;
    --bundle-id)  BUNDLE="$2"; shift 2 ;;
    --out)        OUT="$2"; shift 2 ;;
    --app)        APP="$2"; shift 2 ;;
    --env)        ENVS+=("$2"); shift 2 ;;
    --wait)       WAIT="$2"; shift 2 ;;
    --time)       TIME="$2"; shift 2 ;;
    --no-launch)  LAUNCH=0; shift ;;
    -h|--help)    usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done
[[ -n "$SIM" && -n "$OUT" ]] || usage
[[ $LAUNCH -eq 0 || -n "$BUNDLE" ]] || { echo "--bundle-id is required unless --no-launch" >&2; usage; }

udid_for() {  # $1 = name, $2 = optional state filter
  xcrun simctl list devices available | grep -F "$1 (" | { [[ -n "${2:-}" ]] && grep -F "($2)" || cat; } \
    | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}
UDID="$(udid_for "$SIM" Booted || true)"
[[ -n "$UDID" ]] || UDID="$(udid_for "$SIM" || true)"
[[ -n "$UDID" ]] || { echo "No simulator named '$SIM'. See: xcrun simctl list devices available" >&2; exit 1; }

if ! xcrun simctl list devices | grep -F "$UDID" | grep -q "(Booted)"; then
  xcrun simctl boot "$UDID"
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null

# Apple's marketing status bar: 9:41, full (not charging) battery, strong signal.
xcrun simctl status_bar "$UDID" override \
  --time "$TIME" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100

[[ -n "$APP" ]] && xcrun simctl install "$UDID" "$APP"

if [[ $LAUNCH -eq 1 ]]; then
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  ENVARGS=()
  for kv in ${ENVS[@]+"${ENVS[@]}"}; do ENVARGS+=("SIMCTL_CHILD_$kv"); done
  env ${ENVARGS[@]+"${ENVARGS[@]}"} xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
fi

sleep "$WAIT"
mkdir -p "$(dirname "$OUT")"
xcrun simctl io "$UDID" screenshot --type png "$OUT" >/dev/null
SIZE="$(sips -g pixelWidth -g pixelHeight "$OUT" | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w"x"h}')"
echo "captured $OUT ($SIZE)"
