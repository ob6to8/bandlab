#!/usr/bin/env bash
# desc: Verify referential integrity across all state and data files
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="${REPO_ROOT}/org/.state"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"
CALENDAR="${REPO_ROOT}/org/calendar"

INDEX="${STATE}/shows.json"
PEOPLE="${STATE}/people.json"
VENUES="${STATE}/venues.json"
errors=0
warnings=0
checks=0

pass() {
  printf "  ✓ %s\n" "$1"
  checks=$((checks + 1))
}

fail() {
  printf "  ✗ %s\n" "$1"
  errors=$((errors + 1))
  checks=$((checks + 1))
}

warn() {
  printf "  ? %s\n" "$1"
  warnings=$((warnings + 1))
  checks=$((checks + 1))
}

# ── Required files ────────────────────────────────────────────────────

echo "=== Required Files ==="

for f in "$INDEX" "$PEOPLE" "$VENUES"; do
  if [ -f "$f" ]; then
    pass "$(basename "$f") exists"
  else
    fail "$(basename "$f") MISSING"
  fi
done
echo ""

# ── Show directories ↔ Index ─────────────────────────────────────────

echo "=== Show Directories ↔ Index ==="

# Every show dir should have show.json and be in the index
for show_dir in "${SHOWS_DIR}"/s-*/; do
  show_id="$(basename "$show_dir")"

  if [ ! -f "${show_dir}/show.json" ]; then
    fail "${show_id}: missing show.json"
    continue
  fi

  # Check show is in the index
  in_index=$(jq -r --arg id "$show_id" 'has($id)' "$INDEX")
  if [ "$in_index" = "true" ]; then
    pass "${show_id}: dir + show.json + in index"
  else
    fail "${show_id}: has show.json but NOT in index (run build:index)"
  fi
done

# Every index entry should have a directory
# Uses process substitution to keep counters in current shell
while read -r show_id; do
  if [ ! -d "${SHOWS_DIR}/${show_id}" ]; then
    fail "${show_id}: in index but directory MISSING"
  fi
done < <(jq -r 'keys[]' "$INDEX")
echo ""

# ── Venue references ─────────────────────────────────────────────────

echo "=== Show → Venue References ==="

while IFS=$'\t' read -r show_id venue; do
  if [ "$venue" = "null" ] || [ -z "$venue" ]; then
    warn "${show_id}: venue is null"
    continue
  fi

  exists=$(jq -r --arg v "$venue" 'has($v)' "$VENUES")
  if [ "$exists" = "true" ]; then
    pass "${show_id} → ${venue}"
  else
    fail "${show_id} → ${venue} NOT FOUND in venues.json"
  fi
done < <(jq -r 'to_entries[] | [.key, .value.venue] | @tsv' "$INDEX")
echo ""

# ── Promoter references ──────────────────────────────────────────────

echo "=== Show → Promoter References ==="

while IFS=$'\t' read -r show_id promoter; do
  if [ "$promoter" = "null" ] || [ -z "$promoter" ]; then
    warn "${show_id}: promoter is null"
    continue
  fi

  exists=$(jq -r --arg p "$promoter" 'has($p)' "$PEOPLE")
  if [ "$exists" = "true" ]; then
    pass "${show_id} → ${promoter}"
  else
    fail "${show_id} → ${promoter} NOT FOUND in people.json"
  fi
done < <(jq -r 'to_entries[] | [.key, .value.promoter] | @tsv' "$INDEX")
echo ""

# ── Venue contact references ─────────────────────────────────────────

echo "=== Venue → Contact References ==="

while IFS=$'\t' read -r venue role person_key; do
  exists=$(jq -r --arg p "$person_key" 'has($p)' "$PEOPLE")
  if [ "$exists" = "true" ]; then
    pass "${venue} [${role}] → ${person_key}"
  else
    fail "${venue} [${role}] → ${person_key} NOT FOUND in people.json"
  fi
done < <(jq -r 'to_entries[] | .key as $venue | .value.contacts | to_entries[] | [$venue, .key, .value] | @tsv' "$VENUES")
echo ""

# ── Calendar ↔ Show linkage ──────────────────────────────────────────

echo "=== Calendar ↔ Show Linkage ==="

# Check that every show's date has a calendar file linking back to it
while IFS=$'\t' read -r show_id date; do
  month=$(echo "$date" | cut -d'-' -f1-2)
  day=$(echo "$date" | cut -d'-' -f3 | sed 's/^0//')
  cal_file="${CALENDAR}/${month}/$(printf '%02d' "$day").md"

  if [ ! -f "$cal_file" ]; then
    fail "${show_id} (${date}): calendar file MISSING"
    continue
  fi

  # Check that the calendar file references this show
  if grep -q "show: ${show_id}" "$cal_file"; then
    pass "${show_id} ↔ ${date}"
  else
    fail "${show_id} (${date}): calendar file exists but does NOT reference show"
  fi
done < <(jq -r 'to_entries[] | [.key, .value.date] | @tsv' "$INDEX")
echo ""

# ── People with org refs ─────────────────────────────────────────────

VENDORS="${STATE}/vendors.json"

echo "=== People → Org References ==="

# Check that every person's org field (venue:key or vendor:key) resolves
while IFS=$'\t' read -r person_key org_ref; do
  org_type="${org_ref%%:*}"
  org_key="${org_ref#*:}"

  if [ "$org_type" = "venue" ]; then
    exists=$(jq -r --arg v "$org_key" 'has($v)' "$VENUES")
    if [ "$exists" = "true" ]; then
      pass "${person_key} → ${org_ref}"
    else
      fail "${person_key} → ${org_ref} NOT FOUND in venues.json"
    fi
  elif [ "$org_type" = "vendor" ]; then
    exists=$(jq -r --arg v "$org_key" 'has($v)' "$VENDORS")
    if [ "$exists" = "true" ]; then
      pass "${person_key} → ${org_ref}"
    else
      fail "${person_key} → ${org_ref} NOT FOUND in vendors.json"
    fi
  else
    fail "${person_key} → ${org_ref} UNKNOWN org prefix (expected venue: or vendor:)"
  fi
done < <(jq -r 'to_entries[] | select(.value.org != null) | [.key, .value.org] | @tsv' "$PEOPLE")
echo ""

# ── Summary ───────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  ${checks} checks | ${errors} errors | ${warnings} warnings"

if [ "$errors" -gt 0 ]; then
  echo "  INTEGRITY CHECK FAILED"
  exit 1
else
  echo "  ALL REFERENCES VALID"
fi
