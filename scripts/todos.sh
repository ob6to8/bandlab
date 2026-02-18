#!/usr/bin/env bash
# desc: List todos with optional filters
# usage: todos.sh [filter...]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TODOS="${REPO_ROOT}/org/todos.json"

if [ ! -f "$TODOS" ]; then
  echo "Missing ${TODOS}" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)

# ── Parse filters ──────────────────────────────────────────────────
# Default: status != "done"
jq_filters=()
status_filter='select(.status != "done")'

for arg in "$@"; do
  case "$arg" in
    # Status filters
    open|in-progress|blocked|done)
      status_filter="select(.status == \"${arg}\")"
      ;;
    all)
      status_filter=""
      ;;
    # Owner filters (partial match)
    evan)
      jq_filters+=('select(.owners | index("evan-fraser"))')
      ;;
    mark)
      jq_filters+=('select(.owners | index("mark-reveley"))')
      ;;
    david)
      jq_filters+=('select(.owners | index("david-sartore"))')
      ;;
    # Domain filters
    touring|admin|merch|licensing)
      jq_filters+=("select(.domain == \"${arg}\")")
      ;;
    # Category filters
    advancing|settlement|production|show-documentation)
      jq_filters+=("select(.category == \"${arg}\")")
      ;;
    # Show ID
    s-*)
      jq_filters+=("select(.show == \"${arg}\")")
      ;;
    # Date filters
    overdue)
      jq_filters+=("select(.due != null and .due < \"${TODAY}\")")
      ;;
    upcoming)
      upcoming_end=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d)
      jq_filters+=("select(.due != null and .due >= \"${TODAY}\" and .due <= \"${upcoming_end}\")")
      ;;
    *)
      echo "Unknown filter: ${arg}" >&2
      echo "Filters: open|in-progress|blocked|done|all|evan|mark|david|touring|admin|merch|licensing|advancing|settlement|production|show-documentation|s-YYYY-MMDD-city|overdue|upcoming" >&2
      exit 1
      ;;
  esac
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

results=$(jq -r "[${jq_expr}] | sort_by(.due // \"9999-99-99\") | .[] | [.id, .task, .status, (.owners | join(\", \")), (.due // \"-\"), (.show // \"-\")] | @tsv" "$TODOS")

if [ -z "$results" ]; then
  echo "No matching todos."
  echo ""
  echo "0 todos (of ${total} total)"
  exit 0
fi

printf "%-6s %-40s %-13s %-20s %-12s %s\n" "ID" "TASK" "STATUS" "OWNERS" "DUE" "SHOW"
printf "%-6s %-40s %-13s %-20s %-12s %s\n" "----" "----" "------" "------" "---" "----"

count=0
while IFS=$'\t' read -r id task status owners due show; do
  # Truncate long task names
  if [ ${#task} -gt 38 ]; then
    task="${task:0:35}..."
  fi
  printf "%-6s %-40s %-13s %-20s %-12s %s\n" "$id" "$task" "$status" "$owners" "$due" "$show"
  count=$((count + 1))
done <<< "$results"

echo ""
echo "${count} todos (of ${total} total)"
