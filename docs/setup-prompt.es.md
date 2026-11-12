# Configura mi PC: Claude Code como orquestador con bipolar-code y varios agentes

Eres Claude Code en mi PC con Windows. Quiero dejarlo configurado así: tú eres el **orquestador y revisor**, y el código lo escriben otros agentes CLI que ya instalé (los llamamos **carriles**). La delegación pasa por **bipolar-code**, un broker local que expone un servidor MCP en `http://127.0.0.1:8000/mcp`, elige el carril según la cuota disponible, corre las pruebas y pide una revisión. Además vas a instalar los plugins de Claude Code de cada carril para usarlos directamente cuando bipolar esté apagado, y a montar Ollama en mi GPU para la memoria de Claude (claude-mem) y un carril local gratis, con un guardián que libera la GPU cuando abro un juego o un editor.

Trabaja por fases. Comprueba cada paso con un comando real y no des nada por hecho.

## Reglas para todo el proceso

- Usa PowerShell para los comandos de Windows y Git Bash solo para los scripts `.sh`.
- Antes de instalar algo, comprueba si ya está. No compres nada ni cambies planes o suscripciones.
- Hay cosas que solo yo puedo hacer: iniciar sesión en cuentas (OAuth en el navegador), aceptar ventanas de administrador (UAC) y escribir contraseñas. Cuando llegues a una, dame el comando exacto, dime si va en una ventana normal o en una **como administrador**, y espera a que te confirme.
- **Secretos:** nunca muestres en el chat claves, tokens ni el `UI_API_KEY` de bipolar. Léelos de los archivos locales y úsalos directamente en el comando. Las claves de OpenRouter y NVIDIA las pego yo en la web de bipolar (Settings), no en el chat.
- Lleva el progreso en `C:\proyectos\SETUP-PROGRESO.md`: fase, qué quedó OK, qué falta y por qué. Si la sesión se reinicia y te digo «continúa el setup», lee ese archivo y sigue desde donde quedó.
- Al final de cada fase muéstrame una tabla corta: paso, estado (OK / FALTA / NO APLICA) y una nota.
- Si un paso falla, busca la causa real antes de reintentar: lee el error completo y los logs. No repitas el mismo comando más de dos veces.
- Nunca uses flags que desactiven sandboxes o aprueben todo (`--dangerously-*`, `--allow-all`, `--sandbox danger-full-access`). Nunca abras el puerto 8000 a internet.

## Fase 0: inventario

1. Versiones de Windows, `git`, `node` (necesito 22 o más), `npm`, `python` (3.11 o más), `gh` (opcional) y `claude`. Si falta algo, dime cómo instalarlo (por ejemplo con `winget`) y espera.
   También la GPU: tengo una AMD Radeon RX 7900 XT de 20 GB. Confirma el modelo con `Get-CimInstance Win32_VideoController` (su `AdapterRAM` se corta en 4 GB; la VRAM real la verás en la Fase 3) y la versión del driver de AMD.
2. Carriles: para cada CLI, la ruta y la versión si está en el PATH: `muse` (Muse Code de Meta), `codex`, `copilot`, `agy` (Antigravity), `cursor-agent` (Cursor), `junie` (JetBrains Junie; en Windows deja un acceso `~\.local\bin\junie.bat` y el binario en `~\.local\share\junie\versions\<versión>\junie\junie.exe`), `ollama`, `lms` (LM Studio) y DeepSeek Harness (`%LOCALAPPDATA%\Programs\DeepSeek Harness\DeepSeek Harness.exe`). Si un CLI está instalado pero no en el PATH (busca en `%LOCALAPPDATA%\Programs` y en las carpetas de npm), agrégalo al PATH de **usuario**, no al del sistema.
   - Si no tengo Junie, pregúntame si lo instalo: su modelo `junie-lite` es gratis con una cuenta de JetBrains. Se instala con `powershell -NoProfile -Command "iex (irm 'https://junie.jetbrains.com/install.ps1')"` (instalador oficial, para mi usuario, sin administrador).
