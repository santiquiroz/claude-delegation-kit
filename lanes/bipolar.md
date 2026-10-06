<!-- roles: mechanical -->
## bipolar-code (big local model on your LAN + CLI broker) — `bipolar:bipolar-rescue`

Server: https://github.com/santiquiroz/bipolar-code. Plugin: https://github.com/santiquiroz/bipolar-plugin-cc. Billing: none.

| Trigger | Action |
|---|---|
| Well-specified medium mechanical task that touches files (multi-file renames, specs with pasted signatures) | `bipolar:bipolar-rescue` in the background |
| Unsure which lane has quota and the task is self-contained | `/bipolar:delegate <task>`: the broker picks the agent by tier and remaining quota and fails over by itself |
| Server or model down | Next lane of the row |

- Self-contained tasks only: a local model follows exact instructions well and improvises badly.
