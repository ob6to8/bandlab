#!/usr/bin/env bash
# desc: Check that all keys resolve, files exist, and cross-references are valid
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
VENUES="${REPO_ROOT}/$(cfg '.registries.venues.path')"
CALENDAR_REL=$(cfg_default '.calendar.path' '')
CALENDAR="${REPO_ROOT}/${CALENDAR_REL}"

errors=0
warnings=0
checks=0

# ── Required files ────────────────────────────────────────────────────

echo "=== Required Files ==="

load_shows

for f in "$PEOPLE" "$VENUES"; do
  if [ -f "$f" ]; then
    pass "$(basename "$f") exists"
  else
    fail "$(basename "$f") MISSING"
  fi
done
echo ""

# ── Show directories ↔ Data ──────────────────────────────────────────

echo "=== Show Directories ↔ Data ==="

# Every show dir should have day.json and be in the loaded data
for show_dir in "${SHOWS_DIR}"/s-*/; do
  show_id="$(basename "$show_dir")"

  if [ ! -f "${show_dir}/day.json" ]; then
    fail "${show_id}: missing day.json"
    continue
  fi

  in_data=$(jq -r --arg id "$show_id" 'has($id)' "$SHOWS_DATA")
  if [ "$in_data" = "true" ]; then
    pass "${show_id}: dir + day.json + loaded"
  else
    fail "${show_id}: has day.json but NOT loaded"
  fi
done
echo ""

# ── Show → Registry references (config-driven) ───────────────────────

# Read reference definitions from config and check each one
# shellcheck disable=SC2034
while IFS=$'\t' read -r ref_field ref_registry ref_nullable ref_null_severity; do
  registry_path="${REPO_ROOT}/$(cfg ".registries.${ref_registry}.path")"
  # Capitalize first letter (compatible with bash 3)
  first_char=$(echo "$ref_field" | cut -c1 | tr '[:lower:]' '[:upper:]')
  rest=$(echo "$ref_field" | cut -c2-)
  section_label="${first_char}${rest}"

  echo "=== Show → ${section_label} References ==="

  while IFS=$'\t' read -r show_id value; do
    if [ "$value" = "null" ] || [ -z "$value" ]; then
      if [ "$ref_null_severity" = "warn" ]; then
        warn "${show_id}: ${ref_field} is null"
      fi
      continue
    fi

    exists=$(jq -r --arg v "$value" 'has($v)' "$registry_path")
    if [ "$exists" = "true" ]; then
      pass "${show_id} → ${value}"
    else
      fail "${show_id} → ${value} NOT FOUND in $(basename "$registry_path")"
    fi
  done < <(jq -r "to_entries[] | [.key, .value.${ref_field}] | @tsv" "$SHOWS_DATA")
  echo ""
done < <(jq -r '.entities.shows.references | to_entries[] | [.key, .value.registry, (.value.nullable // false | tostring), (.value.null_severity // "skip")] | @tsv' "$CONFIG")

# ── Venue contact references ─────────────────────────────────────────

# Only check if venues registry declares has_contacts
has_contacts=$(cfg_default '.registries.venues.has_contacts' 'false')
if [ "$has_contacts" = "true" ]; then
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
fi

# ── Calendar ↔ Show linkage ──────────────────────────────────────────

# Only check if calendar section exists in config
if [ -n "$CALENDAR_REL" ] && [ -d "$CALENDAR" ]; then
  echo "=== Calendar ↔ Show Linkage ==="

  show_link_field=$(cfg '.calendar.show_link_field')

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
    if grep -q "${show_link_field}: ${show_id}" "$cal_file"; then
      pass "${show_id} ↔ ${date}"
    else
      fail "${show_id} (${date}): calendar file exists but does NOT reference show"
    fi
  done < <(jq -r 'to_entries[] | [.key, .value.day.date] | @tsv' "$SHOWS_DATA")
  echo ""
fi

# ── People with org refs ─────────────────────────────────────────────

