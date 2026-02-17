#!/usr/bin/env bash
# desc: Rebuild .state/shows.json index from show.json files
# Merges all individual show.json files into one jq-queryable index.
# Run this after editing any show.json file.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SHOWS_DIR="${REPO_ROOT}/org/touring/shows"
OUTPUT="${REPO_ROOT}/org/.state/shows.json"

# Merge all show.json files into a single object keyed by show ID.
# jq reads each file, wraps it as {id: data}, then merges all into one object.
jq -n '
  [inputs | {(.id): .}]
  | add
  // {}
' "${SHOWS_DIR}"/s-*/show.json > "$OUTPUT"

count=$(jq 'length' "$OUTPUT")
echo "Built index: ${OUTPUT} (${count} shows)"
