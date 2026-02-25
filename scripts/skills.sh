#!/usr/bin/env bash
# desc: List agent-only skills (use as /name in Claude Code)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SKILLS_DIR="${REPO_ROOT}/$(cfg '.documentation.skills_dir')"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "No skills directory found." >&2
  exit 0
fi

echo ""
echo "  skills (use as /name in Claude Code)"
echo "  ─────────────────────────────────────"
echo ""

count=0
for skill_dir in "${SKILLS_DIR}"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_md="${skill_dir}SKILL.md"
  [ -f "$skill_md" ] || continue
  name=$(basename "$skill_dir")
  desc=$(head -1 "$skill_md")
  printf "  /%-23s %s\n" "$name" "$desc"
  count=$((count + 1))
done

echo ""
echo "${count} skills"
