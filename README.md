# claude-plus

**Claude Code+ -- The Best AI Agent Coder Possible (when paired with [lsp-manager](https://github.com/gignit/lsp-manager))**

A drop-in enhancement for [Claude Code](https://github.com/anthropics/claude-code) that replaces the default system prompt with a tightened version, sets sane permission and runtime defaults, and registers the Chrome DevTools MCP server so Claude can drive a real browser out of the box.

## What it does

- Replaces Claude Code's built-in system prompt with a direct, production-oriented version (tone, professional objectivity, code quality, tool policy).
- Adds sane permission defaults: `Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`, `LSP`, `WebFetch`, `TodoRead`, `TodoWrite`.
- Enables `alwaysThinkingEnabled` and `skipDangerousModePermissionPrompt`.
- Disables auto-memory (`autoMemoryEnabled: false`) and the away-session recap (`awaySummaryEnabled: false`).
- Raises `MAX_MCP_OUTPUT_TOKENS` to `50000` and sets `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`.
- Registers the [chrome-devtools MCP](https://www.npmjs.com/package/chrome-devtools-mcp) server.
- Ships a `claude-plus` wrapper that re-injects the environment block (cwd, git root, platform, date) that Claude strips when you pass `--system-prompt-file`.
- Suppresses the "Do you trust this folder?" dialog in two places `--dangerously-skip-permissions` doesn't reach: the startup trust gate (via `CLAUDE_CODE_SANDBOXED=1` in the wrapper) and the per-path trust gate used by MCP tools that operate outside the workspace (via a `hasTrustDialogAccepted: true` entry on `$HOME` in `~/.claude.json`, which Claude's upward-walking trust check inherits into every subdirectory).

## Install

```bash
git clone git@github.com:gignit/claude-plus.git
cd claude-plus
make install
```

Requires `claude` and `jq` on your `PATH`. Make sure `~/.local/bin` is on your `PATH` too.

### Skip Chrome DevTools

```bash
scripts/setup.sh --skip-chrome-devtools
```

## Usage

Use `claude-plus` anywhere you would use `claude`. All flags pass through.

```bash
claude-plus
claude-plus --model claude-opus-4-6
claude-plus --resume
```

## Files written

| Path | What |
|------|------|
| `~/.local/bin/claude-plus` | Wrapper binary |
| `~/.claude/anthropic.txt` | Enhanced system prompt |
| `~/.claude/CLAUDE.md` | Global rules |
| `~/.claude/settings.json` | Merged `env`, `permissions`, `alwaysThinkingEnabled`, `skipDangerousModePermissionPrompt`, `autoMemoryEnabled`, `awaySummaryEnabled` |
| `~/.claude.json` | Adds `chrome-devtools` to `mcpServers` (unless `--skip-chrome-devtools`) and sets `projects["$HOME"].hasTrustDialogAccepted = true` to suppress per-path trust prompts |

Every file the installer overwrites under `~/.claude/` is backed up to `~/.claude/backups/claude-plus-<timestamp>/` first, with a `manifest.txt` listing the originals.

## Companion: lsp-manager

claude-plus handles prompts and defaults. For LSP servers and Claude Code plugin wiring, pair it with [lsp-manager](https://github.com/gignit/lsp-manager):

```bash
git clone git@github.com:gignit/lsp-manager.git
cd lsp-manager
make install
lsp-manager init
```

Running both gives you the full experience: enhanced prompts, sane defaults, Chrome DevTools, and working LSP diagnostics in every supported language.

## Uninstall

There is no uninstaller. Installs merge into your existing `~/.claude/settings.json` and `~/.claude.json`, so we can't reliably tell which keys were yours and which came from claude-plus. Remove what you want by hand, or restore the pre-install snapshot from `~/.claude/backups/claude-plus-<timestamp>/` (the installer writes one before every change; `manifest.txt` lists the originals).

To fully detach, also `rm ~/.local/bin/claude-plus`.

## License

MIT. See [LICENSE](LICENSE).
