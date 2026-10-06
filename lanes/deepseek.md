<!-- roles: mechanical reasoning second-opinion -->
## DeepSeek Harness — `deepseek:deepseek-rescue`

Agentic headless lane on the DeepSeek Harness desktop app (`dsh`). Plugin: https://github.com/santiquiroz/deepseek-plugin-cc
(`/deepseek:rescue`, `/deepseek:setup`). Billing: prepaid DeepSeek platform balance, pay as you go.

| Trigger | Action |
|---|---|
| Mechanical task (specs, boilerplate, renames, config, cleanup) | `deepseek:deepseek-rescue` in the background (default `deepseek-flash`) |
| Reasoning task (build broken after one attempt, multi-file refactor, root cause) | `deepseek:deepseek-rescue --model deepseek-v4-pro` in the background |
| Second opinion | `deepseek:deepseek-rescue --read-only`, diff pasted in the task |
| `balance or rate limit hit`, `Insufficient Balance`, `MISSING_CREDENTIAL` | Do not retry; next lane of the row |

- Runs under dsh's own sandbox (`workspace-write`): writes outside the working directory are denied and, headless, every
  escalation is refused. It does not block network or git inside the repo: the task forbids commit/push/reset/checkout.
- Uses the desktop app's login; without it, `DEEPSEEK_API_KEY`.
- Long runs: the subagent starts dsh detached and awaits it in slices of up to 9 minutes (Claude Code's Bash tool kills
  any single call at 10), up to `DEEPSEEK_RESCUE_MAX_SECONDS` (45 minutes by default).
- Windows: the sandbox needs your user to hold an explicit full-control entry on the repo folder, or its shell tool fails
  with `SetNamedSecurityInfoW failed (Win32 5)`. Fix once per tree: `icacls C:\projects /grant <you>:(OI)(CI)F`.
