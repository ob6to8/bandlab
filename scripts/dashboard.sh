#!/usr/bin/env bash
# desc: Launch live dashboard (builds meta, starts local server)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

DATES_DIR="${REPO_ROOT}/$(cfg '.entities.dates.dir')"
RUNS_DIR="${REPO_ROOT}/$(cfg '.entities.runs.dir')"
ONEOFFS_DIR="${REPO_ROOT}/$(cfg '.entities.one_offs.dir')"
PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
VENUES="${REPO_ROOT}/$(cfg '.registries.venues.path')"
TODOS="${REPO_ROOT}/$(cfg '.registries.todos.path')"
STATE_DIR="${REPO_ROOT}/org/touring/.state"
META_OUT="${STATE_DIR}/dashboard-meta.json"
PORT=8026

# ── Preflight checks ───────────────────────────────────────────────
for f in "$PEOPLE" "$VENUES" "$TODOS"; do
  if [ ! -f "$f" ]; then
    echo "Missing ${f}" >&2
    exit 1
  fi
done

load_days

echo "Building dashboard metadata..."

# ── Build run/one-off name lookup ──────────────────────────────────
# Maps run and one-off keys to short display names
run_names="{}"
for run_json in "${RUNS_DIR}"/*/run.json; do
  [ -f "$run_json" ] || continue
  run_id=$(jq -r '.id' "$run_json")
  # Strip tour prefix to get short name, e.g. "spring-2026-southeast" -> "southeast"
  short="${run_id##*-2026-}"
  run_names=$(echo "$run_names" | jq --arg k "$run_id" --arg v "$short" '. + {($k): $v}')
done
for oneoff_json in "${ONEOFFS_DIR}"/*/one-off.json; do
  [ -f "$oneoff_json" ] || continue
  oneoff_id=$(jq -r '.id' "$oneoff_json")
  # Strip year suffix for short name, e.g. "envision-2026" -> "envision"
  short="${oneoff_id%-2026}"
  run_names=$(echo "$run_names" | jq --arg k "$oneoff_id" --arg v "$short" '. + {($k): $v}')
done

# ── Check advancing status and file existence for each show ─────────
adv_status="{}"
file_status="{}"

SOURCES_DIR="${REPO_ROOT}/$(cfg '.entities.sources.dir')"

while IFS= read -r show_id; do
  src_dir="${SOURCES_DIR}/${show_id}"
  has_contract_pdf=false
  has_contract_summary=false

  [ -f "${src_dir}/summary.md" ] && has_contract_summary=true
  if compgen -G "${src_dir}/"*.pdf > /dev/null 2>&1; then
    has_contract_pdf=true
  fi

  # Advancing status from advance object in day.json
  has_advance=$(jq -r --arg id "$show_id" '
    .[$id] | if .advance and (.advance | length) > 0 then "true" else "false" end
  ' "$DATES_DATA")
  all_confirmed=$(jq -r --arg id "$show_id" '
    .[$id] | if .advance and (.advance | length) > 0 and (.advance | to_entries | all(.value.status == "confirmed")) then "true" else "false" end
  ' "$DATES_DATA")

  adv_status=$(echo "$adv_status" | jq \
    --arg id "$show_id" \
    --argjson thread "$has_advance" \
    --argjson confirmed "$all_confirmed" \
    '. + {($id): {"has_thread": $thread, "has_confirmed": $confirmed}}')

  file_status=$(echo "$file_status" | jq \
    --arg id "$show_id" \
    --argjson thread "$has_advance" \
    --argjson confirmed "$all_confirmed" \
    --argjson cpdf "$has_contract_pdf" \
    --argjson csum "$has_contract_summary" \
    --argjson tech false \
    '. + {($id): {"thread_md": $thread, "confirmed_md": $confirmed, "contract_pdf": $cpdf, "contract_summary": $csum, "tech_pack": $tech}}')
done < <(jq -r 'keys[]' "$DATES_DATA")

# ── Extract schedules from date files ─────────────────────────────────
# Reads day.schedule arrays from date JSON files.
schedules=$(jq -r '
  to_entries
  | map(select(.value.day.schedule and (.value.day.schedule | length) > 0))
  | map({
      key: .value.day.date,
      value: {
        type: .value.day.type,
        items: [.value.day.schedule[] | {time, item, who}]
      }
    })
  | from_entries
' "$DATES_DATA")

# ── Write dashboard-meta.json ───────────────────────────────────────
jq -n \
  --argjson adv_status "$adv_status" \
  --argjson file_status "$file_status" \
  --argjson run_names "$run_names" \
  --argjson schedules "$schedules" \
  --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    adv_status: $adv_status,
    file_status: $file_status,
    run_names: $run_names,
    schedules: $schedules,
    generated: $generated
  }' > "$META_OUT"

echo "Wrote ${META_OUT}"
echo "Starting server on http://localhost:${PORT}"
echo "Dashboard: http://localhost:${PORT}/dashboard/"
echo "Press Ctrl+C to stop."
echo ""

# ── Open browser and start server ───────────────────────────────────
# Open browser after a short delay (server needs to be up first)
(sleep 1 && open "http://localhost:${PORT}/dashboard/") &

# Start HTTP server from repo root (serves org/ and dashboard/)
cd "$REPO_ROOT"
python3 -m http.server "$PORT"
