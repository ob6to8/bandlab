#!/usr/bin/env bash
# desc: List all dates with date, venue, guarantee, and status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config
load_days

STRIP_PREFIX=$(cfg_default '.display.show_id_strip_prefix' 's-')

{
  printf "%s\t%s\t%s\t%s\t%s\n" "SHOW ID" "DATE" "VENUE" "GUARANTEE" "STATUS"
  printf "%s\t%s\t%s\t%s\t%s\n" "-------" "----" "-----" "---------" "------"

  jq -r '
    to_entries
    | sort_by(.value.day.date)
    | .[]
    | [
        .key,
        .value.day.date,
        .value.venue.id,
        (if .value.deal.guarantee then ("$" + (.value.deal.guarantee | tostring)) else "% deal" end),
        .value.day.status
      ]
    | @tsv
  ' "$DATES_DATA" | while IFS=$'\t' read -r id date venue guarantee status; do
    printf "%s\t%s\t%s\t%s\t%s\n" \
      "${id#"$STRIP_PREFIX"}" "$date" "$venue" "$guarantee" "$status"
  done
} | column -t -s $'\t'

echo ""
total=$(jq '[.[] | select(.deal.guarantee) | .deal.guarantee] | add' "$DATES_DATA")
count=$(jq 'length' "$DATES_DATA")
guaranteed=$(jq '[.[] | select(.deal.guarantee)] | length' "$DATES_DATA")
pct_deals=$(jq '[.[] | select(.deal.guarantee == null)] | length' "$DATES_DATA")
printf "Total: %d shows | Guaranteed: \$%s across %d shows | Pure %%: %d shows\n" \
  "$count" "$total" "$guaranteed" "$pct_deals"
