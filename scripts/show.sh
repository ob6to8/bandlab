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

# ── Table formatting ──────────────────────────────────────────────
# Column widths: all fixed, table may exceed terminal width
W1=14; W2=48; W3=30

# Truncate string to max length, append ".." if truncated
trunc() {
  local s="$1" max="$2"
  if [ "${#s}" -le "$max" ]; then
    printf '%s' "$s"
  else
    printf '%s' "${s:0:$((max-2))}.."
  fi
}

# Horizontal separator line
hline() {
  printf "+-%s-+-%s-+-%s-+\n" \
    "$(printf '%*s' "$W1" '' | tr ' ' '-')" \
    "$(printf '%*s' "$W2" '' | tr ' ' '-')" \
    "$(printf '%*s' "$W3" '' | tr ' ' '-')"
}

# Data row: trow "Field" "Value" "prov_field_key"
trow() {
  local label="$1" value="$2" field="${3:-}"
  if [ -z "$value" ]; then value="--"; fi
  local src="" vdate=""
  if [ -n "$field" ]; then
    src=$(prov_src "$field")
    vdate=$(ver_date "$field")
    if [ -n "$vdate" ]; then src="${src} ✓${vdate}"; fi
  fi
  printf "| %-${W1}s | %-${W2}s | %-${W3}s |\n" \
    "$(trunc "$label" "$W1")" \
    "$(trunc "$value" "$W2")" \
    "$(trunc "$src" "$W3")"
}

# Section header row spanning all columns
tsection() {
  local title="$1"
  local inner=$((W1 + W2 + W3 + 7))  # hline total is W1+W2+W3+10, minus "| " and "|"
  printf "| %-${inner}s|\n" "$title"
}

# Plain kv for non-table sections (venue, files)
kv()  { local v="$2"; if [ -z "$v" ]; then v="--"; fi; printf "  %-18s%s\n" "$1" "$v"; }
ikv() { local v="$2"; if [ -z "$v" ]; then v="--"; fi; printf "    %-16s%s\n" "$1" "$v"; }

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
# Band block fields
band_member_1=$(get '.band.band_member_1')
band_member_2=$(get '.band.band_member_2')
band_foh=$(get '.band.foh')
band_ld=$(get '.band.ld')
band_vj=$(get '.band.vj')
band_lasers=$(get '.band.lasers')
band_merch=$(get '.band.merch')
band_driver=$(get '.band.driver')
band_vehicle_type=$(get '.band.vehicle_type')
band_vehicle_length=$(get '.band.vehicle_length')
band_laminates=$(get '.band.laminates')
band_backdrop=$(get '.band.backdrop')

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

# ── Print show table ──────────────────────────────────────────────
echo ""
hline
tsection "${show_id} — ${date}"
hline
tsection "SHOW"
hline
trow "Date" "$date" "date"
trow "Venue" "$venue_label" "venue"
trow "Status" "$status"

# Guarantee: show amount, append canada_amount if present
if [ -n "$guarantee" ]; then
  guar_display="\$${guarantee}"
  if [ -n "$canada_amount" ]; then guar_display="${guar_display} (${canada_amount})"; fi
  trow "Guarantee" "$guar_display" "guarantee"
else
  if [ -n "$canada_amount" ]; then
    trow "Guarantee" "— (${canada_amount})" "guarantee"
  else
    trow "Guarantee" "" "guarantee"
  fi
fi

trow "Door Split" "$door_split" "door_split"
trow "Promoter" "$promoter" "promoter"
trow "Ages" "$ages" "ages"
trow "Sell Cap" "$sell_cap" "sell_cap"
trow "Tickets" "$ticket_scaling" "ticket_scaling"
trow "WP" "$wp" "wp"
if [ -n "$sets" ]; then trow "Sets" "$sets"; fi
if [ -n "$routing_notes" ]; then trow "Routing Notes" "$routing_notes"; fi

# ── Venue Capabilities section ───────────────────────────────────
hline
tsection "VENUE CAPABILITIES"
hline
if [ -n "$adv_merch_cut" ]; then
  trow "Merch Cut" "${adv_merch_cut}%" "advance.merch_cut"
else
  trow "Merch Cut" "" "advance.merch_cut"
fi
trow "Merch Seller" "$adv_merch_seller" "advance.merch_seller"
trow "Merch Tax" "$adv_merch_tax_rate" "advance.merch_tax_rate"
trow "Merch Notes" "$adv_merch_notes" "advance.merch_notes"
trow "Parking" "$adv_parking" "advance.parking"
trow "Showers" "$adv_showers" "advance.showers"
trow "Load" "$adv_load" "advance.load"
trow "Guest Comps" "$adv_guest_comps" "advance.guest_comps"
trow "Labor" "$adv_labor" "advance.labor"
trow "Crew Day" "$adv_crew_day" "advance.crew_day"
trow "Settlement" "$adv_settlement" "advance.settlement"
trow "Ticket Count" "$adv_ticket_count" "advance.ticket_count"

# Wifi
if [ -n "$wifi_lines" ]; then
  while IFS= read -r line; do
    trow "Wifi" "$line" "advance.wifi"
  done <<< "$wifi_lines"
fi

# ── Schedule ──────────────────────────────────────────────────────
has_schedule=false
for v in "$sched_access" "$sched_load_in" "$sched_soundcheck" "$sched_doors" "$sched_headliner_set"; do
  if [ -n "$v" ]; then has_schedule=true; fi
done

