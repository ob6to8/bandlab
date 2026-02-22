#!/usr/bin/env bash
# desc: Check that documentation accurately describes the system
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
SKILLS_DIR="${REPO_ROOT}/.claude/skills"
SCRIPTS_DIR="${REPO_ROOT}/bandlab/scripts"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"
INDEX="${REPO_ROOT}/org/touring/.state/shows.json"
OPS_DIR="${REPO_ROOT}/ops"

errors=0
warnings=0
checks=0

pass() {
  printf "  ✓ %s\n" "$1"
  checks=$((checks + 1))
}

fail() {
  printf "  ✗ %s\n" "$1"
  errors=$((errors + 1))
  checks=$((checks + 1))
}

warn() {
  printf "  ? %s\n" "$1"
  warnings=$((warnings + 1))
  checks=$((checks + 1))
}

# ── Skills table ↔ skill directories ─────────────────────────────────

echo "=== Skills Table ↔ Directories ==="

# Extract skill names from CLAUDE.md table (lines matching | /name |)
table_skills=()
while IFS= read -r line; do
  # Extract skill name from table row: | `/skill-name` | or | /skill-name |
  # shellcheck disable=SC2016
  skill=$(echo "$line" | sed -n 's/^| *`\{0,1\}\/\([a-zA-Z0-9_-]*\)`\{0,1\} *|.*/\1/p')
  if [ -n "$skill" ]; then
    table_skills+=("$skill")
  fi
done < "$CLAUDE_MD"

# Get actual skill directories
dir_skills=()
for skill_dir in "${SKILLS_DIR}"/*/; do
  [ -d "$skill_dir" ] || continue
  dir_skills+=("$(basename "$skill_dir")")
done

# Skills in dirs but not in table
for skill in "${dir_skills[@]}"; do
  found=false
  for ts in "${table_skills[@]}"; do
    if [ "$skill" = "$ts" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = true ]; then
    pass "/${skill}: dir + table"
  else
    fail "/${skill}: has skill dir but MISSING from CLAUDE.md table"
  fi
done

# Skills in table but no dir
for skill in "${table_skills[@]}"; do
  found=false
  for ds in "${dir_skills[@]}"; do
    if [ "$skill" = "$ds" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    fail "/${skill}: in CLAUDE.md table but NO skill directory"
  fi
done
echo ""

# ── Skills with backing scripts ──────────────────────────────────────

echo "=== Backing Scripts ==="

# For each skill in the table that has a backing script listed, verify the script exists
while IFS= read -r line; do
  # shellcheck disable=SC2016
  skill=$(echo "$line" | sed -n 's/^| *`\{0,1\}\/\([a-zA-Z0-9_-]*\)`\{0,1\} *|.*/\1/p')
  [ -n "$skill" ] || continue

  # Extract backing script column (second | ... | segment)
  script_col=$(echo "$line" | awk -F'|' '{print $3}' | xargs)

  # Skip agent-only or empty
  case "$script_col" in
    *agent-only*|"") continue ;;
  esac

  # Extract script filename (strip backticks)
  script_name=$(echo "$script_col" | sed 's/`//g' | xargs)
  [ -n "$script_name" ] || continue

  if [ -f "${SCRIPTS_DIR}/${script_name}" ]; then
    pass "/${skill} → ${script_name} exists"
  else
    fail "/${skill} → ${script_name} NOT FOUND in bandlab/scripts/"
  fi
done < "$CLAUDE_MD"
echo ""

# ── Ops directory ↔ CLAUDE.md tree ───────────────────────────────────

echo "=== Ops Directory Sync ==="

# Get actual ops files (relative to ops/)
actual_ops=()
while IFS= read -r f; do
  rel="${f#"${OPS_DIR}"/}"
  actual_ops+=("$rel")
done < <(find "$OPS_DIR" -name '*.md' -type f | sort)

