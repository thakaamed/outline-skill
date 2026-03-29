---
name: outline
description: Read, search, create and update documents in an Outline wiki. Supports full Outline REST API — search, browse, create, update, move, share, comment, star, template, version, and audit log operations.
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

## Common Commands

```bash
# Search the wiki
bash $WORKSPACE/tools/outline/outline.sh search "architecture"

# Read a document (returns full markdown)
bash $WORKSPACE/tools/outline/outline.sh get <doc-id>

# List all collections
bash $WORKSPACE/tools/outline/outline.sh collections

# List docs in a collection
bash $WORKSPACE/tools/outline/outline.sh list <collection-id>

# Create a new document (content from stdin)
echo "# My Doc\nContent here" | bash $WORKSPACE/tools/outline/outline.sh create "Title" <collection-id>

# Update an existing document
cat updated.md | bash $WORKSPACE/tools/outline/outline.sh update <doc-id> "New Title"
```

## Document Versioning

Every important document should carry a version table. This is the standard format:

```markdown
## 📋 Document Version History

| Version | Date | Author | Summary |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-29 | Iris | Initial version |
| 1.1.0 | 2026-04-01 | Nabil | Added architecture section |
```

### Versioning Commands

```bash
SCRIPT="$WORKSPACE/tools/outline/outline.sh"

# Show version table from a doc
bash "$SCRIPT" version-history <doc-id>

# Add a version table (v1.0.0) to an unversioned doc
bash "$SCRIPT" version-init <doc-id> "AuthorName"

# Bump version and record a change
bash "$SCRIPT" version-bump <doc-id> minor "Added deployment section" "AuthorName"
bash "$SCRIPT" version-bump <doc-id> patch "Fixed typo" "AuthorName"
bash "$SCRIPT" version-bump <doc-id> major "Complete rewrite" "AuthorName"
```

### Versioning Rules
- **`patch`** — typos, clarifications, minor wording fixes (1.0.0 → 1.0.1)
- **`minor`** — new sections, added content, non-breaking changes (1.0.0 → 1.1.0)
- **`major`** — full rewrites, structural overhaul, breaking changes (1.0.0 → 2.0.0)
- The version table lives **inside the document body** — visible to all readers
- Use `version-init` before `version-bump` on previously unversioned docs
- Complements Outline's built-in revision history (which tracks every save)

### Templates

```bash
# New versioned doc from template
bash "$SCRIPT" create "My Doc Title" <collection-id> \
  $WORKSPACE/tools/outline/templates/versioned-document.md

# Team member status file
bash "$SCRIPT" create "Alice — Status" <collection-id> \
  $WORKSPACE/tools/outline/templates/team-member-status.md
```

Available templates:
- `templates/versioned-document.md` — generic versioned document
- `templates/team-member-status.md` — living team member status file

## Workflow

1. **Search first** — always search before creating to avoid duplicates
2. **Get full content** — search returns snippets; use `get` for full doc
3. **Confirm before write** — ask before creating/updating docs unless explicitly told to
4. **Use collection IDs** — run `collections` once to cache the IDs and names
5. **Version important docs** — run `version-init` on new docs, `version-bump` on updates
