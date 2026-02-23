#!/usr/bin/env bash
# desc: Rebuild org/.state/shows.json index from show.json files
# Merges all individual show.json files into one jq-queryable index.
# Run this after editing any show.json file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SHOWS_GLOB="${REPO_ROOT}/$(cfg '.entities.shows.glob')"
OUTPUT="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"

# Merge all show.json files into a single object keyed by show ID.
# jq reads each file, wraps it as {id: data}, then merges all into one object.
# shellcheck disable=SC2086
jq -n '
  [inputs | {(.id): .}]
  | add
  // {}
' $SHOWS_GLOB > "$OUTPUT"

count=$(jq 'length' "$OUTPUT")
echo "Built index: ${OUTPUT} (${count} shows)"
