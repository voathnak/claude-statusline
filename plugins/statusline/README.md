# statusline — Claude Code footer

A two-line Claude Code status bar showing the active model, reasoning effort, your
**5-hour** and **weekly** usage-limit remaining percentages (with a reset
countdown), the working directory, context usage, and cumulative session tokens.

```
v1.3.0 · Opus 4.8 (1M ctx) · ⚙ medium · 5h: 92% (⏳ 4h28m) · wk: 98% · 📁 ~/project
23% ctx · ↑ 156.3k · ↓ 8.7k
```

- **Line 1:** version · model · `⚙ effort` · 5h limit · weekly limit · `📁 cwd`
- **Line 2:** context % · `↑` input tokens · `↓` output tokens (cumulative)
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
