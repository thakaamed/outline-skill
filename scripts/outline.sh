#!/usr/bin/env bash
# Outline Wiki CLI for IRIS / OpenClaw
# Usage: outline.sh <command> [args...]
# Requires: OUTLINE_API_KEY and OUTLINE_API_URL in environment
#           OR stored in /data/openclaw/credentials/outline.env

set -euo pipefail

# Load credentials if not already in env
CREDS_FILE="/data/openclaw/credentials/outline.env"
if [[ -z "${OUTLINE_API_KEY:-}" ]] && [[ -f "$CREDS_FILE" ]]; then
  source "$CREDS_FILE"
fi

: "${OUTLINE_API_KEY:?OUTLINE_API_KEY not set. Add to $CREDS_FILE or export it.}"
: "${OUTLINE_API_URL:?OUTLINE_API_URL not set. Add to $CREDS_FILE or export it.}"

COMMAND="${1:-help}"
shift || true

# JSON-encode a string safely
json_str() {
  python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' <<< "$1"
}

api() {
  local endpoint="$1"
  local data="${2:-{\}}"
  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '$tmpfile'" RETURN
  
  curl -s -X POST "${OUTLINE_API_URL}/${endpoint}" \
    -H "Authorization: Bearer ${OUTLINE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$data" > "$tmpfile" 2>&1
  
  # Check for API errors
  local ok
  ok=$(python3 -c "
import sys, json
try:
  with open('$tmpfile') as f:
    d = json.load(f)
  if d.get('ok') == False:
    err = d.get('error', 'unknown_error')
    msg = d.get('message', '')
    print(f'ERROR: {err}' + (f' — {msg}' if msg else ''))
  else:
    print('OK')
except:
  print('ERROR: Invalid response')
" 2>/dev/null)
  
  if [[ "$ok" == OK ]]; then
    cat "$tmpfile"
  else
    echo "$ok" >&2
    return 1
  fi
}

case "$COMMAND" in

  # ─── DOCUMENTS ───────────────────────────────────────────────────────

  search)
    QUERY="${1:?Usage: outline.sh search <query> [limit]}"
    LIMIT="${2:-10}"
    api "documents.search" "{\"query\": $(json_str "$QUERY"), \"limit\": $LIMIT}" \
      | python3 -c "
