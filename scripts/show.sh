#!/usr/bin/env bash
# desc: Display details for a specific show
# usage: show.sh <show-id-or-partial>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

INDEX="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"
VENUES="${REPO_ROOT}/$(cfg '.registries.venues.path')"
SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./bandlab-cli build-index" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: show.sh <show-id-or-partial>" >&2
  exit 1
fi

query="$1"
show_id=$(jq -r "keys[] | select(contains(\"${query}\"))" "$INDEX" | head -1)

if [ -z "$show_id" ]; then
  echo "No show found matching: ${query}" >&2
  exit 1
fi

# ── Formatting helpers ─────────────────────────────────────────────
kv()  { printf "  %-18s%s\n" "$1" "${2:-—}"; }
ikv() { printf "    %-16s%s\n" "$1" "${2:-—}"; }

# Key-value with provenance + verified sub-row (only when present)
# Usage: kvpv "Label" "value" "field_key"
kvpv() {
  local label="$1" value="${2:-—}" field="$3"
  local src vdate subrow=""
  src=$(prov_src "$field")
  vdate=$(ver_date "$field")
  if [ -n "$src" ]; then subrow="← ${src}"; fi
  if [ -n "$vdate" ]; then subrow="${subrow}  ✓${vdate}"; fi
  printf "  %-18s%s\n" "$label" "$value"
  if [ -n "$subrow" ]; then printf "  %-18s%s\n" "" "$subrow"; fi
}

# Indented version for advance/schedule sub-fields
ikvpv() {
  local label="$1" value="${2:-—}" field="$3"
  local src vdate subrow=""
  src=$(prov_src "$field")
  vdate=$(ver_date "$field")
  if [ -n "$src" ]; then subrow="← ${src}"; fi
  if [ -n "$vdate" ]; then subrow="${subrow}  ✓${vdate}"; fi
  printf "    %-16s%s\n" "$label" "$value"
  if [ -n "$subrow" ]; then printf "    %-16s%s\n" "" "$subrow"; fi
}

# Normalize jq null/empty to empty string for shell
n() { local v="$1"; if [ "$v" = "null" ] || [ -z "$v" ]; then echo ""; else echo "$v"; fi; }

# ── Extract show data ──────────────────────────────────────────────
show_json=$(jq --arg id "$show_id" '.[$id]' "$INDEX")
get()  { n "$(echo "$show_json" | jq -r "$1")"; }
getr() { echo "$show_json" | jq -r "$1"; }

