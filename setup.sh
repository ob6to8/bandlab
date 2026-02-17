#!/usr/bin/env bash
# setup.sh — Scaffold the org/ directory tree for a new band repo.
# Run from the repo root: bash bandlab/setup.sh
# Creates calendar files, empty state JSON, example show, and all domain directories.
set -euo pipefail

# Determine the repo root (parent of the bandlab directory this script lives in)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ORG="${REPO_ROOT}/org"

if [ -d "${ORG}" ]; then
  echo "org/ directory already exists. Aborting to avoid overwriting data." >&2
  exit 1
fi

echo "Scaffolding org/ directory tree..."

# ── State files ──────────────────────────────────────────────────────
mkdir -p "${ORG}/.state"
echo '{}' > "${ORG}/.state/people.json"
echo '{}' > "${ORG}/.state/venues.json"
echo '{}' > "${ORG}/.state/vendors.json"
echo '[]' > "${ORG}/.state/todos.json"
echo '{}' > "${ORG}/.state/shows.json"
cat > "${ORG}/.state/last-sync.json" << 'EOF'
{
  "slack": null,
  "gmail": null,
  "spreadsheet": null
}
EOF

# ── Calendar ─────────────────────────────────────────────────────────
# Generate every day for the current year
year=$(date +%Y)
echo "Generating calendar for ${year}..."

for month in $(seq -w 1 12); do
  month_dir="${ORG}/calendar/${year}-${month}"
  mkdir -p "${month_dir}"

  # Determine days in this month
  # Use date to find the last day of the month
  if [ "$(uname)" = "Darwin" ]; then
    # macOS date
    days_in_month=$(date -j -f "%Y-%m-%d" "${year}-${month}-01" +%d 2>/dev/null || echo 28)
    # Get last day by going to next month minus 1 day
    if [ "${month}" = "12" ]; then
      days_in_month=31
    else
      next_month=$(printf '%02d' $((10#$month + 1)))
      days_in_month=$(date -j -v-1d -f "%Y-%m-%d" "${year}-${next_month}-01" +%d)
    fi
  else
    # GNU date
    days_in_month=$(date -d "${year}-${month}-01 +1 month -1 day" +%d)
  fi

  for day in $(seq -w 1 "$days_in_month"); do
    cat > "${month_dir}/${day}.md" << CALEOF
---
date: ${year}-${month}-${day}
touring:
  type: null
schedule: []
releases: []
socials: []
---

## Notes
CALEOF
  done
done

# ── Domain directories ───────────────────────────────────────────────
mkdir -p "${ORG}/touring/tours"
mkdir -p "${ORG}/touring/runs"
mkdir -p "${ORG}/touring/shows"
mkdir -p "${ORG}/touring/budgets"
touch "${ORG}/touring/contacts.md"

mkdir -p "${ORG}/merch/designs"
touch "${ORG}/merch/inventory.md"
touch "${ORG}/merch/vendors.md"

mkdir -p "${ORG}/releases"
touch "${ORG}/releases/catalog.md"

mkdir -p "${ORG}/socials/posts"
touch "${ORG}/socials/accounts.md"
touch "${ORG}/socials/strategy.md"

mkdir -p "${ORG}/licensing/active"
touch "${ORG}/licensing/catalog.md"
touch "${ORG}/licensing/contacts.md"

mkdir -p "${ORG}/distro"
touch "${ORG}/distro/accounts.md"
touch "${ORG}/distro/splits.md"
touch "${ORG}/distro/reporting.md"

mkdir -p "${ORG}/strategy/decisions"
touch "${ORG}/strategy/overview.md"
touch "${ORG}/strategy/goals.md"

mkdir -p "${ORG}/comms/slack"
mkdir -p "${ORG}/comms/email"

mkdir -p "${ORG}/briefings"

# ── Example show ─────────────────────────────────────────────────────
example_id="s-${year}-0101-example-city"
example_dir="${ORG}/touring/shows/${example_id}"
mkdir -p "${example_dir}/source"
mkdir -p "${example_dir}/advancing"
mkdir -p "${example_dir}/settlement/receipts"

cat > "${example_dir}/show.json" << SHOWEOF
{
  "id": "${example_id}",
  "date": "${year}-01-01",
  "venue": "example-venue",
  "run": null,
  "status": "potential",
  "guarantee": null,
  "door_split": null,
  "promoter": null,
  "ages": "all-ages",
  "ticket_link": "",
  "sell_cap": null,
  "ticket_scaling": null,
  "wp": null,
  "support": null,
  "tour": null,
  "advance": {
    "hospitality": "",
    "backline": "",
    "merch_cut": null
  }
}
SHOWEOF

cat > "${example_dir}/tech-pack.md" << 'TECHEOF'
# Tech Pack

## Stage Plot

(Attach or describe stage plot here)

## Input List

| Channel | Instrument | Mic/DI | Notes |
|---|---|---|---|
| 1 | | | |

## Backline Requirements

- (List backline needs here)
TECHEOF

cat > "${example_dir}/source/summary.md" << CONTRACTEOF
---
source: contract
extracted_date: ${year}-01-01
status: pending-review
approved_by: null
approved_date: null
guarantee: null
door_split: null
merch_cut: null
ages: null
radius_clause: ""
cancellation: ""
---

## Agent Notes
Example contract summary. Replace with agent-extracted terms from the actual contract PDF.
CONTRACTEOF

cat > "${example_dir}/advancing/thread.md" << 'THREADEOF'
# Advancing Thread

## Outreach Log

(Log all advancing communications here chronologically)
THREADEOF

cat > "${example_dir}/advancing/confirmed.md" << CONFEOF
---
source: advancing
confirmed_date: ${year}-01-01
load_in: ""
soundcheck: ""
doors: ""
set_time: ""
guarantee: null
hospitality: ""
backline: ""
merch_cut: null
ages: null
parking: ""
wifi: ""
---

## Advancing Thread Summary
Example confirmed details. Replace with actual advancing confirmations.
CONFEOF

touch "${example_dir}/settlement/settlement.md"

# ── Summary ──────────────────────────────────────────────────────────
cal_count=$(find "${ORG}/calendar" -name "*.md" | wc -l | tr -d ' ')
echo ""
echo "Done! Created:"
echo "  - org/.state/ with empty JSON registries"
echo "  - org/calendar/ with ${cal_count} day files for ${year}"
echo "  - org/touring/shows/${example_id}/ (example show)"
echo "  - All domain directories (merch, releases, socials, licensing, distro, strategy, comms, briefings)"
echo ""
echo "Next steps:"
echo "  1. Delete the example show directory when you're ready"
echo "  2. Add your venues, people, and shows"
echo "  3. Run ./bandlab build:index to generate the shows index"
