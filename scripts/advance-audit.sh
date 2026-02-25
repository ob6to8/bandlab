#!/usr/bin/env bash
# desc: Audit advance objects for consistency and completeness
# usage: advance-audit.sh [days]
# filters: Arg=days (default 14, upcoming show window)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
CLUB_QUESTIONS="${REPO_ROOT}/$(cfg '.advancing.email_questions_club_path')"
FESTIVAL_QUESTIONS="${REPO_ROOT}/$(cfg '.advancing.email_questions_festival_path')"

load_shows

WINDOW_DAYS="${1:-14}"

# Today as epoch seconds (macOS date)
TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$TODAY" "+%s")
WINDOW_EPOCH=$((TODAY_EPOCH + WINDOW_DAYS * 86400))

# Used by pass/warn/fail in config.sh
# shellcheck disable=SC2034
errors=0
# shellcheck disable=SC2034
warnings=0
# shellcheck disable=SC2034
checks=0

mismatch_count=0
upcoming_unresolved=0
audited_count=0

echo ""
echo "=== Advance Audit ==="

# ── Check 1: State vs Field Consistency ──────────────────────────────
echo ""
echo "--- State vs Field Consistency ---"

while IFS=$'\t' read -r show_id _date _venue; do
  show_file="${SHOWS_DIR}/${show_id}/show.json"

  has_advance=$(jq -r 'if .advance and (.advance | length) > 0 then "yes" else "no" end' "$show_file")
  if [ "$has_advance" = "no" ]; then
    continue
  fi

  audited_count=$((audited_count + 1))

  # Determine which questions file based on advance object size
  advance_count=$(jq -r '.advance | length' "$show_file")
  if [ "$advance_count" -le 10 ]; then
    questions_file="$FESTIVAL_QUESTIONS"
  else
    questions_file="$CLUB_QUESTIONS"
  fi

  show_mismatches=0
  show_warnings=0

  # Forward check: confirmed questions should have populated venue fields
  while IFS=$'\t' read -r qid status; do
    # Get mapped fields for this question from the questions file
    fields=$(jq -r --arg qid "$qid" '.[] | select(.id == $qid) | .fields // [] | .[]' "$questions_file" 2>/dev/null)

    if [ -z "$fields" ]; then
      continue
    fi

    while read -r field; do
      # Read the field value from show.json using dot notation
      val=$(jq -r --arg f "$field" 'getpath($f | split("."))' "$show_file")

      if [ "$status" = "confirmed" ]; then
        if [ "$val" = "null" ] || [ "$val" = "" ] || [ "$val" = "{}" ] || [ "$val" = "[]" ]; then
          warn "${show_id}: ${qid} confirmed but ${field} empty"
          show_mismatches=$((show_mismatches + 1))
        fi
      fi

      if [ "$status" = "need_to_ask" ] || [ -z "$status" ]; then
        if [ "$val" != "null" ] && [ "$val" != "" ] && [ "$val" != "{}" ] && [ "$val" != "[]" ]; then
          warn "${show_id}: ${field} populated but ${qid} is ${status:-absent}"
          show_warnings=$((show_warnings + 1))
        fi
      fi
    done <<< "$fields"
  done < <(jq -r '.advance | to_entries[] | [.key, .value.status] | @tsv' "$show_file")

  total_mismatches=$((show_mismatches + show_warnings))
  if [ "$total_mismatches" -eq 0 ]; then
    pass "${show_id}: ${advance_count} questions, 0 mismatches"
  fi

  mismatch_count=$((mismatch_count + total_mismatches))
done < <(jq -r 'to_entries | sort_by(.value.show.date) | .[] | [.key, .value.show.date, .value.venue.id] | @tsv' "$SHOWS_DATA")

echo ""

# ── Check 2: Upcoming Shows Completeness ─────────────────────────────
echo "--- Upcoming Shows (next ${WINDOW_DAYS} days) ---"

found_upcoming=0

while IFS=$'\t' read -r show_id show_date _venue_id; do
  show_epoch=$(date -j -f "%Y-%m-%d" "$show_date" "+%s" 2>/dev/null || echo 0)

  if [ "$show_epoch" -lt "$TODAY_EPOCH" ] || [ "$show_epoch" -gt "$WINDOW_EPOCH" ]; then
    continue
  fi

  found_upcoming=1

  # Format date for display (Mon DD)
  display_date=$(date -j -f "%Y-%m-%d" "$show_date" "+%b %-d" 2>/dev/null || echo "$show_date")

  show_file="${SHOWS_DIR}/${show_id}/show.json"
  has_advance=$(jq -r 'if .advance and (.advance | length) > 0 then "yes" else "no" end' "$show_file")

  if [ "$has_advance" = "no" ]; then
    echo "  ${show_id} (${display_date}) - NOT ADVANCING"
    echo ""
    continue
  fi

  # Count unresolved questions
  unresolved=$(jq -r '[.advance | to_entries[] | select(.value.status != "confirmed")] | length' "$show_file")

  if [ "$unresolved" -eq 0 ]; then
    total=$(jq -r '.advance | length' "$show_file")
    echo "  ${show_id} (${display_date}) - ${total}/${total} confirmed"
    echo ""
    continue
  fi

  upcoming_unresolved=$((upcoming_unresolved + unresolved))

  echo "  ${show_id} (${display_date}) - ${unresolved} unresolved"

  # List unresolved questions, priority first, then by status severity
  jq -r '
    {"need_to_ask":0,"needs_response":1,"asked":2} as $order |
    .advance | to_entries
    | map(select(.value.status != "confirmed"))
    | sort_by(
        (if .value.priority == "x" then 0 else 1 end),
        $order[.value.status],
        .key
      )
    | .[]
    | (if .value.priority == "x" then "[x]" else "   " end) as $pri |
    "    \($pri) \(.key | . + " " * (20 - length)) \(.value.status)"
  ' "$show_file"

  echo ""
done < <(jq -r 'to_entries | sort_by(.value.show.date) | .[] | [.key, .value.show.date, .value.venue.id] | @tsv' "$SHOWS_DATA")

if [ "$found_upcoming" -eq 0 ]; then
  echo "  No shows in the next ${WINDOW_DAYS} days."
  echo ""
fi

# ── Summary ──────────────────────────────────────────────────────────
echo "=== Summary ==="
echo "  ${audited_count} shows audited | ${mismatch_count} mismatches | ${upcoming_unresolved} upcoming unresolved"

if [ "$mismatch_count" -gt 0 ]; then
  exit 1
fi
