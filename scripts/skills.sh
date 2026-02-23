#!/usr/bin/env bash
# desc: List all available commands and skills
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SCRIPTS_DIR="${REPO_ROOT}/$(cfg '.documentation.scripts_dir')"
SKILLS_DIR="${REPO_ROOT}/$(cfg '.documentation.skills_dir')"

echo ""
echo "  bandlab — available commands"
echo "  ─────────────────────────────────"
echo ""

for script in "${SCRIPTS_DIR}"/*.sh; do
  [ -f "$script" ] || continue
  name=$(basename "$script" .sh)
  desc=$(grep '^# desc:' "$script" | head -1 | sed 's/^# desc: *//')
  usage=$(grep '^# usage:' "$script" 2>/dev/null | head -1 | sed 's/^# usage: *//' || true)
  if [ -n "$usage" ]; then
    printf "  %-24s %s\n" "$name" "$desc"
    printf "  %-24s usage: %s\n" "" "$usage"
  else
    printf "  %-24s %s\n" "$name" "$desc"
  fi
done

echo ""
echo "Run: ./bandlab-cli <command> [args]"

# ── Skills ────────────────────────────────────────────────────────────
# If skills dir exists, list available skills

if [ -d "$SKILLS_DIR" ]; then
  echo ""
  echo "  skills (use as /name in Claude Code)"
  echo "  ─────────────────────────────────────────────"
  echo ""

  for skill_dir in "${SKILLS_DIR}"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_md="${skill_dir}SKILL.md"
    [ -f "$skill_md" ] || continue
    name=$(basename "$skill_dir")
    # First line of SKILL.md is the description
    desc=$(head -1 "$skill_md")
    printf "  /%-23s %s\n" "$name" "$desc"
  done

  echo ""
fi
