// PreToolUse(Agent): when Claude is about to spawn one of its OWN subagents to implement something, remind it that a
// lane subagent should usually take the job. Lane subagents (deepseek:*, codex:*, …) pass through silently.
const LANE_PREFIXES = (process.env.DELEGATION_LANE_PREFIXES || 'deepseek,muse,codex,copilot,ollama,bipolar,antigravity,cursor')
  .split(',').map(s => s.trim()).filter(Boolean)
const TARGET = process.env.DELEGATION_TARGET || '85'
const IMPLEMENTATION_WORDS = /\b(implement|build|write code|fix|refactor|migrate|create component|generate|add feature|implementar|construir|arregla|refactoriza|migrar|generar|agrega)\b/i
const IMPLEMENTATION_AGENTS = new Set(['general-purpose', 'claude', 'tdd-guide', 'build-error-resolver', 'refactor-cleaner'])

function isLaneAgent(type) {
  return LANE_PREFIXES.some(p => type.startsWith(`${p}:`) || type === `${p}-rescue`)
}

function looksLikeImplementation(input) {
  const type = String(input.subagent_type || 'general-purpose')
  const text = `${input.description || ''} ${input.prompt || ''}`
  return IMPLEMENTATION_AGENTS.has(type) || IMPLEMENTATION_WORDS.test(text)
}

function contextFor(input) {
  const type = String(input.subagent_type || 'general-purpose')
  if (isLaneAgent(type) || !looksLikeImplementation(input)) return null
  return `[AGENTIC-DELEGATE-CHECK] Subagent "${type}" looks like implementation work. Before running it on Claude, ` +
    `check the default-delegate rule: should a lane (${LANE_PREFIXES.map(p => `${p}:${p}-rescue`).join(', ')}) take it? ` +
    `Session target: >=${TARGET}% of subtasks run by lanes.`
}

let data = ''
process.stdin.on('data', chunk => { data += chunk })
process.stdin.on('end', () => {
  try {
    const context = contextFor(JSON.parse(data).tool_input || {})
    if (context) {
      process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', additionalContext: context } }))
    }
  } catch {}
  process.exit(0)
})
