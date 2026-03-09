---
name: outline
description: Read, search, create and update documents in an Outline wiki. Supports full Outline REST API — search, browse, create, update, move, share, comment, star, template, and audit log operations.
---

# Outline Wiki Skill

Connects an OpenClaw agent to any [Outline](https://www.getoutline.com/) wiki instance via the REST API.

## Setup

1. Run the installer:
   ```bash
   bash scripts/install.sh
   ```

2. Edit the credentials file:
   ```env
   # /data/openclaw/credentials/outline.env
   OUTLINE_API_KEY=ol_api_...
   OUTLINE_API_URL=https://your-wiki.example.com/api
   ```
   Get your API key: Outline → Settings → API Tokens

3. Test:
   ```bash
   bash $WORKSPACE/tools/outline/outline.sh collections
   ```

## Tool

All commands via: `bash $WORKSPACE/tools/outline/outline.sh <command>`

## Commands Reference

### Documents
```bash
outline.sh search <query> [limit]              # Full-text search
outline.sh search-titles <query> [limit]       # Fast title-only search
outline.sh get <doc-id>                        # Read document content (markdown)
outline.sh info <doc-id>                       # Document metadata
outline.sh list [collection-id]                # List documents
outline.sh children <parent-doc-id>            # List child documents
outline.sh drafts [limit]                      # List unpublished drafts
outline.sh archived [limit]                    # List archived documents
outline.sh create <title> <coll-id> [file]     # Create document
outline.sh update <doc-id> <title> [file]      # Update document
outline.sh move <doc-id> <parent-doc-id>       # Re-parent document
outline.sh duplicate <doc-id> [new-title]      # Duplicate a document
outline.sh archive <doc-id>                    # Archive document
outline.sh delete <doc-id> [--permanent]       # Delete (trash or permanent)
outline.sh restore <doc-id>                    # Restore from trash
outline.sh unpublish <doc-id>                  # Revert to draft
outline.sh backlinks <doc-id>                  # Docs linking to this one
```

### Collections
```bash
outline.sh collections                         # List all collections
outline.sh collection-info <id>                # Collection details
outline.sh collection-create <name> [desc]     # Create collection
outline.sh collection-update <id> <name> [desc] # Rename/update
outline.sh collection-tree <id>                # Full nested document tree
```

### Comments
```bash
outline.sh comments <doc-id>                   # List comments
outline.sh comment-create <doc-id> <text>      # Add comment
```

### Sharing
```bash
outline.sh share <doc-id>                      # Create public share link
outline.sh shares                              # List active shares
outline.sh unshare <share-id>                  # Revoke share
```

### Stars / Bookmarks
```bash
outline.sh star <doc-id>                       # Star a document
outline.sh unstar <doc-id>                     # Remove star
outline.sh starred                             # List starred documents
```

### Templates
```bash
outline.sh templates                           # List templates
outline.sh template-get <id>                   # Get template content
outline.sh template-create <title> <coll-id> [file]  # Create template
```

### Users & Activity
```bash
outline.sh users                               # List workspace users
outline.sh events [doc-id] [--limit N] [--name EVENT]  # Audit log
```

### Revisions
```bash
outline.sh revisions <doc-id> [limit]          # Revision history
outline.sh revision-get <rev-id> <doc-id>      # Read a specific revision
```

## Agent Workflow Guidelines

1. **Search first** — always search before creating to avoid duplicates
2. **Use `get` for full content** — `search` returns snippets only
3. **Confirm before writes** — ask before creating/updating unless explicitly told to
4. **Cache collection IDs** — run `collections` once and reuse IDs
5. **State files > logs** — for living docs (status pages, etc.), keep as current-truth; Outline versioning handles history

## Templates

| File | Purpose |
|------|---------|
| `templates/team-member-status.md` | Living status doc for a team member |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OUTLINE_API_KEY` | ✅ | API token from Outline settings |
| `OUTLINE_API_URL` | ✅ | Base API URL, e.g. `https://wiki.example.com/api` |
