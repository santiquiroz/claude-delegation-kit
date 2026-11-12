<!-- roles: mechanical reasoning second-opinion -->
## DeepSeek Harness — `deepseek:deepseek-rescue`

Last resort: agentic headless runs of the DeepSeek Harness desktop app (`dsh`). Plugin:
https://github.com/santiquiroz/deepseek-plugin-cc (`/deepseek:rescue`, `/deepseek:setup`). Billing: prepaid DeepSeek
platform balance, pay per token — every other lane is a subscription you already pay for or free.

| Trigger | Action |
|---|---|
| Mechanical task and every mechanical lane before it is out | `deepseek:deepseek-rescue` in the background (default `deepseek-flash`) |
| Reasoning task and every reasoning lane before it is out | `deepseek:deepseek-rescue --model deepseek-v4-pro` in the background |
| Second opinion and every other review lane is out | `deepseek:deepseek-rescue --read-only`, diff pasted in the task |
| `balance or rate limit hit`, `Insufficient Balance`, `MISSING_CREDENTIAL` | Do not retry; inline (it is the last lane) |

- Runs under dsh's own sandbox (`workspace-write`): writes outside the working directory are denied and, headless, every
  escalation is refused. It does not block network or git inside the repo: the task forbids commit/push/reset/checkout.
- Uses the desktop app's login; without it, `DEEPSEEK_API_KEY`. lanes-status sees the login, not the balance: after the
  first `Insufficient Balance` treat it as exhausted for the rest of the session.
- Long runs: the subagent starts dsh detached and awaits it in slices of up to 9 minutes (Claude Code's Bash tool kills
  any single call at 10), up to `DEEPSEEK_RESCUE_MAX_SECONDS` (45 minutes by default).
- Windows: the sandbox needs your user to hold an explicit full-control entry on the repo folder, or its shell tool fails
  with `SetNamedSecurityInfoW failed (Win32 5)`. Fix once per tree: `icacls C:\projects /grant "$($env:USERNAME):(OI)(CI)F"`.
