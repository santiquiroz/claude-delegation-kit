<!-- roles: mechanical second-opinion -->
## Cursor Agent CLI — `cursor:cursor-rescue`

Plugin: https://github.com/santiquiroz/cursor-plugin-cc. Billing: Cursor plan (Free runs only the `auto` model).

| Trigger | Action |
|---|---|
| Bounded task (a spec, a rename, boilerplate, one build fix) when its usual lane is out or busy | `cursor:cursor-rescue` in the background |
| Read-only second opinion | `cursor:cursor-rescue --read-only` (ask mode: no edits, no shell; paste the diff) |

- Cursor imports your `~/.claude` hooks, skills and permissions; on Windows a Claude Code hook can block every tool call.
  The plugin isolates Cursor from `~/.claude` when that happens.
- Never let `--model` hit your own Cursor config on a Free plan: a named model there breaks every later run.
