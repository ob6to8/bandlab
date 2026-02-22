#!/usr/bin/env bash
# desc: Verify that all data traces to source documents with coverage stats
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
ORG="${REPO_ROOT}/org"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"
PEOPLE="${ORG}/people.json"
VENUES="${ORG}/touring/venues.json"

errors=0
warnings=0
checks=0

# Coverage counters
shows_total=0
shows_with_provenance=0
total_data_fields=0
covered_fields=0
manual_fields=0
unsourced_fields=0

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

# ── Show _provenance blocks ──────────────────────────────────────────

echo "=== Show Provenance Blocks ==="

# Fields that are metadata/structural — not data that needs provenance
skip_fields='["id","_provenance","advance","run","one_off","tour","touring_party","status","routing_notes","sets","ticket_link"]'

for show_dir in "${SHOWS_DIR}"/s-*/; do
  [ -f "${show_dir}/show.json" ] || continue
  show_id="$(basename "$show_dir")"
  shows_total=$((shows_total + 1))

  # Check _provenance block exists
  has_prov=$(jq 'has("_provenance")' "${show_dir}/show.json")
  if [ "$has_prov" != "true" ]; then
    fail "${show_id}: missing _provenance block"
    continue
  fi
  shows_with_provenance=$((shows_with_provenance + 1))

  # Collect all provenance-covered fields across all sources
  all_covered=$(jq -r '._provenance | [.[].fields[]] | unique | .[]' "${show_dir}/show.json")

  # Check non-null data fields for coverage
  while read -r field; do
    total_data_fields=$((total_data_fields + 1))

    if echo "$all_covered" | grep -qx "$field"; then
      covered_fields=$((covered_fields + 1))
    else
      unsourced_fields=$((unsourced_fields + 1))
      warn "${show_id}: field '${field}' has data but no provenance entry"
    fi
  done < <(jq -r --argjson skip "$skip_fields" 'to_entries[] | select(.key as $k | $skip | index($k) | not) | select(.value != null and .value != "" and .value != []) | .key' "${show_dir}/show.json")

  # Check for manual provenance entries
  manual_count=$(jq -r '._provenance | keys[] | select(startswith("manual:"))' "${show_dir}/show.json" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$manual_count" -gt 0 ]; then
    manual_fields=$((manual_fields + manual_count))
  fi

  # Check that every source path in _provenance resolves to a real file
  while read -r source_key; do
    # Skip manual: and legacy: entries — they're not file paths
    case "$source_key" in
      manual:*|legacy|legacy:*) continue ;;
    esac

    source_file="${show_dir}/${source_key}"
    if [ -f "$source_file" ]; then
      pass "${show_id}: ${source_key} exists"
    else
      fail "${show_id}: provenance source file missing: ${source_key}"
    fi
  done < <(jq -r '._provenance | keys[]' "${show_dir}/show.json")
done
echo ""

# ── Registry sources (people.json) ───────────────────────────────────

echo "=== People Sources ==="

people_total=0
people_sourced=0
people_manual=0
people_unsourced=0

while read -r person_key; do
  people_total=$((people_total + 1))
  sources=$(jq -r --arg k "$person_key" '.[$k].sources // []' "$PEOPLE")
  count=$(echo "$sources" | jq 'length')

  if [ "$count" -eq 0 ]; then
    people_unsourced=$((people_unsourced + 1))
    warn "${person_key}: no sources"
  else
    # Check if all sources are manual/legacy
    non_manual=$(echo "$sources" | jq '[.[] | select(. != "manual" and (startswith("legacy") | not))] | length')
    if [ "$non_manual" -eq 0 ]; then
      people_manual=$((people_manual + 1))
    else
      people_sourced=$((people_sourced + 1))
    fi

    # Validate file-path sources resolve
    while read -r src; do
      case "$src" in
        manual|legacy|legacy:*) continue ;;
      esac
      if [ ! -f "${ORG}/${src}" ]; then
        fail "${person_key}: source file not found: ${src}"
      fi
    done < <(echo "$sources" | jq -r '.[]')
  fi
done < <(jq -r 'keys[]' "$PEOPLE")

pass "people.json: ${people_total} entries — ${people_sourced} doc-sourced, ${people_manual} manual-only, ${people_unsourced} unsourced"
echo ""

# ── Registry sources (venues.json) ───────────────────────────────────

echo "=== Venue Sources ==="

venues_total=0
venues_sourced=0
venues_manual=0
venues_unsourced=0

while read -r venue_key; do
  venues_total=$((venues_total + 1))
  sources=$(jq -r --arg k "$venue_key" '.[$k].sources // []' "$VENUES")
  count=$(echo "$sources" | jq 'length')

  if [ "$count" -eq 0 ]; then
    venues_unsourced=$((venues_unsourced + 1))
    warn "${venue_key}: no sources"
  else
    non_manual=$(echo "$sources" | jq '[.[] | select(. != "manual" and (startswith("legacy") | not))] | length')
    if [ "$non_manual" -eq 0 ]; then
      venues_manual=$((venues_manual + 1))
    else
      venues_sourced=$((venues_sourced + 1))
    fi

    while read -r src; do
      case "$src" in
        manual|legacy|legacy:*) continue ;;
      esac
      if [ ! -f "${ORG}/${src}" ]; then
        fail "${venue_key}: source file not found: ${src}"
      fi
    done < <(echo "$sources" | jq -r '.[]')
  fi
done < <(jq -r 'keys[]' "$VENUES")

pass "venues.json: ${venues_total} entries — ${venues_sourced} doc-sourced, ${venues_manual} manual-only, ${venues_unsourced} unsourced"
echo ""

# ── Coverage Report ──────────────────────────────────────────────────

echo "=== Provenance Coverage ==="

if [ "$shows_total" -gt 0 ]; then
  prov_pct=$((shows_with_provenance * 100 / shows_total))
  echo "  Shows with _provenance: ${shows_with_provenance}/${shows_total} (${prov_pct}%)"
fi

if [ "$total_data_fields" -gt 0 ]; then
  covered_pct=$((covered_fields * 100 / total_data_fields))
  unsourced_pct=$((unsourced_fields * 100 / total_data_fields))
  echo "  Show data fields covered: ${covered_fields}/${total_data_fields} (${covered_pct}%)"
  echo "  Show data fields unsourced: ${unsourced_fields}/${total_data_fields} (${unsourced_pct}%)"
fi

echo "  Manual provenance entries across shows: ${manual_fields}"
echo ""

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  ${checks} checks | ${errors} errors | ${warnings} warnings"

if [ "$errors" -gt 0 ]; then
  echo "  PROVENANCE VERIFICATION FAILED"
  exit 1
else
  echo "  PROVENANCE VERIFIED"
fi
