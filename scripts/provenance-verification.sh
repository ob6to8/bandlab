#!/usr/bin/env bash
# desc: Verify that all data traces to source documents with coverage stats
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"

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

# Verification counters
verified_fields=0
shows_with_verified=0

# ── Check if provenance is enabled ───────────────────────────────────

prov_enabled=$(cfg_default '.provenance.enabled' 'false')
if [ "$prov_enabled" != "true" ]; then
  echo "Provenance is not enabled in bandlab.config.json — skipping."
  exit 0
fi

prov_field=$(cfg '.provenance.field_name')
skip_fields=$(cfg '.provenance.skip_fields')
special_values=$(cfg '.provenance.special_source_values // []')
special_prefixes=$(cfg '.provenance.special_source_prefixes // []')
source_base="${REPO_ROOT}/$(cfg '.provenance.source_base_dir')"

# ── Show provenance blocks ──────────────────────────────────────────

echo "=== Show Provenance Blocks ==="

for show_dir in "${SHOWS_DIR}"/s-*/; do
  [ -f "${show_dir}/show.json" ] || continue
  show_id="$(basename "$show_dir")"
  shows_total=$((shows_total + 1))

  # Check provenance block exists
  has_prov=$(jq --arg f "$prov_field" 'has($f)' "${show_dir}/show.json")
  if [ "$has_prov" != "true" ]; then
    fail "${show_id}: missing ${prov_field} block"
    continue
  fi
  shows_with_provenance=$((shows_with_provenance + 1))

  # Collect all provenance-covered fields across all sources
  all_covered=$(jq -r --arg f "$prov_field" '.[$f] | [.[].fields[]] | unique | .[]' "${show_dir}/show.json")

  # Check non-null data fields for coverage
  while read -r field; do
    total_data_fields=$((total_data_fields + 1))

    if echo "$all_covered" | grep -qx "$field"; then
      covered_fields=$((covered_fields + 1))
    else
      unsourced_fields=$((unsourced_fields + 1))
      warn "${show_id}: field '${field}' has data but no provenance entry"
    fi
  done < <(jq -r --argjson skip "$skip_fields" '
    # Check if a value has real content (not null, empty string, empty array, or all-empty object)
    def has_content:
      . != null and . != "" and . != [] and . != {} and
      ((type | . != "object") or ([to_entries[].value | . != null and . != "" and . != [] and . != {}] | any));

    # Flatten namespace objects (deal, venue) into dot-notation keys
    # Skip container keys and skip_fields, then enumerate leaf fields
    (to_entries[] | select(.key as $k | $skip | index($k) | not) |
      if (.value | type) == "object" then
        .key as $prefix | .value | to_entries[] |
        select(.value | has_content) |
        ($prefix + "." + .key)
      else
        select(.value | has_content) | .key
      end
    )
  ' "${show_dir}/show.json")

  # Check for manual provenance entries
  manual_count=$(jq -r --arg f "$prov_field" '.[$f] | keys[] | select(startswith("manual:"))' "${show_dir}/show.json" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$manual_count" -gt 0 ]; then
    manual_fields=$((manual_fields + manual_count))
  fi

  # Check that every source path in provenance resolves to a real file
  while read -r source_key; do
    # Skip special source values/prefixes
    is_special=false
    for sp in $(echo "$special_prefixes" | jq -r '.[]'); do
      case "$source_key" in
        "${sp}"*) is_special=true; break ;;
      esac
    done
    if [ "$is_special" = false ]; then
      for sv in $(echo "$special_values" | jq -r '.[]'); do
        [ "$source_key" = "$sv" ] && is_special=true && break
      done
    fi
    [ "$is_special" = true ] && continue

    # URLs are valid external provenance sources
    case "$source_key" in
      http://*|https://*) pass "${show_id}: ${source_key} (URL)"; continue ;;
    esac

    source_file="${show_dir}/${source_key}"
    if [ -f "$source_file" ]; then
      pass "${show_id}: ${source_key} exists"
    else
      fail "${show_id}: provenance source file missing: ${source_key}"
    fi
  done < <(jq -r --arg f "$prov_field" '.[$f] | keys[]' "${show_dir}/show.json")

  # Count human-verified fields
  show_verified=$(jq '._verified // {} | length' "${show_dir}/show.json")
  if [ "$show_verified" -gt 0 ]; then
    shows_with_verified=$((shows_with_verified + 1))
    verified_fields=$((verified_fields + show_verified))
  fi
done
echo ""

# ── Registry sources (config-driven) ─────────────────────────────────

# Iterate all registries that declare has_sources
# shellcheck disable=SC2034
while IFS=$'\t' read -r reg_label reg_path; do
  reg_file="${REPO_ROOT}/${reg_path}"
  [ -f "$reg_file" ] || continue
  reg_basename=$(basename "$reg_file" .json)

  # Capitalize basename for section header (e.g. "people.json" → "People", "venues.json" → "Venue")
  # Strip trailing 's' for plural registry names to match conventional display
  display_base="${reg_basename%s}"
  first_char=$(echo "$display_base" | cut -c1 | tr '[:lower:]' '[:upper:]')
  rest=$(echo "$display_base" | cut -c2-)
  cap_label="${first_char}${rest}"
  echo "=== ${cap_label} Sources ==="

  reg_total=0
  reg_sourced=0
  reg_manual=0
  reg_unsourced=0

  while read -r entry_key; do
    reg_total=$((reg_total + 1))
    sources=$(jq -r --arg k "$entry_key" '.[$k].sources // []' "$reg_file")
    count=$(echo "$sources" | jq 'length')

    if [ "$count" -eq 0 ]; then
      reg_unsourced=$((reg_unsourced + 1))
      warn "${entry_key}: no sources"
    else
      # Check if all sources are manual/legacy
      non_manual=$(echo "$sources" | jq '[.[] | select(. != "manual" and (startswith("legacy") | not))] | length')
      if [ "$non_manual" -eq 0 ]; then
        reg_manual=$((reg_manual + 1))
      else
        reg_sourced=$((reg_sourced + 1))
      fi

      # Validate file-path sources resolve
      while read -r src; do
        # Skip special values
        is_special=false
        for sv in $(echo "$special_values" | jq -r '.[]'); do
          [ "$src" = "$sv" ] && is_special=true && break
        done
        if [ "$is_special" = false ]; then
          for sp in $(echo "$special_prefixes" | jq -r '.[]'); do
            case "$src" in
              "${sp}"*) is_special=true; break ;;
            esac
          done
        fi
        [ "$is_special" = true ] && continue

        if [ ! -f "${source_base}/${src}" ]; then
          fail "${entry_key}: source file not found: ${src}"
        fi
      done < <(echo "$sources" | jq -r '.[]')
    fi
  done < <(jq -r 'keys[]' "$reg_file")

  pass "${reg_basename}.json: ${reg_total} entries — ${reg_sourced} doc-sourced, ${reg_manual} manual-only, ${reg_unsourced} unsourced"
  echo ""
done < <(jq -r '.registries | to_entries[] | select(.value.has_sources == true) | [.key, .value.path] | @tsv' "$CONFIG")

# ── Coverage Report ──────────────────────────────────────────────────

echo "=== Provenance Coverage ==="

if [ "$shows_total" -gt 0 ]; then
  prov_pct=$((shows_with_provenance * 100 / shows_total))
  echo "  Shows with ${prov_field}: ${shows_with_provenance}/${shows_total} (${prov_pct}%)"
fi

if [ "$total_data_fields" -gt 0 ]; then
  covered_pct=$((covered_fields * 100 / total_data_fields))
  unsourced_pct=$((unsourced_fields * 100 / total_data_fields))
  echo "  Show data fields covered: ${covered_fields}/${total_data_fields} (${covered_pct}%)"
  echo "  Show data fields unsourced: ${unsourced_fields}/${total_data_fields} (${unsourced_pct}%)"
fi

echo "  Manual provenance entries across shows: ${manual_fields}"
echo ""
echo "  Human-verified fields: ${verified_fields} (across ${shows_with_verified} shows)"
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
