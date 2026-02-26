#!/usr/bin/env bash
# desc: Show ranked advancing contacts for a specific show
# usage: advance-contacts.sh <show-id-or-partial>
# example: advance-contacts.sh 0304  (matches s-2026-0304-charleston)
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

if [ $# -lt 1 ]; then
  echo "Usage: advance-contacts.sh <show-id-or-partial>" >&2
  echo "Example: advance-contacts.sh 0304" >&2
  exit 1
fi

query="$1"

# Find matching show
show_id=$(jq -r "keys[] | select(contains(\"${query}\"))" "$DATES_DATA" | head -1)

if [ -z "$show_id" ]; then
  echo "No show found matching: ${query}" >&2
  exit 1
fi

# Get venue for this show
venue=$(jq -r ".[\"${show_id}\"].venue.id" "$DATES_DATA")
date=$(jq -r ".[\"${show_id}\"].day.date" "$DATES_DATA")

echo "=== ${show_id} | ${date} | ${venue} ==="
echo ""

# Find advancing contacts for this venue, sorted by priority
# Matches on org field (prefix:key) or null org (cross-venue contacts)
jq -r --arg venue "$venue" --arg role "$CONTACT_ROLE" --arg prefix "$ORG_PREFIX" --arg pfield "$PRIORITY_FIELD" '
  ($prefix + ":" + $venue) as $org_ref |
  to_entries
  | map(select(
      .value.role == $role
      and .value.org != null
      and (.value.org | index($org_ref))
    ))
  | sort_by(.value[$pfield])
  | .[]
  | [
      .value[$pfield],
      .value.name,
      .value.role,
      .value.contact.email,
      .value.contact.phone
    ]
  | @tsv
' "$PEOPLE" | while IFS=$'\t' read -r pri name role email phone; do
  printf "  %s. %-25s %-35s %s  %s\n" "$pri" "$name" "$role" "$email" "$phone"
done

# Check if advancing has started (via advance object in day.json)
has_advance=$(jq -r --arg id "$show_id" 'if .[$id].advance and (.[$id].advance | length) > 0 then "yes" else "no" end' "$DATES_DATA")
echo ""
if [ "$has_advance" = "yes" ]; then
  echo "  Advancing started (advance object present)."
else
  echo "  No advancing started yet."
fi
