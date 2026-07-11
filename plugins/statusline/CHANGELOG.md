# Changelog

All notable changes to the `statusline` plugin.
Versions follow semver; the authoritative number lives in the `# version:` line
at the top of `scripts/statusline.sh` and is mirrored in `plugin.json`.

## 1.5.0
- **New: active account email on line 1** (`👤 you@example.com`, placed right
  before the 5h/weekly limits, which belong to that account). Read from
  `~/.claude.json` → `oauthAccount.emailAddress` (honors `CLAUDE_CONFIG_DIR`),
  which account switchers like [cswap](https://github.com/realiti4/claude-swap)
  swap together with the OAuth tokens — so after a switch the footer shows which
  account you're on. Missing/corrupt file just omits the segment; disable with
  `STATUSLINE_SHOW_ACCOUNT=0`. Note: on macOS a cswap switch appears once
  Claude Code's ~30s Keychain credential cache expires.
- **New: 5-second idle refresh.** The installer now writes
  `"refreshInterval": 5` into the `statusLine` block. Without it, renders are
  event-driven only (new assistant message, `/compact`, mode changes) and the
  ⏳ countdown / 👤 account segments go stale while the session sits idle.
  A user-customized `refreshInterval` already present in `settings.json` is
  preserved on upgrade.

## 1.4.1
- **Marketplace renamed `vlim-tools` → `vk-statusline`.** The claude-context-keeper
  repo declared a marketplace with the same `vlim-tools` name; Claude Code keys
  marketplaces by name, so adding one repo broke the other's plugin. Each repo
  now ships its own uniquely-named marketplace. Re-add with
  `/plugin marketplace add <repo>` and install `statusline@vk-statusline`.
- **Fixed: a non-numeric `rate_limits.*.resets_at` could blank the whole footer.**
  The countdown arithmetic assumed an epoch number with no guard; a string value
  (e.g. ISO timestamp in a future Claude Code version) raised and killed the
  script. Now type-checked — the countdown is simply omitted.
- **Fixed: `install.sh` no longer clobbers an unparseable `settings.json`.**
  Previously a corrupt (or non-object) settings file was silently replaced with
  a minimal `{statusLine}` object, dropping hooks/permissions/env (a backup was
  taken, but still). It now aborts with an error and leaves the file untouched.
- `install.sh`: version compare no longer aborts the installer (under `set -e`)
  on a non-3-part version string like `1.4.0.1` — treated as unrecognized.
- Internal: renamed a shadowed variable in the sidecar write path.

## 1.4.0
- **Fixed cumulative ↑/↓ token totals over-counting.** The transcript JSONL
  writes one line per assistant content block, each repeating the same
  `message.id` and `usage` object; summing per line counted a single API call
  once per block (measured ~2–2.6× inflation on a real session). Totals are now
  deduplicated by `message.id` (last line wins).
- **New: per-session context sidecar for tool interop.** Each render writes
  `~/.claude/statusline-ctx/<session_id>.json` (override dir with
  `STATUSLINE_CTX_DIR`) containing the authoritative `used_percentage`,
  `context_window_size`, `transcript_path`, `transcript_size`, and a timestamp
  (schema `"v":1`). Hooks don't receive `context_window.*`, so tools like
  claude-context-keeper (≥1.3.0) read this to show the exact same percentage
  as the footer. Atomic tmp+rename write; sidecars older than 7 days are pruned
  on write; all failures are swallowed so the footer can never break.

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
