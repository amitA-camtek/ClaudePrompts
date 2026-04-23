# Appendix D — Complete System Block Diagram

> **Part of:** `jobMonitorManagmentDesign.md` stand-alone package

---

## D.1 — High-Level System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  FALCON MACHINE                                                      │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  [1] FALCON APPLICATION LAYER                                │   │
│  │  RMS · AOI_Main · DataServer · Falcon.Net                    │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
│                             │ writes files                           │
│                             ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  [2] FILE SYSTEM  ( c:\job\ )                                │   │
│  │  job folders · recipe files · config files · scan results    │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
│                             │ FSW events                             │
│                             ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  [3] FalconAuditService  (Windows Service — single process)  │   │
│  │                                                              │   │
│  │   ┌────────────────────────┐   ┌───────────────────────┐    │   │
│  │   │  [3a] WRITE SIDE       │   │  [3b] QUERY SIDE      │    │   │
│  │   │  file monitor +        │   │  ASP.NET Core API     │    │   │
│  │   │  audit writer          │   │  port 5100 read-only  │    │   │
│  │   └───────────┬────────────┘   └──────────┬────────────┘    │   │
│  │               │ writes                    │ reads            │   │
│  │               ▼                           ▼                  │   │
│  │   ┌──────────────────────────────────────────────────────┐   │   │
│  │   │  [4] STORAGE LAYER                                   │   │   │
│  │   │  per-job SQLite shards  +  global.db  +  manifests   │   │   │
│  │   └──────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────┬──────────────────────────────┘
                                       │ HTTP :5100
                              ┌────────┴────────┐
                              │  Browser / Tool  │
                              └─────────────────┘
```

---

## D.2 — Drill-Down [1]: Falcon Application Layer

```
┌──────────────────────────────────────────────────────────────────────┐
│  FALCON APPLICATION LAYER                                            │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  ┌────────────┐  │
│  │    RMS      │  │  AOI_Main   │  │ DataServer │  │ Falcon.Net │  │
│  │             │  │             │  │            │  │            │  │
│  │ Recipe edit │  │ Scan result │  │ Optic      │  │ Job status │  │
│  │ Job create  │  │ Alignment   │  │ preset     │  │ status.ini │  │
│  │ Setup save  │  │ Train data  │  │ illum cfg  │  │            │  │
│  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘  └─────┬──────┘  │
│         │                │               │               │          │
│         └────────────────┴───────────────┴───────────────┘          │
│                                  │                                   │
│                          writes INI / JSON /                         │
│                          TXT / XML / DAT files                       │
│                          to  c:\job\...                              │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼  (see D.3 — File System)
```

---

## D.3 — Drill-Down [2]: File System Layout

```
c:\job\                                     c:\bis\auditlog\
│                                           │
├─ status.ini          ← global (P1)        ├─ global.db
│                                           ├─ FileClassificationRules.json
├─ Diced_10.0.4511\                         └─ (logs)
│   ├─ Metadata.ini             ← P1 Job
│   ├─ ProductionInfo.ini       ← P1 Job
│   ├─ MultiRecipe.ini          ← P1 Recipe
│   ├─ Wafer2Table.ini          ← P1 AlignmentData
│   ├─ DefaultWafer2Table.ini   ← P2 AlignmentData
│   │
│   ├─ S1\
│   │   └─ Recipes\
│   │       ├─ R1\
│   │       │   ├─ Recipe.ini              ← P1 Recipe
│   │       │   ├─ Alignment.ini           ← P1 AlignmentData
│   │       │   ├─ GlobalRTP.ini           ← P1 Recipe
│   │       │   ├─ Zones\*.ini             ← P1 Recipe
│   │       │   ├─ WaferAlignData\
│   │       │   │   ├─ AlignmentData.ini   ← P1 AlignmentData
│   │       │   │   └─ Alignment_*.txt     ← P2 AlignmentData
│   │       │   ├─ TrainData\Die.ini       ← P2 Recipe
│   │       │   ├─ DieMapping.dat          ← P2 DieMap
│   │       │   ├─ ScanOverlapLog.txt      ← P3 ScanResult
│   │       │   └─ ImageProcessing.log     ← P4 (ignored)
│   │       └─ R2\  (same structure)
│   │
│   └─ .audit\                 ← created by FalconAuditService
│       ├─ audit.db            ← full history for this job (WAL mode)
│       └─ manifest.json       ← chain-of-custody record
│
└─ AnotherJob\
    ├─ ...
    └─ .audit\
        ├─ audit.db
        └─ manifest.json


