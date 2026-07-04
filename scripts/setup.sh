#!/usr/bin/env bash
set -euo pipefail

# claude-plus installer. Idempotent.
#
# Writes:
#   ~/.claude/CLAUDE.md               -- global rules
#   ~/.claude/rules/coder*.md         -- coder MCP navigation rules (only when
#                                        the coder MCP server is registered)
#   ~/.claude/settings.json           -- merges env/permissions/defaults
#   ~/.claude.json                    -- pre-trusts $HOME, adds chrome-devtools
#                                        MCP (unless --skip-chrome-devtools)
#
# Removes (legacy, from pre-June-2026 versions of claude-plus):
#   ~/.local/bin/claude-plus          -- wrapper binary
#   ~/.claude/anthropic.txt           -- replacement system prompt
#
# Output labels:
#   [copied]   file did not exist, installed fresh
#   [updated]  file existed with different content, overwritten
#   [current]  file already matches, no change made
#   [merged]   JSON file updated with our keys
#   [removed]  legacy artifact backed up and deleted
#
# Any file overwritten or removed under $HOME is first copied to
#   ~/.claude/backups/claude-plus-<timestamp>/
# and logged in that directory's manifest.txt.

SKIP_CHROME=0
for arg in "$@"; do
  case "$arg" in
    --skip-chrome-devtools)
      SKIP_CHROME=1
      ;;
    -h|--help)
      cat <<EOF
Usage: setup.sh [--skip-chrome-devtools]

Options:
  --skip-chrome-devtools   Skip registering the chrome-devtools MCP server.
  -h, --help               Show this help.
EOF
      exit 0
      ;;
    *)
      echo "error: unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"
SETTINGS_PATH="$CLAUDE_DIR/settings.json"

echo "> Installing claude-plus"
echo ""

# -- Validate dependencies --------------------------------------------------
for cmd in claude jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "error: $cmd is required but not found in PATH" >&2
    exit 1
  fi
done

# -- Backup helpers ---------------------------------------------------------
# PID suffix avoids collisions when installs run back-to-back (BSD date has
# no %N, so nanoseconds aren't portable).
BACKUP_DIR="$HOME/.claude/backups/claude-plus-$(date +%Y%m%d-%H%M%S)-$$"
MANIFEST=""

backup_file() {
  local src="$1"
  [ -e "$src" ] || return 0
  if [ -z "$MANIFEST" ]; then
    mkdir -p "$BACKUP_DIR"
    MANIFEST="$BACKUP_DIR/manifest.txt"
    # Append to an existing manifest rather than clobbering, though the
    # nanosecond-resolution dir name makes this path unlikely.
    [ -e "$MANIFEST" ] || : > "$MANIFEST"
  fi
  local rel="${src#$HOME/}"
  local dst="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dst")"
  cp -p "$src" "$dst"
  echo "$src" >> "$MANIFEST"
}

# -- File install helper ---------------------------------------------------
# install_file <source> <destination> <mode> <display-name>
# Emits one of:
#   [current]  <name>
#   [copied]   <name>
#   [updated]  <name>
install_file() {
  local src="$1" dst="$2" mode="$3" name="$4"
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      echo "  [current]  $name"
      return
    fi
    backup_file "$dst"
    install -m "$mode" "$src" "$dst"
    echo "  [updated]  $name"
  else
    install -m "$mode" "$src" "$dst"
    echo "  [copied]   $name"
  fi
}

# -- Rule install helper -----------------------------------------------------
# install_rule <source> <signature>
#
# Idempotency for rules is content-based, NOT a whole-file diff: a rule counts
# as installed if any file in ~/.claude/rules/ contains its signature string
# (the rule's coder guide-tool reference). Rules files may have been renamed,
# reworded, or folded into another rules file locally (e.g. lsp-manager's
# lsp-navigation.md), and none of that should cause a re-add or an overwrite.
install_rule() {
  local src="$1" sig="$2"
  local base dst name hit
  base="$(basename "$src")"
  dst="$RULES_DIR/$base"
  name="~/.claude/rules/$base"
  # `command grep` bypasses shell functions: environments that export a grep
  # wrapper (e.g. ugrep with ignore-file handling) would otherwise skip files
  # here and cause a customized rule to be treated as missing.
  hit=""
  if [ -d "$RULES_DIR" ]; then
    hit="$(command grep -rlF -- "$sig" "$RULES_DIR" | head -n 1 || true)"
    # Re-check the destination directly: if the directory sweep fails
    # transiently, overwriting a rules file the user customized is the one
    # mistake this helper must never make.
    if [ -z "$hit" ] && [ -e "$dst" ] && command grep -qF -- "$sig" "$dst"; then
      hit="$dst"
    fi
  fi
  if [ -n "$hit" ]; then
    if [ "$hit" = "$dst" ]; then
      echo "  [current]  $name"
    else
      echo "  [current]  $name (content lives in ${hit/#$HOME/~})"
    fi
    return
  fi
  if [ -e "$dst" ]; then
    backup_file "$dst"
    install -m 0644 "$src" "$dst"
    echo "  [updated]  $name"
  else
    install -m 0644 "$src" "$dst"
    echo "  [copied]   $name"
  fi
}

# -- Remove legacy artifacts -------------------------------------------------
# Earlier versions replaced Claude Code's system prompt (~/.claude/anthropic.txt)
# and shipped a wrapper binary to re-inject the environment block. The stock
# system prompt is tuned per model (Fable 5 and later) and should not be
# replaced, so both are retired. Back up and delete if a previous install
# left them behind.
for legacy in "$HOME/.local/bin/claude-plus" "$CLAUDE_DIR/anthropic.txt"; do
  if [ -e "$legacy" ]; then
    backup_file "$legacy"
    rm "$legacy"
    echo "  [removed]  ${legacy/#$HOME/~} (legacy)"
  fi
