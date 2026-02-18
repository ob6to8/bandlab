#!/usr/bin/env bash
# desc: List all shows with date, venue, guarantee, and status
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INDEX="${REPO_ROOT}/org/touring/.state/shows.json"

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./dirtclaw build:index" >&2
  exit 1
fi

printf "%-14s %-12s %-30s %10s  %s\n" "SHOW ID" "DATE" "VENUE" "GUARANTEE" "STATUS"
printf "%-14s %-12s %-30s %10s  %s\n" "-------" "----" "-----" "---------" "------"

jq -r '
  to_entries
  | sort_by(.value.date)
  | .[]
  | [
      .key,
      .value.date,
      .value.venue,
      (if .value.guarantee then ("$" + (.value.guarantee | tostring)) else "% deal" end),
      .value.status
    ]
  | @tsv
' "$INDEX" | while IFS=$'\t' read -r id date venue guarantee status; do
  printf "%-14s %-12s %-30s %10s  %s\n" \
    "${id#s-2026-}" "$date" "$venue" "$guarantee" "$status"
done

echo ""
total=$(jq '[.[] | select(.guarantee) | .guarantee] | add' "$INDEX")
count=$(jq 'length' "$INDEX")
guaranteed=$(jq '[.[] | select(.guarantee)] | length' "$INDEX")
pct_deals=$(jq '[.[] | select(.guarantee == null)] | length' "$INDEX")
printf "Total: %d shows | Guaranteed: \$%s across %d shows | Pure %%: %d shows\n" \
  "$count" "$total" "$guaranteed" "$pct_deals"
