---
name: outline
description: "This skill should be used when the user asks to search, read, create, update, or manage documents in an Outline wiki. Triggers on: \"search the wiki\", \"find in wiki\", \"create a wiki doc\", \"update the wiki\", \"sync to wiki\", \"wiki collections\", \"outline documents\", or any Outline wiki operation."
---

# Outline Wiki Skill

Connects Claude Code to any [Outline](https://www.getoutline.com/) wiki instance via the REST API.

## Tool

All commands via: `bash scripts/outline.sh <command> [args...]`

The script reads `OUTLINE_API_KEY` and `OUTLINE_API_URL` from the shell environment.

## Common Commands

```bash
# Search the wiki
bash scripts/outline.sh search "architecture"

# Read a document (returns full markdown)
bash scripts/outline.sh get <doc-id>

# List all collections
bash scripts/outline.sh collections

# List docs in a collection
bash scripts/outline.sh list <collection-id>

# Create a new document (content from stdin)
echo "# My Doc\nContent here" | bash scripts/outline.sh create "Title" <collection-id>

# Update an existing document
cat updated.md | bash scripts/outline.sh update <doc-id> "New Title"
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

## Document Versioning Convention

Every important document should carry a version table:

```markdown
## Document Version History

| Version | Date | Author | Summary |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-29 | Nabil | Initial version |
```

- **patch** — typos, clarifications (1.0.0 -> 1.0.1)
- **minor** — new sections, added content (1.0.0 -> 1.1.0)
- **major** — full rewrites, structural overhaul (1.0.0 -> 2.0.0)

Use `version-init` before `version-bump` on previously unversioned docs.

## Workflow

1. **Search first** — always search before creating to avoid duplicates
2. **Get full content** — search returns snippets; use `get` for full doc
3. **Confirm before write** — ask before creating/updating docs unless explicitly told to
4. **Use collection IDs** — run `collections` once to cache the IDs and names
5. **Version important docs** — run `version-init` on new docs, `version-bump` on updates
