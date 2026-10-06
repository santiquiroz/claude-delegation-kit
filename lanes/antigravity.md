<!-- roles: reasoning mechanical second-opinion -->
## Google Antigravity — `antigravity:antigravity-rescue`

Plugin: https://github.com/santiquiroz/antigravity-plugin-cc. Billing: two independent weekly pools (Gemini; Claude + GPT).

| Trigger | Action |
|---|---|
| Reasoning task and the reasoning lanes before it are out | `antigravity:antigravity-rescue --model gemini-3.1-pro-high` (or a Claude model from the other pool) |
| Mechanical task and the mechanical lanes before it are out | `antigravity:antigravity-rescue --model gemini-3.8-flash-low` |
| Second opinion | `antigravity:antigravity-rescue --read-only` (disposable worktree) |

- An empty pool does not fail fast: agy retries until its timeout. Check the free `/usage` gauge first (the plugin does).
- It edits even when told "read only": use `--read-only` for reviews.
