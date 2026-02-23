#!/usr/bin/env bash
# desc: Show advancing status across all shows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

# Check if advancing is configured
if [ "$(cfg '.advancing // empty')" = "" ]; then
  echo "Advancing not configured in bandlab.config.json" >&2
  exit 0
fi

INDEX="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"
PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
THREAD_FILE=$(cfg '.advancing.thread_file')
CONFIRMED_FILE=$(cfg '.advancing.confirmed_file')
CONTACT_ROLE=$(cfg '.advancing.contact_role')
ORG_PREFIX=$(cfg '.advancing.contact_org_prefix')
PRIORITY_FIELD=$(cfg '.advancing.priority_field')

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./bandlab-cli build-index" >&2
  exit 1
fi

printf "%-12s %-30s %-10s %-30s %s\n" "DATE" "VENUE" "ADVANCING" "TOP CONTACT" "EMAIL"
printf "%-12s %-30s %-10s %-30s %s\n" "----" "-----" "---------" "-----------" "-----"

jq -r 'to_entries | sort_by(.value.date) | .[] | [.key, .value.date, .value.venue.id] | @tsv' "$INDEX" |
while IFS=$'\t' read -r show_id date venue; do

  # Check advancing status
  thread="${SHOWS_DIR}/${show_id}/${THREAD_FILE}"
  confirmed="${SHOWS_DIR}/${show_id}/${CONFIRMED_FILE}"
  if [ -f "$confirmed" ]; then
    adv_status="CONFIRMED"
  elif [ -f "$thread" ]; then
    adv_status="STARTED"
  else
    adv_status="NOT YET"
  fi

  # Get top-priority contact for this venue
  top_contact=$(jq -r --arg venue "$venue" --arg role "$CONTACT_ROLE" --arg prefix "$ORG_PREFIX" --arg pfield "$PRIORITY_FIELD" '
    ($prefix + ":" + $venue) as $org_ref |
    to_entries
    | map(select(
        .value.role == $role
        and .value.org != null
        and (.value.org | index($org_ref))
      ))
    | sort_by(.value[$pfield])
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
  [ ! -f "${SHOWS_DIR}/${sid}/${THREAD_FILE}" ] && echo "$sid"
done | wc -l | tr -d ' ')
total=$(jq 'length' "$INDEX")
echo "Advancing: ${not_started}/${total} shows not yet started"
