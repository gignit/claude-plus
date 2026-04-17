#!/usr/bin/env bash
set -euo pipefail

# claude-plus installer. Idempotent.
#
# Writes:
#   ~/.local/bin/claude-plus          -- wrapper binary
#   ~/.claude/anthropic.txt           -- enhanced system prompt
#   ~/.claude/CLAUDE.md               -- global rules
#   ~/.claude/settings.json           -- merges env/permissions/flags
#   ~/.claude.json                    -- adds chrome-devtools MCP
#                                        (unless --skip-chrome-devtools)
#
# Output labels:
#   [copied]   file did not exist, installed fresh
#   [updated]  file existed with different content, overwritten
#   [current]  file already matches, no change made
#   [merged]   JSON file updated with our keys
#   [ok]       JSON file already contained our keys, no change made
#
# Any file overwritten in ~/.claude/ (or ~/.claude.json) is first copied to
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
BIN_DIR="$REPO_ROOT/bin"

BIN_TARGET="$HOME/.local/bin"
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
# Nanosecond timestamp avoids collisions when installs run back-to-back.
BACKUP_DIR="$HOME/.claude/backups/claude-plus-$(date +%Y%m%d-%H%M%S-%N)"
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

# -- Install binary and prompt files ----------------------------------------
mkdir -p "$BIN_TARGET" "$CLAUDE_DIR"
install_file "$BIN_DIR/claude-plus"     "$BIN_TARGET/claude-plus"     0755 "~/.local/bin/claude-plus"
install_file "$CONFIG_DIR/anthropic.txt" "$CLAUDE_DIR/anthropic.txt"  0644 "~/.claude/anthropic.txt"
install_file "$CONFIG_DIR/CLAUDE.md"     "$CLAUDE_DIR/CLAUDE.md"      0644 "~/.claude/CLAUDE.md"

# -- Merge settings.json ----------------------------------------------------
# Recursive merge with our keys winning on conflicts. Only rewrite the file
# if the resulting content actually differs.
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
# $HOME pre-approves every subdirectory, so MCP tools that operate on
# directories outside the current workspace (e.g. the coder MCP with a
# cwd parameter) don't surface an approval prompt.
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

# -- PATH hint --------------------------------------------------------------
case ":$PATH:" in
  *":$BIN_TARGET:"*) ;;
  *)
    echo ""
    echo "  NOTE: $BIN_TARGET is not on your PATH."
    echo "        Add this to your shell rc (bash/zsh):"
    echo "          export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "        Or for fish:"
    echo "          fish_add_path \$HOME/.local/bin"
    ;;
esac

# -- Summary ----------------------------------------------------------------
echo ""
echo "  [ok] claude-plus installed. Run: claude-plus"
echo ""
echo "  For the full experience (LSP servers + plugin wiring), also install"
echo "  lsp-manager: https://github.com/gignit/lsp-manager"
echo ""
