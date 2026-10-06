<!-- roles: mechanical second-opinion -->
## Muse (Meta) — `muse:muse-rescue`

Agentic headless lane on Meta's coding agent (`muse exec`). Plugin: https://github.com/santiquiroz/muse-plugin-cc
(`/muse:rescue`, `/muse:setup`). Billing: Muse subscription.

| Trigger | Action |
|---|---|
| Bounded task (a spec, a rename, boilerplate, one fix) when the lane before it is busy or out of balance | `muse:muse-rescue` in the background |
| Read-only second opinion or investigation in parallel to another lane | `muse:muse-rescue --read-only` (no writes, no shell) |
| `Muse quota or rate limit hit`, login error | Do not retry; next lane of the row (`muse login` for auth) |

- Slow headless (a trivial task takes 25 s to 4 minutes). Runs are detached and awaited in slices of up to 9 minutes
  (`start` + `wait`), so a run can last up to `MUSE_RESCUE_MAX_SECONDS` (45 minutes by default).
- Runs under Muse's own sandbox (writes confined to the workspace, shell without direct internet), `--approval-mode never`
  (nothing is ever auto-approved; a request to run unsandboxed is refused) and `--no-foreign-personal-context` (without it
  Muse loads your `~/.claude` rules, including these, and may delegate recursively).
- Windows: `muse sandbox windows check` must say `status=ready`. A workspace inside a folder private to your user (e.g. under
  `%USERPROFILE%\AppData`) makes the sandboxed shell hang with no error. A killed run can leave an orphan sandbox worker that
  holds a global lock and breaks the next runs: the plugin cleans it up.
