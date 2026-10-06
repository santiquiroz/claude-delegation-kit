<!-- roles: mechanical -->
## Ollama (local, free) — `ollama:ollama-rescue`

Plugin: https://github.com/santiquiroz/ollama-plugin-cc. Billing: none (your GPU).

| Trigger | Action |
|---|---|
| Pure mechanical text task (boilerplate, renames, simple specs, PR descriptions) on a machine with Ollama | `ollama:ollama-rescue` in the background |
| Service down, model missing or visibly wrong output | Next lane of the row |

- Text completion only: it never touches files. Review the returned text and apply it yourself; lowest trust tier.
- Use context-capped model tags (e.g. `-32k` variants). Raw tags default to their native context and spill out of VRAM.
