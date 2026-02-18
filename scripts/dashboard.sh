#!/usr/bin/env bash
# desc: Launch live dashboard (builds meta, starts local server)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
ORG="${REPO_ROOT}/org"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"
RUNS_DIR="${REPO_ROOT}/org/touring/runs"
ONEOFFS_DIR="${REPO_ROOT}/org/touring/one-offs"
META_OUT="${ORG}/touring/.state/dashboard-meta.json"
PORT=8026

# ── Preflight checks ───────────────────────────────────────────────
for f in people.json venues.json todos.json; do
  if [ ! -f "${ORG}/${f}" ]; then
    echo "Missing ${ORG}/${f}" >&2
    exit 1
  fi
done
if [ ! -f "${ORG}/touring/.state/shows.json" ]; then
  echo "Missing ${ORG}/touring/.state/shows.json — run ./dirtclaw build-index first" >&2
  exit 1
fi

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
done < <(jq -r 'keys[]' "${ORG}/touring/.state/shows.json")

# ── Extract schedules from calendar files ─────────────────────────────
# Reads YAML frontmatter from calendar .md files, extracts non-empty schedule arrays.
# Uses Python (already required for the HTTP server) with a simple regex parser
# since our YAML is controlled and simple — no PyYAML dependency needed.
CAL_DIR="${REPO_ROOT}/org/touring/calendar"
schedules=$(python3 -c "
import os, re, json, sys

cal_dir = sys.argv[1]
schedules = {}

for dirpath, _, filenames in os.walk(cal_dir):
    for fn in filenames:
        if not fn.endswith('.md'):
            continue
        path = os.path.join(dirpath, fn)
        with open(path) as f:
            text = f.read()

        # Extract YAML frontmatter between --- delimiters
        m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
        if not m:
            continue
        fm = m.group(1)

        # Extract date
        dm = re.search(r'^date:\s*(\S+)', fm, re.MULTILINE)
        if not dm:
            continue
        date_str = dm.group(1)

        # Extract touring type (show, travel, etc.)
        tm = re.search(r'^\s+type:\s*(\S+)', fm, re.MULTILINE)
        touring_type = tm.group(1) if tm and tm.group(1) != 'null' else None

        # Check if schedule has entries (not just '[]')
        sm = re.search(r'^schedule:\s*\[\]', fm, re.MULTILINE)
        if sm:
            continue
        sm = re.search(r'^schedule:', fm, re.MULTILINE)
        if not sm:
            continue

        # Parse schedule items: each starts with '  - time:'
        items = []
        for item_m in re.finditer(
            r'  - time:\s*\"([^\"]+)\"\n\s+item:\s*\"([^\"]+)\"\n\s+who:\s*\[([^\]]*)\]',
            fm
        ):
            time_val = item_m.group(1)
            item_val = item_m.group(2)
            who_raw = item_m.group(3)
            who = [w.strip().strip('\"') for w in who_raw.split(',') if w.strip()]
            items.append({'time': time_val, 'item': item_val, 'who': who})

        if items:
            day_type = touring_type or 'off'
            schedules[date_str] = {'type': day_type, 'items': items}

json.dump(schedules, sys.stdout, separators=(',', ':'))
" "$CAL_DIR")

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
