#!/usr/bin/env bash
set -u
set -o pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PASSED=0
TOTAL=0
WHY=''

contains() {
  grep -Fq -- "$2" <<< "$1"
}

test_default_build() {
  local actual expected
  actual=$(bash "$ROOT/scripts/build-claude-md.sh") || {
    WHY='builder failed without arguments'
    return 1
  }
  expected=$(cat "$ROOT/core/rules.md") || {
    WHY='could not read core/rules.md'
    return 1
  }
  [[ "$actual" == "$expected"* ]] || {
    WHY='output does not start with core/rules.md'
    return 1
  }
  contains "$actual" '## Fallback order' || {
    WHY='missing fallback heading'
    return 1
  }
  contains "$actual" '- mechanical: deepseek → muse → ollama → copilot → bipolar → cursor → antigravity → Claude inline' || {
    WHY='mechanical fallback order differs'
    return 1
  }
  contains "$actual" '- reasoning: deepseek → codex → antigravity → Claude inline' || {
    WHY='reasoning fallback order differs'
    return 1
  }
}

test_selected_lanes() {
  local actual
  actual=$(bash "$ROOT/scripts/build-claude-md.sh" codex copilot) || {
    WHY='builder failed for codex copilot'
    return 1
  }
  contains "$actual" '- mechanical: copilot → Claude inline' || {
    WHY='selected mechanical fallback order differs'
    return 1
  }
  contains "$actual" '- reasoning: codex → Claude inline' || {
    WHY='selected reasoning fallback order differs'
    return 1
  }
  contains "$actual" '- second-opinion: copilot → Claude inline' || {
    WHY='selected second-opinion fallback order differs'
    return 1
  }
  contains "$actual" '## Codex' || {
    WHY='missing Codex heading'
    return 1
  }
  contains "$actual" '## GitHub Copilot CLI' || {
    WHY='missing GitHub Copilot CLI heading'
    return 1
  }
  ! contains "$actual" '## DeepSeek' || {
    WHY='unexpected DeepSeek section'
    return 1
  }
  ! contains "$actual" '<!-- roles:' || {
    WHY='lane role metadata leaked into output'
    return 1
  }
}

test_unknown_lane() {
  local actual status
  if actual=$(bash "$ROOT/scripts/build-claude-md.sh" nope 2>&1 1>/dev/null); then
    WHY='builder unexpectedly accepted an unknown lane'
    return 1
  else
    status=$?
  fi
  [[ $status -eq 64 ]] || {
    WHY="expected exit 64, got $status"
    return 1
  }
  contains "$actual" 'unknown lane: nope' || {
    WHY='stderr did not identify the unknown lane'
    return 1
  }
}

test_empty_config() {
  local temp_dir actual status
  temp_dir=$(mktemp -d) || {
    WHY='mktemp failed'
    return 1
  }
  cp -R "$ROOT/core" "$ROOT/lanes" "$ROOT/scripts" "$temp_dir/" &&
    cp "$ROOT/lanes.conf" "$temp_dir/lanes.conf" || {
      rm -rf -- "$temp_dir"
      WHY='could not create temporary repository copy'
      return 1
    }
  printf '# no lanes\n\n  # still no lanes\n\n' > "$temp_dir/lanes.conf"
  if actual=$(bash "$temp_dir/scripts/build-claude-md.sh" 2>&1 1>/dev/null); then
    status=0
  else
    status=$?
  fi
  rm -rf -- "$temp_dir"
  [[ $status -eq 64 ]] || {
    WHY="expected exit 64, got $status"
    return 1
  }
  contains "$actual" 'no lanes' || {
    WHY='stderr did not report no lanes'
    return 1
  }
}

test_lane_role_headers() {
  local file first_line
  local header_pattern='^<!-- roles: (mechanical|reasoning|second-opinion)( (mechanical|reasoning|second-opinion))* -->$'
  local found=0
  for file in "$ROOT"/lanes/*.md; do
    [[ -f "$file" ]] || continue
    found=1
    IFS= read -r first_line < "$file" || first_line=''
    [[ "$first_line" =~ $header_pattern ]] || {
      WHY="${file##*/} has an invalid roles header"
      return 1
    }
  done
  [[ $found -eq 1 ]] || {
    WHY='no lane markdown files found'
    return 1
  }
}

