#!/usr/bin/env bash
# desc: Verify docs, skills, and index are in sync with reality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
INDEX="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"
SKILLS_DIR="${REPO_ROOT}/$(cfg '.documentation.skills_dir')"
CLAUDE_MD="${REPO_ROOT}/$(cfg '.documentation.claude_md')"
OPS_DIR="${REPO_ROOT}/$(cfg '.documentation.ops_dir')"

errors=0
warnings=0
checks=0

# ── Skills sync ──────────────────────────────────────────────────────

echo "=== Skills Sync ==="

# Every skill dir should appear in CLAUDE.md skills table
while read -r skill_dir; do
  skill_name="$(basename "$skill_dir")"
  if grep -q "| \`/${skill_name}\`" "$CLAUDE_MD"; then
    pass "${skill_name}: in skills table"
  else
    fail "${skill_name}: skill dir exists but NOT in CLAUDE.md skills table"
  fi
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

# Every skill in CLAUDE.md table should have a skill dir
# shellcheck disable=SC2016
while read -r skill_name; do
  if [ -d "${SKILLS_DIR}/${skill_name}" ]; then
    pass "${skill_name}: skill dir exists"
  else
    fail "${skill_name}: in CLAUDE.md skills table but NO skill dir"
  fi
done < <(sed -n 's/.*| `\/\([^`]*\)`.*/\1/p' "$CLAUDE_MD" | sort)
echo ""

# ── Ops sync ─────────────────────────────────────────────────────────

echo "=== Ops Sync ==="

# Every .md file in ops/ should appear in CLAUDE.md ops table
while read -r ops_file; do
  filename="$(basename "$ops_file")"
  if grep -q "ops/${filename}" "$CLAUDE_MD"; then
    pass "${filename}: in ops table"
  else
    fail "${filename}: exists in ops/ but NOT in CLAUDE.md ops table"
  fi
done < <(find "$OPS_DIR" -maxdepth 1 -name '*.md' -type f | sort)

# Every ops file in CLAUDE.md table should exist on disk
# shellcheck disable=SC2016
while read -r ops_path; do
  if [ -f "${REPO_ROOT}/${ops_path}" ]; then
    pass "${ops_path}: file exists"
  else
    fail "${ops_path}: in CLAUDE.md ops table but file MISSING"
  fi
done < <(sed -n 's/.*| `\(ops\/[^`]*\.md\)`.*/\1/p' "$CLAUDE_MD" | sort)
echo ""

# ── Shows index freshness ───────────────────────────────────────────

echo "=== Shows Index Freshness ==="

# Count show dirs vs index entries
dir_count=0
for d in "${SHOWS_DIR}"/s-*/; do
  [ -d "$d" ] && dir_count=$((dir_count + 1))
done

index_count=$(jq 'keys | length' "$INDEX")

if [ "$dir_count" -eq "$index_count" ]; then
  pass "show dirs (${dir_count}) match index entries (${index_count})"
else
  fail "show dirs (${dir_count}) != index entries (${index_count}) — run build-index"
fi

# Compare newest show.json mtime vs index mtime
newest_show=0
while read -r show_file; do
  mtime=$(stat -f '%m' "$show_file" 2>/dev/null || stat -c '%Y' "$show_file" 2>/dev/null)
  if [ "$mtime" -gt "$newest_show" ]; then
    newest_show=$mtime
  fi
done < <(find "$SHOWS_DIR" -name 'show.json' -type f)

index_mtime=$(stat -f '%m' "$INDEX" 2>/dev/null || stat -c '%Y' "$INDEX" 2>/dev/null)

if [ "$newest_show" -le "$index_mtime" ]; then
  pass "index is up to date (no show.json newer than shows.json)"
else
  fail "index is STALE — a show.json was modified after shows.json (run build-index)"
fi
echo ""

# ── Submodule status ────────────────────────────────────────────────

echo "=== Submodule Status ==="

bandlab_dir="${REPO_ROOT}/bandlab"
if [ -d "$bandlab_dir/.git" ] || [ -f "$bandlab_dir/.git" ]; then
  # Check for uncommitted changes in bandlab/
  if git -C "$bandlab_dir" diff --quiet && git -C "$bandlab_dir" diff --cached --quiet; then
    pass "bandlab/ has no uncommitted changes"
  else
    fail "bandlab/ has uncommitted changes — commit submodule before parent"
  fi

  # Check if parent repo has staged submodule ref change
  if git diff --quiet -- bandlab 2>/dev/null; then
    pass "bandlab submodule ref is clean in parent"
  else
    fail "bandlab submodule ref is dirty in parent — stage and commit"
  fi
else
  fail "bandlab/ is not a git submodule"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  ${checks} checks | ${errors} errors | ${warnings} warnings"

if [ "$errors" -gt 0 ]; then
  echo "  ISSUES FOUND"
  exit 1
else
  echo "  ALL CLEAR"
fi
