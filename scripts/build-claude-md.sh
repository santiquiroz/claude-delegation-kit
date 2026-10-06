#!/usr/bin/env bash
# Assembles the delegation rules for the lanes you actually have.
# Usage: scripts/build-claude-md.sh [lane ...] > ~/.claude/delegation.md
# Without arguments the lanes come from lanes.conf (one per line, in priority order).
set -euo pipefail

readonly ROOT=$(cd "$(dirname "$0")/.." && pwd)
readonly USAGE_EXIT=64
readonly ROLES=(mechanical reasoning second-opinion)

conf_lanes() {
  grep -Ev '^[[:space:]]*(#|$)' "$ROOT/lanes.conf" | tr -d '\r' | sed 's/[[:space:]]*$//'
}

lane_file() {
  printf '%s/lanes/%s.md' "$ROOT" "$1"
}

require_lane() {
  [ -f "$(lane_file "$1")" ] && return 0
  printf 'unknown lane: %s (available: %s)\n' "$1" "$(ls "$ROOT/lanes" | sed 's/\.md$//' | paste -sd ' ' -)" >&2
  exit "$USAGE_EXIT"
}

has_role() {
  head -1 "$(lane_file "$1")" | grep -Eq "roles:.*(^|[[:space:]])$2([[:space:]]|$)"
}

role_row() {
  local role=$1 lane row=""
  shift
  for lane in "$@"; do
    has_role "$lane" "$role" && row+="$lane → "
  done
  printf -- '- %s: %sClaude inline\n' "$role" "$row"
}

fallback_section() {
  local role
  printf '\n## Fallback order\n\n'
  printf 'Walk the row that matches the task, left to right; skip the lanes lanes-status reports as unavailable.\n'
  printf 'A second opinion always runs the lane in its read-only mode.\n\n'
  for role in "${ROLES[@]}"; do role_row "$role" "$@"; done
}

main() {
  local lanes=("$@") lane
  [ ${#lanes[@]} -gt 0 ] || mapfile -t lanes < <(conf_lanes)
  [ ${#lanes[@]} -gt 0 ] || { echo "no lanes: pass them as arguments or list them in lanes.conf" >&2; exit "$USAGE_EXIT"; }
  for lane in "${lanes[@]}"; do require_lane "$lane"; done
  cat "$ROOT/core/rules.md"
  fallback_section "${lanes[@]}"
  for lane in "${lanes[@]}"; do
    printf '\n'
    sed 1d "$(lane_file "$lane")"
  done
}

main "$@"
