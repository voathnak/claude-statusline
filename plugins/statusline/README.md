# statusline — Claude Code footer

A two-line Claude Code status bar showing the active model, reasoning effort, your
**5-hour** and **weekly** usage-limit remaining percentages (with a reset
countdown), the working directory, context usage, and cumulative session tokens.

```
v1.4.0 · Opus 4.8 (1M ctx) · ⚙ medium · 5h: 92% (⏳ 4h28m) · wk: 98% · 📁 ~/project
23% ctx · ↑ 156.3k · ↓ 8.7k
```

- **Line 1:** version · model · `⚙ effort` · 5h limit · weekly limit · `📁 cwd`
- **Line 2:** context % · `↑` input tokens · `↓` output tokens (cumulative,
  deduplicated by `message.id` — the transcript repeats the same usage on every
  content-block line of a reply)
- Version first (always visible); path last (it varies in length).

## Install

This plugin ships the footer script plus an installer. Because a plugin's bundled
`settings.json` cannot set the **main** `statusLine` (Claude Code only allows
`agent` and `subagentStatusLine` there), activate the footer once with:

```
/statusline:install
```

That runs the bundled `scripts/install.sh`, which:

- copies `scripts/statusline.sh` → `~/.claude/statusline.sh`, and
- merges `"statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }`
  into `~/.claude/settings.json`.

Both files are backed up first (`*.bak-<timestamp>`). The installer is
semver-aware and **will not downgrade** — pass `--force` to override. Open a new
session (or reload) to see the footer.

You can also run it directly:

```sh
./scripts/install.sh          # install or upgrade
./scripts/install.sh --force  # reinstall / allow downgrade
```

## Context sidecar (interop with other tools)

Claude Code gives the **statusline** the authoritative context data
(`context_window.used_percentage`, `context_window_size`) but does **not**
include it in hook payloads. So on every render the script publishes a
per-session sidecar that hook-based tools can read:

- **Path:** `~/.claude/statusline-ctx/<session_id>.json`
  (directory overridable via `STATUSLINE_CTX_DIR` — mainly for testing).
- **Schema (v1):**

  ```json
  {"v": 1, "ts": 1720500000, "used_percentage": 42, "context_window_size": 200000,
   "transcript_path": "/path/to/session.jsonl", "transcript_size": 123456}
  ```

- Written atomically (temp file + rename); consumers can never see a partial
  file. Sidecars older than 7 days are pruned on write. Every step is
  failure-swallowed — the footer can never break because of the sidecar.

`claude-context-keeper` ≥ 1.3.0 uses this so its context
warnings show the **exact same percentage** as this footer, instead of
re-deriving one from the transcript with a guessed window size.

## Requirements

- **`python3`** (recommended) — enables the full footer. Ships with macOS Xcode
  Command Line Tools and is standard on Linux. Also runs under Python 2.
- Without any Python, the footer degrades to **path only** (`📁 ~/dir`).
- The 5h/weekly figures require Claude Code ≳ 2.1.x (older versions don't send
  `rate_limits`; those segments are simply omitted).

## Versioning

The single source of truth is the `# version:` line at the top of
`scripts/statusline.sh`; `plugin.json` mirrors it. Bump both together and add a
`CHANGELOG.md` entry.