Priority key:
  P1 ── stored: SHA-256 + full content snapshot + unified diff
  P2 ── stored: SHA-256 hash only
  P3 ── stored: SHA-256 hash only
  P4 ── not stored, warning log only
```

---

## D.4 — Drill-Down [3a]: Write Side (File Monitor + Audit Writer)

```
FILE SYSTEM (c:\job\)
        │
        │  OS kernel notifications
        ▼
┌───────────────────────────────────────────────────────────────────────┐
│  FileMonitorService                                                   │
│  FileSystemWatcher  c:\job\**  (full tree, 64 KB buffer)             │
│  + DirectoryWatcher  c:\job\*  (depth=1, job folder arrivals)        │
└───────────────────┬───────────────────────────────────┬──────────────┘
                    │ file change events                 │ job folder
                    ▼                                    │ created/deleted
┌───────────────────────────────────────┐               │
│  FileChangeHandler                    │               ▼
│                                       │  ┌────────────────────────┐
│  ┌─────────────────────────────────┐  │  │  DirectoryWatcher      │
│  │ 1. Debounce  500 ms             │  │  │                        │
│  │    ConcurrentDictionary         │  │  │  OnCreated ──────────► ManifestManager
│  │    <path, Timer>                │  │  │    RecordArrival()     │  .RecordArrival()
│  └────────────────┬────────────────┘  │  │    ShardRegistry       │  .RecordDeparture()
│                   │ after 500 ms      │  │    .GetOrCreate()      │  .IncrementEvents()
│                   ▼                   │  │    CatchUpScanner      │
│  ┌─────────────────────────────────┐  │  │    .Run(jobPath)       │  writes atomically
│  │ 2. FileClassifier.Classify()    │  │  │                        │  via .tmp → rename
│  │    ImmutableList of rules       │  │  │  OnDeleted ──────────► │
│  │    (hot-reload from JSON)       │  │  │    ShardRegistry       │
│  │    → module                     │  │  │    .Remove()           │
│  │    → ownerService               │  │  └────────────────────────┘
│  │    → monitorPriority (P1-P4)    │  │
│  └────────────────┬────────────────┘  │
│                   │                   │
│                   ▼                   │
│  ┌─────────────────────────────────┐  │
│  │ 3. Priority routing             │  │
│  │                                 │  │
│  │  P1 ─► HashHelper               │  │
│  │        ContentCache (old text)  │  │
│  │        DiffHelper.UnifiedDiff() │  │
│  │        ContentCache (new text)  │  │
│  │                                 │  │
│  │  P2 ─► HashHelper only          │  │
│  │  P3 ─► HashHelper only          │  │
│  │  P4 ─► skip (log warning)       │  │
│  └────────────────┬────────────────┘  │
│                   │                   │
│                   ▼                   │
│  ┌─────────────────────────────────┐  │
│  │ 4. ExtractJob(filePath)         │  │
│  │                                 │  │
│  │  c:\job\<jobName>\...           │  │
│  │    → ShardRegistry              │  │
│  │      .GetOrCreate(jobName)      │  │
│  │      → per-job SqliteRepository │  │
│  │                                 │  │
│  │  c:\job\status.ini              │  │
│  │    → globalRepo                 │  │
│  └────────────────┬────────────────┘  │
│                   │                   │
│                   ▼                   │
│  ┌─────────────────────────────────┐  │
│  │ 5. repo.Insert(AuditLogEntry)   │  │
│  │    repo.UpsertBaseline()        │  │
│  │    SemaphoreSlim(1) per shard   │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
        │
        ▼  (see D.5 — Storage Layer)


FileClassifier hot-reload path:
  c:\bis\auditlog\FileClassificationRules.json
        │
        │  secondary FileSystemWatcher (watches this file only)
        ▼
  FileClassifier.LoadRules()
    parse JSON → compile glob patterns to Regex
    Interlocked.Exchange(ref _rules, newImmutableList)
    ← lock-free swap, zero downtime
```

---

## D.5 — Drill-Down [3b]: Query Side (Web API)

```
HTTP Request  :5100
      │
      ▼
