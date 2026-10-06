#!/usr/bin/env bash
# Which delegation lanes are usable right now, using free signals only (no lane spends quota).
# Usage: scripts/lanes-status.sh [--probe-codex] [lane ...]
# Without lanes it checks the ones in lanes.conf. --probe-codex spends one minimal Codex turn to see its credits.
set -u

readonly ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOCAL=${LOCALAPPDATA:-$HOME/AppData/Local}
LOCAL=${LOCAL//\\//}
PROBE_CODEX=0

row() { printf '%-12s %-9s %s\n' "$1" "$2" "$3"; }

deepseek_status() {
  local root="$LOCAL/Programs/DeepSeek Harness" ver
  local app="$root/DeepSeek Harness.exe" cli="$root/resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/cli.js"
  [ -f "$app" ] || { row deepseek MISSING "DeepSeek Harness not installed"; return; }
  ver=$(ELECTRON_RUN_AS_NODE=1 "$app" --expose-internals "$cli" --version </dev/null 2>/dev/null | tr -d '\r')
  if grep -q 'deepseek-account-platform/default:' "${DSH_HOME:-$HOME/.dsh}/.credentials.yaml" 2>/dev/null; then
    row deepseek OK "dsh $ver, app login; balance has no free headless meter: platform.deepseek.com/usage"
  elif [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    row deepseek OK "dsh $ver, DEEPSEEK_API_KEY"
  else
    row deepseek NO-AUTH "dsh $ver: open DeepSeek Harness and sign in, or export DEEPSEEK_API_KEY"
  fi
}

muse_status() {
  local dir="$LOCAL/Programs/muse" bin ver sandbox
  bin="$dir/muse-bin-$(tr -d '\r\n' <"$dir/.muse-version" 2>/dev/null).exe"
  [ -f "$bin" ] || bin=$(command -v muse 2>/dev/null)
  [ -n "$bin" ] && [ -e "$bin" ] || { row muse MISSING "Muse not installed"; return; }
  ver=$("$bin" --version </dev/null 2>/dev/null | tr -d '\r')
  if [ -d "$dir" ]; then
    sandbox=$("$bin" sandbox windows check </dev/null 2>/dev/null | tr -d '\r' | sed -n 's/^status=//p')
    [ "$sandbox" = ready ] || { row muse BROKEN "$ver: sandbox '$sandbox' — run 'muse sandbox windows setup' elevated"; return; }
  fi
  if [ -n "${META_API_KEY:-}" ] || grep -Eq '"(access_token|api_key)"[[:space:]]*:[[:space:]]*"[^"]' "$HOME/.config/muse/auth.json" 2>/dev/null; then
    row muse OK "$ver; subscription has no free headless meter"
  else
    row muse NO-AUTH "$ver: run 'muse login' once"
  fi
}

codex_status() {
  command -v codex >/dev/null 2>&1 || { row codex MISSING "codex not on PATH"; return; }
  local version model out
  version=$(codex --version 2>/dev/null | awk '{print $2}')
  model=$(grep -m1 '^model *=' "$HOME/.codex/config.toml" 2>/dev/null | cut -d'"' -f2)
  [ "$PROBE_CODEX" = 1 ] || { row codex "?" "cli $version, model ${model:-default}; credits: rerun with --probe-codex"; return; }
  # --ignore-user-config: with a stale user config codex can hang silently on account errors
  out=$(cd "$(mktemp -d)" && timeout 90 codex exec --ignore-user-config --skip-git-repo-check -s read-only ${model:+-m "$model"} "Reply with exactly: ok" </dev/null 2>&1)
  case "$out" in
    *"out of credits"*) row codex EXHAUSTED "cli $version: no credits left" ;;
    *"not supported"*) row codex BROKEN "cli $version: model $model not supported — npm i -g @openai/codex@latest" ;;
    *ok*) row codex OK "cli $version, model ${model:-default}" ;;
    *) row codex "?" "cli $version: $(printf '%s' "$out" | grep -m1 -i error | cut -c1-90)" ;;
  esac
}