if $has_schedule; then
  hline
  tsection "SCHEDULE"
  hline
  trow "Access" "$sched_access" "advance.schedule"
  trow "Load-in" "$sched_load_in" "advance.schedule"
  trow "Soundcheck" "$sched_soundcheck" "advance.schedule"
  trow "Support Check" "$sched_support_check" "advance.schedule"
  trow "Doors" "$sched_doors" "advance.schedule"
  trow "Support Set" "$sched_support_set" "advance.schedule"
  trow "Headliner Set" "$sched_headliner_set" "advance.schedule"
  if [ -n "$sched_set_length" ]; then
    trow "Set Length" "${sched_set_length} min" "advance.schedule"
  else
    trow "Set Length" "" "advance.schedule"
  fi
  trow "Curfew" "$sched_curfew" "advance.schedule"
  trow "Backstage" "$sched_backstage_curfew" "advance.schedule"
fi

# ── DOS Contacts ──────────────────────────────────────────────────
if [ -n "$dos_lines" ]; then
  hline
  tsection "DOS CONTACTS"
  hline
  while IFS=$'\t' read -r name phone; do
    trow "$name" "$phone" "advance.dos_contacts"
  done <<< "$dos_lines"
fi

# ── Hotels ────────────────────────────────────────────────────────
if [ -n "$hotel_lines" ]; then
  hline
  tsection "HOTELS"
  hline
  while IFS= read -r h; do
    trow "" "$h" "advance.hotels"
  done <<< "$hotel_lines"
fi

# ── Band section ─────────────────────────────────────────────────
hline
echo ""
hline
tsection "BAND: Show"
hline
trow "Band" "$band_member_1" "band.band_member_1"
trow "Band" "$band_member_2" "band.band_member_2"
trow "FOH" "$band_foh" "band.foh"
trow "LD" "$band_ld" "band.ld"
trow "VJ" "$band_vj" "band.vj"
trow "Lasers" "$band_lasers" "band.lasers"
trow "Merch" "$band_merch" "band.merch"
trow "Driver" "$band_driver" "band.driver"
veh="$band_vehicle_type"
if [ -n "$band_vehicle_length" ]; then veh="${veh} (${band_vehicle_length})"; fi
trow "Vehicle" "$veh" "band.vehicle_type"
trow "Laminates" "$band_laminates" "band.laminates"
trow "Backdrop" "$band_backdrop" "band.backdrop"
trow "Support" "$support" "support"
trow "Hospitality" "$adv_hospitality" "advance.hospitality"
trow "Backline" "$adv_backline" "advance.backline"

# Logistics block
if [ -n "$run" ]; then
  trow "Run" "$run"
elif [ -n "$one_off" ]; then
  trow "One-off" "$one_off"
fi

trow "Tour" "$tour"

# ── Tour Production ──────────────────────────────────────────────
TOURS_DIR="${REPO_ROOT}/$(cfg '.entities.tours.dir')"
if [ -n "$tour" ]; then
  tour_json_file="${TOURS_DIR}/${tour}/tour.json"
  if [ -f "$tour_json_file" ]; then
    tour_json=$(jq '.' "$tour_json_file")
    has_prod=$(echo "$tour_json" | jq 'has("production")')
    if [ "$has_prod" = "true" ]; then
      # Build provenance lookup for tour
      tour_prov=$(echo "$tour_json" | jq '
        [._provenance // {} | to_entries[] |
         .key as $src | .value.fields // [] | .[] |
         {key: ., value: ($src | ltrimstr("source/"))}
        ] | from_entries
      ')
      tour_src() { echo "$tour_prov" | jq -r --arg f "$1" '.[$f] // empty'; }

      # Use tour provenance for source column
      ts() { tour_src "$1"; }
      trow_t() {
        local label="$1" value="$2" field="${3:-}"
        if [ -z "$value" ]; then value="--"; fi
        local src=""
        if [ -n "$field" ]; then src=$(ts "$field"); fi
        printf "| %-${W1}s | %-${W2}s | %-${W3}s |\n" \
          "$(trunc "$label" "$W1")" \
          "$(trunc "$value" "$W2")" \
          "$(trunc "$src" "$W3")"
      }

      prod_stands=$(n "$(echo "$tour_json" | jq -r '.production.stands_venue')")
      prod_mics_v=$(n "$(echo "$tour_json" | jq -r '.production.mics_venue')")

      hline
      tsection "BAND: ${tour}"
      hline
      tsection "BACKLINE"
      hline
      trow_t "Stands" "$prod_stands" "production.stands_venue"
      trow_t "Mics" "$prod_mics_v" "production.mics_venue"

      prod_mics_c=$(n "$(echo "$tour_json" | jq -r '.production.mics_carried')")
      prod_foh=$(n "$(echo "$tour_json" | jq -r '.production.foh_console')")
      prod_mon=$(n "$(echo "$tour_json" | jq -r '.production.mon_rack')")
      prod_monitors=$(n "$(echo "$tour_json" | jq -r '.production.monitors')")
      prod_audio=$(n "$(echo "$tour_json" | jq -r '.production.audio_notes')")

      hline
      tsection "CARRIED"
      hline
      trow_t "Mics" "$prod_mics_c" "production.mics_carried"
      trow_t "FOH Console" "$prod_foh" "production.foh_console"
      trow_t "Mon Rack" "$prod_mon" "production.mon_rack"
      trow_t "Monitors" "$prod_monitors" "production.monitors"
      trow_t "Audio Notes" "$prod_audio" "production.audio_notes"
    fi
  fi
fi

hline

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