┌─────────────────────────────────────────────────────────────────┐
│  ASP.NET Core Minimal API  (Kestrel — same process as writer)   │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Endpoints                                                │  │
│  │                                                           │  │
│  │  GET /api/jobs                     JobsEndpoints          │  │
│  │  GET /api/jobs/{j}/manifest        JobsEndpoints          │  │
│  │  GET /api/jobs/{j}/files           JobsEndpoints          │  │
│  │  GET /api/jobs/{j}/events          EventsEndpoints        │  │
│  │  GET /api/jobs/{j}/events/{id}     EventsEndpoints        │  │
│  │  GET /api/jobs/{j}/history/{path}  FileHistoryEndpoints   │  │
│  │  GET /api/global/events            EventsEndpoints        │  │
│  └───────────────────────┬───────────────────────────────────┘  │
│                          │                                       │
│                          ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  QueryRepository  (read-only)                             │  │
│  │                                                           │  │
│  │  ConcurrentDictionary<jobName, SqliteConnection>          │  │
│  │  Mode=ReadOnly · WAL · connection pool per shard          │  │
│  │                                                           │  │
│  │  GetEvents(jobName, EventFilter)  → paginated rows        │  │
│  │  GetEvent(jobName, id)            → full row + content    │  │
│  │  GetFileHistory(jobName, path)    → all versions asc      │  │
│  │  GetFileList(jobName)             → DISTINCT rel_filepath  │  │
│  │  GetJobStats(jobName)             → count / dates         │  │
│  └───────────────────────┬───────────────────────────────────┘  │
│                          │                                       │
│                          ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  JobDiscoveryService                                      │  │
│  │                                                           │  │
│  │  Scans c:\job\*\.audit\audit.db  every 30 s              │  │
│  │  Registers new shards → QueryRepository                   │  │
│  │  Removes gone shards  → QueryRepository.CloseConnection() │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────┬───────────────────────────────┘
                                  │  reads (WAL — no write lock conflict)
                                  ▼  (see D.6 — Storage Layer)


Shared with write side (same process):
  ShardRegistry ── QueryRepository can call GetOrCreate() to reuse
                   the same SqliteRepository connection pool
                   instead of opening duplicate connections
```

---

## D.6 — Drill-Down [4]: Storage Layer

```
┌──────────────────────────────────────────────────────────────────────────┐
│  STORAGE LAYER                                                           │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Per-job SQLite shard    c:\job\<jobName>\.audit\audit.db         │  │
│  │                                                                   │  │
│  │  audit_log table:                                                 │  │
│  │  ┌────────────────┬──────────────────────────────────────────┐   │  │
│  │  │ id             │ INTEGER PRIMARY KEY AUTOINCREMENT         │   │  │
│  │  │ changed_at     │ TEXT  (ISO 8601 UTC)                      │   │  │
│  │  │ event_type     │ TEXT  Created | Modified | Deleted |      │   │  │
│  │  │                │       Renamed                             │   │  │
│  │  │ filepath       │ TEXT  absolute path on this machine       │   │  │
│  │  │ rel_filepath   │ TEXT  relative to job root                │   │  │
│  │  │ module         │ TEXT  Recipe | Job | Config | ...         │   │  │
│  │  │ owner_service  │ TEXT  RMS | AOI_Main | DataServer | ...   │   │  │
│  │  │ monitor_priority│ TEXT P1 | P2 | P3                        │   │  │
│  │  │ machine_name   │ TEXT  writing machine (e.g. FALCON-01)    │   │  │
│  │  │ sha256_hash    │ TEXT  hex SHA-256 of file content         │   │  │
│  │  │ old_content    │ TEXT  P1 only — snapshot before change    │   │  │
│  │  │ diff_text      │ TEXT  P1 Modified only — unified diff     │   │  │
│  │  └────────────────┴──────────────────────────────────────────┘   │  │
│  │                                                                   │  │
│  │  file_baselines table:                                            │  │
│  │  ┌────────────────┬──────────────────────────────────────────┐   │  │
│  │  │ filepath       │ TEXT PRIMARY KEY                          │   │  │
│  │  │ last_hash      │ TEXT                                      │   │  │
│  │  │ last_seen      │ TEXT                                      │   │  │
│  │  └────────────────┴──────────────────────────────────────────┘   │  │
│  │                                                                   │  │
│  │  PRAGMA journal_mode = WAL;    ← multiple concurrent readers     │  │
│  │  PRAGMA synchronous  = NORMAL; ← balance safety / speed          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  manifest.json    c:\job\<jobName>\.audit\manifest.json           │  │
│  │                                                                   │  │
│  │  {                                                                │  │
│  │    "jobName": "Diced_10.0.4511",                                  │  │
│  │    "created": { "machine": "FALCON-01", "at": "..." },           │  │
│  │    "history": [                                                   │  │
│  │      { "machine": "FALCON-01",                                   │  │
│  │        "from": "2026-03-10T08:00:00Z",                           │  │
│  │        "to":   "2026-04-15T14:00:00Z", "events": 1420 },        │  │
│  │      { "machine": "FALCON-02",                                   │  │
│  │        "from": "2026-04-15T14:05:00Z",                           │  │
│  │        "to":   null,                   "events": 38  }          │  │
│  │    ]                                                              │  │
│  │  }                                                                │  │
│  │                                                                   │  │
│  │  Written atomically: manifest.json.tmp → File.Move(overwrite)    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  global.db    c:\bis\auditlog\global.db                          │  │
│  │  Same schema — stores events for c:\job\status.ini only          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## D.7 — Drill-Down: Job Portability Flow