copilot_status() {
  command -v copilot >/dev/null 2>&1 || { row copilot MISSING "copilot not on PATH"; return; }
  command -v gh >/dev/null 2>&1 || { row copilot "?" "gh not installed: no free quota reading"; return; }
  gh api copilot_internal/user 2>/dev/null | python -c '
import json, sys
d = json.load(sys.stdin)
chat = (d.get("quota_snapshots") or {}).get("chat") or {}
left = chat.get("remaining", 0)
state = "OK" if chat.get("unlimited") or left > 0 else "EXHAUSTED"
name, login, plan = "copilot", d.get("login"), d.get("copilot_plan")
total, reset = chat.get("entitlement"), d.get("quota_reset_date")
print(f"{name:<12} {state:<9} {login} ({plan}): chat {left}/{total}, reset {reset}")
' 2>/dev/null || row copilot "?" "gh api copilot_internal/user gave no answer"
}

ollama_status() {
  local models
  models=$(curl -s -m 3 http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -E -- '-32k|mechanical' | paste -sd ',' -)
  if [ -n "$models" ]; then row ollama OK "$models"
  elif curl -s -m 3 http://localhost:11434/api/tags >/dev/null; then row ollama NO-MODEL "service up, no context-capped (-32k) models"
  else row ollama DOWN "no answer on :11434"; fi
}

bipolar_status() {
  [ -f "$HOME/.config/bipolar-cc/env" ] && . "$HOME/.config/bipolar-cc/env"
  [ -n "${BIPOLAR_URL:-}" ] || { row bipolar UNSET "no ~/.config/bipolar-cc/env (run /bipolar:setup)"; return; }
  local health
  health=$(curl -s -m 5 -H "x-api-key: ${BIPOLAR_API_KEY:-}" "$BIPOLAR_URL/api/health")
  [ -n "$health" ] && row bipolar OK "$(printf '%s' "$health" | cut -c1-90)" || row bipolar DOWN "$BIPOLAR_URL does not answer"
}

antigravity_status() {
  local agy usage
  agy=$(command -v agy || ls "$LOCAL/agy/bin/agy.exe" 2>/dev/null | head -1)
  [ -n "$agy" ] || { row antigravity MISSING "agy not installed"; return; }
  # MSYS_NO_PATHCONV: without it Git Bash turns /usage into a path and it becomes a paid turn
  usage=$(MSYS_NO_PATHCONV=1 "$agy" -p "/usage" --output-format text --print-timeout 30s 2>/dev/null | tr '\t' ' ')
  [ -n "$usage" ] || { row antigravity "?" "/usage gave no answer"; return; }
  printf '%s\n' "$usage" | while read -r line; do antigravity_pool_row "$line"; done
}

antigravity_pool_row() {
  local pct
  pct=$(printf '%s' "$1" | grep -oE '[0-9]+%' | head -1)
  [ -n "$pct" ] || return 0
  if [ "${pct%\%}" -le 2 ]; then row antigravity EXHAUSTED "$1"; else row antigravity OK "$1"; fi
}

cursor_status() {
  local ver about
  ver=$(ls -d "$LOCAL/cursor-agent"/versions/*/ 2>/dev/null | sort -V | tail -1)
  if [ -n "$ver" ]; then about=$(CURSOR_CONFIG_DIR="$HOME/.cursor-rescue" "${ver}node.exe" "${ver}index.js" about </dev/null 2>&1)
  elif command -v cursor-agent >/dev/null 2>&1; then about=$(CURSOR_CONFIG_DIR="$HOME/.cursor-rescue" cursor-agent about </dev/null 2>&1)
  else row cursor MISSING "cursor-agent not installed"; return; fi
  case "$about" in
    *"Not logged in"*) row cursor NO-AUTH "run once: cursor-agent login" ;;
    *) row cursor OK "$(printf '%s' "$about" | grep -E 'Subscription Tier|CLI Version' | tr -s ' ' | paste -sd ';' -)" ;;
  esac
}

conf_lanes() {
  grep -Ev '^[[:space:]]*(#|$)' "$ROOT/lanes.conf" | tr -d '\r' | sed 's/[[:space:]]*$//'
}

main() {
  local lanes=() lane
  for lane in "$@"; do
    if [ "$lane" = --probe-codex ]; then PROBE_CODEX=1; else lanes+=("$lane"); fi
  done
  [ ${#lanes[@]} -gt 0 ] || mapfile -t lanes < <(conf_lanes)
  row LANE STATE DETAIL
  for lane in "${lanes[@]}"; do
    if declare -F "${lane}_status" >/dev/null; then "${lane}_status"; else row "$lane" UNKNOWN "no status check for this lane"; fi
  done
}

main "$@"