import sys, json, re
d = json.load(sys.stdin)
for item in d.get('data', []):
  doc = item.get('document', {})
  ctx = re.sub(r'<[^>]+>', '', item.get('context', '')).strip()
  print(f\"[{doc.get('id','')}] {doc.get('title','')}\")
  print(f\"  {doc.get('url','')}\")
  if ctx: print(f\"  {ctx[:200]}\")
  print()
"
    ;;

  search-titles)
    QUERY="${1:?Usage: outline.sh search-titles <query> [limit]}"
    LIMIT="${2:-10}"
    api "documents.search_titles" "{\"query\": $(json_str "$QUERY"), \"limit\": $LIMIT}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
for doc in d.get('data', []):
  print(f\"[{doc.get('id','')}] {doc.get('title','')}  (updated: {doc.get('updatedAt','')[:10]})\")
"
    ;;

  get)
    ID="${1:?Usage: outline.sh get <doc-id>}"
    api "documents.info" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"# {d.get('title','')}\n\n{d.get('text','')}\")
"
    ;;

  info)
    ID="${1:?Usage: outline.sh info <doc-id>}"
    api "documents.info" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Title: {d.get('title','')}\")
print(f\"ID: {d.get('id','')}\")
print(f\"Revision: {d.get('revision','')}\")
print(f\"Created: {d.get('createdAt','')[:19]}\")
print(f\"Updated: {d.get('updatedAt','')[:19]}\")
print(f\"Collection: {d.get('collectionId','')}\")
print(f\"Parent: {d.get('parentDocumentId','')}\")
print(f\"URL: https://wiki.thakaa.cloud{d.get('url','')}\")
"
    ;;

  list)
    COLLECTION="${1:-}"
    DATA="{\"limit\": 25}"
    [[ -n "$COLLECTION" ]] && DATA="{\"collectionId\": \"$COLLECTION\", \"limit\": 25}"
    api "documents.list" "$DATA" \
      | python3 -c "
import sys, json
for d in json.load(sys.stdin).get('data', []):
  print(f\"[{d['id']}] {d['title']} (updated: {d.get('updatedAt','')[:10]})\")
"
    ;;

  children)
    ID="${1:?Usage: outline.sh children <parent-doc-id>}"
    api "documents.list" "{\"parentDocumentId\": \"$ID\", \"limit\": 50}" \
      | python3 -c "
import sys, json
for d in json.load(sys.stdin).get('data', []):
  print(f\"[{d['id']}] {d['title']} (updated: {d.get('updatedAt','')[:10]})\")
"
    ;;

  drafts)
    LIMIT="${1:-25}"
    api "documents.drafts" "{\"limit\": $LIMIT}" \
      | python3 -c "
import sys, json
docs = json.load(sys.stdin).get('data', [])
if not docs:
  print('No drafts found.')
else:
  for d in docs:
    print(f\"[{d['id']}] {d['title']} (updated: {d.get('updatedAt','')[:10]})\")
"
    ;;

  archived)
    LIMIT="${1:-25}"
    api "documents.archived" "{\"limit\": $LIMIT}" \
      | python3 -c "
import sys, json
docs = json.load(sys.stdin).get('data', [])
if not docs:
  print('No archived documents found.')
else:
  for d in docs:
    print(f\"[{d['id']}] {d['title']} (archived: {d.get('archivedAt','')[:10]})\")
"
    ;;

  create)
    TITLE="${1:?Usage: outline.sh create <title> <collection-id> [markdown-file]}"
    COLLECTION="${2:?Missing collection-id}"
    if [[ -n "${3:-}" ]]; then
      CONTENT=$(cat "$3")
    else
      CONTENT=$(cat)  # read from stdin
    fi
    ESCAPED=$(echo "$CONTENT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
    api "documents.create" "{\"title\": $(json_str "$TITLE"), \"collectionId\": \"$COLLECTION\", \"text\": $ESCAPED, \"publish\": true}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Created: [{d.get('id','')}] {d.get('title','')}\\nURL: {d.get('url','')}\")
"
    ;;

  update)
    ID="${1:?Usage: outline.sh update <doc-id> <title> [markdown-file]}"
    TITLE="${2:?Missing title}"
    if [[ -n "${3:-}" ]]; then
      CONTENT=$(cat "$3")
    else
      CONTENT=$(cat)
    fi
    ESCAPED=$(echo "$CONTENT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
    api "documents.update" "{\"id\": \"$ID\", \"title\": $(json_str "$TITLE"), \"text\": $ESCAPED}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Updated: [{d.get('id','')}] {d.get('title','')}\")
"
    ;;

  move)
    ID="${1:?Usage: outline.sh move <doc-id> <parent-doc-id>}"
    PARENT="${2:?Missing parent-doc-id}"
    api "documents.move" "{\"id\": \"$ID\", \"parentDocumentId\": \"$PARENT\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
docs = d if isinstance(d, list) else [d]
for doc in docs:
  if isinstance(doc, dict) and 'title' in doc:
    print(f\"Moved: [{doc.get('id','')}] {doc.get('title','')} → parent {doc.get('parentDocumentId','')}\")
    break
else:
  print('Move completed.')
"
    ;;

  archive)
    ID="${1:?Usage: outline.sh archive <doc-id>}"
    api "documents.archive" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Archived: [{d.get('id','')}] {d.get('title','')}\")
"
    ;;

  delete)
    ID="${1:?Usage: outline.sh delete <doc-id> [--permanent]}"
    PERMANENT="${2:-}"
    if [[ "$PERMANENT" == "--permanent" ]]; then
      api "documents.delete" "{\"id\": \"$ID\", \"permanent\": true}" \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'Permanently deleted: {\"$ID\"}')" 
    else
      api "documents.delete" "{\"id\": \"$ID\"}" \
        | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Deleted (trashed): [{d.get('id','$ID')}] {d.get('title','')}\")
print('Use --permanent to permanently delete, or restore with: outline.sh restore <doc-id>')
"
    fi
    ;;

  restore)
    ID="${1:?Usage: outline.sh restore <doc-id>}"
    api "documents.restore" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Restored: [{d.get('id','')}] {d.get('title','')}\")
"
    ;;

  duplicate)
    ID="${1:?Usage: outline.sh duplicate <doc-id> [new-title]}"
    TITLE="${2:-}"
    if [[ -n "$TITLE" ]]; then
      DATA="{\"id\": \"$ID\", \"title\": $(json_str "$TITLE")}"
    else
      DATA="{\"id\": \"$ID\"}"
    fi
    api "documents.duplicate" "$DATA" \
      | python3 -c "
import sys, json
raw = json.load(sys.stdin).get('data', {})
# API returns {documents: [doc]} not a direct doc
if isinstance(raw, dict) and 'documents' in raw:
  docs = raw['documents']
  d = docs[0] if docs else {}
else:
  d = raw
print(f\"Duplicated: [{d.get('id','')}] {d.get('title','')}\")
print(f\"URL: {d.get('url','')}\")
"
    ;;

  unpublish)
    ID="${1:?Usage: outline.sh unpublish <doc-id>}"
    api "documents.unpublish" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Unpublished (now draft): [{d.get('id','')}] {d.get('title','')}\")
"
    ;;

  # ─── COLLECTIONS ─────────────────────────────────────────────────────

  collections)
    api "collections.list" '{}' \
      | python3 -c "
import sys, json
for c in json.load(sys.stdin).get('data', []):
  print(f\"[{c['id']}] {c['name']} — {c.get('description') or ''}\")
"
    ;;

  collection-info)
    ID="${1:?Usage: outline.sh collection-info <collection-id>}"
    api "collections.info" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
c = json.load(sys.stdin).get('data', {})
print(f\"Name: {c.get('name','')}\")
print(f\"ID: {c.get('id','')}\")
print(f\"Description: {c.get('description','')}\")
print(f\"Color: {c.get('color','')}\")
print(f\"Documents: {c.get('documentCount', c.get('documents',{}).get('count','?'))}\")
print(f\"Permission: {c.get('permission','')}\")
print(f\"Created: {c.get('createdAt','')[:19]}\")
print(f\"Updated: {c.get('updatedAt','')[:19]}\")
"
    ;;

  collection-create)
    NAME="${1:?Usage: outline.sh collection-create <name> [description]}"
    DESC="${2:-}"
    DATA="{\"name\": $(json_str "$NAME")}"
    [[ -n "$DESC" ]] && DATA="{\"name\": $(json_str "$NAME"), \"description\": $(json_str "$DESC")}"
    api "collections.create" "$DATA" \
      | python3 -c "
import sys, json
c = json.load(sys.stdin).get('data', {})
print(f\"Created: [{c.get('id','')}] {c.get('name','')}\")
"
    ;;

  collection-update)
    ID="${1:?Usage: outline.sh collection-update <collection-id> <name> [description]}"
    NAME="${2:?Missing name}"
    DESC="${3:-}"
    DATA="{\"id\": \"$ID\", \"name\": $(json_str "$NAME")}"
    [[ -n "$DESC" ]] && DATA="{\"id\": \"$ID\", \"name\": $(json_str "$NAME"), \"description\": $(json_str "$DESC")}"
    api "collections.update" "$DATA" \
      | python3 -c "
import sys, json
c = json.load(sys.stdin).get('data', {})
print(f\"Updated: [{c.get('id','')}] {c.get('name','')}\")
"
    ;;

  collection-tree)
    ID="${1:?Usage: outline.sh collection-tree <collection-id>}"
    api "collections.documents" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json

def print_tree(nodes, indent=0):
  for node in nodes:
    prefix = '  ' * indent + ('├── ' if indent > 0 else '')
    title = node.get('title', 'Untitled')
    nid = node.get('id', '')
    print(f'{prefix}[{nid}] {title}')
    children = node.get('children', [])
    if children:
      print_tree(children, indent + 1)

d = json.load(sys.stdin)
nodes = d.get('data', [])
if not nodes:
  print('No documents in this collection.')
else:
  print_tree(nodes)
"
    ;;

  # ─── COMMENTS ────────────────────────────────────────────────────────

  comments)
    DOC_ID="${1:?Usage: outline.sh comments <doc-id>}"
    api "comments.list" "{\"documentId\": \"$DOC_ID\"}" \
      | python3 -c "
import sys, json

def extract_text(data):
  '''Extract plain text from ProseMirror JSON.'''
  if isinstance(data, str):
    return data
  if isinstance(data, dict):
    if data.get('type') == 'text':
      return data.get('text', '')
    parts = []
    for child in data.get('content', []):
      parts.append(extract_text(child))
    return ' '.join(parts)
  return ''

d = json.load(sys.stdin)
comments = d.get('data', [])
if not comments:
  print('No comments found.')
else:
  for c in comments:
    user = c.get('createdBy', {}).get('name', 'unknown')
    date = c.get('createdAt', '')[:19]
    text = extract_text(c.get('data', {})).strip()
    resolved = ' [RESOLVED]' if c.get('resolvedAt') else ''
    print(f\"[{c.get('id','')}] {user} ({date}){resolved}\")
    print(f\"  {text[:300]}\")
    print()
"
    ;;

  comment-create)
    DOC_ID="${1:?Usage: outline.sh comment-create <doc-id> <text>}"
    TEXT="${2:?Missing comment text}"
    # Convert plain text to ProseMirror JSON
    PM_DATA=$(python3 -c "
import json, sys
text = sys.argv[1]
# Split by newlines into paragraphs
paragraphs = text.split('\n')
content = []
for p in paragraphs:
  if p.strip():
    content.append({
      'type': 'paragraph',
      'content': [{'type': 'text', 'text': p}]
    })
  else:
    content.append({'type': 'paragraph'})
if not content:
  content = [{'type': 'paragraph', 'content': [{'type': 'text', 'text': text}]}]
doc = {'type': 'doc', 'content': content}
print(json.dumps(doc))
" "$TEXT")
    api "comments.create" "{\"documentId\": \"$DOC_ID\", \"data\": $PM_DATA}" \
      | python3 -c "
import sys, json
c = json.load(sys.stdin).get('data', {})
print(f\"Comment created: [{c.get('id','')}]\")
print(f\"By: {c.get('createdBy', {}).get('name', 'unknown')}\")
"
    ;;

  # ─── SHARING ─────────────────────────────────────────────────────────

  share)
    DOC_ID="${1:?Usage: outline.sh share <doc-id>}"
    api "shares.create" "{\"documentId\": \"$DOC_ID\", \"published\": true}" \
      | python3 -c "
import sys, json
s = json.load(sys.stdin).get('data', {})
url = s.get('url', '')
print(f\"Share created: [{s.get('id','')}]\")
print(f\"URL: {url}\")
print(f\"Includes children: {s.get('includeChildDocuments', False)}\")
"
    ;;

  shares)
    api "shares.list" '{}' \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data', [])
# Could be list or dict with 'shares' key
if isinstance(data, dict):
  shares = data.get('shares', [])
else:
  shares = data
if not shares:
  print('No active shares.')
else:
  for s in shares:
    doc_title = s.get('documentTitle', s.get('sourceTitle', ''))
    published = ' [published]' if s.get('published') else ' [unpublished]'
    print(f\"[{s.get('id','')}] {doc_title}{published}\")
    print(f\"  URL: {s.get('url','')}\")
    print(f\"  Created: {s.get('createdAt','')[:19]}  Views: {s.get('views', 0)}\")
    print()
"
    ;;

  unshare)
    SHARE_ID="${1:?Usage: outline.sh unshare <share-id>}"
    api "shares.revoke" "{\"id\": \"$SHARE_ID\"}" \
      | python3 -c "
import sys, json
json.load(sys.stdin)
print(f'Share revoked: $SHARE_ID')
"
    ;;

  # ─── STARS ───────────────────────────────────────────────────────────

  star)
    DOC_ID="${1:?Usage: outline.sh star <doc-id>}"
    api "stars.create" "{\"documentId\": \"$DOC_ID\"}" \
      | python3 -c "
import sys, json
s = json.load(sys.stdin).get('data', {})
print(f\"Starred: [{s.get('documentId', '$DOC_ID')}]\")
"
    ;;

  unstar)
    DOC_ID="${1:?Usage: outline.sh unstar <doc-id>}"
    # stars.delete needs the star ID, so we list first
    STAR_ID=$(api "stars.list" '{}' 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin).get('data', {})
stars = data.get('stars', []) if isinstance(data, dict) else data
for s in stars:
  if s.get('documentId') == '$DOC_ID':
    print(s.get('id', ''))
    break
" 2>/dev/null)
    if [[ -n "$STAR_ID" ]]; then
      api "stars.delete" "{\"id\": \"$STAR_ID\"}" \
        | python3 -c "
import sys, json
json.load(sys.stdin)
print(f'Unstarred: $DOC_ID')
"
    else
      echo "Document is not starred: $DOC_ID"
    fi
    ;;

  starred)
    api "stars.list" '{}' \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
data = d.get('data', {})
# API returns {stars: [], documents: []}
if isinstance(data, dict):
  stars = data.get('stars', [])
  docs = {doc['id']: doc for doc in data.get('documents', [])}
else:
  stars = data
  docs = {}
if not stars:
  print('No starred documents.')
else:
  for s in stars:
    doc_id = s.get('documentId', '')
    doc = docs.get(doc_id, {})
    title = doc.get('title', '')
    print(f\"[{doc_id}] {title} (starred: {s.get('createdAt','')[:10]})\")
"
    ;;

  # ─── TEMPLATES ───────────────────────────────────────────────────────

  templates)
    api "documents.list" '{"template": true, "limit": 50}' \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
templates = d.get('data', [])
if not templates:
  print('No templates found.')
else:
  for t in templates:
    print(f\"[{t.get('id','')}] {t.get('title','')} (updated: {t.get('updatedAt','')[:10]})\")
"
    ;;

  template-get)
    ID="${1:?Usage: outline.sh template-get <template-id>}"
    api "documents.info" "{\"id\": \"$ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"# {d.get('title','')}\n\n{d.get('text','')}\")
"
    ;;

  template-create)
    TITLE="${1:?Usage: outline.sh template-create <title> <collection-id> [markdown-file]}"
    COLLECTION="${2:?Missing collection-id}"
    if [[ -n "${3:-}" ]]; then
      CONTENT=$(cat "$3")
    else
      CONTENT=$(cat)
    fi
    ESCAPED=$(echo "$CONTENT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
    # Create doc then convert to template using documents.templatize
    api "documents.create" "{\"title\": $(json_str "$TITLE"), \"collectionId\": \"$COLLECTION\", \"text\": $ESCAPED, \"publish\": true}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
doc_id = d.get('id', '')
print(doc_id)
" | while read -r DOC_ID; do
      if [[ -n "$DOC_ID" ]]; then
        api "documents.templatize" "{\"id\": \"$DOC_ID\"}" \
          | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"Template created: [{d.get('id','')}] {d.get('title','')}\")
"
      fi
    done
    ;;

  # ─── USERS ──────────────────────────────────────────────────────────

  users)
    api "users.list" '{}' \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
users = d.get('data', [])
if not users:
  print('No users found.')
else:
  for u in users:
    role = u.get('role', '')
    email = u.get('email', '')
    status = ' [suspended]' if u.get('isSuspended') else ''
    print(f\"[{u.get('id','')}] {u.get('name','')} <{email}> ({role}){status}\")
"
    ;;

  # ─── EVENTS / AUDIT ─────────────────────────────────────────────────

  events)
    # Parse optional args: events [doc-id] [--limit N] [--name event-name]
    DOC_ID="" ; LIMIT="25" ; EVT_NAME=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --limit) LIMIT="$2"; shift 2 ;;
        --name) EVT_NAME="$2"; shift 2 ;;
        *) DOC_ID="$1"; shift ;;
      esac
    done
    DATA=$(python3 -c "
import json
d = {'limit': $LIMIT}
doc_id = '$DOC_ID'
evt_name = '$EVT_NAME'
if doc_id: d['documentId'] = doc_id
if evt_name: d['name'] = evt_name
print(json.dumps(d))
")
    api "events.list" "$DATA" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
events = d.get('data', [])
if not events:
  print('No events found.')
else:
  for e in events:
    actor = e.get('actor', {}).get('name', 'system')
    name = e.get('name', '')
    date = e.get('createdAt', '')[:19]
    edata = e.get('data') or {}
    doc_title = ''
    if edata.get('title'):
      doc_title = f\" — {edata['title']}\"
    elif e.get('documentId'):
      doc_title = f\" — doc:{e['documentId'][:8]}\"
    coll_name = ''
    if edata.get('name'):
      coll_name = f\" — {edata['name']}\"
    print(f\"{date}  {name}  by {actor}{doc_title}{coll_name}\")
"
    ;;

  # ─── BACKLINKS ───────────────────────────────────────────────────────

  backlinks)
    DOC_ID="${1:?Usage: outline.sh backlinks <doc-id>}"
    # Get the document's URL slug, then search for references to it
    URL_ID=$(api "documents.info" "{\"id\": \"$DOC_ID\"}" | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(d.get('urlId', ''))
" 2>/dev/null)
    if [[ -z "$URL_ID" ]]; then
      echo "Could not find document: $DOC_ID" >&2
      exit 1
    fi
    api "documents.search" "{\"query\": \"$URL_ID\", \"limit\": 50}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
results = d.get('data', [])
# Exclude the document itself
backlinks = [item for item in results if item.get('document', {}).get('id') != '$DOC_ID']
if not backlinks:
  print('No backlinks found.')
else:
  for item in backlinks:
    doc = item.get('document', {})
    print(f\"[{doc.get('id','')}] {doc.get('title','')}\")
"
    ;;

  # ─── REVISIONS ──────────────────────────────────────────────────────

  revisions)
    ID="${1:?Usage: outline.sh revisions <doc-id> [limit]}"
    LIMIT="${2:-5}"
    api "revisions.list" "{\"documentId\": \"$ID\", \"limit\": $LIMIT}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin)
revs = d.get('data', [])
if not revs:
  print('No revisions found.')
else:
  for r in revs:
    user = r.get('createdBy', {}).get('name', 'unknown')
    print(f\"[{r.get('id','')}] v{r.get('version', '?')} — {r.get('createdAt','')[:19]} by {user}\")
"
    ;;

  revision-get)
    ID="${1:?Usage: outline.sh revision-get <revision-id> <doc-id>}"
    DOC_ID="${2:?Usage: outline.sh revision-get <revision-id> <doc-id>}"
    api "revisions.info" "{\"id\": \"$ID\", \"documentId\": \"$DOC_ID\"}" \
      | python3 -c "
import sys, json
d = json.load(sys.stdin).get('data', {})
print(f\"# Revision {d.get('version', '?')} — {d.get('createdAt','')[:19]}\n\n{d.get('text','')}\")
"
    ;;

  # ─── HELP ────────────────────────────────────────────────────────────

  help|*)
    cat <<'EOF'
Outline Wiki CLI — wiki.thakaa.cloud

DOCUMENTS:
  search <query> [limit]              Full-text search
  search-titles <query> [limit]       Fast title-only search
  get <doc-id>                        Read document content (markdown)
  info <doc-id>                       Document metadata
  list [collection-id]                List documents
  children <parent-doc-id>            List child documents
  drafts [limit]                      List unpublished drafts
  archived [limit]                    List archived documents
  create <title> <coll-id> [file]     Create document (content from file or stdin)
  update <doc-id> <title> [file]      Update document
  move <doc-id> <parent-doc-id>       Move document under a new parent
  duplicate <doc-id> [new-title]      Duplicate a document
  archive <doc-id>                    Archive a document
  delete <doc-id> [--permanent]       Delete document (trash or permanent)
  restore <doc-id>                    Restore from trash/archive
  unpublish <doc-id>                  Revert published doc to draft
  backlinks <doc-id>                  Show documents linking to this one

COLLECTIONS:
  collections                         List all collections
  collection-info <id>                Collection details
  collection-create <name> [desc]     Create a new collection
  collection-update <id> <name> [desc]  Rename/update collection
  collection-tree <id>                Full nested document tree

COMMENTS:
  comments <doc-id>                   List comments on a document
  comment-create <doc-id> <text>      Add a comment to a document

SHARING:
  share <doc-id>                      Create a public share link
  shares                              List all active shares
  unshare <share-id>                  Revoke a share link

STARS:
  star <doc-id>                       Star/bookmark a document
  unstar <doc-id>                     Remove star from a document
  starred                             List starred documents

TEMPLATES:
  templates                           List available templates
  template-get <id>                   Get template content
  template-create <title> <coll-id> [file]  Create a new template

USERS:
  users                               List workspace users

ACTIVITY:
  events [doc-id] [--limit N] [--name EVENT]  Recent activity/audit log

REVISIONS:
  revisions <doc-id> [limit]          Revision history
  revision-get <rev-id> <doc-id>      Read a specific revision

Environment (or /data/openclaw/credentials/outline.env):
  OUTLINE_API_KEY=ol_api_...
  OUTLINE_API_URL=https://wiki.thakaa.cloud/api
EOF
    ;;
esac
