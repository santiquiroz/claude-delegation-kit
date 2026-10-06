# Multi-agent delegation

Claude Code is the orchestrator and the reviewer. The implementation work goes to cheaper or quota-separate agents
("lanes") that run headless in the background. Claude writes the contract of each subtask, launches it, keeps working,
reviews the diff when it comes back, and commits. The lanes, their order and their rules follow below.

## Check the lanes before delegating

Lanes run out (monthly allowances, weekly pools, prepaid balances), and finding out by delegating costs minutes: some CLIs
hang silently or retry for many minutes on an empty pool.

- On the FIRST delegation of a session, and after any quota error, run `bash scripts/lanes-status.sh` (free probes only)
  and skip every lane reported `EXHAUSTED`, `MISSING`, `NO-AUTH`, `DOWN` or `BROKEN`.
- Never record quota percentages in this file: they go stale. The script is the source of truth.

## Default-delegate rule (mandatory)

- Before writing ANY code, decide explicitly which lane does it. Claude implements inline ONLY when:
  (a) the task is on the "never delegate" list below, or
  (b) it is a trivial edit of ≤3 lines in one file, where coordinating a delegate costs more than doing it.
- Everything else is delegated in the background from the start, following the lane order of the matching row in
  "Fallback order".
- Read-only work is delegated too: exploring code, contrasting a diagnosis, reviewing a diff (use a lane's read-only mode).
- Session target: **≥85% of subtasks executed by lanes**. A task finished 100% inline is a process failure; say so in the
  session summary.
- This applies inside agentic flows too: before spawning a Claude subagent to IMPLEMENT something, check whether one of the
  lane subagents should take it instead. "I already delegated it to a Claude subagent" does not count.
- Tests, specs, PR descriptions, parallel investigations and fixes with an exact known instruction are ALWAYS delegated.

## Never delegate

- Domain logic, business rules, entity state machines.
- Architecture decisions or feature design.
- Complex refactors that need the whole codebase in mind.
- Anything where the WHY lives in the current conversation.

## How to write a delegated task

- Self-contained: absolute paths, pasted signatures and contracts, acceptance criteria. The delegate never sees this
  conversation.
- Tell it not to commit, push, reset, checkout, clean or delete; the orchestrator verifies and commits.
- Ask for the list of touched files at the end.
- Treat every result as medium trust: read `git status`, `git diff`, `git log` and `git stash list` before committing.

## Parallel pattern

```
Claude: writes the domain piece itself
  → launches lane A in the background: "fix the build errors in module X"
  → launches lane B in the background: "write tests for X (signatures below)"
Claude: continues with the next subtask while both run, then reviews both diffs
```

- Never sit idle waiting for a delegate.
- WIP cap: 3-5 concurrent delegations. Beyond that, coordination overhead and unreviewed mistakes outweigh the gain.
- Kill switch: after 3 stuck or failed iterations of the same task on one lane, hand it to another lane once or bring it
  back to the main thread. Never loop.

## Quota fallback

Detect quota or auth trouble only in FAILED runs (a successful run that merely talks about quotas is not a signal):
`rate limit`, `429`, `quota`, `usage limit`, `limit reached`, `insufficient balance`, `out of credits`,
`RESOURCE_EXHAUSTED`, `401`, `not logged in`.

- A soft cap with a retry hint (`retry-after`): wait that long and retry the SAME lane once.
- A server or overload error (5xx, `overloaded`, no hint): move to the next lane immediately.
- Then walk the matching row of "Fallback order". When the row is exhausted, do it inline.
- Tell the user in one line which lane failed and which one picked the task up.
- If every lane is exhausted in a session, stop auto-delegating for the rest of it and say so once.

## Long tasks (> 8 minutes)

Claude Code's Bash tool has a hard 10-minute ceiling: a delegate launched in the foreground dies at 10 minutes even while
it is making progress, and that kill is NOT a failure of the delegate.

- Launch long runs with `run_in_background: true` and watch liveness from outside (file writes, CPU, exit notification).
- Prefer resuming the same session of the delegate over starting from scratch after such a kill.
- Ask the delegate to leave work in the tree in small finished steps, so a kill loses minutes, not everything.