# Only check if people registry declares has_org_refs
has_org_refs=$(cfg_default '.registries.people.has_org_refs' 'false')
if [ "$has_org_refs" = "true" ]; then
  echo "=== People → Org References ==="

  # Build the org prefix → registry path mapping from config
  # Read org_prefixes array and map each to its registry
  org_prefix_count=$(cfg '.registries.people.org_prefixes | length')

  # Check that every person's org field (prefix:key) resolves
  while IFS=$'\t' read -r person_key org_ref; do
    org_type="${org_ref%%:*}"
    org_key="${org_ref#*:}"

    resolved=false
    # Check each known org prefix
    i=0
    while [ "$i" -lt "$org_prefix_count" ]; do
      prefix=$(cfg ".registries.people.org_prefixes[$i]")
      if [ "$org_type" = "$prefix" ]; then
        # Find the registry for this prefix
        # Convention: "venue" → registries.venues, "vendor" → registries.vendors
        registry_name="${prefix}s"
        registry_path_rel=$(cfg_default ".registries.${registry_name}.path" "")
        if [ -n "$registry_path_rel" ] && [ "$registry_path_rel" != "null" ]; then
          registry_path="${REPO_ROOT}/${registry_path_rel}"
          if [ -f "$registry_path" ]; then
            exists=$(jq -r --arg v "$org_key" 'has($v)' "$registry_path")
            if [ "$exists" = "true" ]; then
              pass "${person_key} → ${org_ref}"
            else
              fail "${person_key} → ${org_ref} NOT FOUND in $(basename "$registry_path")"
            fi
          fi
        else
          # No registry for this prefix (e.g., "management") — valid without lookup
          pass "${person_key} → ${org_ref}"
        fi
        resolved=true
        break
      fi
      i=$((i + 1))
    done

    if [ "$resolved" = false ]; then
      # Build expected prefixes string for error message
      expected=$(cfg '.registries.people.org_prefixes | join(":, ")' )
      fail "${person_key} → ${org_ref} UNKNOWN org prefix (expected ${expected}:)"
    fi
  done < <(jq -r 'to_entries[] | select(.value.org != null) | .key as $k | .value.org[] | [$k, .] | @tsv' "$PEOPLE")
  echo ""
fi

# ── Source Provenance ─────────────────────────────────────────────────

echo "=== Source Provenance ==="

# Read special source values from config for file path validation
special_values=$(cfg '.provenance.special_source_values // []')
special_prefixes=$(cfg '.provenance.special_source_prefixes // []')

# Build a case pattern for skipping special values
# We build this inline per-check below

# Check registries that have sources
# shellcheck disable=SC2034
while IFS=$'\t' read -r reg_name reg_path; do
  reg_file="${REPO_ROOT}/${reg_path}"
  [ -f "$reg_file" ] || continue

  with=0
  without=0
  while read -r entry_key; do
    has_sources=$(jq -r --arg k "$entry_key" '.[$k] | has("sources")' "$reg_file")
    if [ "$has_sources" = "true" ]; then
      with=$((with + 1))
    else
      without=$((without + 1))
      fail "${entry_key}: missing sources field in $(basename "$reg_file")"
    fi
  done < <(jq -r 'keys[]' "$reg_file")

  if [ "$without" -eq 0 ]; then
    pass "$(basename "$reg_file"): all ${with} entries have sources"
  fi
done < <(jq -r '.registries | to_entries[] | select(.value.has_sources == true) | [.key, .value.path] | @tsv' "$CONFIG")

# Check that file-path sources resolve to real files
# Special values (manual, legacy, legacy:*) are valid without file checks
bad_paths=0
good_paths=0

