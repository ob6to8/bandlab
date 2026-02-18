#!/usr/bin/env bash
# desc: List runs and one-offs with dates, shows, and status
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
RUNS_DIR="${REPO_ROOT}/org/touring/runs"
ONEOFFS_DIR="${REPO_ROOT}/org/touring/one-offs"

# ── Collect all logistics blocks into one JSON array ───────────────
blocks="[]"

run_count=0
for run_json in "${RUNS_DIR}"/*/run.json; do
  [ -f "$run_json" ] || continue
  # Add type field, compute short name by stripping tour prefix
  block=$(jq '{
    type: "run",
    id: .id,
    short: (.id | sub("^.*-2026-"; "")),
    start: .dates[0],
    end: .dates[1],
    shows: (.shows | length),
    status: .status,
    tour: (.tour // "—")
  }' "$run_json")
  blocks=$(echo "$blocks" | jq --argjson b "$block" '. + [$b]')
  run_count=$((run_count + 1))
done

oneoff_count=0
for oneoff_json in "${ONEOFFS_DIR}"/*/one-off.json; do
  [ -f "$oneoff_json" ] || continue
  block=$(jq '{
    type: "one-off",
    id: .id,
    short: (.id | sub("-2026$"; "")),
    start: .dates[0],
    end: .dates[1],
    shows: (.shows | length),
    status: .status,
    tour: ((.tour // "—") | if . == "null" then "—" else . end)
  }' "$oneoff_json")
  blocks=$(echo "$blocks" | jq --argjson b "$block" '. + [$b]')
  oneoff_count=$((oneoff_count + 1))
done

total=$((run_count + oneoff_count))

if [ "$total" -eq 0 ]; then
  echo "No runs or one-offs found."
  exit 0
fi

# ── Sort by start date and print ──────────────────────────────────
printf "%-8s %-26s %-24s %6s  %-10s %s\n" "TYPE" "BLOCK" "DATES" "SHOWS" "STATUS" "TOUR"
printf "%-8s %-26s %-24s %6s  %-10s %s\n" "----" "-----" "-----" "-----" "------" "----"

jq -r 'sort_by(.start) | .[] | [.type, .short, (.start + " → " + .end[5:]), (.shows | tostring), .status, .tour] | @tsv' <<< "$blocks" |
while IFS=$'\t' read -r type short dates shows status tour; do
  printf "%-8s %-26s %-24s %6s  %-10s %s\n" "$type" "$short" "$dates" "$shows" "$status" "$tour"
done

echo ""
echo "${run_count} runs | ${oneoff_count} one-offs | ${total} total"
