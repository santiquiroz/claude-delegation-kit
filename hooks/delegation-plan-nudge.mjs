// PostToolUse(TodoWrite): when a long plan moves a task to in_progress, remind Claude to pick a lane before
// implementing it inline. Configure with DELEGATION_LANES and DELEGATION_TARGET (see hooks/README in the repo).
const MIN_TODOS_FOR_NUDGE = 3
const LANES = process.env.DELEGATION_LANES || 'deepseek > muse > codex > copilot > ollama'
const TARGET = process.env.DELEGATION_TARGET || '85'

function nudgeFor(todos) {
  if (todos.length < MIN_TODOS_FOR_NUDGE) return ''
  const current = todos.find(t => t.status === 'in_progress')
  if (!current) return ''
  const pending = todos.filter(t => t.status !== 'completed').length
  return `\n[DELEGATE-CHECK] Long plan in progress (${todos.length} tasks, ${pending} pending).\n` +
    `Before implementing "${current.content}" inline, pick a lane by the default-delegate rule: ${LANES}. ` +
    'Inline only for <=3 lines or domain logic.\n' +
    `Session target: >=${TARGET}% of subtasks run by lanes.\n`
}

let data = ''
process.stdin.on('data', chunk => { data += chunk })
process.stdin.on('end', () => {
  try {
    process.stdout.write(nudgeFor(JSON.parse(data).tool_input?.todos || []))
  } catch {}
  process.exit(0)
})
