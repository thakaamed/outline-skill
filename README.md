# outline-skill

An [OpenClaw](https://openclaw.ai) agent skill for full-featured [Outline](https://www.getoutline.com/) wiki management.

Works with any self-hosted or cloud Outline instance.

## What It Does

Gives any OpenClaw agent a complete Outline wiki interface via CLI:
- Full-text and title search
- Read, create, update, move, archive, delete documents
- Navigate collections and document trees
- Manage shares, stars, comments, templates
- **Document versioning** — standardized version tables with `version-init` / `version-bump`
- Audit log and revision history

**40+ commands** covering the full Outline REST API.

## Installation

### OpenClaw

```bash
git clone https://github.com/thakaamed/outline-skill.git
cd outline-skill
bash scripts/install.sh
```

Then edit the generated credentials file with your API key:

```bash
nano /data/openclaw/credentials/outline.env
# Set: OUTLINE_API_KEY=ol_api_... and OUTLINE_API_URL=https://your-wiki.example.com/api
```

Get your API key from: **Outline → Settings → API Tokens**

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "outline": {
      "command": "npx",
      "args": ["-y", "@thakaamed/outline-mcp"],
      "env": {
        "OUTLINE_API_KEY": "ol_api_your_token_here",
        "OUTLINE_API_URL": "https://your-wiki.example.com/api"
      }
    }
  }
}
```

Restart Claude Desktop — the Outline tools will appear automatically.

### Claude Code (CLI)

```bash
claude mcp add outline \
  --transport stdio \
  --env OUTLINE_API_KEY=ol_api_your_token_here \
  --env OUTLINE_API_URL=https://your-wiki.example.com/api \
  -- npx -y @thakaamed/outline-mcp
```

Verify: run `claude` then `/mcp` to confirm the `outline` server is listed with 17 tools.

### Any MCP Client (VS Code Copilot, Cursor, Windsurf, etc.)

```json
{
  "mcpServers": {
    "outline": {
      "command": "npx",
      "args": ["-y", "@thakaamed/outline-mcp"],
      "env": {
        "OUTLINE_API_KEY": "ol_api_your_token_here",
        "OUTLINE_API_URL": "https://your-wiki.example.com/api"
      }
    }
  }
}
```

## Requirements

- `bash` 4+
- `curl`
- `python3` (stdlib only — `json`, `sys`, `re`)
- An Outline API key

## Registering with OpenClaw

After installing, add the skill path to your agent's `openclaw.json`:

```json
{
  "skills": [
    {
      "name": "outline",
      "path": "/path/to/workspace/skills/outline"
    }
  ]
}
```

Or place the `skills/outline/` folder under your agent's workspace `skills/` directory — OpenClaw will auto-detect it.

## Structure

```
outline-skill/
├── SKILL.md                        # OpenClaw skill definition
├── README.md                       # This file
├── package.json                    # npm package (@thakaamed/outline-mcp)
├── tsconfig.json                   # TypeScript build config
├── server.json                     # MCP Registry metadata
├── .env.example                    # Credentials template
├── src/
│   └── index.ts                    # MCP server (17 tools, stdio transport)
├── build/                          # Compiled JS (generated, gitignored)
├── scripts/
│   ├── outline.sh                  # Main CLI (40+ commands) — shared core
│   └── install.sh                  # OpenClaw installer
└── templates/
    ├── versioned-document.md       # Generic versioned doc template
    └── team-member-status.md       # Living status doc template
```

**Dual compatibility:** OpenClaw agents use `SKILL.md` + `install.sh` + `outline.sh` directly. Claude Desktop/Code spawn the npm MCP server, which also shells out to `outline.sh`. Same execution core, two install paths — no conflicts.

## Usage Examples

```bash
SCRIPT="$WORKSPACE/tools/outline/outline.sh"

# Search the wiki
bash "$SCRIPT" search "architecture"

# Read a document
bash "$SCRIPT" get <doc-id>

# List all collections
bash "$SCRIPT" collections

# Full tree of a collection
bash "$SCRIPT" collection-tree <collection-id>

# Create a document from a file
bash "$SCRIPT" create "My Doc" <collection-id> my-doc.md

# Create from stdin
echo "# My Doc" | bash "$SCRIPT" create "My Doc" <collection-id>

# Revision history
bash "$SCRIPT" revisions <doc-id>

# Recent audit log
bash "$SCRIPT" events --limit 20
```

## Full Command Reference

### Documents
| Command | Description |
|---------|-------------|
| `search <query> [limit]` | Full-text search |
| `search-titles <query> [limit]` | Fast title-only search |
| `get <doc-id>` | Read document content (markdown) |
| `info <doc-id>` | Document metadata |
| `list [collection-id]` | List documents |
| `children <parent-doc-id>` | List child documents |
| `drafts [limit]` | List unpublished drafts |
| `archived [limit]` | List archived documents |
| `create <title> <coll-id> [file]` | Create document |
| `update <doc-id> <title> [file]` | Update document |
| `move <doc-id> <parent-doc-id>` | Re-parent document |
| `duplicate <doc-id> [title]` | Duplicate a document |
| `archive <doc-id>` | Archive document |
| `delete <doc-id> [--permanent]` | Delete (trash or permanent) |
| `restore <doc-id>` | Restore from trash |
| `unpublish <doc-id>` | Revert to draft |
| `backlinks <doc-id>` | Docs linking to this one |

### Collections
| Command | Description |
|---------|-------------|
| `collections` | List all collections |
| `collection-info <id>` | Collection details |
| `collection-create <name> [desc]` | Create collection |
| `collection-update <id> <name> [desc]` | Rename/update |
| `collection-tree <id>` | Full nested document tree |

### Comments, Sharing, Stars, Templates
| Command | Description |
|---------|-------------|
| `comments <doc-id>` | List comments |
| `comment-create <doc-id> <text>` | Add comment |
| `share <doc-id>` | Create public share link |
| `shares` | List active shares |
| `unshare <share-id>` | Revoke share |
| `star <doc-id>` | Star a document |
| `unstar <doc-id>` | Remove star |
| `starred` | List starred documents |
| `templates` | List templates |
| `template-get <id>` | Get template content |
| `template-create <title> <coll-id> [file]` | Create template |

### Document Versioning
| Command | Description |
|---------|-------------|
| `version-history <doc-id>` | Show version table inside a document |
| `version-init <doc-id> [author]` | Add version table (v1.0.0) to an unversioned doc |
| `version-bump <doc-id> <major\|minor\|patch> <summary> [author]` | Bump version + record change |

### Users & Activity
| Command | Description |
|---------|-------------|
| `users` | List workspace users |
| `events [doc-id] [--limit N] [--name EVENT]` | Audit log |
| `revisions <doc-id> [limit]` | Server-side revision history |
| `revision-get <rev-id> <doc-id>` | Read a specific revision |

## License

MIT — use freely in any project.
