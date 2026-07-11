#!/usr/bin/env bash
# version: 1.5.0
# Claude Code status line (two rows).
# Line 1: v<ver> · <model> · ⚙ <effort> · 👤 <account email> · 5h: <left>% (⏳ <countdown>) · wk: <left>% · 📁 <cwd>
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
# The transcript writes one line PER ASSISTANT CONTENT BLOCK, each repeating the
# same message.id and usage — so totals are deduplicated by message.id (last
# line wins) or a single API call would be counted once per block.
# Claude Code pipes session JSON to this script on stdin.
#
# Side effect: each render also publishes the authoritative context data to
# $STATUSLINE_CTX_DIR (default ~/.claude/statusline-ctx)/<session_id>.json —
# {"v":1,"ts":...,"used_percentage":N,"context_window_size":N,
#  "transcript_path":"...","transcript_size":N} — so tools that only get hook
# payloads (which carry no context_window.*), like claude-context-keeper, can
# show the exact same percentage. Atomic tmp+rename; files older than 7 days
# are pruned on write; any failure is swallowed (the footer must never break).
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

# Active account (👤) — placed right before the 5h/weekly limits, which belong
# to this account. cswap (claude-swap) users switch accounts often and forget
# which one is live; the stdin payload carries no account info, but the email
# of the active account lives in ~/.claude.json (oauthAccount.emailAddress),
# which cswap swaps together with the OAuth tokens. Missing/corrupt file ->
# segment omitted. Disable with STATUSLINE_SHOW_ACCOUNT=0. (macOS: a cswap
# switch shows up once the ~30s Keychain credential cache expires.)
# NB: this whole Python program is a single-quoted shell string — no
# apostrophes anywhere in it, comments included.
if os.environ.get("STATUSLINE_SHOW_ACCOUNT", "1") != "0":
    try:
        cfg_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~")
        cf = open(os.path.join(cfg_dir, ".claude.json"))
        try:
            email = (json.load(cf).get("oauthAccount") or {}).get("emailAddress")
        finally:
            cf.close()
        if email:
            parts.append("👤 " + email)
    except Exception:
        pass

rl = d.get("rate_limits") or {}

fh = rl.get("five_hour") or {}
if "used_percentage" in fh:
    seg = "5h: %d%%" % (100 - fh["used_percentage"])
    ra = fh.get("resets_at")
    # Guard the type: a non-numeric resets_at (e.g. an ISO string in a future
    # Claude Code version) must degrade to "no countdown", not kill the footer.
    if isinstance(ra, (int, float)):
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

tp = d.get("transcript_path")

# Publish the authoritative context data as a per-session sidecar (see header).
try:
    sid = d.get("session_id") or ""
    win = cw.get("context_window_size")
    if ctx is not None and win and sid and all(c.isalnum() or c in "-_" for c in sid):
        sc_dir = os.environ.get("STATUSLINE_CTX_DIR") or os.path.join(
            os.path.expanduser("~"), ".claude", "statusline-ctx")
        try:
            os.makedirs(sc_dir)
        except Exception:
            pass
        try:
            tsize = os.stat(tp).st_size if tp else 0
        except Exception:
            tsize = 0
        rec = {"v": 1, "ts": int(time.time()), "used_percentage": ctx,
               "context_window_size": win,
               "transcript_path": tp or "", "transcript_size": tsize}
        tmp = os.path.join(sc_dir, "%s.json.tmp.%d" % (sid, os.getpid()))
        sf = open(tmp, "w")
        try:
            sf.write(json.dumps(rec))
        finally:
            sf.close()
        os.rename(tmp, os.path.join(sc_dir, sid + ".json"))
        now = time.time()
        for fn in os.listdir(sc_dir):
            try:
                fp = os.path.join(sc_dir, fn)
                if now - os.stat(fp).st_mtime > 7 * 86400:
                    os.unlink(fp)
            except Exception:
                pass
except Exception:
    pass

# Sum cumulative tokens from the session transcript, one entry per message.id
# (multi-block replies repeat the same usage on every line; last line wins).
if tp and os.path.exists(tp):
    per = {}
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
                m = o.get("message") or {}
                u = m.get("usage")
                if not u:
                    continue
                per[m.get("id") or o.get("uuid")] = (
                    u.get("input_tokens", 0)
                    + u.get("cache_creation_input_tokens", 0)
                    + u.get("cache_read_input_tokens", 0),
                    u.get("output_tokens", 0))
        finally:
            f.close()
    except Exception:
        per = {}
    sent = sum(v[0] for v in per.values())
    recv = sum(v[1] for v in per.values())
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
