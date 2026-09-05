#!/usr/bin/env bash
# Installs the Claude Code skill and builds/links the shotkit binary.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

mkdir -p "$SKILLS" "$HOME/.local/bin"
ln -sfn "$KIT/skill/appstore-screenshots" "$SKILLS/appstore-screenshots"
echo "skill   → $SKILLS/appstore-screenshots"

(cd "$KIT" && swift build -c release 2>&1 | tail -1)
ln -sfn "$KIT/.build/release/shotkit" "$HOME/.local/bin/shotkit"
echo "binary  → ~/.local/bin/shotkit"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "note: ~/.local/bin is not on PATH — the skill falls back to $KIT/.build/release/shotkit" ;;
esac
echo "done. In Claude Code: ask for App Store screenshots, or /appstore-screenshots"
