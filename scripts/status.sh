#!/usr/bin/env bash
# desc: Surface actionable items across the org
# usage: status.sh [advances|hotels|flights|merch|production|org]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config
load_shows

TODOS="${REPO_ROOT}/$(cfg '.registries.todos.path')"
TODAY=$(date +%Y-%m-%d)

# macOS date arithmetic: add N days to today
date_add_days() {
  local days="$1"
  date -v+"${days}d" +%Y-%m-%d 2>/dev/null || date -d "+${days} days" +%Y-%m-%d
}

HOTEL_WINDOW=$(date_add_days 14)
FLIGHT_WINDOW=$(date_add_days 30)

STRIP_PREFIX=$(cfg_default '.display.show_id_strip_prefix' 's-')

# ── Filter parsing ───────────────────────────────────────────────
FILTER="${1:-all}"

case "$FILTER" in
  all|advances|hotels|flights|merch|production|org) ;;
  *)
    echo "Usage: status [advances|hotels|flights|merch|production|org]" >&2
    echo "  No filter shows everything." >&2
    exit 1
    ;;
esac

# ── Helpers ──────────────────────────────────────────────────────

# Section header: section_header "ADVANCES" count
section_header() {
  local title="$1" count="$2"
  local label="items"
  if [ "$count" -eq 1 ]; then label="item"; fi
  echo "${title} (${count} ${label})"
}

# ── ADVANCES ─────────────────────────────────────────────────────

