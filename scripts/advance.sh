#!/usr/bin/env bash
# desc: Show next advancing actions needed across shows
# usage: advance.sh [show-id-or-partial [question]|priority]
# filters: Mode=priority|<show-id>|<show-id>&<question>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
CONTACT_ROLE=$(cfg '.advancing.contact_role')
ORG_PREFIX=$(cfg '.advancing.contact_org_prefix')
PRIORITY_FIELD=$(cfg '.advancing.priority_field')

load_shows

# ── Resolve show from partial ID ──────────────────────────────────
resolve_show() {
  local partial="$1"
  jq -r --arg p "$partial" '
    to_entries | map(select(.key | contains($p))) | .[0].key // empty
  ' "$SHOWS_DATA"
}

# ── Show summary: advance <show> ─────────────────────────────────
show_summary() {
  local match="$1"
  local show_file="${SHOWS_DIR}/${match}/show.json"
  local venue date
  venue=$(jq -r '.venue.id' "$show_file")
  date=$(jq -r '.date' "$show_file")

  echo ""
  echo "  ${match} (${venue}) - ${date}"
  echo "  ────────────────────────────────────"

  local has_advance
  has_advance=$(jq -r 'if .advance and (.advance | length) > 0 then "yes" else "no" end' "$show_file")

  if [ "$has_advance" = "no" ]; then
    echo ""
    echo "  No advance object. Run advancing to populate."
    echo ""
    return
  fi

  echo ""
  printf "  %-4s %-20s %-16s %s\n" "PRI" "QUESTION" "STATUS" "LAST"
  printf "  %-4s %-20s %-16s %s\n" "---" "--------" "------" "----"

  jq -r '
    .advance | to_entries | sort_by(.key) | .[] |
    (.value.priority // "-") as $pri |
    (.value.notes // [] | if length > 0 then last.date else "-" end) as $last |
    [$pri, .key, .value.status, $last] | @tsv
  ' "$show_file" | while IFS=$'\t' read -r pri question status last; do
    printf "  %-4s %-20s %-16s %s\n" "$pri" "$question" "$status" "$last"
  done

  echo ""
  jq -r '
    .advance | length as $total |
    ([to_entries[] | select(.value.status == "confirmed")] | length) as $conf |
    "\($conf)/\($total) confirmed"
  ' "$show_file"
}

# ── Question detail: advance <show> <question> ───────────────────
show_question() {
  local match="$1"
  local question="$2"
  local show_file="${SHOWS_DIR}/${match}/show.json"
  local venue date
  venue=$(jq -r '.venue.id' "$show_file")
  date=$(jq -r '.date' "$show_file")

  local exists
  exists=$(jq -r --arg q "$question" '.advance[$q] // empty' "$show_file")
  if [ -z "$exists" ]; then
    echo "No advance question '${question}' in ${match}" >&2
    echo "Questions: $(jq -r '.advance | keys | join(", ")' "$show_file")" >&2
    exit 1
  fi

  echo ""
  echo "  ${match} (${venue}) - ${date}"
  echo "  ${question}"
  echo "  ────────────────────────────────────"

  jq -r --arg q "$question" '
    .advance[$q] |
    "  status:   \(.status)",
    "  priority: \(.priority // "-")",
    "",
    (
      (.notes // []) | group_by(.source) | .[] |
      "  thread: \(.[0].source)",
      (.[] | "    \(.date)  \(.action)  \(.text)")
    )
  ' "$show_file"

  echo ""
}

# ── Priority view: all priority items across shows ────────────────
show_priority() {
  echo ""
  echo "=== PRIORITY ADVANCE ITEMS ==="
  echo ""
  printf "  %-7s %-24s %-20s %-16s %s\n" "DATE" "VENUE" "QUESTION" "STATUS" "LAST ACTION"
  printf "  %-7s %-24s %-20s %-16s %s\n" "----" "-----" "--------" "------" "-----------"

  while IFS=$'\t' read -r show_id date venue; do
    local show_file="${SHOWS_DIR}/${show_id}/show.json"
    local short_date="${date:5}"

    jq -r --arg venue "$venue" --arg date "$short_date" '
      .advance // {} | to_entries[] | select(.value.priority == "x") |
      (.value.notes | if length > 0 then last | "\(.date) \(.action)" else "-" end) as $last |
      [$date, $venue, .key, .value.status, $last] | @tsv
    ' "$show_file" 2>/dev/null | while IFS=$'\t' read -r d v question status last_action; do
      printf "  %-7s %-24s %-20s %-16s %s\n" "$d" "$v" "$question" "$status" "$last_action"
    done
  done < <(jq -r 'to_entries | sort_by(.value.date) | .[] | [.key, .value.date, .value.venue.id] | @tsv' "$SHOWS_DATA")

  echo ""
}

# ── Route by argument ─────────────────────────────────────────────
if [ $# -gt 0 ]; then
  case "$1" in
    priority)
      show_priority
      exit 0
      ;;
    *)
      match=$(resolve_show "$1")
      if [ -z "$match" ]; then
        echo "No show matching: $1" >&2
        exit 1
      fi
      if [ $# -ge 2 ]; then
        show_question "$match" "$2"
      else
        show_summary "$match"
      fi
      exit 0
      ;;
  esac
fi

# ── Default: overview ─────────────────────────────────────────────
needs_outreach=""
in_progress=""
confirmed=""

needs_count=0
progress_count=0
confirmed_count=0

while IFS=$'\t' read -r show_id date venue; do
  short_date="${date:5}"

  read -r total num_confirmed num_asked num_needs_response num_need_to_ask < <(
    jq -r '
      if .advance == null or (.advance | length) == 0 then
        "0 0 0 0 0"
      else
        (.advance | length) as $total |
        (.advance | [to_entries[] | select(.value.status == "confirmed")] | length) as $conf |
        (.advance | [to_entries[] | select(.value.status == "asked")] | length) as $asked |
        (.advance | [to_entries[] | select(.value.status == "needs_response")] | length) as $nr |
        (.advance | [to_entries[] | select(.value.status == "need_to_ask")] | length) as $nta |
        "\($total) \($conf) \($asked) \($nr) \($nta)"
      end
    ' "${SHOWS_DIR}/${show_id}/show.json"
  )

  if [ "$total" -eq 0 ]; then
    contact_info=$(jq -r --arg venue "$venue" --arg role "$CONTACT_ROLE" --arg prefix "$ORG_PREFIX" --arg pfield "$PRIORITY_FIELD" '
      ($prefix + ":" + $venue) as $org_ref |
      to_entries
      | map(select(
          .value.role == $role
          and .value.org != null
          and (.value.org | index($org_ref))
        ))
      | sort_by(.value[$pfield])
      | first
      | [.value.name, .value.contact.email]
      | @tsv
    ' "$PEOPLE" 2>/dev/null || echo "	")

    name=$(printf '%s' "$contact_info" | cut -f1)
    email=$(printf '%s' "$contact_info" | cut -f2)

    needs_outreach="${needs_outreach}${short_date}\t${venue}\t${name:-NONE}\t${email:--}\n"
    needs_count=$((needs_count + 1))
  elif [ "$num_confirmed" -eq "$total" ]; then
    confirmed="${confirmed}${short_date}\t${venue}\t${num_confirmed}/${total}\n"
    confirmed_count=$((confirmed_count + 1))
  else
    parts=""
    if [ "$num_confirmed" -gt 0 ]; then
      parts="${num_confirmed} confirmed"
    fi
    if [ "$num_asked" -gt 0 ]; then
      if [ -n "$parts" ]; then parts="${parts}, "; fi
      parts="${parts}${num_asked} asked"
    fi
    if [ "$num_needs_response" -gt 0 ]; then
      if [ -n "$parts" ]; then parts="${parts}, "; fi
      parts="${parts}${num_needs_response} needs response"
    fi
    if [ "$num_need_to_ask" -gt 0 ]; then
      if [ -n "$parts" ]; then parts="${parts}, "; fi
      parts="${parts}${num_need_to_ask} need to ask"
    fi

    in_progress="${in_progress}${short_date}\t${venue}\t${num_confirmed}/${total}\t${parts}\n"
    progress_count=$((progress_count + 1))
  fi
done < <(jq -r 'to_entries | sort_by(.value.date) | .[] | [.key, .value.date, .value.venue.id] | @tsv' "$SHOWS_DATA")

if [ "$needs_count" -gt 0 ]; then
  echo "=== NEEDS OUTREACH (${needs_count}) ==="
  printf '%b' "$needs_outreach" | while IFS=$'\t' read -r date venue name email; do
    printf "  %-7s %-24s %-26s %s\n" "$date" "$venue" "$name" "$email"
  done
  echo ""
fi

if [ "$progress_count" -gt 0 ]; then
  echo "=== IN PROGRESS (${progress_count}) ==="
  printf '%b' "$in_progress" | while IFS=$'\t' read -r date venue progress detail; do
    printf "  %-7s %-24s %-7s %s\n" "$date" "$venue" "$progress" "$detail"
  done
  echo ""
fi

if [ "$confirmed_count" -gt 0 ]; then
  echo "=== CONFIRMED (${confirmed_count}) ==="
  printf '%b' "$confirmed" | while IFS=$'\t' read -r date venue progress; do
    printf "  %-7s %-24s %s\n" "$date" "$venue" "$progress"
  done
  echo ""
fi

total=$((needs_count + progress_count + confirmed_count))
echo "Summary: ${needs_count} need outreach | ${progress_count} in progress | ${confirmed_count} confirmed | ${total} total"
