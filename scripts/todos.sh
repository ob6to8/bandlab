#!/usr/bin/env bash
# desc: List todos with optional filters
# usage: todos.sh [filter...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

TODOS="${REPO_ROOT}/$(cfg '.registries.todos.path')"

if [ ! -f "$TODOS" ]; then
  echo "Missing ${TODOS}" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)

# ── Load filter vocabularies from config ──────────────────────────
# Owner aliases: {"evan": "evan-fraser", "mark": "mark-reveley", ...}
# Domains: ["touring", "admin", ...]
# Categories: ["advancing", "settlement", ...]

owner_aliases=$(cfg '.owner_aliases // {}')
domains=$(cfg '.todo_filters.domains // []')
categories=$(cfg '.todo_filters.categories // []')

# Build help string dynamically
alias_names=$(echo "$owner_aliases" | jq -r 'keys | join("|")')
domain_names=$(echo "$domains" | jq -r 'join("|")')
category_names=$(echo "$categories" | jq -r 'join("|")')

# ── Parse filters ──────────────────────────────────────────────────
# Default: status != "done"
jq_filters=()
status_filter='select(.status != "done")'

for arg in "$@"; do
  # Check status filters
  case "$arg" in
    open|in-progress|blocked|done)
      status_filter="select(.status == \"${arg}\")"
      continue
      ;;
    all)
      status_filter=""
      continue
      ;;
    s-*)
      jq_filters+=("select(.show == \"${arg}\")")
      continue
      ;;
    priority)
      jq_filters+=("select(.priority == \"x\")")
      continue
      ;;
    overdue)
      jq_filters+=("select(.due != null and .due < \"${TODAY}\")")
      continue
      ;;
    upcoming)
      upcoming_end=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d)
      jq_filters+=("select(.due != null and .due >= \"${TODAY}\" and .due <= \"${upcoming_end}\")")
      continue
      ;;
  esac

  # Check owner aliases from config
  owner_key=$(echo "$owner_aliases" | jq -r --arg a "$arg" '.[$a] // empty')
  if [ -n "$owner_key" ]; then
    jq_filters+=("select(.owners | index(\"${owner_key}\"))")
    continue
  fi

  # Check domain filters from config
  if echo "$domains" | jq -e --arg a "$arg" 'index($a) != null' > /dev/null 2>&1; then
    jq_filters+=("select(.domain == \"${arg}\")")
    continue
  fi

  # Check category filters from config
  if echo "$categories" | jq -e --arg a "$arg" 'index($a) != null' > /dev/null 2>&1; then
    jq_filters+=("select(.category == \"${arg}\")")
    continue
  fi

  echo "Unknown filter: ${arg}" >&2
  echo "Filters: open|in-progress|blocked|done|all|priority|${alias_names}|${domain_names}|${category_names}|s-YYYY-MMDD-city|overdue|upcoming" >&2
  exit 1
done

# ── Build jq pipeline ─────────────────────────────────────────────
jq_expr=".[] | del(.history)"
if [ -n "$status_filter" ]; then
  jq_expr="${jq_expr} | ${status_filter}"
fi
for f in "${jq_filters[@]+"${jq_filters[@]}"}"; do
  [ -n "$f" ] && jq_expr="${jq_expr} | ${f}"
done

# ── Run query and format ──────────────────────────────────────────
total=$(jq 'length' "$TODOS")

results=$(jq -r "[${jq_expr}] | sort_by(.due // \"9999-99-99\") | .[] | [.id, (.priority // \"-\"), .task, .status, .category, (.owners | join(\", \")), (.due // \"-\"), (.show // \"-\")] | @tsv" "$TODOS")

if [ -z "$results" ]; then
  echo "No matching todos."
  echo ""
  echo "0 todos (of ${total} total)"
  exit 0
fi

printf "%-6s %-4s %-40s %-13s %-12s %-20s %-12s %s\n" "ID" "PRI" "TASK" "STATUS" "CATEGORY" "OWNERS" "DUE" "SHOW"
printf "%-6s %-4s %-40s %-13s %-12s %-20s %-12s %s\n" "----" "---" "----" "------" "--------" "------" "---" "----"

count=0
while IFS=$'\t' read -r id pri task status category owners due show; do
  # Truncate long task names
  if [ ${#task} -gt 38 ]; then
    task="${task:0:35}..."
  fi
  printf "%-6s %-4s %-40s %-13s %-12s %-20s %-12s %s\n" "$id" "$pri" "$task" "$status" "$category" "$owners" "$due" "$show"
  count=$((count + 1))
done <<< "$results"

echo ""
echo "${count} todos (of ${total} total)"
