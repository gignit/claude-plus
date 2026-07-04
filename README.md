# claude-plus

**Claude Code+ -- one-command Claude Code setup for a new machine (pairs well with [lsp-manager](https://github.com/gignit/lsp-manager))**

A drop-in setup for [Claude Code](https://github.com/anthropics/claude-code) that merges sane permission and runtime defaults, installs global rules, registers the Chrome DevTools MCP server so Claude can drive a real browser out of the box, and pre-trusts `$HOME` so trust dialogs never interrupt.

> **Note on the old system prompt replacement:** versions before June 2026 replaced Claude Code's built-in system prompt (`~/.claude/anthropic.txt`) and shipped a `claude-plus` wrapper binary to re-inject the environment block. That approach is retired: the stock system prompt is tuned per model (Fable 5 and later) and has grown harness features a frozen copy loses. The installer now removes those artifacts if an earlier version left them behind. See [docs/claude_digging.md](docs/claude_digging.md) for the reverse-engineering notes from that era.

## What it does

- Merges defaults into `~/.claude/settings.json`:
  - `permissions.defaultMode: bypassPermissions` (replaces the old wrapper's `--dangerously-skip-permissions` flag -- no alias or wrapper needed) plus an allow list using current tool names.
  - `MAX_MCP_OUTPUT_TOKENS=50000` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`.
  - Model `fable`, vim editor mode, dark theme (reasoning effort is left at the default, not forced).
  - Disables auto-memory, away-session recap, and auto-compact; skips the dangerous-mode permission prompt.
  - A `user@host:cwd (branch) [model]` status line.
  - No hooks, deliberately: destructive-command blocking is unnecessary inside a VM, format-on-save mid-task breaks an agent's exact-match sequential edits, and CLAUDE.md now survives compaction natively.
  - Keys it doesn't ship (hooks, plugins, marketplaces) are left untouched, so it composes with lsp-manager.
- Installs global rules to `~/.claude/CLAUDE.md`.
- If the coder MCP server is registered in `~/.claude.json` (user scope or any project scope), installs coder navigation rules to `~/.claude/rules/`: `coder.md` plus path-scoped `coder-{go,typescript,cpp,python,java}.md`. These make Claude fetch the language's `mcp__coder__<language>_guide` tool early in a session -- so the guide is always the live version, never a stale copy -- and navigate code through coder tools instead of Read/grep/head/sed. Skipped entirely when coder isn't registered.
  - Idempotency for rules is content-based, not a whole-file diff: a rule counts as installed if **any** file in `~/.claude/rules/` contains its signature (the `mcp__coder__<language>_guide` reference). Rules you've renamed, reworded, or folded into another rules file are left untouched; a `coder-*.md` file that has lost its signature is backed up and refreshed.
- Registers the [chrome-devtools MCP](https://www.npmjs.com/package/chrome-devtools-mcp) server.
- Pre-trusts `$HOME` in `~/.claude.json`: Claude's trust check walks up the directory tree, so one `hasTrustDialogAccepted: true` entry on `$HOME` suppresses the startup trust gate and per-path prompts (e.g. MCP tools operating outside the workspace) for every directory under home.
- Removes legacy claude-plus artifacts (`~/.local/bin/claude-plus`, `~/.claude/anthropic.txt`) from earlier installs.

Last verified against Claude Code 2.1.172.

## Install

```bash
git clone git@github.com:gignit/claude-plus.git
cd claude-plus
make install
```

Requires `claude` and `jq` on your `PATH`. On a brand-new machine, run `claude` once first so `~/.claude.json` exists (the installer skips the trust and MCP merges until it does).

### Skip Chrome DevTools

```bash
scripts/setup.sh --skip-chrome-devtools
```

## Usage

Just run `claude`. There is no wrapper anymore -- `bypassPermissions` comes from settings, so flags and shell aliases like `claude --dangerously-skip-permissions` are unnecessary.

## Files written

| Path | What |
|------|------|
| `~/.claude/CLAUDE.md` | Global rules |
| `~/.claude/rules/coder*.md` | coder MCP navigation rules (only when the coder MCP server is registered) |
| `~/.claude/settings.json` | Merged `env`, `permissions`, model/effort, editor, theme, status line, feature toggles |
| `~/.claude.json` | Adds `chrome-devtools` to `mcpServers` (unless `--skip-chrome-devtools`) and sets `projects["$HOME"].hasTrustDialogAccepted = true` |

| Removed (legacy) | What |
|------|------|
| `~/.local/bin/claude-plus` | Old wrapper binary |
| `~/.claude/anthropic.txt` | Old replacement system prompt |

Every file the installer overwrites or removes is backed up to `~/.claude/backups/claude-plus-<timestamp>/` first, with a `manifest.txt` listing the originals.

## Companion: lsp-manager

claude-plus handles defaults and global config. For LSP servers and Claude Code plugin wiring, pair it with [lsp-manager](https://github.com/gignit/lsp-manager):

```bash
git clone git@github.com:gignit/lsp-manager.git
cd lsp-manager
make install
lsp-manager init
```

Running both gives you the full experience: sane defaults, Chrome DevTools, and working LSP diagnostics in every supported language.

## Uninstall

There is no uninstaller. Installs merge into your existing `~/.claude/settings.json` and `~/.claude.json`, so we can't reliably tell which keys were yours and which came from claude-plus. Remove what you want by hand, or restore the pre-install snapshot from `~/.claude/backups/claude-plus-<timestamp>/` (the installer writes one before every change; `manifest.txt` lists the originals).

## License

MIT. See [LICENSE](LICENSE).
