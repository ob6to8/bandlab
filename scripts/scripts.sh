#!/usr/bin/env bash
# desc: Show usage and available filters for commands
# usage: scripts.sh [command]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# grep that returns "" instead of failing under set -e
safe_grep() {
  grep "$@" || true
}

show_command_help() {
  local script="$1"
  local name
  name=$(basename "$script" .sh)
  local desc usage filters

  desc=$(safe_grep '^# desc:' "$script" | head -1 | sed 's/^# desc: *//')
  usage=$(safe_grep '^# usage:' "$script" | head -1 | sed 's/^# usage: *//')
  filters=$(safe_grep '^# filters:' "$script" | head -1 | sed 's/^# filters: *//')

  echo ""
  echo "  ${name} - ${desc}"
  echo ""

  if [ -n "$usage" ]; then
    local cli_usage
    cli_usage="${usage/${name}.sh/bandlab-cli ${name}}"
    echo "  Usage: ./${cli_usage}"
    echo ""
  fi

  if [ -n "$filters" ]; then
    echo "  Filters:"
    for group in $filters; do
      local label values
      label=$(echo "$group" | cut -d= -f1)
      values=$(echo "$group" | cut -d= -f2 | tr '|' '  ')
      printf "    %-12s %s\n" "${label}:" "$values"
    done
    echo ""
  fi
}

# ── Single command ────────────────────────────────────────────────
if [ $# -gt 0 ]; then
  cmd="$1"
  script_path="${SCRIPT_DIR}/${cmd}.sh"

  if [ ! -f "$script_path" ]; then
    echo "Unknown command: ${cmd}" >&2
    echo "Run: ./bandlab-cli scripts" >&2
    exit 1
  fi

  show_command_help "$script_path"
  exit 0
fi

# ── All commands ──────────────────────────────────────────────────
echo ""
echo "  bandlab - available commands"
echo "  ────────────────────────────"

for script in "${SCRIPT_DIR}"/*.sh; do
  [ -f "$script" ] || continue
  name=$(basename "$script" .sh)
  [ "$name" = "scripts" ] && continue

  desc=$(safe_grep '^# desc:' "$script" | head -1 | sed 's/^# desc: *//')
  usage=$(safe_grep '^# usage:' "$script" | head -1 | sed 's/^# usage: *//')
  filters=$(safe_grep '^# filters:' "$script" | head -1 | sed 's/^# filters: *//')

  printf "\n  %-24s %s\n" "$name" "$desc"

  if [ -n "$filters" ]; then
    echo "                           run: ./bandlab-cli scripts ${name}"
  elif [ -n "$usage" ]; then
    local_usage="${usage/${name}.sh/bandlab-cli ${name}}"
    echo "                           ./${local_usage}"
  fi
done

echo ""