3. Sesión de cada uno, sin gastar cuota:
   - Muse: `muse sandbox windows check` y si tiene sesión (si no, yo corro `muse login`).
   - Codex: `codex login status` (si no, yo corro `codex login`).
   - Copilot: si la CLI tiene sesión (si no, yo corro `copilot` y dentro escribo `/login`).
   - Antigravity: en Git Bash, `MSYS_NO_PATHCONV=1 agy -p "/usage"` (muestra sus dos pools de cuota semanal sin gastar nada).
   - Cursor: `cursor-agent status` o `cursor-agent about` (si no, yo corro `cursor-agent login`).
   - Junie: tiene sesión si existe algún `~\.junie\dpapi_credentials\*.dpapi` (no lo abras) o la variable `JUNIE_API_KEY`. Si no, yo corro `junie` en una terminal normal y elijo «Continue with JetBrains account».
4. DeepSeek: tengo un acceso directo «DeepSeek (LM Studio)». Si lo que hay es **LM Studio** con un modelo DeepSeek, anótalo así: LM Studio no es un carril de delegación. En bipolar sirve como *provider* local (servidor compatible con OpenAI en `http://localhost:1234`). El carril `deepseek` de bipolar necesita la app **DeepSeek Harness** (`dsh`, cobra por uso); si no está, márcalo NO APLICA.
5. Escribe el inventario en `SETUP-PROGRESO.md`, muéstrame la tabla, dime qué inicios de sesión me faltan y espera a que los haga antes de la Fase 2.

## Fase 1: carpeta de trabajo

1. Crea `C:\proyectos` si no existe. Ahí van todos mis repos. No uses como workspace carpetas bajo `%USERPROFILE%\AppData` ni carpetas sincronizadas con OneDrive: el shell aislado de Muse se cuelga ahí sin mostrar ningún error.
2. Crea `C:\herramientas` para bipolar-code y el kit (quedan fuera de la carpeta en la que trabajan los agentes).
3. Dale a mi usuario control total explícito sobre `C:\proyectos`. Lo necesita el sandbox de DeepSeek Harness; sin eso su shell falla con `SetNamedSecurityInfoW failed (Win32 5)`:
   `icacls C:\proyectos /grant "$($env:USERNAME):(OI)(CI)F"`

## Fase 2: sandboxes (la parte delicada)

1. **Muse.** `muse sandbox windows check` debe decir `status=ready`. Si no, pídeme que corra en PowerShell **como administrador** `muse sandbox windows setup` y que elija «Yes». Eso crea dos cuentas locales restringidas (`muse-sbx-…`) y el grupo `MuseSandboxUsers`: es el sandbox y es normal. Los comandos que corre el agente se ejecutan con esas cuentas y solo pueden tocar la carpeta del proyecto. Vuelve a comprobar.
2. **Permiso de Temp para Muse.** Por defecto, `MuseSandboxUsers` solo hereda lectura sobre mi carpeta Temp, y eso hace que Muse se cuelgue o falle con `UnauthorizedAccessException` al compilar. Revisa `(Get-Acl "$env:LOCALAPPDATA\Temp").Access`. Si el grupo no tiene `Modify` explícito, aplica (solo cuando el grupo ya exista):
   `icacls "$env:LOCALAPPDATA\Temp" /grant "MuseSandboxUsers:(OI)(CI)M"`
   Se revierte con `icacls "$env:LOCALAPPDATA\Temp" /remove:g MuseSandboxUsers`. Si existe el grupo `CodexSandboxUsers`, comprueba que también tenga `Modify` (Codex suele ponerlo solo).
3. **Codex.** Actualiza la CLI: `npm i -g @openai/codex@latest`. Si instalé la app de escritorio de Codex, la app escribe `~/.codex/config.toml` con un modelo que una CLI vieja no soporta, y `codex exec` falla con `model is not supported` o se cuelga sin decir nada. Diagnostica una sola vez (gasta un turno mínimo), desde una carpeta temporal:
   `codex exec --ignore-user-config --skip-git-repo-check -s read-only "Reply with exactly: ok"`
   Si Codex pide permisos de administrador para preparar su sandbox de Windows, avísame para que acepte.
4. **Antigravity y Cursor.** Sus listas de comandos prohibidos las escribe el `/setup` de cada plugin en la Fase 7. No las hagas a mano.

## Fase 3: Ollama local, Corral y guardián de juegos

Ollama corre modelos en mi GPU. Con la RX 7900 XT usa ROCm sin instalar nada aparte del driver de AMD (Adrenalin) al día.

