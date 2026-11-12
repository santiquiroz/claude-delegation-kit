<!-- roles: mechanical reasoning second-opinion -->
## OpenRouter free models (through bipolar) — `delegate(..., agent="openrouter")`

bipolar-code's `openrouter` agent runs Claude Code headless against OpenRouter's Anthropic-compatible API with `:free`
models only; the adapter refuses any other model, so it cannot spend credits. No plugin: it is used only through the
bipolar MCP. Billing: free daily allowance (50 requests/day; 1000/day once the account has bought 10 credits).

| Trigger | Action |
|---|---|
| Bounded or mechanical task and the lanes before it are out | `mcp__bipolar__delegate(..., agent="openrouter")` |
| Task that needs secrets, connection strings or personal data in the prompt | Never: free models may store and train on prompts |
| `free-models-per-day` (429) | Daily allowance gone; bipolar marks it exhausted for a day: next lane |

- It has its own `workspace_allowlist` in bipolar (empty = every job refused).
- Key: `OPENROUTER_API_KEY` in bipolar's `.env`. The agent runs with Bash and can read it: use a dedicated key with a
  credit limit of 0 (lanes-status warns when it is not).
- Each Claude Code turn is one request: 50 cover one or two small tasks. Split reviews of big diffs into pieces of 1-2 files.
- Non-Anthropic models handle Claude Code's tool calls worse: short, self-contained tasks, and review the diff.
- Set `default_model` to a current `:free` model with tool support and two `fallback_models`: when one is rate limited,
  overloaded or retired, bipolar retries with the next (the daily allowance does not switch models).
