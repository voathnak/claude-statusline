#!/usr/bin/env bash
# version: 1.3.0
# Claude Code status line (two rows).
# Line 1: v<ver> · <model> · ⚙ <effort> · 5h: <left>% (⏳ <countdown>) · wk: <left>% · 📁 <cwd>
# Line 2: <N>% ctx · ↑ <sent tokens> · ↓ <received tokens>
# (No $ cost: cost.total_cost_usd is an API-list-price estimate, not the actual
#  bill on a team/subscription plan, so it is intentionally omitted.)
# Path goes last because it varies in length and can grow; version goes first so
# it is always visible. Bump the "# version:" line above — it is the single
# source of truth, read both here and by install.sh.
#
# Line 2 token totals are CUMULATIVE for the session, summed from the transcript
# JSONL (the payload's context_window.* are current-context only since CC 2.1.132).
# ↑ sent = input + cache_creation + cache_read ; ↓ received = output.
# Claude Code pipes session JSON to this script on stdin.
#
# Parsing is done by an inline Python block (works on both Python 3 and 2).
# If no Python interpreter is found, falls back to a sed path-only line.

input=$(cat)

# Single source of truth: the "# version:" line at the top of this file.
SL_VERSION=$(sed -n 's/^# version: *//p' "$0" | head -1)
export SL_VERSION

PY=$(command -v python3 || command -v python || command -v python2)

if [ -n "$PY" ]; then
  printf '%s' "$input" | "$PY" -c '
import json, sys, os, time

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

home = os.environ.get("HOME", "")
ws = d.get("workspace") or {}
path = ws.get("current_dir") or d.get("cwd") or ""
if home and path.startswith(home):
    path = "~" + path[len(home):]

parts = []

ver = os.environ.get("SL_VERSION")
if ver:
    parts.append("v" + ver)

model = (d.get("model") or {}).get("display_name")
if model:
    parts.append(model)

effort = (d.get("effort") or {}).get("level")
if effort:
    parts.append("⚙ " + effort)

rl = d.get("rate_limits") or {}

fh = rl.get("five_hour") or {}
if "used_percentage" in fh:
    seg = "5h: %d%%" % (100 - fh["used_percentage"])
    ra = fh.get("resets_at")
    if ra:
        secs = int(ra - time.time())
        if secs > 0:
            seg += " (⏳ %dh%dm)" % (secs // 3600, (secs % 3600) // 60)
    parts.append(seg)

sd = rl.get("seven_day") or {}
if "used_percentage" in sd:
    parts.append("wk: %d%%" % (100 - sd["used_percentage"]))

parts.append("📁 " + path)

# ---- Line 2: cost + context + cumulative session tokens --------------------
def human(n):
    if n >= 1000000:
        return "%.1fM" % (n / 1000000.0)
    if n >= 1000:
        return "%.1fk" % (n / 1000.0)
    return str(int(n))

line2 = []

cw = d.get("context_window") or {}
ctx = cw.get("used_percentage")
if ctx is not None:
    line2.append("%d%% ctx" % ctx)

# Sum cumulative tokens from the session transcript.
tp = d.get("transcript_path")
if tp and os.path.exists(tp):
    sent = recv = 0
    try:
        f = open(tp)
        try:
            for line in f:
                if "\"usage\"" not in line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                u = (o.get("message") or {}).get("usage")
                if not u:
                    continue
                sent += (u.get("input_tokens", 0)
                         + u.get("cache_creation_input_tokens", 0)
                         + u.get("cache_read_input_tokens", 0))
                recv += u.get("output_tokens", 0)
        finally:
            f.close()
    except Exception:
        sent = recv = 0
    if sent or recv:
        line2.append("↑ " + human(sent))
        line2.append("↓ " + human(recv))

out = " · ".join(parts)
if line2:
    out += "\n" + " · ".join(line2)
sys.stdout.write(out)
'
else
  # No Python available: best-effort version + path-only line.
  dir=$(printf '%s' "$input" | sed -n 's/.*"current_dir":"\([^"]*\)".*/\1/p')
  printf 'v%s · 📁 %s' "$SL_VERSION" "${dir/#$HOME/~}"
fi