1. **Ollama.** Si no está: `winget install Ollama.Ollama`. Queda en `%LOCALAPPDATA%\Programs\Ollama` y arranca con Windows desde la bandeja. Comprueba `GET http://127.0.0.1:11434/api/version`.
   - Variable de usuario `OLLAMA_NUM_PARALLEL=2` (claude-mem procesa dos sesiones a la vez): `[Environment]::SetEnvironmentVariable('OLLAMA_NUM_PARALLEL', '2', 'User')`. Reinicia Ollama para que la tome: cierra «Ollama» en la bandeja y ábrelo de nuevo.
   - En `%LOCALAPPDATA%\Ollama\server.log`, la línea `inference compute` debe mostrar la 7900 XT con `library=ROCm` y unos 20 GB. Si dice CPU, el driver no está al día: dímelo y espera.
   - **VRAM libre de verdad.** Los programas abiertos también usan VRAM: en un PC de prueba con Edge, Discord, VS Code, Steam, un fondo animado y Phone Link abiertos ya había 9 GB ocupados antes de cargar ningún modelo. Lo que no cabe, Windows lo pasa en silencio a la RAM del sistema por PCIe: `ollama ps` sigue diciendo `100% GPU`, pero el modelo genera de 3 a 10 veces más lento. Con mis programas de siempre abiertos y ningún modelo cargado, mide cuánta VRAM queda: `Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage'` (la instancia con más uso es la 7900 XT; resta ese valor de unos 18,5 GB, porque el driver se reserva algo más de 1 GB de los 20). Anótalo en `SETUP-PROGRESO.md` y dime qué programas usan más VRAM con `Get-Counter '\GPU Process Memory(*)\Dedicated Usage'` (ignora `dwm`, que sale inflado).
2. **Modelos con contexto acotado.** Nunca uses un tag descargado tal cual: su contexto nativo (100K a 256K tokens) reserva tanta memoria que se sale de la VRAM y todo se vuelve lento. Descarga la base con `ollama pull` y crea una variante con un Modelfile (`ollama create <nombre> -f <archivo>`), por ejemplo:

   ```
   FROM qwen3.5:9b
   PARAMETER num_ctx 32768
   PARAMETER num_predict 4096
   ```

   | Para qué | Base | Nombre | Parámetros |
   |---|---|---|---|
   | claude-mem | `qwen3.5:9b` | `qwen3.5-mem` | `num_ctx 32768`, `num_predict 4096`, `temperature 1`, `top_k 20`, `top_p 0.95`, `presence_penalty 1.5`, `num_batch 256` |
   | carril Ollama (delegación de texto) | `devstral:24b` | `ollama-rescue-mechanical` | `num_ctx 32768`, `num_predict 4096` |
   | chat sin censura | `huihui_ai/qwen3.6-abliterated:35b-a3b` | `sin-censura` | `num_ctx 8192`, `num_predict 4096`, `num_gpu 99` |

   - Prueba cada uno con `POST /api/generate` (prompt corto, `"stream": false`) y mira la VRAM real, no la columna PROCESSOR de `ollama ps`, que no ve el desborde. Hay dos maneras: el aviso «Desbordando VRAM» de Corral (paso 3), o `Get-Counter '\GPU Process Memory(pid_<pid>_*)\Shared Usage'` del proceso `llama-server` que lanza Ollama (más de ~0,5 GB compartidos = desborde).
   - `qwen3.5-mem` corre todo el día para claude-mem y **no** debe desbordar. Si desborda, dime qué programas ocupan la VRAM (cerrar el fondo animado o apagar la aceleración por hardware de Discord y del navegador libera varios GB) o baja su `num_ctx` a 16384.
   - Cuando un modelo no cabe junto a otro, Ollama descarga uno para cargar el otro: al chatear con `sin-censura`, claude-mem espera un rato. Es normal.
   - El modelo sin censura es una versión *abliterated* (le quitaron las negativas) de Qwen 3.6 35B-A3B, un MoE: tiene 35B parámetros pero usa solo 3B por token. Por eso aguanta bien no caber entero en la VRAM. En un PC de prueba con 16 GB de VRAM, 9 de ellos ocupados por programas, se midió así:
     - **Este modelo:** 16–17 tok/s, sin negarse a nada, y resolvió bien acertijos y código.
     - **El 27B denso de la misma familia:** cayó a 2 tok/s, porque cuando no cabe se hunde.
     - **`num_gpu 99`:** fuerza todas las capas a la GPU aunque una parte se vaya a la RAM, y salió un 25 % más rápido que dejar que Ollama reparta. Necesita unos 24 GB entre VRAM y RAM.

     Es para chatear desde la ventana de Ollama. No lo uses en claude-mem ni para delegar: con el mismo trabajo de claude-mem fue 2 a 3 veces más lento que `qwen3.5-mem`, con calidad parecida. Si el tag ya no existe, busca en ollama.com un `abliterated` de un Qwen MoE (`a3b` en el nombre) que pese menos de 26 GB y pregúntame antes de bajarlo.