# Iterate source-bearing registries
# shellcheck disable=SC2034
while IFS=$'\t' read -r _reg_name reg_path; do
  reg_file="${REPO_ROOT}/${reg_path}"
  [ -f "$reg_file" ] || continue

  while IFS=$'\t' read -r entry_key source_path; do
    # Skip special values
    is_special=false
    for sv in $(echo "$special_values" | jq -r '.[]'); do
      [ "$source_path" = "$sv" ] && is_special=true && break
    done
    if [ "$is_special" = false ]; then
      for sp in $(echo "$special_prefixes" | jq -r '.[]'); do
        case "$source_path" in
          "${sp}"*) is_special=true; break ;;
        esac
      done
    fi
    [ "$is_special" = true ] && continue

    # URLs are valid external provenance sources
    case "$source_path" in
      http://*|https://*) good_paths=$((good_paths + 1)); continue ;;
    esac

    source_base="${REPO_ROOT}/$(cfg '.provenance.source_base_dir')"
    if [ -f "${source_base}/${source_path}" ]; then
      good_paths=$((good_paths + 1))
    else
      bad_paths=$((bad_paths + 1))
      fail "${entry_key}: source file not found: ${source_path}"
    fi
  done < <(jq -r 'to_entries[] | .key as $k | .value.sources // [] | .[] | [$k, .] | @tsv' "$reg_file")
done < <(jq -r '.registries | to_entries[] | select(.value.has_sources == true) | [.key, .value.path] | @tsv' "$CONFIG")

if [ "$bad_paths" -eq 0 ] && [ "$good_paths" -gt 0 ]; then
  pass "all ${good_paths} file-path sources resolve"
fi
echo ""

# ── Source Provenance — Shows ────────────────────────────────────────

prov_enabled=$(cfg_default '.provenance.enabled' 'false')
if [ "$prov_enabled" = "true" ]; then
  prov_field=$(cfg '.provenance.field_name')

  echo "=== Source Provenance — Shows ==="

  shows_with_prov=0
  shows_without_prov=0
  while read -r show_id; do
    show_file="${SHOWS_DIR}/${show_id}/day.json"
    [ ! -f "$show_file" ] && continue

    has_prov=$(jq --arg f "$prov_field" 'has($f)' "$show_file")
    if [ "$has_prov" = "true" ]; then
      shows_with_prov=$((shows_with_prov + 1))

      # Check that source file paths in _provenance resolve
      while IFS=$'\t' read -r prov_key; do
        # Skip special source values/prefixes
        is_special=false
        for sp in $(echo "$special_prefixes" | jq -r '.[]'); do
          case "$prov_key" in
            "${sp}"*) is_special=true; break ;;
          esac
        done
        for sv in $(echo "$special_values" | jq -r '.[]'); do
          [ "$prov_key" = "$sv" ] && is_special=true && break
        done
        [ "$is_special" = true ] && continue

        # URLs are valid external provenance sources
        case "$prov_key" in
          http://*|https://*) pass "${show_id}: ${prov_key} (URL)"; continue ;;
        esac

        source_base="${REPO_ROOT}/$(cfg '.provenance.source_base_dir')"
        if [ -f "${source_base}/${prov_key}" ]; then
          pass "${show_id}: ${prov_key} exists"
        else
          fail "${show_id}: provenance file not found: ${prov_key}"
        fi
      done < <(jq -r --arg f "$prov_field" '.[$f] | keys[]' "$show_file")
    else
      shows_without_prov=$((shows_without_prov + 1))
      warn "${show_id}: missing ${prov_field}"
    fi
  done < <(jq -r 'keys[]' "$SHOWS_DATA")

  total_shows=$((shows_with_prov + shows_without_prov))
  if [ "$total_shows" -gt 0 ]; then
    pct=$((shows_with_prov * 100 / total_shows))
    echo "  ${shows_with_prov}/${total_shows} shows with provenance (${pct}%)"
    checks=$((checks + 1))
  fi
  echo ""
fi

# ── Email Thread Associations ─────────────────────────────────────────

