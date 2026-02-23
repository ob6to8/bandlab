#!/usr/bin/env bash
# desc: Display details for a specific show
# usage: show.sh <show-id-or-partial>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

INDEX="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"
VENUES="${REPO_ROOT}/$(cfg '.registries.venues.path')"
SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"

if [ ! -f "$INDEX" ]; then
  echo "Index not found. Run: ./bandlab-cli build-index" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: show.sh <show-id-or-partial>" >&2
  exit 1
fi

query="$1"
show_id=$(jq -r "keys[] | select(contains(\"${query}\"))" "$INDEX" | head -1)

if [ -z "$show_id" ]; then
  echo "No show found matching: ${query}" >&2
  exit 1
fi

# Show data from index
echo "=== ${show_id} ==="
jq --arg id "$show_id" '.[$id]' "$INDEX"

# Venue data
venue=$(jq -r --arg id "$show_id" '.[$id].venue' "$INDEX")
echo ""
echo "=== Venue: ${venue} ==="
jq --arg v "$venue" '.[$v]' "$VENUES"

# Files present
echo ""
echo "=== Files ==="
show_dir="${SHOWS_DIR}/${show_id}"

# Read file checklist from config
while IFS= read -r f; do
  if [ -f "${show_dir}/${f}" ]; then
    echo "  [x] ${f}"
  else
    echo "  [ ] ${f}"
  fi
done < <(cfg '.entities.shows.file_checklist[]')

# Source PDFs
source_count=$(find "${show_dir}/source" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
echo "  [x] source/ (${source_count} PDF)" 2>/dev/null || echo "  [ ] source/"