done

# -- Install global rules ----------------------------------------------------
mkdir -p "$CLAUDE_DIR"
install_file "$CONFIG_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" 0644 "~/.claude/CLAUDE.md"

# -- Install coder MCP rules --------------------------------------------------
# Path-scoped rules that steer Claude to coder MCP tools (and the per-language
# *_guide tool) instead of Read/grep/head/sed for code navigation. Installed
# only when the coder MCP server is registered -- user scope or any project
# scope in ~/.claude.json -- since the rules are useless without the server.
coder_installed() {
  [ -f "$CLAUDE_JSON" ] || return 1
  jq -e '
    ((.mcpServers // {}) | has("coder"))
    or ([.projects // {} | to_entries[] | .value.mcpServers // {} | has("coder")] | any)
  ' "$CLAUDE_JSON" >/dev/null
}

RULES_DIR="$CLAUDE_DIR/rules"
if coder_installed; then
  mkdir -p "$RULES_DIR"
  install_rule "$CONFIG_DIR/rules/coder.md" 'mcp__coder__<language>_guide'
  for lang in go typescript cpp python java; do
    install_rule "$CONFIG_DIR/rules/coder-$lang.md" "mcp__coder__${lang}_guide"
  done
else
  echo "  [skipped]  ~/.claude/rules/coder*.md (coder MCP not registered)"
fi

# -- Merge settings.json ----------------------------------------------------
# Recursive merge with our keys winning on conflicts (arrays are replaced,
# not unioned, so stale permission entries get refreshed). Keys we don't
# ship -- hooks, plugins, marketplaces -- are left untouched. Only rewrite
# the file if the resulting content actually differs.
ours="$CONFIG_DIR/settings.json"

if [ -f "$SETTINGS_PATH" ]; then
  merged="$(jq -s '.[0] * .[1]' "$SETTINGS_PATH" "$ours")"
  if [ "$(jq -S . "$SETTINGS_PATH")" = "$(echo "$merged" | jq -S .)" ]; then
    echo "  [current]  ~/.claude/settings.json"
  else
    backup_file "$SETTINGS_PATH"
    echo "$merged" > "$SETTINGS_PATH"
    echo "  [merged]   ~/.claude/settings.json"
  fi
else
  install -m 0644 "$ours" "$SETTINGS_PATH"
  echo "  [copied]   ~/.claude/settings.json"
fi

# -- Pre-trust $HOME in ~/.claude.json -------------------------------------
# Claude Code's per-path trust check (isPathTrusted) walks up the directory
# tree looking for projects[path].hasTrustDialogAccepted. Setting it on
# $HOME pre-approves every subdirectory, so neither the startup trust gate
# nor MCP tools that operate on directories outside the current workspace
# (e.g. the coder MCP with a cwd parameter) surface an approval prompt.
if [ -f "$CLAUDE_JSON" ]; then
  merged="$(jq --arg home "$HOME" '
    .projects = ((.projects // {}) | .[$home] = (.[$home] // {
      "allowedTools": [],
      "mcpContextUris": [],
      "mcpServers": {},
      "enabledMcpjsonServers": [],
      "disabledMcpjsonServers": [],
      "hasTrustDialogAccepted": false,
      "projectOnboardingSeenCount": 0,
      "hasClaudeMdExternalIncludesApproved": false,
      "hasClaudeMdExternalIncludesWarningShown": false
    }) | .[$home].hasTrustDialogAccepted = true)
  ' "$CLAUDE_JSON")"
  if [ "$(jq -S . "$CLAUDE_JSON")" = "$(echo "$merged" | jq -S .)" ]; then
    echo "  [current]  ~/.claude.json (\$HOME trust)"
  else
    backup_file "$CLAUDE_JSON"
    echo "$merged" > "$CLAUDE_JSON"
    echo "  [merged]   ~/.claude.json (\$HOME trust)"
  fi
else
  echo "  [skipped]  ~/.claude.json not found (run claude first) -- \$HOME trust"
fi

# -- Merge chrome-devtools MCP into ~/.claude.json -------------------------
if [ "$SKIP_CHROME" -eq 1 ]; then
  echo "  [skipped]  ~/.claude.json (chrome-devtools MCP, --skip-chrome-devtools)"
else
  if [ -f "$CLAUDE_JSON" ]; then
    merged="$(jq '.mcpServers = ((.mcpServers // {}) + {
      "chrome-devtools": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "chrome-devtools-mcp@latest", "--viewport=1920x1080"]
      }
    })' "$CLAUDE_JSON")"
    if [ "$(jq -S . "$CLAUDE_JSON")" = "$(echo "$merged" | jq -S .)" ]; then
      echo "  [current]  ~/.claude.json (chrome-devtools MCP)"
    else
      backup_file "$CLAUDE_JSON"
      echo "$merged" > "$CLAUDE_JSON"
      echo "  [merged]   ~/.claude.json (chrome-devtools MCP)"
    fi
  else
    echo "  [skipped]  ~/.claude.json not found (run claude first)"
  fi
fi

# -- Report backups, if any -------------------------------------------------
if [ -n "$MANIFEST" ]; then
  echo ""
  echo "  backups -> ${BACKUP_DIR/#$HOME/~}"
fi

# -- Summary ----------------------------------------------------------------
echo ""
echo "  [ok] claude-plus installed. Run: claude"
echo ""
echo "  For the full experience (LSP servers + plugin wiring), also install"
echo "  lsp-manager: https://github.com/gignit/lsp-manager"
echo ""
