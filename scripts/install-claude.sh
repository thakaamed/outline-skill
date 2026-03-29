#!/usr/bin/env bash
# Outline Skill Installer for Claude Code
# Usage: bash install-claude.sh
#
# Sets up environment variables and prints instructions to install
# the outline-wiki plugin via the Claude Code marketplace.

set -euo pipefail

CLAUDE_ENV="${HOME}/.claude/.env"

echo "Outline Wiki — Claude Code Setup"
echo "================================="
echo ""

# 1. Prompt for credentials
read -rp "Outline API Key [ol_api_...]: " API_KEY
if [[ -z "$API_KEY" ]]; then
  echo "Error: API key is required."
  exit 1
fi

read -rp "Outline API URL [https://wiki.thakaa.cloud/api]: " API_URL
API_URL="${API_URL:-https://wiki.thakaa.cloud/api}"
# Strip trailing slash from URL if present
API_URL="${API_URL%/}"

# 2. Write env vars to ~/.claude/.env
mkdir -p "$(dirname "$CLAUDE_ENV")"

# Append or update existing values
if [[ -f "$CLAUDE_ENV" ]]; then
  # Remove existing OUTLINE_ lines if present
  grep -v '^OUTLINE_API_KEY=' "$CLAUDE_ENV" | grep -v '^OUTLINE_API_URL=' > "${CLAUDE_ENV}.tmp" || true
  mv "${CLAUDE_ENV}.tmp" "$CLAUDE_ENV"
fi

cat >> "$CLAUDE_ENV" << EOF
OUTLINE_API_KEY=${API_KEY}
OUTLINE_API_URL=${API_URL}
EOF

chmod 600 "$CLAUDE_ENV"
echo ""
echo "Credentials saved to ${CLAUDE_ENV}"

# 3. Print next steps
echo ""
echo "Next steps — run these inside Claude Code:"
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
echo "Done! The outline-wiki MCP server will have 17 tools"
echo "for searching, reading, creating, and managing wiki documents."
