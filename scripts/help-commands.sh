#!/usr/bin/env bash
# desc: List all available dirtclaw commands
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPTS_DIR="${REPO_ROOT}/bandlab/scripts"

echo ""
echo "  dirtclaw — available commands"
echo "  ─────────────────────────────────"
echo ""

for script in "${SCRIPTS_DIR}"/*.sh; do
  [ -f "$script" ] || continue
  name=$(basename "$script" .sh)
  cmd="${name/-/:}"
  desc=$(grep '^# desc:' "$script" | head -1 | sed 's/^# desc: *//')
  usage=$(grep '^# usage:' "$script" 2>/dev/null | head -1 | sed 's/^# usage: *//' || true)
  if [ -n "$usage" ]; then
    # Replace script filename with command name in usage string
    usage_display="${usage/${name}.sh/$cmd}"
    printf "  %-24s %s\n" "$cmd" "$desc"
    printf "  %-24s usage: %s\n" "" "$usage_display"
  else
    printf "  %-24s %s\n" "$cmd" "$desc"
  fi
done

echo ""
echo "Run: ./dirtclaw <command> [args]"