3. **Corral**, una app de bandeja que muestra cuánta VRAM usa cada modelo y pausa o reanuda Ollama con un clic. Busca el asset `*-setup.exe` de la última release con la API pública de GitHub (`https://api.github.com/repos/santiquiroz/corral/releases/latest`), descárgalo a `C:\herramientas\instaladores` y pídeme que lo ejecute (se instala para mi usuario, sin administrador). No está firmado: si sale «Windows protegió su PC», es «Más información» y «Ejecutar de todas formas». Luego, en Corral, Ajustes, que active «Iniciar con Windows (oculto en la bandeja)». Comprueba que quedó la entrada en `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
4. **Guardián de juegos y editores.** Corral pausa a mano; para que la GPU se libere sola está el guardián del kit:
   - Clona ya el kit: `git clone https://github.com/santiquiroz/claude-delegation-kit C:\herramientas\claude-delegation-kit` (la Fase 6 lo usa de nuevo).
   - Copia `scripts\ollama-guard.ps1` y `scripts\ollama-guard.rules.txt` a `C:\herramientas\ollama-guard\`, para que un `git pull` del kit no pise mis reglas. Lee los dos archivos. Cada 5 segundos el guardián revisa los procesos abiertos. Si encuentra un juego (carpetas de Steam, Epic, Xbox, Riot, Ubisoft, GOG y EA) o un editor (DaVinci Resolve, Premiere, After Effects, Photoshop, Blender, CapCut), detiene Ollama y libera la VRAM. Cuando el programa lleva 20 segundos cerrado, vuelve a abrir Ollama y le avisa a claude-mem, que guarda su cola mientras tanto.
   - Con todos mis juegos y editores cerrados, corre `powershell -ExecutionPolicy Bypass -File C:\herramientas\ollama-guard\ollama-guard.ps1 -Check`. Debe decir `heavy processes: none`. Si lista algo, es un programa que vive en esas carpetas pero queda siempre abierto (overlays, fondos animados, mascotas de escritorio). Muéstramelo, agrégalo a las reglas con una línea `!<nombre>.exe` y repite hasta que diga `none`. Con algo en esa lista Ollama quedaría parado para siempre; por eso el instalador se niega a instalar mientras haya coincidencias.
   - Pregúntame qué juegos tengo fuera de esas tiendas (Battle.net, emuladores) y qué otros programas pesados uso, y agrégalos como `<nombre>.exe`.
   - Instala: el mismo script con `-Install`. Crea la tarea `ollama-guard`, que corre en mi sesión, sin administrador.
   - Prueba sin abrir un juego de verdad: copia `C:\Windows\System32\PING.EXE` como `C:\herramientas\ollama-guard\prueba\steamapps\common\Juego\juego.exe` y córrelo con `-n 15 127.0.0.1`. A los 10 segundos el API de Ollama no debe responder y el log `C:\herramientas\ollama-guard\ollama-guard.log` debe decir `paused Ollama: juego.exe running`. Unos 25 segundos después de que termine, Ollama debe responder otra vez. Borra la carpeta `prueba`.
   - Se quita con `-Uninstall`. Si alguna vez Ollama no responde mientras juego, es el guardián: no lo reinicies.

## Fase 4: plugins de Claude Code

Para cada carril instalado, agrega el marketplace e instala el plugin desde PowerShell. Son repos públicos de GitHub; lee el README de cada uno antes de instalarlo.

| Carril | Agregar marketplace | Instalar |
|---|---|---|
| Codex | `claude plugin marketplace add openai/codex-plugin-cc` | `claude plugin install codex@openai-codex` |
| Muse | `claude plugin marketplace add santiquiroz/muse-plugin-cc` | `claude plugin install muse@muse-plugin-cc` |
| Copilot | `claude plugin marketplace add santiquiroz/copilot-plugin-cc` | `claude plugin install copilot@copilot-plugin-cc` |
| Antigravity | `claude plugin marketplace add santiquiroz/antigravity-plugin-cc` | `claude plugin install antigravity@antigravity-plugin-cc` |
| Cursor | `claude plugin marketplace add santiquiroz/cursor-plugin-cc` | `claude plugin install cursor@cursor-plugin-cc` |
| Junie | `claude plugin marketplace add santiquiroz/junie-plugin-cc` | `claude plugin install junie@junie-plugin-cc` |
| bipolar | `claude plugin marketplace add santiquiroz/bipolar-plugin-cc` | `claude plugin install bipolar@bipolar-plugin-cc` |
| Ollama | `claude plugin marketplace add santiquiroz/ollama-plugin-cc` | `claude plugin install ollama@ollama-plugin-cc` |
| claude-mem (memoria entre sesiones) | `claude plugin marketplace add thedotmack/claude-mem` | `claude plugin install claude-mem@thedotmack` |
| DeepSeek Harness (solo si está `dsh`) | `claude plugin marketplace add santiquiroz/deepseek-plugin-cc` | `claude plugin install deepseek@deepseek-plugin-cc` |

Comprueba con `claude plugin list`. Los plugins se cargan al reiniciar Claude Code (Fase 7).

## Fase 5: bipolar-code

1. Clona: `git clone https://github.com/santiquiroz/bipolar-code C:\herramientas\bipolar-code`. Necesito la versión 2.23.0 o más nueva, que trae el agente `junie` (si ya estaba clonado, `git pull`). Lee su `README.md`, sobre todo «Caso de uso 7», «Caso de uso 8», «Arranque con Windows» y «Seguridad».
2. Crea el entorno virtual: `powershell -ExecutionPolicy Bypass -File scripts\setup-venv.ps1` (queda en `%LOCALAPPDATA%\bipolar-code\venv`, fuera del repo a propósito: los sandboxes de Muse y Codex marcan el workspace con integridad baja).
3. Compila la interfaz web: en `frontend`, `npm ci` y `npm run build`. El backend sirve `frontend\dist` en `http://127.0.0.1:8000`.
4. Arranque al iniciar sesión, sin administrador: `powershell -ExecutionPolicy Bypass -File scripts\install-session-task.ps1`. Esa tarea corre bipolar en mi sesión interactiva, que es donde funcionan los sandboxes de Muse y Codex (en la sesión 0 de una tarea de servicio, bipolar los descarta con `sandbox_requires_interactive_session`).
   - El lanzador escucha por defecto en `0.0.0.0`. No voy a usar bipolar desde otros PCs, así que agrega `-BindHost 127.0.0.1` a los argumentos de la acción de la tarea `bipolar-code backend sesion` (con `Get-ScheduledTask` y `Set-ScheduledTask`). Después inicia la tarea (`Start-ScheduledTask`) y comprueba con `Get-NetTCPConnection -LocalPort 8000 -State Listen` que escucha en `127.0.0.1`.
   - No instales `install-autostart.ps1` (arranque sin iniciar sesión): pide administrador y mi contraseña de Windows, y no hace falta.
