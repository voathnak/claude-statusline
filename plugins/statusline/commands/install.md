---
description: Install the statusline footer into ~/.claude (script + settings.json statusLine block)
---

Wire the two-line statusline footer into the user's Claude Code config by running
the bundled installer. The installer copies the script to `~/.claude/statusline.sh`
and merges a `statusLine` block into `~/.claude/settings.json` (both backed up
first; it refuses to downgrade unless `--force` is passed).

Run exactly this command:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"
```

If the user passed `--force` in their message, append it.

After it runs, report the installer's output verbatim and remind the user that the
footer appears in a **new** Claude Code session (or after a reload). Note that the
full footer (model + usage limits + tokens) requires `python3`; without it the
footer degrades to showing the path only.
