#!/usr/bin/env bash
# desc: List all shows with date, venue, guarantee, and status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config

INDEX="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"
STRIP_PREFIX=$(cfg_default '.display.show_id_strip_prefix' 's-')

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./bandlab-cli build-index" >&2
  exit 1
fi

{
  printf "%s\t%s\t%s\t%s\t%s\n" "SHOW ID" "DATE" "VENUE" "GUARANTEE" "STATUS"
  printf "%s\t%s\t%s\t%s\t%s\n" "-------" "----" "-----" "---------" "------"

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
    printf "%s\t%s\t%s\t%s\t%s\n" \
      "${id#"$STRIP_PREFIX"}" "$date" "$venue" "$guarantee" "$status"
  done
} | column -t -s $'\t'

echo ""
total=$(jq '[.[] | select(.guarantee) | .guarantee] | add' "$INDEX")
count=$(jq 'length' "$INDEX")
guaranteed=$(jq '[.[] | select(.guarantee)] | length' "$INDEX")
pct_deals=$(jq '[.[] | select(.guarantee == null)] | length' "$INDEX")
printf "Total: %d shows | Guaranteed: \$%s across %d shows | Pure %%: %d shows\n" \
  "$count" "$total" "$guaranteed" "$pct_deals"
