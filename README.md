# vk-statusline

A personal [Claude Code](https://code.claude.com) plugin marketplace with a single
plugin. (Each of my plugin repos ships its own uniquely-named marketplace —
marketplace names are global in Claude Code, so two repos must never share one;
see also [claude-context-keeper](../claude-context-keeper), marketplace
`vk-context-keeper`.)

## Plugins

| Plugin       | Version | Description                                                                 |
| :----------- | :------ | :-------------------------------------------------------------------------- |
| `statusline` | 1.6.0   | Two-line footer: model, effort, account email, 5h/weekly usage limits, cwd, context, tokens. Self-deploys on plugin update. |

## Add this marketplace

```
/plugin marketplace add gitea.home.vlim.cc/vlim/claude-statusline
```

Then install a plugin:

```
/plugin install statusline@vk-statusline
```

After installing `statusline`, run `/statusline:install` once to wire the footer
into `~/.claude/settings.json`, then open a new session. See
[`plugins/statusline/README.md`](plugins/statusline/README.md) for details.

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest
plugins/
  statusline/
    .claude-plugin/plugin.json    # plugin manifest (version source mirror)
    scripts/statusline.sh         # the footer script (# version: is source of truth)
    scripts/install.sh            # semver-aware installer
    hooks/hooks.json              # SessionStart auto-deploy (install.sh --quiet)
    commands/install.md           # /statusline:install
    README.md
    CHANGELOG.md
```
