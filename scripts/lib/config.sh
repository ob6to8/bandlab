#!/usr/bin/env bash
# lib/config.sh — shared config loading for bandlab scripts
#
# Every script sources this file and calls load_config to initialize:
#   REPO_ROOT — git repository root
#   CONFIG    — path to bandlab.config.json
#   ORG       — path to org/ directory (REPO_ROOT + registries base)
#
# Provides:
#   cfg <jq-expr>           — read a config value (exits on null)
#   cfg_default <jq> <val>  — read a config value with a default
#   pass/fail/warn          — check result helpers with counters
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "${SCRIPT_DIR}/lib/config.sh" && load_config

load_config() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CONFIG="${REPO_ROOT}/bandlab.config.json"
  if [ ! -f "$CONFIG" ]; then
    echo "Missing bandlab.config.json — run: bash bandlab/setup.sh" >&2
    exit 1
  fi
  # Derive ORG from the registries base — used by sourcing scripts
  # shellcheck disable=SC2034
  ORG="${REPO_ROOT}/org"
}

# Read a config value. Returns the raw jq result (caller checks for "null" if needed).
cfg() { jq -r "$1" "$CONFIG"; }

# Read a config value with a fallback default.
cfg_default() { jq -r "$1 // \"$2\"" "$CONFIG"; }

# ── Check result helpers ─────────────────────────────────────────────
# Scripts must initialize: errors=0 warnings=0 checks=0

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
