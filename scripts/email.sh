#!/usr/bin/env bash
# desc: Look up an email thread summary by subject or slug
# usage: email.sh <query>
# examples: email.sh 'email:Dirtwire Hired Auto Policy'
#           email.sh hired-auto
#           email.sh insurance
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config

EMAIL_DIR="${REPO_ROOT}/$(cfg '.entities.email.dir')"

if [ -z "${1:-}" ]; then
  echo "Usage: email <query>"
  echo ""
  echo "Looks up email thread summaries in org/email/."
  echo "Query matches against thread subject, filename slug, or categories."
  echo ""
  echo "Examples:"
  echo "  email 'email:Dirtwire Hired Auto Policy'"
  echo "  email hired-auto"
  echo "  email insurance"
  exit 0
fi

query="$1"

# Strip 'email:' prefix if present
query="${query#email:}"

# Search: match thread subject (case-insensitive) or slug or category
found=0
# shellcheck disable=SC2086
for f in "${EMAIL_DIR}"/*.md; do
  [ -f "$f" ] || continue
  slug="$(basename "$f" .md)"

  # Check slug match
  if echo "$slug" | grep -qi "$query"; then
    cat "$f"
    found=$((found + 1))
    continue
  fi

  # Check thread subject match in frontmatter
  thread_subject=$(sed -n 's/^thread: *"\(.*\)"/\1/p' "$f")
  if echo "$thread_subject" | grep -qi "$query"; then
    cat "$f"
    found=$((found + 1))
    continue
  fi

  # Check category match
  if sed -n '/^categories:/,/^[^ ]/p' "$f" | grep -qi "$query"; then
    cat "$f"
    found=$((found + 1))
    continue
  fi
done

if [ "$found" -eq 0 ]; then
  echo "No email threads matching: $query"
  exit 1
fi
