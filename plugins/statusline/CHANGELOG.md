# Changelog

All notable changes to the `statusline` plugin.
Versions follow semver; the authoritative number lives in the `# version:` line
at the top of `scripts/statusline.sh` and is mirrored in `plugin.json`.

## 1.3.0
- **Packaged as a Claude Code marketplace plugin** (`vlim-tools` marketplace).
  The footer logic is unchanged from 1.2.0; this release is the plugin wrapper.
- Added the `/statusline:install` command, which runs the bundled installer to
  wire `~/.claude/statusline.sh` and the `statusLine` block in
  `~/.claude/settings.json`.
- Script and installer now live under `scripts/` inside the plugin.

> Note: a plugin's bundled `settings.json` can only set `agent` and
> `subagentStatusLine` — not the main `statusLine`. So enabling the plugin makes
> the script and `/statusline:install` command available; run the command once to
> activate the footer in your user settings.

## 1.2.0
- Line 1 now shows the model's reasoning effort as `⚙ <level>` (from
  `effort.level`: low/medium/high/xhigh/max), right after the model name.
  Omitted gracefully when the field is absent.

## 1.1.1
- Removed the `💰 $<cost> session` segment from line 2. `cost.total_cost_usd` is
  an API-list-price estimate, not the actual bill on a team/subscription plan, so
  it was misleading. Line 2 is now `<N>% ctx · ↑ <sent> · ↓ <received>`.

## 1.1.0
- Added a second row: `💰 $<cost> session · <N>% ctx · ↑ <sent> · ↓ <received>`.
  Token totals are CUMULATIVE for the session, summed from the transcript JSONL.

## 1.0.0
- Initial release.
- Footer shows: version · model · 5h limit (remaining % + ⏳ reset countdown) ·
  weekly limit (remaining %) · current working directory.
- Parsing via inline Python (Python 3 or 2); `sed` path-only fallback.
- `install.sh` with semver-aware, no-downgrade install and `settings.json` merge.
