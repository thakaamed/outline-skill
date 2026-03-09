# outline-skill

An [OpenClaw](https://openclaw.ai) agent skill for full-featured Outline wiki management.

Built by ThakaaMed engineering — used in production at `wiki.thakaa.cloud`.

## What It Does

Gives any OpenClaw agent a complete Outline wiki interface:
- Full-text and title search
- Read, create, update, move, archive, delete documents
- Navigate collections and document trees
- Manage shares, stars, comments, templates
- Audit log and revision history

## Quick Install

```bash
git clone git@github.com:thakaamed/outline-skill.git
cd outline-skill
bash scripts/install.sh
```

Then edit `/data/openclaw/credentials/outline.env` with your API key.

## Requirements

- `bash` 4+
- `curl`
- `python3` (stdlib only — `json`, `sys`, `re`)
- An Outline API key (Settings → API Tokens in your Outline workspace)

## Registering with OpenClaw

After installing, reference the skill in your agent's `openclaw.json`:

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

Or place it under your workspace `skills/` directory — OpenClaw will auto-detect it.

## Structure

```
outline-skill/
├── SKILL.md                        # OpenClaw skill definition
├── README.md                       # This file
├── .env.example                    # Credentials template
├── scripts/
│   ├── outline.sh                  # Main CLI (all commands)
│   └── install.sh                  # Installer
└── templates/
    └── team-member-status.md       # Living status doc template
```

## Usage Examples

```bash
# Search the wiki
bash outline.sh search "FHIR architecture"

# Read a document
bash outline.sh get abc123

# Create a document
echo "# My Doc\n\nContent here." | bash outline.sh create "My Doc" <collection-id>

# List collections
bash outline.sh collections

# Full tree of a collection
bash outline.sh collection-tree <collection-id>

# Revision history
bash outline.sh revisions <doc-id>
```

## License

MIT — use freely in any project.

---

Maintained by [ThakaaMed](https://thakaamed.com)
