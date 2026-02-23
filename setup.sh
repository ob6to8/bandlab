#!/usr/bin/env bash
# setup.sh — Set up a new band repo using the bandlab framework.
# Run from the repo root: bash bandlab/setup.sh
# Generates CLI launcher, symlinks skills, and scaffolds org/ directory tree.
set -euo pipefail

# Determine the repo root (parent of the bandlab directory this script lives in)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── CLI launcher ──────────────────────────────────────────────────────
if [ ! -f "${REPO_ROOT}/bandlab-cli" ]; then
  cp "${SCRIPT_DIR}/templates/bandlab-cli" "${REPO_ROOT}/bandlab-cli"
  chmod +x "${REPO_ROOT}/bandlab-cli"
  echo "Created ./bandlab-cli"
else
  echo "./bandlab-cli already exists, skipping"
fi

# ── Config file ─────────────────────────────────────────────────────────
if [ ! -f "${REPO_ROOT}/bandlab.config.json" ]; then
  cat > "${REPO_ROOT}/bandlab.config.json" << 'CONFIGEOF'
{
  "$schema": "bandlab-config-v1",

  "project": {
    "name": "My Band",
    "cli_name": "bandlab-cli"
  },

  "registries": {
    "people": {
      "path": "org/people.json",
      "key_type": "object",
      "has_sources": true,
      "has_org_refs": true,
      "org_prefixes": ["venue", "vendor", "management"]
    },
    "venues": {
      "path": "org/touring/venues.json",
      "key_type": "object",
      "has_sources": true,
      "has_contacts": true
    },
    "vendors": {
      "path": "org/vendors.json",
      "key_type": "object"
    },
    "todos": {
      "path": "org/todos.json",
      "key_type": "array",
      "schema_fields": ["id", "task", "domain", "category", "show", "owners", "status", "due", "blocked_by", "source", "created", "updated", "notes", "history"]
    }
  },

  "entities": {
    "shows": {
      "dir": "org/touring/shows",
      "glob": "org/touring/shows/s-*/show.json",
      "id_field": "id",
      "index_path": "org/touring/.state/shows.json",
      "schema_fields": ["id", "date", "venue", "run", "one_off", "status", "guarantee", "door_split", "promoter", "ages", "ticket_link", "sell_cap", "ticket_scaling", "wp", "support", "tour", "touring_party", "advance", "_provenance"],
      "file_checklist": ["show.json", "source/summary.md", "tech-pack.md", "advancing/thread.md", "advancing/confirmed.md"],
      "references": {
        "venue": { "registry": "venues", "nullable": true },
        "promoter": { "registry": "people", "nullable": true, "null_severity": "warn" }
      }
    },
    "runs": {
      "dir": "org/touring/runs",
      "glob": "org/touring/runs/*/run.json",
      "id_field": "id"
    },
    "one_offs": {
      "dir": "org/touring/one-offs",
      "glob": "org/touring/one-offs/*/one-off.json",
      "id_field": "id"
    },
    "tours": {
      "dir": "org/touring/tours",
      "glob": "org/touring/tours/*/tour.json",
      "id_field": "id"
    }
  },

  "calendar": {
    "path": "org/touring/calendar",
    "show_link_field": "show"
  },

  "provenance": {
    "enabled": true,
    "field_name": "_provenance",
    "skip_fields": ["id", "_provenance", "advance", "run", "one_off", "tour", "touring_party", "status", "routing_notes", "sets", "ticket_link"],
    "special_source_values": ["manual", "legacy"],
    "special_source_prefixes": ["manual:", "legacy:"],
    "source_base_dir": "org"
  },

  "verification": {
    "scripts": [
      { "name": "referential-integrity-check", "label": "Referential Integrity" },
      { "name": "provenance-verification", "label": "Provenance Verification" },
      { "name": "doc-check", "label": "Documentation Sync" }
    ]
  },

  "documentation": {
    "claude_md": "CLAUDE.md",
    "ops_dir": "ops",
    "skills_dir": ".claude/skills",
    "scripts_dir": "bandlab/scripts"
  },

  "owner_aliases": {},

  "todo_filters": {
    "domains": ["touring", "admin", "merch", "licensing"],
    "categories": ["advancing", "settlement", "production", "show-documentation"]
  },

  "display": {
    "show_id_strip_prefix": "s-2026-"
  }
}
CONFIGEOF
  echo "Created bandlab.config.json (edit to customize)"
else
  echo "bandlab.config.json already exists, skipping"
fi

# ── Skill symlinks ───────────────────────────────────────────────────
mkdir -p "${REPO_ROOT}/.claude/skills"
link_count=0
for skill_dir in "${SCRIPT_DIR}/.claude/skills"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  target="../../bandlab/.claude/skills/${skill_name}"
  link="${REPO_ROOT}/.claude/skills/${skill_name}"
  if [ ! -L "$link" ]; then
    ln -sf "$target" "$link"
    link_count=$((link_count + 1))
  fi
done
if [ "$link_count" -gt 0 ]; then
  echo "Linked ${link_count} skills to .claude/skills/"
else
  echo "All skill symlinks already exist, skipping"
fi

# ── Org directory scaffolding ─────────────────────────────────────────
ORG="${REPO_ROOT}/org"

if [ -d "${ORG}" ]; then
  echo "org/ already exists, skipping scaffolding"
  exit 0
fi

echo "Scaffolding org/ directory tree..."

# ── Data registries ──────────────────────────────────────────────────
echo '{}' > "${ORG}/people.json"
echo '{}' > "${ORG}/touring/venues.json"
echo '{}' > "${ORG}/vendors.json"
echo '[]' > "${ORG}/todos.json"

# ── Derived/generated state ─────────────────────────────────────────
mkdir -p "${ORG}/touring/.state"
echo '{}' > "${ORG}/touring/.state/shows.json"
cat > "${ORG}/touring/.state/last-sync.json" << 'EOF'
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
  month_dir="${ORG}/touring/calendar/${year}-${month}"
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
cal_count=$(find "${ORG}/touring/calendar" -name "*.md" | wc -l | tr -d ' ')
echo ""
echo "Done! Created:"
echo "  - org/ with empty JSON registries (people, venues, vendors, todos)"
echo "  - org/touring/.state/ with derived state (shows index, sync timestamps)"
echo "  - org/touring/calendar/ with ${cal_count} day files for ${year}"
echo "  - org/touring/shows/${example_id}/ (example show)"
echo "  - All domain directories (merch, releases, socials, licensing, distro)"
echo ""
echo "Next steps:"
echo "  1. Delete the example show directory when you're ready"
echo "  2. Add your venues, people, and shows"
echo "  3. Run ./bandlab-cli build-index to generate the shows index"
