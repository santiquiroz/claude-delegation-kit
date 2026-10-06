<!-- roles: reasoning -->
## Codex — `codex:codex-rescue`

OpenAI Codex CLI through the official plugin https://github.com/openai/codex-plugin-cc. Billing: ChatGPT plan credits.

| Trigger | Action |
|---|---|
| Build error (TS, .NET, Angular…) after one failed fix | `codex:codex-rescue` immediately |
| New logic-bearing handler/service/controller/repository | `codex:codex-rescue` in the background for its specs |
| Bug persists after one failed fix | Stop retrying manually; `codex:codex-rescue` |
| Multi-file refactor that changes control flow | `codex:codex-rescue` in a worktree |

- Codex's `workspace-write` sandbox never lets it write `.git`: tell it not to run git add/commit; the orchestrator commits.
- If `codex exec` fails with "model is not supported" or hangs silently, update the CLI (`npm i -g @openai/codex@latest`)
  and diagnose with `codex exec --ignore-user-config -m <model> "Reply ok"`, which shows the real error.
