<!-- roles: mechanical second-opinion -->
## JetBrains Junie CLI — `junie:junie-rescue`

Plugin: https://github.com/santiquiroz/junie-plugin-cc (`/junie:rescue`, `/junie:setup`). Billing: default model
`junie-lite` is free (no credits); `--model <name>` (with optional `--effort low|medium|high`) spends JetBrains credits.

| Trigger | Action |
|---|---|
| Bounded task when its usual lane is out or busy | `junie:junie-rescue` in the background |
| Read-only second opinion | `junie:junie-rescue --read-only` (runs in a disposable git worktree; paste the code or diff in the task) |
| Quota or credit limit hit, or sign-in missing (exit 70) | Do not retry Junie; go to the next lane |

- Junie headless is slow (a trivial task took ~35 s). Detached runs last up to 45 minutes (`JUNIE_RESCUE_MAX_SECONDS=2700`);
  the subagent awaits in slices of up to 9 minutes; exit 75 = still running.
- On Windows Junie headless has **no sandbox** and auto-approves every command (ignores allowlist.json): constraints in the
  task are not enforced. Always review `git status` and `git diff` after a run.
- Sign-in: run `junie` once in a normal terminal (JetBrains account), or set `JUNIE_API_KEY`.
- The plugin turns off Junie's default skill/command locations so it does not import `~/.claude`.
- bipolar-code 2.23.0 and later add the broker agent `junie` once to every `tier_order`, right before `deepseek`.
