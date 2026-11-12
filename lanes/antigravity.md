<!-- roles: reasoning mechanical second-opinion -->
## Google Antigravity — `antigravity:antigravity-rescue`

Plugin: https://github.com/santiquiroz/antigravity-plugin-cc. Billing: two independent weekly pools (Gemini; Claude + GPT).

| Trigger | Action |
|---|---|
| Reasoning task and the reasoning lanes before it are out | `antigravity:antigravity-rescue --model gemini-3.1-pro-high` (or a Claude model from the other pool) |
| Mechanical task and the mechanical lanes before it are out | `antigravity:antigravity-rescue --model gemini-3.8-flash-low` |
| Second opinion | `antigravity:antigravity-rescue --read-only` (disposable worktree) |

- An empty pool does not fail fast: agy retries until its timeout and returns `The stream was interrupted`. Check the free
  gauge first (the plugin does): `MSYS_NO_PATHCONV=1 agy -p "/usage"` in Git Bash, which answers without spending a turn.
- When the Gemini pool is low, start in the other one: `--model claude-sonnet-4-6` (reasoning) or
  `--model gpt-oss-120b-medium` (mechanical). `--effort` works only with Gemini models.
- It edits even when told "read only": use `--read-only` for reviews.
