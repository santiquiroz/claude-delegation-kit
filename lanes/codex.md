<!-- roles: mechanical reasoning second-opinion -->
## Codex — `codex:codex-rescue`

Second lane for every kind of task: OpenAI Codex CLI through the official plugin https://github.com/openai/codex-plugin-cc.
Billing: ChatGPT plan credits.

| Trigger | Action |
|---|---|
| Muse is out or busy, any kind of task | `codex:codex-rescue` in the background |
| Build error (TS, .NET, Angular…) after one failed fix | `codex:codex-rescue` immediately |
| Bug persists after one failed fix | Stop retrying manually; `codex:codex-rescue` |
| Multi-file refactor that changes control flow | `codex:codex-rescue` in a worktree |
| Read-only second opinion | `codex exec --sandbox read-only -C <dir> - < task.md` (the answer is at the end of the log) |

- Codex's `workspace-write` sandbox never lets it write `.git`: tell it not to run git add/commit; the orchestrator commits.
- If `codex exec` fails with "model is not supported" or hangs silently, update the CLI (`npm i -g @openai/codex@latest`)
  and diagnose with `codex exec --ignore-user-config --skip-git-repo-check -s read-only "Reply with exactly: ok"`, which
  shows the real error (`out of credits`, model, auth). The desktop app writes its own model into `~/.codex/config.toml`.
- Long tasks (> 8 minutes): launch with `run_in_background: true`; if the Bash tool killed it at 10 minutes while it was
  progressing, resume the same thread with `codex exec resume <session id> "<continue>"` instead of starting over.