print_advances() {
  local lines=()

  while IFS=$'\t' read -r show_id date status; do
    # Skip past shows
    [[ "$date" > "$TODAY" || "$date" == "$TODAY" ]] || continue

    local display_id="${show_id#"$STRIP_PREFIX"}"
    # Check advance is present AND an object (many shows have "advance": null)
    local advance_type
    advance_type=$(jq -r --arg id "$show_id" '.[$id].advance | type' "$SHOWS_DATA")

    if [ "$advance_type" != "object" ]; then
      # No real advance block = not started
      if [ "$status" = "confirmed" ] || [ "$status" = "offered" ]; then
        lines+=("$(printf "  %-24s %-20s %s" "$display_id" "not started" "--")")
      fi
      continue
    fi

    # Has advance block - check for actionable statuses
    local needs_response needs_ask
    needs_response=$(jq -r --arg id "$show_id" '
      .[$id].advance | to_entries
      | map(select(.value.status? == "needs_response"))
      | map(.key) | join(", ")
    ' "$SHOWS_DATA")

    needs_ask=$(jq -r --arg id "$show_id" '
      .[$id].advance | to_entries
      | map(select(.value.status? == "need_to_ask"))
      | map(.key) | join(", ")
    ' "$SHOWS_DATA")

    if [ -n "$needs_response" ]; then
      lines+=("$(printf "  %-24s %-20s %s" "$display_id" "need to respond" "$needs_response")")
    fi
    if [ -n "$needs_ask" ]; then
      lines+=("$(printf "  %-24s %-20s %s" "$display_id" "need to ask" "$needs_ask")")
    fi
  done < <(jq -r '
    to_entries | sort_by(.value.day.date) | .[]
    | [.key, .value.day.date, .value.day.status] | @tsv
  ' "$SHOWS_DATA")

  if [ "$FILTER" = "all" ]; then
    section_header "ADVANCES" "${#lines[@]}"
  fi
  if [ "${#lines[@]}" -eq 0 ]; then
    echo "  all clear"
  else
    printf '%s\n' "${lines[@]}"
  fi
}

# ── HOTELS ───────────────────────────────────────────────────────

print_hotels() {
  local lines=()

  while IFS=$'\t' read -r show_id date lodging_status lodging_name; do
    # Future shows within window only
    [[ "$date" > "$TODAY" || "$date" == "$TODAY" ]] || continue
    [[ "$date" < "$HOTEL_WINDOW" || "$date" == "$HOTEL_WINDOW" ]] || continue

    local display_id="${show_id#"$STRIP_PREFIX"}"
    local short_date="${date:5}"  # MM-DD

    if [ "$lodging_status" = "needed" ]; then
      lines+=("$(printf "  %-24s %s  %-10s %s" "$display_id" "$short_date" "$lodging_status" "no lodging booked")")
    elif [ "$lodging_status" = "booked" ] || [ "$lodging_status" = "provided" ]; then
      local detail="${lodging_name:-$lodging_status}"
      lines+=("$(printf "  %-24s %s  %-10s %s" "$display_id" "$short_date" "$lodging_status" "$detail")")
    fi
  done < <(jq -r '
    to_entries | sort_by(.value.day.date) | .[]
    | select(.value.travel != null and .value.travel.lodging != null)
    | [.key, .value.day.date, .value.travel.lodging.status, (.value.travel.lodging.name // "")] | @tsv
  ' "$SHOWS_DATA")

  if [ "$FILTER" = "all" ]; then
    section_header "HOTELS" "${#lines[@]}"
  fi
  if [ "${#lines[@]}" -eq 0 ]; then
    echo "  all clear"
  else
    printf '%s\n' "${lines[@]}"
  fi
}

# ── FLIGHTS ──────────────────────────────────────────────────────

print_flights() {
  local lines=()

  while IFS=$'\t' read -r show_id date fl_status fl_passenger fl_direction; do
    [[ "$date" > "$TODAY" || "$date" == "$TODAY" ]] || continue
    [[ "$date" < "$FLIGHT_WINDOW" || "$date" == "$FLIGHT_WINDOW" ]] || continue

    local display_id="${show_id#"$STRIP_PREFIX"}"
    local short_date="${date:5}"

    if [ "$fl_status" = "needed" ]; then
      local detail="${fl_passenger:-?} ${fl_direction:-?}"
      lines+=("$(printf "  %-24s %s  %-10s %s" "$display_id" "$short_date" "needed" "$detail")")
    fi
  done < <(jq -r '
    to_entries | sort_by(.value.day.date) | .[]
    | select(.value.travel != null and .value.travel.flights != null)
    | .key as $id | .value.day.date as $date
    | .value.travel.flights[]
    | [$id, $date, .status, (.passenger // ""), (.direction // "")] | @tsv
  ' "$SHOWS_DATA")

  if [ "$FILTER" = "all" ]; then
    section_header "FLIGHTS" "${#lines[@]}"
  fi
  if [ "${#lines[@]}" -eq 0 ]; then
    echo "  all clear"
  else
    printf '%s\n' "${lines[@]}"
  fi
}

# ── Todo-based sections ──────────────────────────────────────────

print_todos() {
  local header="$1" jq_filter="$2"

  if [ ! -f "$TODOS" ]; then
    if [ "$FILTER" = "all" ]; then
      section_header "$header" 0
    fi
    echo "  all clear"
    return
  fi

  local lines=()
  while IFS=$'\t' read -r id status task; do
    [ -n "$id" ] || continue
    lines+=("$(printf "  %-6s [%-11s]  %s" "$id" "$status" "$task")")
  done < <(jq -r "[.[] | select(.status != \"done\" and .status != \"cancelled\") | select(${jq_filter}) | del(.history)] | sort_by(.priority // \"z\") | .[] | [.id, .status, .task] | @tsv" "$TODOS" 2>/dev/null || true)

  if [ "$FILTER" = "all" ]; then
    section_header "$header" "${#lines[@]}"
  fi
  if [ "${#lines[@]}" -eq 0 ]; then
    echo "  all clear"
  else
    printf '%s\n' "${lines[@]}"
  fi
}

# ── Output ───────────────────────────────────────────────────────

if [ "$FILTER" = "all" ] || [ "$FILTER" = "advances" ]; then
  print_advances
  [ "$FILTER" = "all" ] && echo ""
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "hotels" ]; then
  print_hotels
  [ "$FILTER" = "all" ] && echo ""
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "flights" ]; then
  print_flights
  [ "$FILTER" = "all" ] && echo ""
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "merch" ]; then
  print_todos "MERCH" '.domain == "merch" or .category == "merch"'
  [ "$FILTER" = "all" ] && echo ""
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "production" ]; then
  print_todos "PRODUCTION" '.domain == "production" or .category == "production" or .category == "set" or .priority == "x"'
  [ "$FILTER" = "all" ] && echo ""
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "org" ]; then
  print_todos "ORG" '(.domain != "merch" and .domain != "production") and (.category != "merch" and .category != "production" and .category != "set") and (.priority != "x")'
fi
