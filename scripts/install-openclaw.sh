#!/usr/bin/env bash
# Outline Skill Installer for OpenClaw
# Usage: bash install.sh [/path/to/credentials/outline.env]
#
# Sets up the Outline skill in an OpenClaw agent workspace.
# - Copies outline.sh to $WORKSPACE/tools/outline/
# - Copies templates to $WORKSPACE/tools/outline/templates/
# - Copies SKILL.md to $WORKSPACE/skills/outline/
# - Creates credential file stub (if not exists)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Detect workspace (default to OpenClaw workspace convention)
WORKSPACE="${OPENCLAW_WORKSPACE:-/data/openclaw/workspace}"
if [[ ! -d "$WORKSPACE" ]]; then
  # Fallback: try to detect from home
  WORKSPACE="${HOME}/.openclaw/workspace"
fi

CREDS_FILE="${1:-/data/openclaw/credentials/outline.env}"

echo "🔮 Outline Skill Installer"
echo "  Workspace: $WORKSPACE"
echo "  Credentials: $CREDS_FILE"
echo ""

# 1. Create directories
mkdir -p "$WORKSPACE/tools/outline/templates"
mkdir -p "$WORKSPACE/skills/outline"

# 2. Install CLI script
cp "$SKILL_DIR/skills/outline/scripts/outline.sh" "$WORKSPACE/tools/outline/outline.sh"
chmod +x "$WORKSPACE/tools/outline/outline.sh"
echo "✅ Installed outline.sh → $WORKSPACE/tools/outline/outline.sh"

# 3. Install templates
if [[ -d "$SKILL_DIR/skills/outline/templates" ]]; then
  cp -r "$SKILL_DIR/skills/outline/templates/"* "$WORKSPACE/tools/outline/templates/" 2>/dev/null || true
  echo "✅ Installed templates → $WORKSPACE/tools/outline/templates/"
fi

# 4. Install SKILL.md
cp "$SKILL_DIR/SKILL.md" "$WORKSPACE/skills/outline/SKILL.md"
echo "✅ Installed SKILL.md → $WORKSPACE/skills/outline/SKILL.md"

# 5. Create credentials stub (if not exists)
CREDS_DIR="$(dirname "$CREDS_FILE")"
mkdir -p "$CREDS_DIR"
if [[ ! -f "$CREDS_FILE" ]]; then
  cat > "$CREDS_FILE" << 'EOF'
# Outline Wiki Credentials
# Get your API key from: Outline → Settings → API Tokens
OUTLINE_API_KEY=ol_api_REPLACE_ME
OUTLINE_API_URL=https://your-wiki.example.com/api
EOF
  chmod 600 "$CREDS_FILE"
  echo "📝 Created credentials stub → $CREDS_FILE"
  echo "   ⚠️  Edit this file and add your API key before use"
else
  echo "✅ Credentials file already exists: $CREDS_FILE"
fi

echo ""
echo "🎉 Done! Test with:"
echo "   bash $WORKSPACE/tools/outline/outline.sh collections"