email_glob="${REPO_ROOT}/$(cfg_default '.entities.email.glob' '')"
# Only run if email entity is configured and files exist
# shellcheck disable=SC2086
if [ -n "$email_glob" ] && ls $email_glob &>/dev/null 2>&1; then
  echo "=== Email Thread Associations ==="

  TODOS="${REPO_ROOT}/$(cfg '.registries.todos.path')"

  # shellcheck disable=SC2086
  for email_file in $email_glob; do
    slug="$(basename "$email_file" .md)"

    # Extract YAML frontmatter (between --- markers)
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$email_file" | sed '1d;$d')

    # Validate participants -> people.json
    while read -r person; do
      [ -z "$person" ] && continue
      exists=$(jq -r --arg p "$person" 'has($p)' "$PEOPLE")
      if [ "$exists" = "true" ]; then
        pass "${slug}: participant ${person}"
      else
        fail "${slug}: participant ${person} NOT FOUND in people.json"
      fi
    done <<< "$(echo "$frontmatter" | sed -n '/^participants:/,/^[^ ]/p' | grep '^ *- ' | sed 's/^ *- //')"

    # Validate typed associations using association_types from config
    assoc_types=$(jq -r '.association_types // {} | keys[]' "$CONFIG" 2>/dev/null)
    for atype in $assoc_types; do
      # Extract association values for this type from frontmatter
      # Use awk to properly handle YAML nesting: find "  <atype>:" then collect
      # "    - value" lines until we hit a line with different/less indentation
      values=$(echo "$frontmatter" | awk -v key="  ${atype}:" '
        $0 == key { found=1; next }
        found && /^    - / { sub(/^    - /, ""); print; next }
        found { exit }
      ')
      [ -z "$values" ] && continue

      # Determine where this type resolves
      resolve_registry=$(jq -r --arg t "$atype" '.association_types[$t].registry // empty' "$CONFIG")
      resolve_entity=$(jq -r --arg t "$atype" '.association_types[$t].entity // empty' "$CONFIG")

      while read -r ref; do
        [ -z "$ref" ] && continue

        if [ -n "$resolve_registry" ]; then
          reg_path="${REPO_ROOT}/$(cfg ".registries.${resolve_registry}.path")"
          if [ -f "$reg_path" ]; then
            exists=$(jq -r --arg v "$ref" 'has($v)' "$reg_path")
            if [ "$exists" = "true" ]; then
              pass "${slug}: ${atype} ${ref}"
            else
              fail "${slug}: ${atype} ${ref} NOT FOUND in $(basename "$reg_path")"
            fi
          else
            warn "${slug}: registry file not found for ${atype}"
          fi
        elif [ -n "$resolve_entity" ]; then
          entity_dir="${REPO_ROOT}/$(cfg ".entities.${resolve_entity}.dir")"
          if [ -d "${entity_dir}/${ref}" ]; then
            pass "${slug}: ${atype} ${ref}"
          else
            fail "${slug}: ${atype} ${ref} NOT FOUND in ${resolve_entity}"
          fi
        fi
      done <<< "$values"
    done

    # Validate todos -> todos.json
    todo_refs=$(echo "$frontmatter" | sed -n '/^todos:/,/^[^ ]/p' | grep '^ *- ' | sed 's/^ *- //' || true)
    if [ -n "$todo_refs" ] && [ -f "$TODOS" ]; then
      while read -r tid; do
        [ -z "$tid" ] && continue
        exists=$(jq -r --arg id "$tid" '[.[] | select(.id == $id)] | length > 0' "$TODOS")
        if [ "$exists" = "true" ]; then
          pass "${slug}: todo ${tid}"
        else
          fail "${slug}: todo ${tid} NOT FOUND in todos.json"
        fi
      done <<< "$todo_refs"
    fi
  done
  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  ${checks} checks | ${errors} errors | ${warnings} warnings"

if [ "$errors" -gt 0 ]; then
  echo "  INTEGRITY CHECK FAILED"
  exit 1
else
  echo "  ALL REFERENCES VALID"
fi
