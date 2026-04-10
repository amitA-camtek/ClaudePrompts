# Audit Log — Output 3: Monitoring Service Alternatives

> **Input:** `output/02_file_summary.md` + `system.md` + codebase  
> **Date:** 2026-04-10  
> **Platform context:** .NET Framework 4.8 / C# 7.3 (Falcon.Net, AOI_Main); .NET 6+ available for new standalone processes

---

## Option A: Embedded FileSystemWatcher in `falcon.net.aoi_main`

### Architecture Sketch

```
AOI_Main process (STA COM thread)
│
├── AppStartup
│   └── new FileAuditEmbedded()     ← created AFTER COM registration completes
│       ├── FileSystemWatcher(c:\job, recursive=true)
│       │   ├── Created / Changed / Deleted / Renamed
│       │   └── Error → restart watcher
│       ├── BlockingCollection<ChangeEvent> _queue
│       └── Thread _writerThread     ← dedicated background (MTA) thread
│           └── SqliteWriter (WAL mode)
│
└── AppShutdown
    └── FileAuditEmbedded.Dispose()
        ├── _watcher.EnableRaisingEvents = false
        ├── _queue.CompleteAdding()
        └── _writerThread.Join(5 s)
```

**Owner class:** A new `FileAuditService` class, instantiated from `AOI_Main`'s main startup routine after COM STA apartment initialization is complete.

**Thread model:** The `FileSystemWatcher` raises events on ThreadPool (MTA) threads. Events are posted to a `BlockingCollection<ChangeEvent>`. A dedicated background MTA thread drains the queue and writes to SQLite — this keeps COM STA clean and avoids any threading conflict.

**SQLite initialization:** `SqliteConnection` opened once on the writer thread at startup; connection held open with WAL journal mode enabled (`PRAGMA journal_mode=WAL`).

### SQLite Access Pattern

The FSW callback (ThreadPool/MTA) only enqueues a lightweight `ChangeEvent` struct (filepath, change type, timestamp). The dedicated writer thread is the sole SQLite writer — no lock contention.

### Error Handling

- SQLite locked → retry with exponential backoff (max 3 s); log error to Windows Event Log if persistent. Machine continues operating — the queue continues accumulating events in memory.
- Disk full → write SQLite error to Event Log; disable audit temporarily; alert operator via existing Falcon.Net alarm mechanism.
- FSW buffer overflow (`Error` event) → log warning, restart watcher, run a catch-up hash scan on `c:\job\` in the writer thread.

### Pros

1. **No separate process to deploy** — ships as part of the existing `AOI_Main` installer
2. **Guaranteed lifecycle** — watcher starts and stops with the machine application; no orphan watchers
3. **No IPC overhead** — events flow in-process via a queue; sub-millisecond latency from file change to queue entry
4. **Reuses existing COM/RMS event context** — future extension could correlate FSW events with active job/recipe loaded in AOI_Main's internal state

### Cons

1. **Failure coupling** — a crash in the audit code (e.g., SQLite corruption) could destabilize `AOI_Main`; requires careful isolation with try/catch at every boundary
2. **COM STA constraint** — must never call SQLite or queue operations from the COM STA thread; threading discipline must be maintained across all contributors
3. **Process restart loses state** — if `AOI_Main` restarts, in-flight queue events are lost; no catch-up scan is naturally triggered
4. **.NET Framework 4.8 target** — limited to older SQLite NuGet packages (`System.Data.SQLite`); WAL mode support is available but less ergonomic than modern .NET
5. **Harder to test independently** — must stub COM infrastructure to unit-test the audit component

### Complexity

- Estimated new code: ~400–600 lines (FSW wiring, queue, SQLite writer, classifier, error handling)
- New dependencies: `System.Data.SQLite` (already likely present) or `Microsoft.Data.Sqlite`
- Deployment: added to existing `AOI_Main` build; no separate installer step

### Risk to Falcon Operation

**Medium** — The writer thread and queue are isolated from COM callbacks. However, any unhandled exception that propagates past the catch boundaries in the writer thread could terminate the process. Thorough exception handling is mandatory.

---

## Option B: External Standalone Windows Service (.NET 6+)

### Architecture Sketch

```
Windows SCM
│
└── FalconAuditService.exe  (runs as LocalSystem or dedicated svc account)
    │
    ├── Worker : BackgroundService
    │   ├── StartAsync()
    │   │   ├── CatchUpScanner.Run()     ← hash-compare current files vs baseline
    │   │   └── FileMonitorService.Start()
    │   └── StopAsync()
    │       └── FileMonitorService.Stop()
    │
    ├── FileMonitorService
    │   ├── FileSystemWatcher(c:\job, recursive=true)
    │   ├── Dictionary<string, Timer> _debounceTimers
    │   └── BlockingCollection<ChangeEvent> → SqliteRepository
    │
    ├── FileClassifier
    │   └── Classify(path) → (module, ownerService, priority)
    │
    ├── HashHelper
    │   └── SHA256File(path) → string
    │
    ├── SqliteRepository (WAL mode, serialized write)
    │   ├── InsertAuditLog(entry)
    │   └── UpsertBaseline(filepath, hash, size)
    │
    └── CatchUpScanner
        └── Run(watchPath, db) — on-start reconciliation
