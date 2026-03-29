#!/usr/bin/env bash
# Outline Wiki — Claude Code Installer
# Usage: bash install-claude.sh
#
# Sets up OUTLINE_API_KEY and OUTLINE_API_URL in the user's shell profile
# so Claude Code can resolve them when starting the MCP server.
#
# Supports: macOS, Linux, Windows (Git Bash, WSL)
# Shells:   zsh, bash, fish

set -euo pipefail

# ---------------------------------------------------------------------------
# Shell profile detection (NVM-style)
# ---------------------------------------------------------------------------
detect_profile() {
  local shell_name
  shell_name="$(basename "${SHELL:-/bin/bash}")"

  case "$shell_name" in
    zsh)
      echo "${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    bash)
      # macOS bash uses login shells (.bash_profile); Linux uses .bashrc
      if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    fish)
      echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
      ;;
    *)
      # Fallback: first existing profile we find
      local f
      for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
        if [[ -f "$f" ]]; then
          echo "$f"
          return
        fi
      done
      ;;
  esac
}

is_fish() {
  [[ "$(basename "${SHELL:-}")" == "fish" ]]
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "Outline Wiki — Claude Code Setup"
echo "================================="
echo ""

# 1. Prompt for credentials
read -rp "Outline API Key: " API_KEY
if [[ -z "$API_KEY" ]]; then
  echo "Error: API key is required. Get one from Outline -> Settings -> API Tokens."
  exit 1
fi

read -rp "Outline API URL [https://wiki.thakaa.cloud/api]: " API_URL
API_URL="${API_URL:-https://wiki.thakaa.cloud/api}"
API_URL="${API_URL%/}"  # strip trailing slash

# 2. Detect shell profile
PROFILE="$(detect_profile)"

if [[ -z "$PROFILE" ]]; then
  echo ""
  echo "Warning: Could not detect your shell profile."
  echo "Manually add these to your shell config:"
  if is_fish; then
    echo "  set -gx OUTLINE_API_KEY \"$API_KEY\""
    echo "  set -gx OUTLINE_API_URL \"$API_URL\""
  else
    echo "  export OUTLINE_API_KEY=\"$API_KEY\""
    echo "  export OUTLINE_API_URL=\"$API_URL\""
  fi
  exit 1
fi

# Create profile file if it doesn't exist
mkdir -p "$(dirname "$PROFILE")"
touch "$PROFILE"

# 3. Remove existing OUTLINE_ lines (idempotent re-runs)
if is_fish; then
  sed -i.bak '/^set -gx OUTLINE_API_KEY /d;/^set -gx OUTLINE_API_URL /d' "$PROFILE"
else
  sed -i.bak '/^export OUTLINE_API_KEY=/d;/^export OUTLINE_API_URL=/d' "$PROFILE"
fi
rm -f "${PROFILE}.bak"

# 4. Append env vars with correct shell syntax
echo "" >> "$PROFILE"
if is_fish; then
  cat >> "$PROFILE" << EOF
# Outline Wiki (added by install-claude.sh)
set -gx OUTLINE_API_KEY "$API_KEY"
set -gx OUTLINE_API_URL "$API_URL"
EOF
else
  cat >> "$PROFILE" << EOF
# Outline Wiki (added by install-claude.sh)
export OUTLINE_API_KEY="$API_KEY"
export OUTLINE_API_URL="$API_URL"
EOF
fi

echo ""
echo "Environment variables written to $PROFILE"

# 5. Source the profile in the current shell (if not fish)
if is_fish; then
  echo ""
  echo "Run this to load the variables now:"
  echo "  source $PROFILE"
else
  # shellcheck disable=SC1090
  source "$PROFILE" 2>/dev/null || true
  echo "Variables loaded into current session."
fi

# 6. Next steps
echo ""
echo "Next steps — open Claude Code and run:"
echo ""
echo "  1. Add the marketplace:"
echo "     /plugin marketplace add thakaamed/outline-skill"
echo ""
echo "  2. Install the plugin:"
echo "     /plugin install outline-wiki@outline-skill"
echo ""
echo "  3. Verify the MCP server is running:"
echo "     /mcp"
echo ""
echo "Done! The outline-wiki MCP server provides 17 tools"
echo "for searching, reading, creating, and managing wiki documents."