# ── Provenance + verification lookups ────────────────────────────
# Invert _provenance (source→fields) to field→source JSON object
# Shorten source names: strip "source/" prefix and "DIRTWIRE_" prefix
prov_lookup=$(echo "$show_json" | jq '
  [._provenance // {} | to_entries[] |
   .key as $src | .value.fields // [] | .[] |
   {key: ., value: ($src | ltrimstr("source/") | ltrimstr("DIRTWIRE_"))}
  ] | from_entries
')
veri_lookup=$(echo "$show_json" | jq '._verified // {}')

# Lookup helpers — query the JSON objects
prov_src()  { echo "$prov_lookup" | jq -r --arg f "$1" '.[$f] // empty'; }
ver_date()  { echo "$veri_lookup" | jq -r --arg f "$1" '.[$f] // empty'; }

date=$(get '.date')
venue_key=$(get '.venue')
status=$(get '.status')
guarantee=$(get '.guarantee')
canada_amount=$(get '.canada_amount')
door_split=$(get '.door_split')
promoter=$(get '.promoter')
ages=$(get '.ages')
sell_cap=$(get '.sell_cap')
ticket_scaling=$(get '.ticket_scaling')
wp=$(get '.wp')
support=$(get '.support')
run=$(get '.run')
one_off=$(get '.one_off')
tour=$(get '.tour')
sets=$(echo "$show_json" | jq -r 'if .sets then [.sets[] | "\(.date) \(.time) — \(.stage)"] | join(", ") else "" end')
routing_notes=$(get '.routing_notes')
touring_party=$(getr '[.touring_party // [] | .[] ] | join(", ")')

# Advance fields
adv_hospitality=$(get '.advance.hospitality')
adv_backline=$(get '.advance.backline')
adv_merch_cut=$(get '.advance.merch_cut')
adv_merch_seller=$(get '.advance.merch_seller')
adv_merch_tax_rate=$(get '.advance.merch_tax_rate')
adv_merch_notes=$(get '.advance.merch_notes')
adv_parking=$(get '.advance.parking')
adv_showers=$(get '.advance.showers')
adv_load=$(get '.advance.load')
adv_guest_comps=$(get '.advance.guest_comps')
adv_labor=$(get '.advance.labor')
adv_crew_day=$(get '.advance.crew_day')
adv_settlement=$(get '.advance.settlement')
adv_ticket_count=$(get '.advance.ticket_count')

# Schedule
sched_access=$(get '.advance.schedule.access')
sched_load_in=$(get '.advance.schedule.load_in')
sched_soundcheck=$(get '.advance.schedule.soundcheck')
sched_support_check=$(get '.advance.schedule.support_check')
sched_doors=$(get '.advance.schedule.doors')
sched_support_set=$(get '.advance.schedule.support_set')
sched_headliner_set=$(get '.advance.schedule.headliner_set')
sched_set_length=$(get '.advance.schedule.set_length')
sched_curfew=$(get '.advance.schedule.curfew')
sched_backstage_curfew=$(get '.advance.schedule.backstage_curfew')

# Wifi (object → "network / password" lines)
wifi_lines=$(echo "$show_json" | jq -r '.advance.wifi // {} | to_entries[] | "\(.key): \(.value)"' 2>/dev/null)

# DOS contacts (object → "key  phone" lines)
dos_lines=$(echo "$show_json" | jq -r '.advance.dos_contacts // {} | to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)

# Hotels (array → lines)
hotel_lines=$(echo "$show_json" | jq -r '.advance.hotels // [] | .[]' 2>/dev/null)

# Venue lookup for header
venue_name=$(jq -r --arg v "$venue_key" '.[$v].name // $v' "$VENUES")
venue_city=$(jq -r --arg v "$venue_key" '.[$v].city // ""' "$VENUES")
venue_state=$(jq -r --arg v "$venue_key" '.[$v].state // ""' "$VENUES")
venue_label="${venue_name}"
if [ -n "$venue_city" ] && [ -n "$venue_state" ]; then
  venue_label="${venue_name} (${venue_city}, ${venue_state})"
fi

# ── Print show ─────────────────────────────────────────────────────
echo ""
echo "=== ${show_id} — ${date} ==="
echo ""
kvpv "Date" "$date" "date"
kvpv "Venue" "$venue_label" "venue"
kv "Status" "$status"

# Guarantee: show amount, append canada_amount if present
if [ -n "$guarantee" ]; then
  guar_display="\$${guarantee}"
  [ -n "$canada_amount" ] && guar_display="${guar_display} (${canada_amount})"
  kvpv "Guarantee" "$guar_display" "guarantee"
else
  if [ -n "$canada_amount" ]; then
    kvpv "Guarantee" "— (${canada_amount})" "guarantee"
  else
    kvpv "Guarantee" "" "guarantee"
  fi
fi

kvpv "Door Split" "$door_split" "door_split"
kvpv "Promoter" "$promoter" "promoter"
kvpv "Ages" "$ages" "ages"
kvpv "Sell Cap" "$sell_cap" "sell_cap"
kvpv "Tickets" "$ticket_scaling" "ticket_scaling"
kvpv "WP" "$wp" "wp"
kvpv "Support" "$support" "support"

# Logistics block
if [ -n "$run" ]; then
  kv "Run" "$run"
elif [ -n "$one_off" ]; then
  kv "One-off" "$one_off"
fi

kv "Tour" "$tour"

[ -n "$sets" ] && kv "Sets" "$sets"
[ -n "$routing_notes" ] && kv "Routing Notes" "$routing_notes"

kv "Touring Party" "$touring_party"

# ── Advance section ───────────────────────────────────────────────
echo ""
echo "  Advance"
ikvpv "Hospitality" "$adv_hospitality" "advance.hospitality"
ikvpv "Backline" "$adv_backline" "advance.backline"
if [ -n "$adv_merch_cut" ]; then
  ikvpv "Merch Cut" "${adv_merch_cut}%" "advance.merch_cut"
else
  ikvpv "Merch Cut" "" "advance.merch_cut"
fi
ikvpv "Merch Seller" "$adv_merch_seller" "advance.merch_seller"
ikvpv "Merch Tax" "$adv_merch_tax_rate" "advance.merch_tax_rate"
ikvpv "Merch Notes" "$adv_merch_notes" "advance.merch_notes"
ikvpv "Parking" "$adv_parking" "advance.parking"
ikvpv "Showers" "$adv_showers" "advance.showers"
ikvpv "Load" "$adv_load" "advance.load"
ikvpv "Guest Comps" "$adv_guest_comps" "advance.guest_comps"
ikvpv "Labor" "$adv_labor" "advance.labor"
ikvpv "Crew Day" "$adv_crew_day" "advance.crew_day"
ikvpv "Settlement" "$adv_settlement" "advance.settlement"
ikvpv "Ticket Count" "$adv_ticket_count" "advance.ticket_count"

# Wifi
if [ -n "$wifi_lines" ]; then
  echo ""
  echo "    Wifi"
  while IFS= read -r line; do
    printf "      %s\n" "$line"
  done <<< "$wifi_lines"
fi

# ── Schedule ──────────────────────────────────────────────────────
has_schedule=false
for v in "$sched_access" "$sched_load_in" "$sched_soundcheck" "$sched_doors" "$sched_headliner_set"; do
  [ -n "$v" ] && has_schedule=true
done

if $has_schedule; then
  echo ""
  echo "  Schedule"
  ikvpv "Access" "$sched_access" "advance.schedule"
  ikvpv "Load-in" "$sched_load_in" "advance.schedule"
  ikvpv "Soundcheck" "$sched_soundcheck" "advance.schedule"
  ikvpv "Support Check" "$sched_support_check" "advance.schedule"
  ikvpv "Doors" "$sched_doors" "advance.schedule"
  ikvpv "Support Set" "$sched_support_set" "advance.schedule"
  ikvpv "Headliner Set" "$sched_headliner_set" "advance.schedule"
  if [ -n "$sched_set_length" ]; then
    ikvpv "Set Length" "${sched_set_length} min" "advance.schedule"
  else
    ikvpv "Set Length" "" "advance.schedule"
  fi
  ikvpv "Curfew" "$sched_curfew" "advance.schedule"
  ikvpv "Backstage" "$sched_backstage_curfew" "advance.schedule"
fi

# ── DOS Contacts ──────────────────────────────────────────────────
if [ -n "$dos_lines" ]; then
  echo ""
  echo "  DOS Contacts"
  while IFS=$'\t' read -r name phone; do
    ikv "$name" "$phone"
  done <<< "$dos_lines"
fi

# ── Hotels ────────────────────────────────────────────────────────
if [ -n "$hotel_lines" ]; then
  echo ""
  echo "  Hotels"
  while IFS= read -r h; do
    printf "    %s\n" "$h"
  done <<< "$hotel_lines"
fi

# ── Provenance ────────────────────────────────────────────────────
prov_lines=$(echo "$show_json" | jq -r '
  ._provenance // {} | to_entries[] |
  "\(.key) (\(.value.fields | length) fields)"
' 2>/dev/null)

if [ -n "$prov_lines" ]; then
  echo ""
  echo "  Provenance"
  while IFS= read -r p; do
    printf "    %s\n" "$p"
  done <<< "$prov_lines"
fi

# ── Venue section ─────────────────────────────────────────────────
echo ""
echo "=== Venue: ${venue_key} ==="
venue_json=$(jq --arg v "$venue_key" '.[$v]' "$VENUES")
v_name=$(n "$(echo "$venue_json" | jq -r '.name')")
v_address=$(n "$(echo "$venue_json" | jq -r '.address')")
v_city=$(n "$(echo "$venue_json" | jq -r '.city')")
v_state=$(n "$(echo "$venue_json" | jq -r '.state')")
v_capacity=$(n "$(echo "$venue_json" | jq -r '.capacity')")
v_notes=$(n "$(echo "$venue_json" | jq -r '.notes')")

kv "Name" "$v_name"
kv "Address" "$v_address"
kv "City" "$v_city"
kv "State" "$v_state"
[ -n "$v_capacity" ] && kv "Capacity" "$v_capacity"

# Venue contacts
v_contacts=$(echo "$venue_json" | jq -r '.contacts // {} | to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)
if [ -n "$v_contacts" ]; then
  echo "  Contacts"
  while IFS=$'\t' read -r role person; do
    ikv "$role" "$person"
  done <<< "$v_contacts"
fi

[ -n "$v_notes" ] && kv "Notes" "$v_notes"

# ── Files section ─────────────────────────────────────────────────
echo ""
echo "=== Files ==="
show_dir="${SHOWS_DIR}/${show_id}"

# Read file checklist from config
while IFS= read -r f; do
  if [ -f "${show_dir}/${f}" ]; then
    echo "  [x] ${f}"
  else
    echo "  [ ] ${f}"
  fi
done < <(cfg '.entities.shows.file_checklist[]')

# Source documents
if [ -d "${show_dir}/source" ]; then
  source_count=$(find "${show_dir}/source" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "  [x] source/ (${source_count} files)"
else
  echo "  [ ] source/"
fi
