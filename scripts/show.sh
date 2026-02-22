#!/usr/bin/env bash
# desc: Display details for a specific show
# usage: show.sh <show-id-or-partial>
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
INDEX="${REPO_ROOT}/org/touring/.state/shows.json"
VENUES="${REPO_ROOT}/org/touring/venues.json"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"

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
for f in show.json source/summary.md tech-pack.md advancing/thread.md advancing/confirmed.md; do
  if [ -f "${show_dir}/${f}" ]; then
    echo "  [x] ${f}"
  else
    echo "  [ ] ${f}"
  fi
done

# Source PDFs
source_count=$(find "${show_dir}/source" -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
echo "  [x] source/ (${source_count} PDF)" 2>/dev/null || echo "  [ ] source/"
