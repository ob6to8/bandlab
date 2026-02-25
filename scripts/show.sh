#!/usr/bin/env bash
# desc: Display details for a specific show
# usage: show.sh <show-id-or-partial>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config
load_shows

VENUES="${REPO_ROOT}/$(cfg '.registries.venues.path')"
SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"

if [ $# -lt 1 ]; then
  echo "Usage: show.sh <show-id-or-partial>" >&2
  exit 1
fi

query="$1"
show_id=$(jq -r "keys[] | select(contains(\"${query}\"))" "$SHOWS_DATA" | head -1)

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

# Plain kv for non-table sections (files)
kv()  { local v="$2"; if [ -z "$v" ]; then v="--"; fi; printf "  %-18s%s\n" "$1" "$v"; }

# Normalize jq null/empty to empty string for shell
n() { local v="$1"; if [ "$v" = "null" ] || [ -z "$v" ]; then echo ""; else echo "$v"; fi; }

# ── Extract show data ──────────────────────────────────────────────
show_json=$(jq --arg id "$show_id" '.[$id]' "$SHOWS_DATA")
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

date=$(get '.show.date')
venue_key=$(get '.venue.id')
status=$(get '.show.status')
guarantee=$(get '.deal.guarantee')
canada_amount=$(get '.deal.canada_amount')
door_split=$(get '.deal.door_split')
promoter=$(get '.deal.promoter')
ages=$(get '.deal.ages')
sell_cap=$(get '.deal.sell_cap')
ticket_scaling=$(get '.deal.ticket_scaling')
wp=$(get '.deal.wp')
support=$(get '.deal.support')
tour=$(get '.show.tour')
run=$(get '.show.run')
one_off=$(get '.show.one_off')
sets=$(echo "$show_json" | jq -r 'if .deal.sets then [.deal.sets[] | "\(.date) \(.time) - \(.stage)"] | join(", ") else "" end')
# Band block fields
band_member_1=$(get '.band.band_member_1')
band_member_2=$(get '.band.band_member_2')
band_foh=$(get '.band.foh')
band_ld=$(get '.band.ld')
band_vj=$(get '.band.vj')
band_lasers=$(get '.band.lasers')
band_merch=$(get '.band.merch')
band_driver=$(get '.band.driver')

# Venue fields
adv_hospitality=$(get '.venue.hospitality')
adv_merch_cut=$(get '.venue.merch_cut')
adv_merch_seller=$(get '.venue.merch_seller')
adv_merch_tax_rate=$(get '.venue.merch_tax_rate')
adv_merch_notes=$(get '.venue.merch_notes')
adv_parking=$(get '.venue.parking')
adv_showers=$(get '.venue.showers')
adv_load=$(get '.venue.load')
adv_guest_comps=$(get '.venue.guest_comps')
adv_labor=$(get '.venue.labor')
adv_crew_day=$(get '.venue.crew_day')
adv_settlement=$(get '.venue.settlement')
adv_ticket_count=$(get '.venue.ticket_count')

# Schedule
sched_access=$(get '.venue.schedule.access')
sched_load_in=$(get '.venue.schedule.load_in')
sched_soundcheck=$(get '.venue.schedule.soundcheck')
sched_support_check=$(get '.venue.schedule.support_check')
sched_doors=$(get '.venue.schedule.doors')
sched_support_set=$(get '.venue.schedule.support_set')
sched_headliner_set=$(get '.venue.schedule.headliner_set')
sched_set_length=$(get '.venue.schedule.set_length')
sched_curfew=$(get '.venue.schedule.curfew')
sched_backstage_curfew=$(get '.venue.schedule.backstage_curfew')

# Wifi (object → "network / password" lines)
wifi_lines=$(echo "$show_json" | jq -r '.venue.wifi // {} | to_entries[] | "\(.key): \(.value)"' 2>/dev/null)

# DOS contacts (object → "key  phone" lines)
dos_lines=$(echo "$show_json" | jq -r '.venue.dos_contacts // {} | to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)

# Hotels (array → lines)
hotel_lines=$(echo "$show_json" | jq -r '.venue.hotels // [] | .[]' 2>/dev/null)

# Venue lookup for header
venue_name=$(jq -r --arg v "$venue_key" '.[$v].name // $v' "$VENUES")
venue_city=$(jq -r --arg v "$venue_key" '.[$v].city // ""' "$VENUES")
venue_state=$(jq -r --arg v "$venue_key" '.[$v].state // ""' "$VENUES")
venue_label="${venue_name}"
if [ -n "$venue_city" ] && [ -n "$venue_state" ]; then
  venue_label="${venue_name} (${venue_city}, ${venue_state})"
fi

# Venue registry data
venue_json=$(jq --arg v "$venue_key" '.[$v]' "$VENUES")
v_address=$(n "$(echo "$venue_json" | jq -r '.address')")
v_capacity=$(n "$(echo "$venue_json" | jq -r '.capacity')")
v_notes=$(n "$(echo "$venue_json" | jq -r '.notes')")
v_contacts=$(echo "$venue_json" | jq -r '.contacts // {} | to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)

# ── Print SHOW block ─────────────────────────────────────────────
echo ""
hline
tsection "${show_id} — ${date}"
hline
tsection "SHOW"
hline
trow "Date" "$date" "show.date"
trow "Venue" "$venue_label" "venue.id"
trow "Status" "$status"
if [ -n "$tour" ]; then trow "Tour" "$tour"; fi
if [ -n "$run" ]; then
  trow "Run" "$run"
elif [ -n "$one_off" ]; then
  trow "One-off" "$one_off"
fi

# ── Print VENUE block ────────────────────────────────────────────
echo ""
hline
tsection "VENUE"
hline

# Registry info
trow "Address" "$v_address"
if [ -n "$v_capacity" ]; then trow "Capacity" "$v_capacity"; fi
if [ -n "$v_contacts" ]; then
  while IFS=$'\t' read -r role person; do
    trow "$role" "$person"
  done <<< "$v_contacts"
fi
if [ -n "$v_notes" ]; then trow "Notes" "$v_notes"; fi

# Capabilities
trow "Hospitality" "$adv_hospitality" "venue.hospitality"
trow "Video" "$(get '.venue.video')" "venue.video"
if [ -n "$adv_merch_cut" ]; then
  trow "Merch Cut" "${adv_merch_cut}%" "venue.merch_cut"
else
  trow "Merch Cut" "" "venue.merch_cut"
fi
trow "Merch Seller" "$adv_merch_seller" "venue.merch_seller"
trow "Merch Tax" "$adv_merch_tax_rate" "venue.merch_tax_rate"
trow "Merch Notes" "$adv_merch_notes" "venue.merch_notes"
trow "Parking" "$adv_parking" "venue.parking"
trow "Showers" "$adv_showers" "venue.showers"
trow "Load" "$adv_load" "venue.load"
trow "Guest Comps" "$adv_guest_comps" "venue.guest_comps"
trow "Labor" "$adv_labor" "venue.labor"
trow "Crew Day" "$adv_crew_day" "venue.crew_day"
trow "Settlement" "$adv_settlement" "venue.settlement"
trow "Ticket Count" "$adv_ticket_count" "venue.ticket_count"

# Wifi
if [ -n "$wifi_lines" ]; then
  while IFS= read -r line; do
    trow "Wifi" "$line" "venue.wifi"
  done <<< "$wifi_lines"
fi

# ── Schedule subsection ──────────────────────────────────────────
has_schedule=false
for v in "$sched_access" "$sched_load_in" "$sched_soundcheck" "$sched_doors" "$sched_headliner_set"; do
  if [ -n "$v" ]; then has_schedule=true; fi
done

if $has_schedule; then
  hline
  tsection "SCHEDULE"
  hline
  trow "Access" "$sched_access" "venue.schedule"
  trow "Load-in" "$sched_load_in" "venue.schedule"
  trow "Soundcheck" "$sched_soundcheck" "venue.schedule"
  trow "Support Check" "$sched_support_check" "venue.schedule"
  trow "Doors" "$sched_doors" "venue.schedule"
  trow "Support Set" "$sched_support_set" "venue.schedule"
  trow "Headliner Set" "$sched_headliner_set" "venue.schedule"
  if [ -n "$sched_set_length" ]; then
    trow "Set Length" "${sched_set_length} min" "venue.schedule"
  else
    trow "Set Length" "" "venue.schedule"
  fi
  trow "Curfew" "$sched_curfew" "venue.schedule"
  trow "Backstage" "$sched_backstage_curfew" "venue.schedule"
fi

# ── DOS Contacts subsection ──────────────────────────────────────
if [ -n "$dos_lines" ]; then
  hline
  tsection "DOS CONTACTS"
  hline
  while IFS=$'\t' read -r name phone; do
    trow "$name" "$phone" "venue.dos_contacts"
  done <<< "$dos_lines"
fi

# ── Hotels subsection ────────────────────────────────────────────
if [ -n "$hotel_lines" ]; then
  hline
  tsection "HOTELS"
  hline
  while IFS= read -r h; do
    trow "" "$h" "venue.hotels"
  done <<< "$hotel_lines"
fi

# ── Print BAND block ────────────────────────────────────────────
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

# ── Tour Production ──────────────────────────────────────────────
TOURS_DIR="${REPO_ROOT}/$(cfg '.entities.tours.dir')"
if [ -n "$tour" ]; then
  tour_json_file="${TOURS_DIR}/${tour}/tour.json"
  if [ -f "$tour_json_file" ]; then
    tour_json=$(jq '.' "$tour_json_file")
    has_tour_data=$(echo "$tour_json" | jq 'has("production") or has("hospitality")')
    if [ "$has_tour_data" = "true" ]; then
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

      tget() { n "$(echo "$tour_json" | jq -r "$1")"; }
      tour_hospitality=$(tget '.hospitality')

      hline
      tsection "BAND: ${tour}"
      hline
      if [ -n "$tour_hospitality" ]; then
        trow_t "Hospitality" "$tour_hospitality" "hospitality"
      fi
      tour_vehicle_type=$(tget '.vehicle_type')
      tour_vehicle_length=$(tget '.vehicle_length')
      veh="$tour_vehicle_type"
      if [ -n "$tour_vehicle_length" ]; then veh="${veh} (${tour_vehicle_length})"; fi
      trow_t "Vehicle" "$veh" "vehicle_type"
      tour_laminates=$(tget '.laminates')
      trow_t "Laminates" "$tour_laminates" "laminates"
      tour_backdrop=$(tget '.backdrop')
      trow_t "Backdrop" "$tour_backdrop" "backdrop"

      has_prod=$(echo "$tour_json" | jq 'has("production")')
      if [ "$has_prod" = "true" ]; then
        prod_stands=$(n "$(echo "$tour_json" | jq -r '.production.stands_venue')")
        prod_front_fills=$(n "$(echo "$tour_json" | jq -r '.production.front_fills')")
        prod_mics_v=$(n "$(echo "$tour_json" | jq -r '.production.mics_venue')")

        hline
        tsection "BACKLINE: Needed"
        hline
        trow_t "Stands" "$prod_stands" "production.stands_venue"
        if [ -n "$prod_front_fills" ]; then
          trow_t "Front Fills" "$prod_front_fills" "production.front_fills"
        fi
        trow_t "Mics" "$prod_mics_v" "production.mics_venue"

        prod_mics_c=$(n "$(echo "$tour_json" | jq -r '.production.mics_carried')")
        prod_foh=$(n "$(echo "$tour_json" | jq -r '.production.foh_console')")
        prod_mon=$(n "$(echo "$tour_json" | jq -r '.production.mon_rack')")
        prod_monitors=$(n "$(echo "$tour_json" | jq -r '.production.monitors')")
        prod_audio=$(n "$(echo "$tour_json" | jq -r '.production.audio_notes')")

        hline
        tsection "BACKLINE: Carried"
        hline
        trow_t "Mics" "$prod_mics_c" "production.mics_carried"
        trow_t "FOH Console" "$prod_foh" "production.foh_console"
        trow_t "Mon Rack" "$prod_mon" "production.mon_rack"
        trow_t "Monitors" "$prod_monitors" "production.monitors"
        trow_t "Audio Notes" "$prod_audio" "production.audio_notes"
      fi
    fi
  fi
fi

# ── Print DEAL block ────────────────────────────────────────────
echo ""
hline
tsection "DEAL"
hline

# Guarantee: show amount, append canada_amount if present
if [ -n "$guarantee" ]; then
  guar_display="\$${guarantee}"
  if [ -n "$canada_amount" ]; then guar_display="${guar_display} (${canada_amount})"; fi
  trow "Guarantee" "$guar_display" "deal.guarantee"
else
  if [ -n "$canada_amount" ]; then
    trow "Guarantee" "— (${canada_amount})" "deal.guarantee"
  else
    trow "Guarantee" "" "deal.guarantee"
  fi
fi

trow "Door Split" "$door_split" "deal.door_split"
trow "Promoter" "$promoter" "deal.promoter"
trow "Ages" "$ages" "deal.ages"
trow "Sell Cap" "$sell_cap" "deal.sell_cap"
trow "Tickets" "$ticket_scaling" "deal.ticket_scaling"
trow "WP" "$wp" "deal.wp"
trow "Support" "$support" "deal.support"
if [ -n "$sets" ]; then trow "Sets" "$sets"; fi

hline

# ── Advance checklist ────────────────────────────────────────────
CLUB_QUESTIONS="${REPO_ROOT}/$(cfg '.advancing.email_questions_club_path')"
FESTIVAL_QUESTIONS="${REPO_ROOT}/$(cfg '.advancing.email_questions_festival_path')"
has_advance=$(echo "$show_json" | jq 'has("advance")')
advance_count=$(echo "$show_json" | jq '.advance | length')
if [ "$advance_count" -le 10 ]; then
  QUESTIONS="$FESTIVAL_QUESTIONS"
else
  QUESTIONS="$CLUB_QUESTIONS"
fi
if [ -f "$QUESTIONS" ]; then
  echo ""
  hline
  tsection "ADVANCE"
  hline
  if [ "$has_advance" = "true" ]; then
    # State machine display: read advance object per question, sorted by status priority
    while IFS= read -r qid; do
      adv_status=$(echo "$show_json" | jq -r --arg q "$qid" '.advance[$q].status // empty')
      if [ -z "$adv_status" ]; then
        adv_status="--"
        adv_detail=""
      else
        # Get last note date and text for source column
        adv_detail=$(echo "$show_json" | jq -r --arg q "$qid" '
          .advance[$q].notes // [] | last //empty |
          "\(.date) \(.text)"' 2>/dev/null)
        if [ "$adv_detail" = "null" ]; then adv_detail=""; fi
      fi
      printf "| %-${W1}s | %-${W2}s | %-${W3}s |\n" \
        "$(trunc "$qid" "$W1")" \
        "$(trunc "$adv_status" "$W2")" \
        "$(trunc "$adv_detail" "$W3")"
    done < <(
      # Merge question IDs from file with advance statuses, sort by status priority
      jq -r --slurpfile qs "$QUESTIONS" '
        def status_order:
          if . == "need_to_ask" then 0
          elif . == "asked" then 1
          elif . == "needs_response" then 2
          elif . == "confirmed" then 3
          else 4 end;
        [ $qs[0][].id as $qid |
          { id: $qid, status: (.advance[$qid].status // "--") }
        ] | sort_by(.status | status_order) | .[].id
      ' <<< "$show_json"
    )
  else
    # Legacy fallback: check if mapped fields have data
    while IFS=$'\t' read -r qid fields; do
      answered="no"
      IFS=',' read -ra flds <<< "$fields"
      for f in ${flds[@]+"${flds[@]}"}; do
        val=$(echo "$show_json" | jq -r --arg f "$f" 'getpath($f | split(".")) // empty')
        if [ -n "$val" ] && [ "$val" != "{}" ] && [ "$val" != "[]" ] && [ "$val" != "null" ]; then
          answered="yes"
          break
        fi
      done
      trow "$qid" "$answered"
    done < <(jq -r '.[] | [.id, (.fields | join(","))] | @tsv' "$QUESTIONS")
  fi
  hline
fi

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