5. El primer arranque crea `C:\litellm\.env` con `UI_API_KEY`. Léela de ahí para los pasos siguientes, sin mostrarla. Comprueba `GET http://127.0.0.1:8000/api/health` con el header `x-api-key`. Logs: `C:\litellm\bipolar-launcher.log` y `C:\litellm\bipolar-backend.log`.
6. Configura la delegación por API (o en la web: pestaña Agentes). Haz `GET /api/smart/config`, modifica y devuelve con `PUT /api/smart/config` el objeto `delegation` completo y la lista `cli_agents` completa:
   - `delegation.enabled = true`
   - `delegation.workspace_allowlist = ["C:\\proyectos"]`
   - `delegation.allow_request_verify = true`: permite que bipolar corra los comandos de prueba (`verify`) fuera del sandbox. Eso ejecuta código que el agente pudo modificar, así que solo se usa en mis repos.
   - `delegation.review_default = true`
   - `delegation.thinkers = ["codex", "claude"]` (revisores en solo lectura)
   - `delegation.tier_order`, quitando los agentes que no tenga instalados o con sesión:
     - `trivial`: `muse, codex, openrouter, ollama, copilot, antigravity, cursor, claude, junie, deepseek`
     - `simple`: `muse, codex, openrouter, copilot, antigravity, cursor, claude, junie, deepseek`
     - `standard` y `complex`: `muse, codex, openrouter, claude, antigravity, copilot, junie, deepseek`
   - En `cli_agents`: `muse.max_concurrency = 3`; `claude.model_by_tier = {"trivial": "haiku", "simple": "sonnet", "standard": "sonnet", "complex": "opus"}`; `enabled = false` en los agentes que no tenga (deja `anthropic` apagado: necesita una clave de API de Anthropic con créditos).
   - **Junie**: si quedó con sesión, `enabled = true` con el modelo que trae (`junie-lite`, gratis). No le pongas otro modelo: la capa gratis solo permite ese y los demás gastan créditos de JetBrains. Ojo: en Windows, Junie sin interfaz aprueba cualquier comando solo y no tiene sandbox. Por eso va de penúltimo, y bipolar solo lo usa dentro de `C:\proyectos`.
   - **OpenRouter** (gratis, 50 requests por día): pídeme que cree una clave en openrouter.ai **con límite de crédito 0** y que la pegue en Settings de bipolar (`OPENROUTER_API_KEY`). Luego, en `cli_agents`, el agente `openrouter`: `enabled = true`, `workspace_allowlist = ["C:\\proyectos"]` (tiene lista propia; vacía, rechaza todo), `default_model` = un modelo `:free` vigente que soporte tools (consulta `https://openrouter.ai/api/v1/models` y filtra los `:free` cuyo `supported_parameters` incluya `tools`) y dos `fallback_models` `:free`.
   - Vuelve a hacer `GET /api/smart/config` y muéstrame una tabla de agentes: instalado, sesión, cuota.
