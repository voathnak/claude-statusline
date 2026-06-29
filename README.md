# vlim-tools

A personal [Claude Code](https://code.claude.com) plugin marketplace.

## Plugins

| Plugin       | Version | Description                                                                 |
| :----------- | :------ | :-------------------------------------------------------------------------- |
| `statusline` | 1.3.0   | Two-line footer: model, effort, 5h/weekly usage limits, cwd, context, tokens. |

## Add this marketplace

```
/plugin marketplace add gitea.home.vlim.cc/vlim/claude-statusline
```

Then install a plugin:

```
/plugin install statusline@vlim-tools
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
    commands/install.md           # /statusline:install
    README.md
    CHANGELOG.md
```
