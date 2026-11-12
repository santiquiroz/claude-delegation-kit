<!-- roles: mechanical reasoning second-opinion -->
## bipolar-code broker (MCP) — `mcp__bipolar__delegate`

Self-hosted gateway and delegation broker: https://github.com/santiquiroz/bipolar-code. It exposes an MCP server at `/mcp`
(tools `delegate`, `job_status`, `job_output`, `cancel_job`, `list_agents`), picks the agent by tier and remaining quota,
runs your `verify` commands on the host outside the agents' sandboxes, asks a read-only reviewer and escalates when
something fails. Optional plugin (`/bipolar:delegate`): https://github.com/santiquiroz/bipolar-plugin-cc. Billing: none
of its own; each agent bills its own account.

| Trigger | Action |
|---|---|
| Any delegable task and the `mcp__bipolar__delegate` tool is available | `delegate(task=<contract>, workspace=<absolute repo path>, verify=["<test command>"], wait_s=0)`, then `job_status(job_id, wait_s=540)` until it ends |
| Tests the lanes' sandboxes cannot run (`dotnet test`, async pytest, anything that opens local sockets) | Put them in `verify`: bipolar runs them on the host and sends failures back to the delegate |
| A specific lane is wanted | `agent="<id>"` — a preference, not an order: a busy or unhealthy agent is skipped |
| `ECONNREFUSED` or the tool is missing | bipolar is down: use the plugin subagents of the next lanes of the row |

- Setup: the workspace must be in `delegation.workspace_allowlist`, `allow_request_verify=true` to pass `verify`, and the
  MCP registered once: `claude mcp add --transport http --scope user bipolar http://127.0.0.1:8000/mcp --header "x-api-key: <UI_API_KEY>"`.
- Windows: run bipolar in your interactive session (`scripts/install-session-task.ps1`). In session 0 (a service or a
  password-based scheduled task) the Muse and Codex sandboxes cannot start and the broker skips them with
  `sandbox_requires_interactive_session`.
- `verify` runs without a shell: no `cd`, pass paths as arguments. It executes code the delegate could have changed: use
  it only on your own repos.
- Its `claude` agent is Claude Code on your own subscription: delegating there saves no quota, so keep it near the end.
- Check the result with your own build and tests: a bipolar restart loses the job registry (`job unknown`) while the edits
  are already in the tree. The orchestrator commits.
