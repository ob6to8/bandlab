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

PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
CONTACT_ROLE=$(cfg '.advancing.contact_role')
ORG_PREFIX=$(cfg '.advancing.contact_org_prefix')
PRIORITY_FIELD=$(cfg '.advancing.priority_field')

load_days

printf "%-12s %-30s %-10s %-30s %s\n" "DATE" "VENUE" "ADVANCING" "TOP CONTACT" "EMAIL"
printf "%-12s %-30s %-10s %-30s %s\n" "----" "-----" "---------" "-----------" "-----"

jq -r 'to_entries | sort_by(.value.day.date) | .[] | [.key, .value.day.date, .value.venue.id] | @tsv' "$DATES_DATA" |
while IFS=$'\t' read -r show_id date venue; do

  # Check advancing status via advance object
  adv_status=$(jq -r --arg id "$show_id" '
    .[$id] |
    if .advance == null or (.advance | length) == 0 then "NOT YET"
    elif (.advance | to_entries | all(.value.status == "confirmed")) then "CONFIRMED"
    else "STARTED"
    end
  ' "$DATES_DATA")

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
not_started=$(jq -r '[to_entries[] | select(.value.advance == null or (.value.advance | length) == 0)] | length' "$DATES_DATA")
total=$(jq 'length' "$DATES_DATA")
echo "Advancing: ${not_started}/${total} shows not yet started"
