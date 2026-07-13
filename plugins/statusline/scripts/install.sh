#!/usr/bin/env bash
#
# Installer for the Claude Code "working directory + usage limits" status line.
#
# Installs ./statusline.sh to ~/.claude/statusline.sh and adds the matching
# `statusLine` block to ~/.claude/settings.json.
#
# Versioning: refuses to downgrade. If the already-installed script is a newer
# semver than the one in this bundle, it is left untouched (override with --force).
#
# Usage:
#   ./install.sh           # install or upgrade
#   ./install.sh --force   # install even if it would be a downgrade / re-install
#   ./install.sh --quiet   # errors only (used by the plugin's SessionStart
#                          # auto-update hook — must stay silent on success)
#
set -eu

FORCE=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --quiet) QUIET=1 ;;
    *) printf 'ERROR: unknown option: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

# Informational output; silenced by --quiet (errors still reach stderr).
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$1"; }

TS=$(date +%Y%m%d-%H%M%S)
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_SCRIPT="$SRC_DIR/statusline.sh"
DEST_DIR="$HOME/.claude"
DEST_SCRIPT="$DEST_DIR/statusline.sh"
SETTINGS="$DEST_DIR/settings.json"

err() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[ -f "$SRC_SCRIPT" ] || err "statusline.sh not found next to this installer."

read_version() { sed -n 's/^# version: *//p' "$1" 2>/dev/null | head -1; }

# Returns 0/1/2 for newer/equal/older of $1 vs $2 (semver major.minor.patch).
# Echoes: "newer" | "equal" | "older" | "unknown"
semver_cmp() {
  a="$1"; b="$2"
  case "$a" in ''|*[!0-9.]*) echo unknown; return;; esac
  case "$b" in ''|*[!0-9.]*) echo unknown; return;; esac
  IFS=. read -r a1 a2 a3 <<EOF
$a
EOF
  IFS=. read -r b1 b2 b3 <<EOF
$b
EOF
  a1=${a1:-0}; a2=${a2:-0}; a3=${a3:-0}
  b1=${b1:-0}; b2=${b2:-0}; b3=${b3:-0}
  # A 4th component ends up appended to $a3/$b3 as "0.1" — not an integer, so
  # `[ -gt ]` would abort the whole installer under `set -e`. Treat as unknown.
  for c in "$a1" "$a2" "$a3" "$b1" "$b2" "$b3"; do
    case "$c" in ''|*[!0-9]*) echo unknown; return;; esac
  done
  for pair in "$a1 $b1" "$a2 $b2" "$a3 $b3"; do
    set -- $pair
    if [ "$1" -gt "$2" ]; then echo newer; return; fi
    if [ "$1" -lt "$2" ]; then echo older; return; fi
  done
  echo equal
}

BUNDLE_VER=$(read_version "$SRC_SCRIPT")
[ -n "$BUNDLE_VER" ] || err "bundle statusline.sh has no '# version:' line."

mkdir -p "$DEST_DIR"

# --- Decide whether to (over)write the script ---------------------------------
DO_INSTALL=1
if [ -f "$DEST_SCRIPT" ]; then
  INSTALLED_VER=$(read_version "$DEST_SCRIPT")
  REL=$(semver_cmp "$BUNDLE_VER" "${INSTALLED_VER:-}")
  case "$REL" in
    newer)   say "Upgrading status line: v${INSTALLED_VER} -> v${BUNDLE_VER}" ;;
    equal)   if [ "$FORCE" -eq 1 ]; then say "Reinstalling v${BUNDLE_VER} (--force)";
             else say "Already up to date (v${BUNDLE_VER}); skipping script."; DO_INSTALL=0; fi ;;
    older)   if [ "$FORCE" -eq 1 ]; then say "Downgrading v${INSTALLED_VER} -> v${BUNDLE_VER} (--force)";
             else say "Installed v${INSTALLED_VER} is newer than bundle v${BUNDLE_VER} — not downgrading. Use --force to override."; DO_INSTALL=0; fi ;;
    unknown) say "Installed version unrecognized; replacing with v${BUNDLE_VER}." ;;
  esac
else
  say "Installing status line v${BUNDLE_VER} (fresh)."
fi

if [ "$DO_INSTALL" -eq 1 ]; then
  if [ -f "$DEST_SCRIPT" ]; then
    BAK="$DEST_SCRIPT.bak-${INSTALLED_VER:-unknown}-${TS}"
    cp "$DEST_SCRIPT" "$BAK"
    say "  backed up existing script -> $BAK"
  fi
  cp "$SRC_SCRIPT" "$DEST_SCRIPT"
  chmod +x "$DEST_SCRIPT"
  say "  installed -> $DEST_SCRIPT"
fi

# --- Merge the statusLine block into settings.json ----------------------------
PY=$(command -v python3 || command -v python || command -v python2 || true)
if [ -z "$PY" ]; then
  say 'NOTE: no Python interpreter found. Add this to '"$SETTINGS"' manually:
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 5 }
Also: without python3, the status line shows only the path (no model/limits).'
else
  SETTINGS="$SETTINGS" SETTINGS_BAK="$SETTINGS.bak-$TS" SL_QUIET="$QUIET" "$PY" - <<'PYEOF'
import json, os, shutil, sys

def say(msg):
    if os.environ.get("SL_QUIET") != "1":
        print(msg)
p = os.environ["SETTINGS"]
bak = os.environ["SETTINGS_BAK"]
existed = os.path.exists(p)
if existed:
    # An existing-but-unreadable settings.json must ABORT, not be replaced with
    # a minimal {statusLine} object — that would silently drop the user's
    # hooks, permissions and env.
    try:
        with open(p) as f:
            data = json.load(f)
    except (IOError, OSError, ValueError) as e:
        sys.stderr.write(
            "ERROR: %s exists but is not valid JSON (%s).\n"
            "Fix it (or move it aside) and re-run, or add this block manually:\n"
            '  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 5 }\n'
            % (p, e))
        sys.exit(1)
    if not isinstance(data, dict):
        sys.stderr.write("ERROR: %s is valid JSON but not an object; not touching it.\n" % p)
        sys.exit(1)
else:
    data = {}
# refreshInterval re-runs the script every N seconds even while the session is
# idle (otherwise renders are event-driven only and the countdown/account
# segments go stale). Preserve a user-customized value on upgrade.
desired = {"type": "command", "command": "~/.claude/statusline.sh",
           "refreshInterval": 5}
current = data.get("statusLine")
if isinstance(current, dict) and isinstance(current.get("refreshInterval"), (int, float)):
    desired["refreshInterval"] = current["refreshInterval"]
if current == desired:
    say("settings.json already configured; no change.")
else:
    if existed:
        shutil.copyfile(p, bak)            # back up only when about to change
        say("Backed up settings -> " + bak)
    data["statusLine"] = desired
    with open(p, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    say("Wrote statusLine block to settings.json.")
PYEOF
fi

say "Done. Open a new Claude Code session (or reload) to see the footer."
say "Tip: 'python3' enables the full footer (model + usage limits); without it you get the path only."