7. Providers (opcional, para el chat y el proxy, no para delegar): si pegué una clave de NVIDIA NIM en Settings, o si uso LM Studio, comprueba que el provider aparezca en la pestaña Providers.
8. Registra el MCP a nivel de usuario. Arma el comando con la clave leída del `.env`, sin imprimirla:
   `claude mcp add --transport http --scope user bipolar http://127.0.0.1:8000/mcp --header "x-api-key: <UI_API_KEY>"`
   Usa `127.0.0.1` y no `localhost`, porque bipolar solo escucha en IPv4.

## Fase 6: reglas de delegación, estado de carriles y hooks

Todo sale del kit https://github.com/santiquiroz/claude-delegation-kit, que también trae este prompt en `docs/setup-prompt.es.md`.

1. Clónalo en `C:\herramientas\claude-delegation-kit` (si ya está, `git pull`).
2. Edita su `lanes.conf`: deja solo mis carriles instalados y con sesión, en el orden que trae (`bipolar` primero; `openrouter` solo si quedó configurado en bipolar).
3. Genera las reglas en Git Bash: `bash scripts/build-claude-md.sh > ~/.claude/delegation.md`. Agrega la línea `@delegation.md` al final de `~/.claude/CLAUDE.md` (créalo si no existe; no borres lo que tenga). Las reglas están en inglés: son para ti, está bien.
4. Estado de carriles: copia `scripts/lanes-status.sh` a `~/.claude/scripts/` y `lanes.conf` a `~/.claude/lanes.conf` (el script busca `lanes.conf` en la carpeta padre de la suya). Córrelo: `bash ~/.claude/scripts/lanes-status.sh`. Lee las claves de bipolar y OpenRouter del `.env` sin mostrarlas.
5. Hooks que le recuerdan a Claude delegar: copia `hooks/delegation-agent-nudge.mjs` y `hooks/delegation-plan-nudge.mjs` a `~/.claude/hooks/`, y **fusiona** (no reemplaces) `hooks/settings.example.json` en `~/.claude/settings.json`. Valida que `settings.json` siga siendo JSON válido.
6. Corre `bash tests/run.sh` del kit: todo debe salir PASS.

## Fase 7: reinicio y setup de cada plugin

