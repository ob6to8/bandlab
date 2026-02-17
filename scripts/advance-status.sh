#!/usr/bin/env bash
# desc: Show advancing status across all shows
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INDEX="${REPO_ROOT}/org/.state/shows.json"
PEOPLE="${REPO_ROOT}/org/people.json"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./dirtclaw build:index" >&2
  exit 1
fi

printf "%-12s %-30s %-10s %-30s %s\n" "DATE" "VENUE" "ADVANCING" "TOP CONTACT" "EMAIL"
printf "%-12s %-30s %-10s %-30s %s\n" "----" "-----" "---------" "-----------" "-----"

jq -r 'to_entries | sort_by(.value.date) | .[] | [.key, .value.date, .value.venue] | @tsv' "$INDEX" |
while IFS=$'\t' read -r show_id date venue; do

  # Check advancing status
  thread="${SHOWS_DIR}/${show_id}/advancing/thread.md"
  confirmed="${SHOWS_DIR}/${show_id}/advancing/confirmed.md"
  if [ -f "$confirmed" ]; then
    adv_status="CONFIRMED"
  elif [ -f "$thread" ]; then
    adv_status="STARTED"
  else
    adv_status="NOT YET"
  fi

  # Get top-priority contact for this venue
  top_contact=$(jq -r --arg venue "$venue" '
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

  name=$(echo "$top_contact" | cut -f1)
  email=$(echo "$top_contact" | cut -f2)

  printf "%-12s %-30s %-10s %-30s %s\n" "$date" "$venue" "$adv_status" "${name:-NONE}" "${email:--}"
done

echo ""
not_started=$(jq -r 'keys[]' "$INDEX" | while read -r sid; do
  [ ! -f "${SHOWS_DIR}/${sid}/advancing/thread.md" ] && echo "$sid"
done | wc -l | tr -d ' ')
total=$(jq 'length' "$INDEX")
echo "Advancing: ${not_started}/${total} shows not yet started"