```
FALCON-01                               FALCON-02
─────────────────────────────────────   ─────────────────────────────────────

c:\job\Diced_10.0.4511\                 c:\job\
  .audit\                                 (empty — job not yet present)
    audit.db   ← 1420 rows
    manifest.json
      history[0]: FALCON-01
        from: 2026-03-10
        to:   null
        events: 1420
  S1\Recipes\R1\Recipe.ini
  ...

Service on FALCON-01 running.
Last write recorded. Manifest open.

      │
      │  operator action:
      │  cut  c:\job\Diced_10.0.4511\
      │  paste to FALCON-02 c:\job\
      │  (USB / network share)
      │
      ▼

                                        c:\job\Diced_10.0.4511\
                                          .audit\
                                            audit.db   ← 1420 rows (intact)
                                            manifest.json  ← FALCON-01 entry
                                          S1\...

                                        ┌─────────────────────────────────┐
                                        │  DirectoryWatcher.OnCreated     │
                                        │  fires for "Diced_10.0.4511"    │
                                        └──────────────┬──────────────────┘
                                                       │
                                          ┌────────────▼────────────────┐
                                          │  ManifestManager            │
                                          │  .RecordArrival()           │
                                          │                             │
                                          │  close FALCON-01 entry:     │
                                          │    to = now                 │
                                          │    events = 1420 (final)    │
                                          │                             │
                                          │  append FALCON-02 entry:    │
                                          │    from = now               │
                                          │    to   = null              │
                                          │    events = 0               │
                                          │                             │
                                          │  write atomically via .tmp  │
                                          └────────────┬────────────────┘
                                                       │
                                          ┌────────────▼────────────────┐
                                          │  ShardRegistry              │
                                          │  .GetOrCreate(              │
                                          │    "Diced_10.0.4511",       │
                                          │    jobPath)                 │
                                          │                             │
                                          │  opens existing audit.db    │
                                          │  (1420 rows preserved)      │
                                          └────────────┬────────────────┘
                                                       │
                                          ┌────────────▼────────────────┐
                                          │  CatchUpScanner             │
                                          │  .Run(jobPath=Diced_...)    │
                                          │                             │
                                          │  Phase 1: scan disk files   │
                                          │  vs DB baselines            │
                                          │  → emit Missing events      │
                                          │    for any changed files    │
                                          │                             │
                                          │  Phase 2: mark deleted any  │
                                          │  baseline files no longer   │
                                          │  on disk                    │
                                          └────────────┬────────────────┘
                                                       │
                                          New events appended to audit.db
                                          machine_name = "FALCON-02"
                                          Manifest events counter increments
                                          per write via IncrementEvents()
```

---

## D.8 — Component Dependency Summary

```
Program.cs
  │
  ├─► FileClassifier          ← reads FileClassificationRules.json
  │     └─ secondary FSW      ← watches rules file for hot-reload
  │
  ├─► ShardRegistry
  │     └─ SqliteRepository × N   ← one per active job  (write)
  │
  ├─► SqliteRepository (global)   ← global.db  (write)
  │
  ├─► Worker  (BackgroundService)
  │     ├─ FileMonitorService     ← FSW full tree
  │     ├─ FileChangeHandler      ← debounce · classify · route · write
  │     │     ├─ FileClassifier
  │     │     ├─ HashHelper
  │     │     ├─ DiffHelper
  │     │     ├─ ContentCache
  │     │     └─ ShardRegistry
  │     ├─ DirectoryWatcher       ← FSW depth-1
  │     │     ├─ ManifestManager
  │     │     ├─ ShardRegistry
  │     │     └─ CatchUpScanner
  │     └─ CatchUpScanner         ← startup reconcile
  │           └─ ShardRegistry
  │
  └─► WebApplication  (Kestrel :5100)
        ├─ JobDiscoveryService    ← scans c:\job\*\.audit\ every 30 s
        ├─ QueryRepository        ← read-only SQLite connections (reuses ShardRegistry)
        └─ Endpoints (Jobs · Events · FileHistory)
```