```

**Service registration:** Standard .NET 6 `UseWindowsService()` + `IHostedService`. Registered with SCM via `sc.exe` or `install.ps1`.

**FSW survival across pause/resume:** On `StopAsync`, `EnableRaisingEvents = false`; on `StartAsync` (resume), re-enable and immediately run `CatchUpScanner` to catch any changes during downtime.

### Startup Scan (Catch-Up)

On service start, `CatchUpScanner` performs:
1. Enumerate all included files under `c:\job\`.
2. For each file: compute SHA-256; compare to `file_baseline` table.
3. If not in baseline → insert `Created` audit event.
4. If hash differs → insert `Modified` audit event (old_hash from baseline, new_hash current).
5. Update baseline for all present files.
6. Query `file_baseline` for any filepath no longer on disk → insert `Deleted` audit event; remove baseline row.

### SQLite Schema (Draft)

```sql
CREATE TABLE audit_log (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    filepath         TEXT    NOT NULL,
    filename         TEXT    NOT NULL,
    extension        TEXT    NOT NULL,
    change_type      TEXT    NOT NULL CHECK(change_type IN ('Created','Modified','Deleted','Renamed')),
    old_hash         TEXT,
    new_hash         TEXT,
    old_content      TEXT,
    new_content      TEXT,
    diff_text        TEXT,
    module           TEXT,
    owner_service    TEXT,
    monitor_priority TEXT,
    detected_at      TEXT    NOT NULL,
    machine_name     TEXT    NOT NULL
);
CREATE INDEX idx_al_filepath   ON audit_log(filepath);
CREATE INDEX idx_al_detected   ON audit_log(detected_at);
CREATE INDEX idx_al_priority   ON audit_log(monitor_priority);

CREATE TABLE file_baseline (
    filepath         TEXT PRIMARY KEY,
    last_hash        TEXT NOT NULL,
    last_seen        TEXT NOT NULL,
    last_size        INTEGER,
    module           TEXT,
    monitor_priority TEXT
);

CREATE TABLE monitor_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

### Pros

1. **Full process isolation** — a crash in the audit service does not affect `AOI_Main`, RMS, or any other Falcon component
2. **Independent lifecycle** — service can be restarted, upgraded, or disabled without touching the machine application
3. **Modern .NET 6+ runtime** — access to `Microsoft.Data.Sqlite` (in-process, no external DLL), `System.IO.Hashing`, `DiffPlex` NuGet packages
4. **Clean catch-up on restart** — `CatchUpScanner` is a natural service-start step; no special COM-context requirements
5. **Testable independently** — no COM stubs needed; standard xUnit / MSTest unit tests

### Cons