test_script_syntax() {
  local file
  for file in "$ROOT"/scripts/*.sh; do
    [[ -f "$file" ]] || continue
    bash -n "$file" || {
      WHY="${file##*/} failed bash -n"
      return 1
    }
  done
}

test_hook_and_json_syntax() {
  local file
  for file in "$ROOT"/hooks/*.mjs; do
    [[ -f "$file" ]] || continue
    node --check "$file" || {
      WHY="${file##*/} failed node --check"
      return 1
    }
  done
  node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$ROOT/hooks/settings.example.json" || {
    WHY='settings.example.json is invalid JSON'
    return 1
  }
}

test_agent_nudge() {
  local actual
  actual=$(printf '%s' '{"tool_input":{"subagent_type":"deepseek:deepseek-rescue","description":"implement x"}}' |
    node "$ROOT/hooks/delegation-agent-nudge.mjs") || {
      WHY='agent nudge failed for a lane agent'
      return 1
    }
  [[ -z "$actual" ]] || {
    WHY='lane agent unexpectedly received a nudge'
    return 1
  }
  actual=$(printf '%s' '{"tool_input":{"subagent_type":"general-purpose","description":"implement the parser"}}' |
    node "$ROOT/hooks/delegation-agent-nudge.mjs") || {
      WHY='agent nudge failed for implementation work'
      return 1
    }
  contains "$actual" 'AGENTIC-DELEGATE-CHECK' || {
    WHY='implementation work did not receive the delegate check'
    return 1
  }
  actual=$(printf '%s' '{"tool_input":{"subagent_type":"Explore","description":"find where X is defined"}}' |
    node "$ROOT/hooks/delegation-agent-nudge.mjs") || {
      WHY='agent nudge failed for exploratory work'
      return 1
    }
  [[ -z "$actual" ]] || {
    WHY='exploratory work unexpectedly received a nudge'
    return 1
  }
}

test_plan_nudge() {
  local todos actual
  todos='{"tool_input":{"todos":[{"content":"one","status":"pending"},{"content":"two","status":"in_progress"},{"content":"three","status":"pending"}]}}'
  actual=$(printf '%s' "$todos" | node "$ROOT/hooks/delegation-plan-nudge.mjs") || {
    WHY='plan nudge failed for three todos'
    return 1
  }
  contains "$actual" 'DELEGATE-CHECK' || {
    WHY='three-todo plan did not receive the delegate check'
    return 1
  }
  contains "$actual" '>=85%' || {
    WHY='default delegation target was not included'
    return 1
  }
  actual=$(printf '%s' "$todos" | DELEGATION_TARGET=90 node "$ROOT/hooks/delegation-plan-nudge.mjs") || {
    WHY='plan nudge failed with a custom target'
    return 1
  }
  contains "$actual" '>=90%' || {
    WHY='custom delegation target was not included'
    return 1
  }
  actual=$(printf '%s' '{"tool_input":{"todos":[{"content":"one","status":"in_progress"},{"content":"two","status":"pending"}]}}' |
    node "$ROOT/hooks/delegation-plan-nudge.mjs") || {
      WHY='plan nudge failed for two todos'
      return 1
    }
  [[ -z "$actual" ]] || {
    WHY='two-todo plan unexpectedly received a nudge'
    return 1
  }
}

run_test() {
  local name=$1
  shift
  TOTAL=$((TOTAL + 1))
  WHY=''
  if "$@"; then
    PASSED=$((PASSED + 1))
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s: %s\n' "$name" "${WHY:-check failed}"
  fi
}

run_test 'default build uses lanes.conf' test_default_build
run_test 'selected lane build' test_selected_lanes
run_test 'unknown lane exits 64' test_unknown_lane
run_test 'empty lanes.conf exits 64' test_empty_config
run_test 'lane role headers' test_lane_role_headers
run_test 'shell script syntax' test_script_syntax
run_test 'hook and settings syntax' test_hook_and_json_syntax
run_test 'agent nudge behavior' test_agent_nudge
run_test 'plan nudge behavior' test_plan_nudge

printf '%s/%s tests passed\n' "$PASSED" "$TOTAL"
[[ $PASSED -eq $TOTAL ]]