# Check each actual ops file is mentioned in CLAUDE.md
for f in "${actual_ops[@]}"; do
  basename_f=$(basename "$f")
  if grep -q "$basename_f" "$CLAUDE_MD"; then
    pass "ops/${f}: mentioned in CLAUDE.md"
  else
    warn "ops/${f}: NOT mentioned in CLAUDE.md ops tree"
  fi
done
echo ""

# ── Shows index freshness ───────────────────────────────────────────

echo "=== Shows Index Freshness ==="

if [ -f "$INDEX" ]; then
  index_count=$(jq 'length' "$INDEX")
  dir_count=$(find "$SHOWS_DIR" -maxdepth 1 -name 's-*' -type d | wc -l | tr -d ' ')

  if [ "$index_count" -eq "$dir_count" ]; then
    pass "shows index count (${index_count}) matches directory count (${dir_count})"
  else
    fail "shows index (${index_count}) ≠ show directories (${dir_count}) — run build-index"
  fi
else
  fail "shows.json index missing"
fi
echo ""

# ── Submodule status ────────────────────────────────────────────────

echo "=== Submodule Status ==="

submodule_status=$(cd "$REPO_ROOT" && git submodule status bandlab 2>/dev/null || echo "not-a-submodule")

if echo "$submodule_status" | grep -q '^+'; then
  warn "bandlab/ submodule has uncommitted ref change (dirty)"
elif echo "$submodule_status" | grep -q '^-'; then
  fail "bandlab/ submodule not initialized"
elif echo "$submodule_status" | grep -q 'not-a-submodule'; then
  warn "bandlab/ is not a submodule in this repo"
else
  pass "bandlab/ submodule is clean"
fi
echo ""

# ── Schema field check ──────────────────────────────────────────────

echo "=== Schema vs Reality ==="

# Get the union of all fields across all show.json files
actual_fields=$(find "$SHOWS_DIR" -name 'show.json' -exec jq -r 'keys[]' {} + | sort -u)

# Known schema fields from bandlab/CLAUDE.md show.json definition
# These are the fields documented in the schema
schema_fields="id date venue run one_off status guarantee canada_amount door_split promoter ages ticket_link sell_cap ticket_scaling wp support tour touring_party sets routing_notes advance _provenance"

for field in $actual_fields; do
  found=false
  for sf in $schema_fields; do
    if [ "$field" = "$sf" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = true ]; then
    pass "field '${field}' is in schema"
  else
    warn "field '${field}' found in show.json files but NOT in documented schema"
  fi
done
echo ""

# ── Todo schema check ──────────────────────────────────────────────

echo "=== Todo Schema vs Reality ==="

TODOS="${REPO_ROOT}/org/todos.json"

if [ -f "$TODOS" ]; then
  actual_todo_fields=$(jq -r '[.[] | keys[]] | unique[]' "$TODOS" | sort -u)
  todo_schema_fields="id task domain category show owners status due blocked_by source created updated notes history"

  for field in $actual_todo_fields; do
    found=false
    for sf in $todo_schema_fields; do
      if [ "$field" = "$sf" ]; then
        found=true
        break
      fi
    done
    if [ "$found" = true ]; then
      pass "todo field '${field}' is in schema"
    else
      warn "todo field '${field}' found in todos.json but NOT in documented schema"
    fi
  done

  # Check blocked_by references point to valid todo IDs
  todo_ids=$(jq -r '.[].id' "$TODOS")
  blocked_refs=$(jq -r '.[] | select(.blocked_by != null) | .blocked_by[]' "$TODOS" 2>/dev/null || true)
  for ref in $blocked_refs; do
    if echo "$todo_ids" | grep -q "^${ref}$"; then
      pass "blocked_by ref '${ref}' resolves to valid todo"
    else
      fail "blocked_by ref '${ref}' does NOT resolve to any todo"
    fi
  done
else
  warn "todos.json not found"
fi
echo ""

# ── Summary ─────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  ${checks} checks | ${errors} errors | ${warnings} warnings"

if [ "$errors" -gt 0 ]; then
  echo "  DOC CHECK FAILED"
  exit 1
else
  echo "  DOCS IN SYNC"
fi
