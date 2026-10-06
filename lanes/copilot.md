<!-- roles: mechanical second-opinion -->
## GitHub Copilot CLI — `copilot:copilot-rescue`

Plugin: https://github.com/santiquiroz/copilot-plugin-cc. Billing: Copilot plan (monthly premium-request allowance).

| Trigger | Action |
|---|---|
| Simple CRUD/mapping specs, mechanical renames across 3+ files, dead code, unused imports | `copilot:copilot-rescue` in the background |
| TypeScript interfaces from backend DTOs, component boilerplate shells, identical config in N files | `copilot:copilot-rescue` |
| PR description for self-explanatory commits | `copilot:copilot-rescue` (not when the WHY lives in the conversation) |
| Second opinion | `copilot:copilot-rescue --read-only` |

- Scoped flags only: `--allow-tool='shell(git:*)' --allow-tool=write --deny-tool='shell(rm)' --deny-tool='shell(git push)'`,
  never `--allow-all`. Deny always wins over allow.
- Any extra shell permission is full code execution: after every run read `.git/config` and `.git/hooks` before running git.
