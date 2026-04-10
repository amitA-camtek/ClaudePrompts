# Falcon System Context — Audit Log Prompts

> **Purpose:** Provides the system facts needed for all audit log prompts.
> Full architecture is documented in [`../system/output/system.md`](../system/output/system.md).
> This file contains only the subset relevant to file monitoring under `c:\job\`.

---

## Relevant Deployment Paths

| Path | Purpose |
|---|---|
| `c:\job\` | RMS job/recipe files — primary scope for this audit |
| `c:\falcon\data\` | Machine-specific config (`config.ini`, calibration data) |
| `c:\bis\bin\` | BIS application binaries and shared DLLs |
| `c:\bis\errorlog\` | Application error logs |

---

## Services That Write to `c:\job\`

| Service | Language/Framework | Role | Writes to `c:\job\` |
|---|---|---|---|
| **RMS** (Recipe Management System) | ASP.NET Core, gRPC (ports 5001, 5020) | Manages job/recipe lifecycle — create, load, save, delete | Yes — primary writer |
| **Falcon.Net** | C# .NET Framework, COM | Main application entry point; loads and runs jobs | Reads jobs; may write result/status files |
| **AOI_Main** | C# .NET Framework, COM callbacks | Test automation orchestrator | Reads job state; may write `.seq` or config overrides |
| **DataServer** | WCF, net.tcp (ports 8002–8272) | Centralized data broker | Indirectly (via RMS job export) |
| **JobSelect.Net** | WinForms | Job selection UI | Reads job list; triggers RMS job load |

---

## Known File Types in `c:\job\`

| Extension | Typical content | Owner |
|---|---|---|
| `.xml` | Job definition, recipe parameters | RMS |
| `.ini` | Job-level configuration overrides | RMS / Falcon.Net |
| `.json` | Structured recipe data (newer format) | RMS |
| `.csv` | Die map, threshold tables | RMS / AOI_Main |
| `.txt` | Notes, parameter dumps | Various |
| `.seq` | Scan sequence definition | AOI_Main |
| `.log` | Per-job run log | Falcon.Net / AOI_Main |
| `.cfg` | Component-level config | DataServer / RMS |

---

## Integration Points Relevant to Monitoring

- **COM callbacks:** `RegisterScanEvent`, `RegisterAutoCycleEvent`, `RegisterFalconGuiEvent` — fire on scan/job events but do NOT expose file-level change notifications
- **RMS gRPC:** Job CRUD operations go through RMS; no built-in file-change webhook
- **No existing file watcher:** The system uses event-driven COM/gRPC for state, not `FileSystemWatcher`

---

## Technology Baseline

- **.NET Framework 4.8 / C# 7.3** — current runtime for `Falcon.Net` and `AOI_Main`
- **.NET 6+ / C# 10** — available for a new standalone Windows Service
- **SQLite** — chosen DB for the audit log (local, embedded, no server)
- **No RabbitMQ from AOI_Main** — message bus not used in the monitoring path