1. Actualiza `SETUP-PROGRESO.md` y dime que cierre Claude Code, lo abra de nuevo en `C:\proyectos` (`cd C:\proyectos; claude`) y escriba «continúa el setup».
2. Después del reinicio, corre el setup de cada plugin instalado (están como comandos o skills): `/codex:setup`, `/muse:setup`, `/copilot:setup`, `/antigravity:setup` (escribe la lista de comandos prohibidos en `~/.gemini/antigravity-cli/settings.json`; el plugin se niega a correr sin ella), `/cursor:setup` (crea `~/.cursor-rescue` con su lista de comandos prohibidos y aísla a Cursor de los hooks de `~/.claude`, que en Windows le bloquean todo), `/junie:setup` (revisa la CLI y la sesión sin mostrar credenciales), `/bipolar:setup`, y `/ollama:setup` o `/deepseek:setup` si aplican.
3. Comprueba que tienes las herramientas `mcp__bipolar__*` y llama `list_agents`.
4. **claude-mem con el modelo local y sin «pensar».** Usa el proveedor `openrouter` de claude-mem apuntado a Ollama, no el `openai-compatible`. El motivo: `qwen3.5-mem` piensa por defecto y gasta miles de tokens en cada observación. Medido: una observación de 8.000 tokens tardaba 141 s, y a veces quedaba vacía porque el pensamiento se comía todo el presupuesto; sin pensar, 23 s. Para apagarlo, Ollama necesita `reasoning_effort: "none"` en la petición. El proveedor `openai-compatible` manda `reasoning: {enabled: false}`, que Ollama ignora, y no tiene dónde agregar campos. El proveedor `openrouter` sí los tiene, con `EXTRA_BODY`. En `~/.claude-mem/settings.json` (respáldalo antes) o en la web del worker (`http://127.0.0.1:37777`), pon:
   - `CLAUDE_MEM_PROVIDER = openrouter`
   - `CLAUDE_MEM_OPENROUTER_BASE_URL = http://127.0.0.1:11434/v1` (con `127.0.0.1`: Ollama solo escucha en IPv4)
   - `CLAUDE_MEM_OPENROUTER_MODEL = qwen3.5-mem`
   - `CLAUDE_MEM_OPENROUTER_API_KEY = ollama` (Ollama no la mira, pero el proveedor no arranca con la clave vacía)
   - `CLAUDE_MEM_OPENROUTER_EXTRA_BODY = {"reasoning_effort":"none"}` (es un texto con JSON adentro)

   Edita `settings.json` cargándolo y guardándolo como JSON (por ejemplo con Python), no con reemplazos de texto: tiene otras claves. El worker relee el archivo en cada llamada (verificado en claude-mem 15.18), así que no hace falta reiniciarlo. Si falta el modelo, claude-mem vuelve en silencio a usar Claude y gasta mi plan. Comprueba tres cosas después de una sesión que use herramientas:
   - en los logs de claude-mem (`~/.claude-mem/logs/`), que no haya errores del proveedor;
   - con `ollama ps`, que `qwen3.5-mem` se cargó;
   - en `%LOCALAPPDATA%\Ollama\server.log`, que las líneas `eval time = … / N tokens` tengan N en los cientos y no en los miles. Si son miles, sigue pensando.

## Fase 8: prueba de punta a punta

1. Crea `C:\proyectos\prueba-delegacion` con `git init`, un `README.md` y un commit inicial.
2. Delega por el MCP: `delegate(task="Crea hola.py que imprima 'hola desde bipolar'. No hagas commit. Al final lista los archivos tocados.", workspace="C:\\proyectos\\prueba-delegacion", verify=["python hola.py"], wait_s=0)`. Luego `job_status(job_id, wait_s=540)` hasta que termine. Muéstrame qué agente lo hizo, el resultado de `verify`, la revisión y `files_touched`, y revisa `git status` y `git diff`.
3. Prueba un plugin directo: `muse:muse-rescue --read-only` con la tarea «explica en dos líneas qué hace hola.py» (pega el contenido del archivo en la tarea).
4. Corre `lanes-status.sh` otra vez.
5. Resumen final: tabla de todo lo configurado, lo que quedó pendiente y por qué, cómo reiniciar bipolar si se cae (detener el proceso que escucha en el puerto 8000 y `Start-ScheduledTask 'bipolar-code backend sesion'`), cómo pausar Ollama a mano (Corral) y dónde editar las reglas del guardián.
