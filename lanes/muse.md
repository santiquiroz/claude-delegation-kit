<!-- roles: mechanical reasoning second-opinion -->
## Muse (Meta) — `muse:muse-rescue`

First lane: agentic headless runs of Meta's coding agent (`muse exec`). Plugin: https://github.com/santiquiroz/muse-plugin-cc
(`/muse:rescue`, `/muse:setup`). Billing: Muse Code subscription (short window plus a weekly limit, no headless meter).

| Trigger | Action |
|---|---|
| Bounded task (a spec, a rename, boilerplate, config, one fix, a PR description) | `muse:muse-rescue` in the background, first |
| Reasoning task (build broken after one attempt, multi-file refactor, root cause) | `muse:muse-rescue` in the background; if it comes back unusable or incomplete, next lane |
| Read-only second opinion or investigation | `muse:muse-rescue --read-only` (no writes, no shell; paste the code or the diff) |
| Several independent subtasks | Up to 3-4 Muse jobs at once on different files |
| `Muse quota or rate limit hit`, login error | Do not retry; next lane of the row (`muse login` for auth) |

- Slow headless: 25 s to 15 minutes per task. Runs are detached and awaited in slices of up to 9 minutes (`start` +
  `wait`), up to `MUSE_RESCUE_MAX_SECONDS` (45 minutes by default). Slowness is no reason to skip it: keep working meanwhile.
- Another directory (another repo, a git worktree): pass `-C <dir>` before the task, or Muse runs in the session folder and
  its sandbox denies writes to the other one.
- Runs under Muse's own sandbox (writes confined to the workspace, network only through its proxy), `--approval-mode never`
  and `--no-foreign-personal-context` (without it Muse loads your `~/.claude` rules and delegates recursively).
- Its sandbox cannot run anything that opens local sockets (`dotnet test`, `ng test`, `npx`): tell it "do not run the
  tests" and run them yourself or through bipolar's `verify`. A `dotnet restore` without network can also break `obj/`.
- When its quota runs out mid-run it can leave files empty and still report it finished: check `git diff --stat`.
- Two jobs can deadlock on the sandbox's global ACL lock ("ACL publication lock … timed out"): cancel one, rerun in series.
- Windows: `muse sandbox windows check` must say `status=ready` (else `muse sandbox windows setup`, elevated). Give the
  `MuseSandboxUsers` group write access to your Temp folder once, or builds fail with `UnauthorizedAccessException`:
  `icacls "$env:LOCALAPPDATA\Temp" /grant "MuseSandboxUsers:(OI)(CI)M"`. A workspace under `%USERPROFILE%\AppData`
  makes the sandboxed shell hang with no error.
