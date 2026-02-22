#!/usr/bin/env bash
# desc: Show ranked advancing contacts for a specific show
# usage: advance-contacts.sh <show-id-or-partial>
# example: advance-contacts.sh 0304  (matches s-2026-0304-charleston)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INDEX="${REPO_ROOT}/org/touring/.state/shows.json"
PEOPLE="${REPO_ROOT}/org/people.json"

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./bandlab-cli build-index" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: advance-contacts.sh <show-id-or-partial>" >&2
  echo "Example: advance-contacts.sh 0304" >&2
  exit 1
fi

query="$1"

# Find matching show
show_id=$(jq -r "keys[] | select(contains(\"${query}\"))" "$INDEX" | head -1)

if [ -z "$show_id" ]; then
  echo "No show found matching: ${query}" >&2
  exit 1
fi

# Get venue for this show
venue=$(jq -r ".[\"${show_id}\"].venue" "$INDEX")
date=$(jq -r ".[\"${show_id}\"].date" "$INDEX")

echo "=== ${show_id} | ${date} | ${venue} ==="
echo ""

# Find advancing contacts for this venue, sorted by priority
# Matches on org field (venue:key prefix) or null org (cross-venue contacts)
jq -r --arg venue "$venue" '
  ("venue:" + $venue) as $org_ref |
  to_entries
  | map(select(
      .value.role == "advancing"
      and .value.org != null
      and (.value.org | index($org_ref))
    ))
  | sort_by(.value.advancing_priority)
  | .[]
  | [
      .value.advancing_priority,
      .value.name,
      .value.role,
      .value.contact.email,
      .value.contact.phone
    ]
  | @tsv
' "$PEOPLE" | while IFS=$'\t' read -r pri name role email phone; do
  printf "  %s. %-25s %-35s %s  %s\n" "$pri" "$name" "$role" "$email" "$phone"
done

# Check if advancing has started
thread="${REPO_ROOT}/org/touring/shows/${show_id}/advancing/thread.md"
if [ -f "$thread" ]; then
  echo ""
  echo "  Advancing thread exists: ${thread}"
else
  echo ""
  echo "  No advancing started yet."
fi