1. **Separate deployment artifact** — requires its own installer, `install.ps1`, and SCM registration; must be included in machine imaging
2. **Machine admin rights** for install — service registration requires elevation; operator procedure needed
3. **No job-context knowledge** — the service sees file changes but does not know which job is currently loaded (no native access to AOI_Main's internal state)
4. **Startup gap** — if the service is stopped (e.g., during a Windows Update reboot) and files change before restart, the catch-up scan detects the change but cannot determine *exactly* when it occurred

### Complexity

- Estimated new code: ~800–1,000 lines
- New NuGet packages: `Microsoft.Data.Sqlite`, `DiffPlex` (diff generation), `Microsoft.Extensions.Hosting.WindowsServices`
- Deployment steps: build self-contained exe; run `install.ps1 -Action Install`; set `sc config FalconAudit start= auto`

### Deployment

```powershell
# install.ps1
param([string]$Action = 'Install')
$svcName = 'FalconAuditService'
$exePath = 'C:\bis\bin\FalconAuditService\FalconAuditService.exe'
if ($Action -eq 'Install') {
    sc.exe create $svcName binPath= $exePath start= auto obj= LocalSystem
    sc.exe description $svcName "Falcon c:\job\ file audit logger"
    sc.exe start $svcName
} elseif ($Action -eq 'Uninstall') {
    sc.exe stop $svcName
    sc.exe delete $svcName
}
```

---

## Option C: PowerShell / Python Agent (Scheduled Task)

### Architecture Sketch

**Variant chosen: PowerShell poll-based agent, invoked every 30 seconds by Task Scheduler.**

```
Windows Task Scheduler
│
└── FalconAuditPoll.ps1  (runs as SYSTEM, every 30 s)
    │
    ├── Load state: last-seen hashes from SQLite (via System.Data.SQLite.dll)
    ├── Enumerate c:\job\ (include-list filter)
    ├── For each file:
    │   ├── Compute hash (Get-FileHash -Algorithm SHA256)
    │   ├── Compare to stored hash
    │   └── Write audit row to SQLite if changed
    ├── Detect deletes: files in DB not found on disk
    └── Update baseline table
```

**Persistent state:** `file_baseline` table in the same SQLite database.

**SQLite from PowerShell:** Load `System.Data.SQLite.dll` from a fixed path (`C:\bis\bin\System.Data.SQLite.dll`) using `Add-Type -Path`.

**Event-based alternative:** `Register-ObjectEvent` on a `FileSystemWatcher` within a persistent PowerShell session — more responsive but requires keeping a PowerShell session alive, which is fragile.

### Change Detection Algorithm

On each 30-second poll:
1. Query `file_baseline` → `$knownHashes` dictionary.
2. `Get-ChildItem -Recurse` → `$currentFiles`.
3. For each `$currentFile`: hash it; compare to `$knownHashes[$path]`.
   - Not in known → **Created** event.
   - Hash differs → **Modified** event.
   - Update/insert baseline.
4. For each `$path` in `$knownHashes` not in `$currentFiles` → **Deleted** event; remove baseline row.

Minimum safe polling interval: **30 seconds** — on 190 files averaging ~2 KB each, SHA-256 hashing takes <200 ms on typical Falcon hardware; SQLite writes take <50 ms. At 30 s this is a <1.5 % CPU duty cycle.

### SQLite Access

`System.Data.SQLite` NuGet package, DLL deployed alongside the script. WAL mode enabled. Single connection per poll invocation (opened, used, closed).

### Pros

1. **Zero new compiled code** — pure script; no build pipeline, no IDE required for changes
2. **Easiest to audit and modify** — plain-text PowerShell readable by any engineer
3. **No SCM registration required** — Task Scheduler is sufficient; no admin service overhead
4. **Portable** — can be enabled on any Falcon machine by copying two files (script + SQLite DLL)

### Cons

1. **30-second minimum detection latency** — changes made and reverted within one poll window are invisible; fine for recipe edits but misses transient file states
2. **Misses rapid sequences** — if a file is Created, Modified, then Deleted within 30 s, the net result looks like no change
3. **No Renamed event** — polling detects rename as Delete + Create; the link between old and new path is lost
4. **Performance on large `.dat` files** — SHA-256 of a 200 KB `DieMapping.dat` is fast, but if the `.dat` file set grows (e.g., 50 MB reference images), hashing time increases linearly
5. **Fragile persistence** — if the Task Scheduler task is disabled (e.g., by Group Policy push), monitoring silently stops with no alert

### Complexity

- Estimated new code: ~200–300 lines of PowerShell
- New dependencies: `System.Data.SQLite.dll` (single file deployment)
- No build toolchain required

### Limitations vs FileSystemWatcher

| Limitation | Impact |
|---|---|
| Cannot detect sub-second changes | Low — recipe files are not changed at that frequency |
| Misses changes during task execution window | Very low — hashing 190 files takes <1 s |
| Cannot distinguish `Renamed` from `Delete`+`Create` | Medium — renaming a recipe directory loses the lineage link |
| No buffer overflow protection | N/A — polling is inherently immune to FSW internal buffer issues |
| SQLite connection opened/closed every 30 s | Low overhead, but prevents using long-lived prepared statements |

---

## Option D: Hybrid — Lightweight Windows Service + RMS gRPC Hook

### Architecture Sketch

```
FalconAuditService.exe  (Option B base)
│
├── FileMonitorService  (FileSystemWatcher — same as Option B)
│   └── → SqliteRepository
│
└── RmsEventSubscriber  ← NEW component
    ├── gRPC channel to RMS (localhost:5001)
    ├── Subscribes to job lifecycle stream:
    │   JobCreated / JobLoaded / JobSaved / JobDeleted
    └── On event: enriches next N audit rows with
        { job_name, user_id, trigger_action }
        by writing to an enrichment buffer keyed on filepath prefix
```

**Graceful fallback:** If the gRPC channel cannot connect (RMS not running, timeout 5 s), `RmsEventSubscriber` logs a warning and the service falls back to FSW-only mode — all audit rows are still written, just without job-context enrichment.

**How gRPC complements FSW:**
- FSW detects the physical file change (subsecond)
- gRPC event provides the semantic context: *who* initiated the job-load, the *job name* as known to RMS, and the *trigger action* (user via JobSelect.Net, automated, etc.)
- The two are correlated by timestamp proximity and filepath prefix matching

### Additional Value over Option B

With gRPC enrichment, an audit row for `c:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini` can include:
- `rms_job_name = "Diced_10.0.4511"`
- `rms_action = "JobLoad"`
- `rms_user = "operator_01"` (if RMS auth context is available)
- `rms_correlation_id = "uuid"` (groups all file changes from one job-load together)

This converts the audit log from a file-event stream into a **job-action audit trail**.

### Pros (beyond Option B)

1. **Job-action attribution** — each file change can be attributed to a named RMS action and operator, not just a timestamp
2. **Batch correlation** — all file changes from a single `JobLoad` are linked by a correlation ID, making the audit log queryable by action rather than just by file
3. **Validates FSW events** — if RMS reports `JobSaved` but no file changes are detected, that anomaly is captured

### Cons / Added Complexity

1. **gRPC client code** — requires `Grpc.Net.Client` NuGet + RMS `.proto` file; adds ~300 lines and a compile-time dependency on RMS's gRPC interface
2. **RMS proto coupling** — if RMS's gRPC API changes, the audit service must be updated in sync; creates a cross-team maintenance dependency
3. **Enrichment timing gap** — gRPC event may arrive after FSW event (or vice versa); the correlation logic must handle a ±2 s timing window, adding complexity

### Is this complexity justified?

**Conditionally yes** — if the primary stakeholder requirement is *who changed what recipe and when*, the gRPC enrichment is worth it. If the requirement is only *what changed*, Option B is sufficient and simpler.

---

## Comparison Matrix

| Criterion | Option A (Embedded) | Option B (Win Service) | Option C (Script) | Option D (Hybrid) |
|---|---|---|---|---|
| **Isolation from Falcon process** | None — same process as AOI_Main | Full — separate OS process | Full — separate process, no native dependency | Full |
| **Catches all change events** | Yes — FSW subsecond | Yes — FSW subsecond | No — 30 s latency; misses sub-window changes | Yes — FSW subsecond + gRPC context |
| **Handles service downtime** | Poor — in-memory queue lost on crash/restart | Good — CatchUpScanner on every start | Good — hash comparison on every poll | Good — CatchUpScanner + gRPC re-subscribe |
| **SQLite write safety** | Medium — queue + dedicated thread; risk if AOI_Main crashes mid-write | High — independent process; WAL mode; queue serialization | Medium — open/close per poll; no persistent queue | High |
| **Deployment simplicity** | Simple — part of AOI_Main installer | Medium — requires separate service install + `install.ps1` | Simple — Task Scheduler + script copy | Complex — service install + gRPC proto + RMS dependency |
| **Maintenance burden** | High — audit code mixed with COM/Falcon code; harder to update independently | Low — independent service; can update without touching AOI_Main | Very low — edit plain-text PS1 | Medium — two codebases (service + gRPC client) |
| **Implementation effort** | Medium (~500 LOC) | Medium-High (~900 LOC) | Low (~250 LOC PS1) | High (~1,200 LOC + proto work) |
| **Overall risk** | Medium — failure coupling to production process | Low | Low | Medium — gRPC coupling to RMS version |
