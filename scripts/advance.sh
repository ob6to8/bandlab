#!/usr/bin/env bash
# desc: Show next advancing actions needed across shows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
CONTACT_ROLE=$(cfg '.advancing.contact_role')
ORG_PREFIX=$(cfg '.advancing.contact_org_prefix')
PRIORITY_FIELD=$(cfg '.advancing.priority_field')

load_shows

# ── Classify each show by advance object in show.json ─────────────
needs_outreach=""
in_progress=""
confirmed=""

needs_count=0
progress_count=0
confirmed_count=0

while IFS=$'\t' read -r show_id date venue; do
  short_date="${date:5}"

  # Read advance object stats from show.json
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
    # No advance object - needs outreach. Find top contact.
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
    # Build status summary
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

# ── Print grouped output ──────────────────────────────────────────
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
