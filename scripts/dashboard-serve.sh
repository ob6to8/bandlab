#!/usr/bin/env bash
# desc: Launch live dashboard (builds meta, starts local server)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
STATE="${REPO_ROOT}/org/.state"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"
RUNS_DIR="${REPO_ROOT}/org/touring/runs"
META_OUT="${STATE}/dashboard-meta.json"
PORT=8026

# ── Preflight checks ───────────────────────────────────────────────
for f in shows.json people.json venues.json todos.json; do
  if [ ! -f "${STATE}/${f}" ]; then
    echo "Missing ${STATE}/${f} — run ./dirtclaw build:index first" >&2
    exit 1
  fi
done

echo "Building dashboard metadata..."

# ── Build run name lookup ───────────────────────────────────────────
# Maps run keys to short display names (strip "spring-2026-" prefix)
run_names="{}"
for run_json in "${RUNS_DIR}"/*/run.json; do
  [ -f "$run_json" ] || continue
  run_id=$(jq -r '.id' "$run_json")
  # Strip tour prefix to get short name, e.g. "spring-2026-southeast" -> "southeast"
  short="${run_id##*-2026-}"
  run_names=$(echo "$run_names" | jq --arg k "$run_id" --arg v "$short" '. + {($k): $v}')
done

# ── Check advancing status and file existence for each show ─────────
adv_status="{}"
file_status="{}"

while IFS= read -r show_id; do
  dir="${SHOWS_DIR}/${show_id}"
  has_thread=false
  has_confirmed=false
  has_contract_pdf=false
  has_contract_summary=false
  has_tech_pack=false

  [ -f "${dir}/advancing/thread.md" ] && has_thread=true
  [ -f "${dir}/advancing/confirmed.md" ] && has_confirmed=true
  [ -f "${dir}/tech-pack.md" ] && has_tech_pack=true
  [ -f "${dir}/source/summary.md" ] && has_contract_summary=true

  # Check for any PDF in source/
  if compgen -G "${dir}/source/"*.pdf > /dev/null 2>&1; then
    has_contract_pdf=true
  fi

  adv_status=$(echo "$adv_status" | jq \
    --arg id "$show_id" \
    --argjson thread "$has_thread" \
    --argjson confirmed "$has_confirmed" \
    '. + {($id): {"has_thread": $thread, "has_confirmed": $confirmed}}')

  file_status=$(echo "$file_status" | jq \
    --arg id "$show_id" \
    --argjson thread "$has_thread" \
    --argjson confirmed "$has_confirmed" \
    --argjson cpdf "$has_contract_pdf" \
    --argjson csum "$has_contract_summary" \
    --argjson tech "$has_tech_pack" \
    '. + {($id): {"thread_md": $thread, "confirmed_md": $confirmed, "contract_pdf": $cpdf, "contract_summary": $csum, "tech_pack": $tech}}')
done < <(jq -r 'keys[]' "${STATE}/shows.json")

# ── Write dashboard-meta.json ───────────────────────────────────────
jq -n \
  --argjson adv_status "$adv_status" \
  --argjson file_status "$file_status" \
  --argjson run_names "$run_names" \
  --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    adv_status: $adv_status,
    file_status: $file_status,
    run_names: $run_names,
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

# Start HTTP server from repo root (serves org/.state/ and dashboard/)
cd "$REPO_ROOT"
python3 -m http.server "$PORT"
