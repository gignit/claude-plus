#!/usr/bin/env bash
set -euo pipefail

# claude-plus uninstaller. Idempotent.
#
# Removes files installed by setup.sh:
#   ~/.local/bin/claude-plus
#   ~/.claude/anthropic.txt    (only if SHA matches the repo version)
#   ~/.claude/CLAUDE.md        (only if SHA matches the repo version)
#   claude-plus keys from ~/.claude/settings.json
#   chrome-devtools entry from ~/.claude.json
#
# Output labels:
#   [removed]  file/key existed and was removed
#   [absent]   file/key already not present, nothing to do
#   [kept]     file exists but differs from the repo version, left alone
#   [restored] file was restored from a backup (--restore-backup)
#
# Usage:
#   uninstall.sh
#   uninstall.sh --restore-backup=/path/to/backups/claude-plus-YYYYMMDD-HHMMSS

RESTORE_DIR=""
for arg in "$@"; do
  case "$arg" in
    --restore-backup=*)
      RESTORE_DIR="${arg#*=}"
      ;;
    -h|--help)
      cat <<EOF
Usage: uninstall.sh [--restore-backup=PATH]

Options:
  --restore-backup=PATH   Replay the manifest in PATH to restore the files
                          that were backed up during setup.sh.
  -h, --help              Show this help.
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

BIN_TARGET="$HOME/.local/bin"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"
SETTINGS_PATH="$CLAUDE_DIR/settings.json"

echo "> Uninstalling claude-plus"
echo ""

# -- Require jq for JSON edits ----------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "error: jq is required but not found in PATH" >&2
  exit 1
fi

# -- Remove wrapper ---------------------------------------------------------
if [ -e "$BIN_TARGET/claude-plus" ]; then
  rm -f "$BIN_TARGET/claude-plus"
  echo "  [removed]  ~/.local/bin/claude-plus"
else
  echo "  [absent]   ~/.local/bin/claude-plus"
fi

# -- Remove prompt files (only if unchanged) -------------------------------
remove_if_matches() {
  # remove_if_matches <installed> <source> <display-name>
  local installed="$1" source="$2" name="$3"
  if [ ! -e "$installed" ]; then
    echo "  [absent]   $name"
    return
  fi
  if [ ! -e "$source" ]; then
    echo "  [kept]     $name (repo source missing, cannot verify)"
    return
  fi
  if cmp -s "$installed" "$source"; then
    rm -f "$installed"
    echo "  [removed]  $name"
  else
    echo "  [kept]     $name (content differs from claude-plus version)"
  fi
}

remove_if_matches "$CLAUDE_DIR/anthropic.txt" "$CONFIG_DIR/anthropic.txt" "~/.claude/anthropic.txt"
remove_if_matches "$CLAUDE_DIR/CLAUDE.md"     "$CONFIG_DIR/CLAUDE.md"     "~/.claude/CLAUDE.md"

# -- Strip our keys from settings.json -------------------------------------
if [ -f "$SETTINGS_PATH" ]; then
  tmp="$(mktemp)"
  jq '
    if .env then
      .env |= del(.MAX_MCP_OUTPUT_TOKENS, .CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC)
      | if (.env | length) == 0 then del(.env) else . end
    else . end
    | if .permissions.allow then
        .permissions.allow |= map(select(
          . as $p |
          ["Bash(*)","Read","Edit","Write","Glob","Grep","LSP","TodoRead","TodoWrite","WebFetch"]
          | index($p) | not
        ))
        | if (.permissions.allow | length) == 0 then del(.permissions.allow) else . end
        | if (.permissions | length) == 0 then del(.permissions) else . end
      else . end
    | del(.alwaysThinkingEnabled, .skipDangerousModePermissionPrompt)
  ' "$SETTINGS_PATH" > "$tmp"
  before_sig="$(jq -S . "$SETTINGS_PATH")"
  after_sig="$(jq -S . "$tmp")"
  if [ "$before_sig" = "$after_sig" ]; then
    rm -f "$tmp"
    echo "  [absent]   ~/.claude/settings.json (no claude-plus keys present)"
  else
    # If nothing meaningful is left, remove the file entirely rather than
    # leaving an empty {} behind.
    if [ "$(jq -c '.' "$tmp")" = "{}" ]; then
      rm -f "$SETTINGS_PATH" "$tmp"
      echo "  [removed]  ~/.claude/settings.json (empty after key removal)"
    else
      mv "$tmp" "$SETTINGS_PATH"
      echo "  [removed]  claude-plus keys from ~/.claude/settings.json"
    fi
  fi
else
  echo "  [absent]   ~/.claude/settings.json"
fi

# -- Remove chrome-devtools from ~/.claude.json ----------------------------
if [ -f "$CLAUDE_JSON" ]; then
  tmp="$(mktemp)"
  jq 'if .mcpServers then
        del(.mcpServers."chrome-devtools")
        | if (.mcpServers | length) == 0 then del(.mcpServers) else . end
      else . end' \
    "$CLAUDE_JSON" > "$tmp"
  before_sig="$(jq -S . "$CLAUDE_JSON")"
  after_sig="$(jq -S . "$tmp")"
  if [ "$before_sig" = "$after_sig" ]; then
    rm -f "$tmp"
    echo "  [absent]   ~/.claude.json (chrome-devtools MCP not present)"
  else
    mv "$tmp" "$CLAUDE_JSON"
    echo "  [removed]  chrome-devtools MCP from ~/.claude.json"
  fi
else
  echo "  [absent]   ~/.claude.json"
fi

# -- Optional backup restore -----------------------------------------------
if [ -n "$RESTORE_DIR" ]; then
  manifest="$RESTORE_DIR/manifest.txt"
  if [ ! -f "$manifest" ]; then
    echo ""
    echo "error: manifest not found at $manifest" >&2
    exit 1
  fi
  echo ""
  echo "> Restoring from backup ${RESTORE_DIR/#$HOME/~}"
  echo ""
  while IFS= read -r original_path; do
    [ -z "$original_path" ] && continue
    rel="${original_path#$HOME/}"
    backup_src="$RESTORE_DIR/$rel"
    display="${original_path/#$HOME/~}"
    if [ ! -e "$backup_src" ]; then
      echo "  [skipped]  $display (backup copy missing)"
      continue
    fi
    mkdir -p "$(dirname "$original_path")"
    cp -p "$backup_src" "$original_path"
    echo "  [restored] $display"
  done < "$manifest"
fi

echo ""
echo "  [ok] claude-plus uninstalled"
echo ""
