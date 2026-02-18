#!/usr/bin/env bash
# desc: Show next advancing actions needed across shows
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INDEX="${REPO_ROOT}/org/touring/.state/shows.json"
PEOPLE="${REPO_ROOT}/org/people.json"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./dirtclaw build:index" >&2
  exit 1
fi

# ── Classify each show by advancing state ─────────────────────────
needs_outreach=""
awaiting_reply=""
confirmed=""

needs_count=0
awaiting_count=0
confirmed_count=0

while IFS=$'\t' read -r show_id date venue; do
  dir="${SHOWS_DIR}/${show_id}"

  # Format short date (strip year)
  short_date="${date:5}"

  # Determine state
  if [ -f "${dir}/advancing/confirmed.md" ]; then
    # Get confirmed date from frontmatter
    conf_date=$(grep '^confirmed_date:' "${dir}/advancing/confirmed.md" 2>/dev/null | sed 's/^confirmed_date: *//' || echo "unknown")
    confirmed="${confirmed}${short_date}\t${venue}\t(confirmed ${conf_date})\n"
    confirmed_count=$((confirmed_count + 1))
  elif [ -f "${dir}/advancing/thread.md" ]; then
    # Get thread start date (first line after frontmatter, or file mod date)
    thread_date=$(head -20 "${dir}/advancing/thread.md" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || echo "unknown")
    awaiting_reply="${awaiting_reply}${short_date}\t${venue}\t(thread started ${thread_date})\n"
    awaiting_count=$((awaiting_count + 1))
  else
    # Find top contact for this venue
    contact_info=$(jq -r --arg venue "$venue" '
      ("venue:" + $venue) as $org_ref |
      to_entries
      | map(select(
          .value.role == "advancing"
          and .value.org != null
          and (.value.org | index($org_ref))
        ))
      | sort_by(.value.advancing_priority)
      | first
      | [.value.name, .value.contact.email]
      | @tsv
    ' "$PEOPLE" 2>/dev/null || echo "	")

    name=$(printf '%s' "$contact_info" | cut -f1)
    email=$(printf '%s' "$contact_info" | cut -f2)

    needs_outreach="${needs_outreach}${short_date}\t${venue}\t${name:-NONE}\t${email:--}\n"
    needs_count=$((needs_count + 1))
  fi
done < <(jq -r 'to_entries | sort_by(.value.date) | .[] | [.key, .value.date, .value.venue] | @tsv' "$INDEX")

# ── Print grouped output ──────────────────────────────────────────
if [ "$needs_count" -gt 0 ]; then
  echo "=== NEEDS OUTREACH (${needs_count} shows) ==="
  printf '%b' "$needs_outreach" | while IFS=$'\t' read -r date venue name email; do
    printf "  %-7s %-24s %-26s %s\n" "$date" "$venue" "$name" "$email"
  done
  echo ""
fi

if [ "$awaiting_count" -gt 0 ]; then
  echo "=== AWAITING REPLY (${awaiting_count} shows) ==="
  printf '%b' "$awaiting_reply" | while IFS=$'\t' read -r date venue info; do
    printf "  %-7s %-24s %s\n" "$date" "$venue" "$info"
  done
  echo ""
fi

if [ "$confirmed_count" -gt 0 ]; then
  echo "=== CONFIRMED (${confirmed_count} shows) ==="
  printf '%b' "$confirmed" | while IFS=$'\t' read -r date venue info; do
    printf "  %-7s %-24s %s\n" "$date" "$venue" "$info"
  done
  echo ""
fi

total=$((needs_count + awaiting_count + confirmed_count))
echo "Summary: ${needs_count} need outreach | ${awaiting_count} awaiting reply | ${confirmed_count} confirmed | ${total} total"
