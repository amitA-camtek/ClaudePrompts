# Appendix C — Web Server: API, Queries & Flows

> **Part of:** `jobMonitorManagmentDesign.md` stand-alone package  
> **Scope:** Read-only HTTP query layer over the per-job SQLite shards produced by `FalconAuditService`

---

## C.1 — System Overview with Web Server

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  FALCON MACHINE                                                               │
│                                                                               │
│  ┌─────────────────────────────┐    ┌──────────────────────────────────────┐ │
│  │   FalconAuditService        │    │   FalconAuditWebServer               │ │
│  │   (Windows Service)         │    │   (ASP.NET Core — same host or       │ │
│  │                             │    │    separate process, port 5100)      │ │
│  │  FileSystemWatcher          │    │                                      │ │
│  │  FileChangeHandler          │    │  Minimal API endpoints               │ │
│  │  CatchUpScanner             │    │  QueryRepository (read-only)         │ │
│  │  ShardRegistry ─────────────┼────┼──► shared ShardRegistry (read view) │ │
│  │  ManifestManager            │    │  JobDiscoveryService                 │ │
│  │  DirectoryWatcher           │    │                                      │ │
│  └──────────┬──────────────────┘    └──────────────┬───────────────────────┘ │
│             │ writes                               │ reads (WAL read-only)   │
│             ▼                                      ▼                          │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  c:\job\                                                              │    │
│  │    Diced_10.0.4511\                                                   │    │
│  │      .audit\audit.db   ◄── shard (WAL mode, multiple readers OK)    │    │
│  │      .audit\manifest.json                                             │    │
│  │    AnotherJob\                                                        │    │
│  │      .audit\audit.db                                                  │    │
│  │  c:\bis\auditlog\                                                     │    │
│  │    global.db                                                          │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
└───────────────────────────────────────┬──────────────────────────────────────┘
                                        │ HTTP / LAN
                              ┌─────────▼──────────┐
                              │  Browser / Client   │
                              │  (Engineer laptop,  │
                              │   QA dashboard,     │
                              │   support tool)     │
                              └─────────────────────┘
```

**Key constraint:** The web server opens all SQLite shards in **read-only WAL mode** (`Pragma journal_mode=WAL; Mode=ReadOnly`). It never writes. The audit service continues writing concurrently — WAL allows unlimited concurrent readers.

---

## C.2 — Component Diagram

```
FalconAuditWebServer
─────────────────────────────────────────────────────────────────
 Program.cs
 └─ WebApplication.CreateBuilder()
    ├─ AddSingleton<JobDiscoveryService>   ← scans c:\job\* for .audit\audit.db
    ├─ AddSingleton<QueryRepository>       ← opens/caches read-only connections
    └─ MapGroup("/api") ──────────────────────────────────────────
       │
       ├─ JobsEndpoints.cs
       │   GET /api/jobs
       │   GET /api/jobs/{jobName}/manifest
       │   GET /api/jobs/{jobName}/files
       │
       ├─ EventsEndpoints.cs
       │   GET /api/jobs/{jobName}/events          ← paginated, filterable
       │   GET /api/jobs/{jobName}/events/{id}     ← single event with full content
       │   GET /api/global/events                  ← events from global.db
       │
       └─ FileHistoryEndpoints.cs
           GET /api/jobs/{jobName}/history/{*filePath}  ← all versions of one file


QueryRepository
─────────────────────────────────────────────────────────────────
  ConcurrentDictionary<string, SqliteConnection> _connections
  │
  ├─ GetConnection(jobName)
  │   → _connections.GetOrAdd(jobName, OpenReadOnly(shardPath))
  │
  ├─ ListJobs()                → SELECT DISTINCT + manifest.json scan
  ├─ GetEvents(jobName, filter) → parameterised SELECT with WHERE clause builder
  ├─ GetEvent(jobName, id)     → SELECT * WHERE id=@id (includes old_content, diff_text)
  ├─ GetFileHistory(jobName, relPath) → SELECT * WHERE rel_filepath=@p ORDER BY changed_at
  └─ GetManifest(jobName)      → deserialise .audit\manifest.json


JobDiscoveryService
─────────────────────────────────────────────────────────────────
  ├─ EnumerateJobs()           → Directory.GetDirectories(@"c:\job\*")
  │                              filter: subdirectory contains .audit\audit.db
  └─ Refresh()                 → called on startup + every 30 s (background timer)
```

---

## C.3 — API Endpoint Map

```
BASE URL: http://falcon-machine:5100/api

┌──────────────────────────────────────────────────────────┬────────────────────────────────────────────────┐
│ Endpoint                                                 │ Description                                    │
├──────────────────────────────────────────────────────────┼────────────────────────────────────────────────┤
│ GET /api/jobs                                            │ List all jobs with shard stats                 │
│ GET /api/jobs/{jobName}/manifest                         │ Chain-of-custody manifest                      │
│ GET /api/jobs/{jobName}/files                            │ Distinct files ever changed in this job        │
│ GET /api/jobs/{jobName}/events                           │ Paginated events (see query params below)      │
│ GET /api/jobs/{jobName}/events/{id}                      │ Single event including full content + diff     │
│ GET /api/jobs/{jobName}/history/{*filePath}              │ All versions of one specific file              │
│ GET /api/global/events                                   │ Events from global.db (status.ini etc.)        │
└──────────────────────────────────────────────────────────┴────────────────────────────────────────────────┘

Query parameters for /events:
  ?module=Recipe                 filter by module (Recipe|Job|Config|AlignmentData|DieMap|Log|ScanResult)
  ?priority=P1                   filter by monitor priority (P1|P2|P3)
  ?service=RMS                   filter by ownerService
  ?eventType=Modified            filter by event_type (Created|Modified|Deleted|Renamed)
  ?from=2026-04-01T00:00:00Z     changed_at >= from (ISO 8601)
  ?to=2026-04-23T23:59:59Z       changed_at <= to
  ?machine=FALCON-01             filter by machine_name
  ?path=Recipe.ini               substring match on filepath
  ?page=1                        page number (1-based, default 1)
  ?pageSize=50                   rows per page (default 50, max 500)
  ?sort=desc                     changed_at sort direction (asc|desc, default desc)
```

---

## C.4 — Query Flow (HTTP Request → SQLite → JSON Response)

```
Client                 EventsEndpoints        QueryRepository         SQLite Shard
  │                         │                       │                      │
  │  GET /api/jobs/          │                       │                      │
  │  Diced_10.0.4511/events  │                       │                      │
  │  ?priority=P1&page=2     │                       │                      │
  │─────────────────────────►│                       │                      │
  │                          │                       │                      │
  │                          │ Parse & validate       │                      │
  │                          │ query params           │                      │
  │                          │ Build EventFilter      │                      │
  │                          │                       │                      │
  │                          │ GetEvents(             │                      │
  │                          │   "Diced_10.0.4511",   │                      │
  │                          │   filter)              │                      │
  │                          │──────────────────────►│                      │
  │                          │                       │ GetOrAdd connection   │
  │                          │                       │──────────────────────►│
  │                          │                       │  (WAL read-only)      │
  │                          │                       │◄──────────────────────│
  │                          │                       │                       │
  │                          │                       │ SELECT id,            │
  │                          │                       │   changed_at,         │
  │                          │                       │   event_type,         │
  │                          │                       │   filepath,           │
  │                          │                       │   module,             │
  │                          │                       │   monitor_priority,   │
  │                          │                       │   owner_service,      │
  │                          │                       │   machine_name,       │
  │                          │                       │   sha256_hash         │
  │                          │                       │ FROM audit_log        │
  │                          │                       │ WHERE monitor_priority│
  │                          │                       │   = 'P1'              │
  │                          │                       │ ORDER BY changed_at   │
  │                          │                       │   DESC                │
  │                          │                       │ LIMIT 50 OFFSET 50    │
  │                          │                       │──────────────────────►│
  │                          │                       │◄──────────────────────│
  │                          │                       │  rows (no content)    │
  │                          │◄──────────────────────│                       │
  │                          │                       │                       │
  │                          │ Serialize to JSON      │                       │
  │                          │ Add pagination headers │                       │
  │◄─────────────────────────│                       │                       │
  │  200 OK                  │                       │                       │
  │  X-Total-Count: 142      │                       │                       │
  │  X-Page: 2               │                       │                       │
  │  X-PageSize: 50          │                       │                       │
  │  [ { id, changed_at, ... }, ... ]                │                       │
```

> `old_content` and `diff_text` are **not** returned in list queries — only in the single-event endpoint `GET /api/jobs/{job}/events/{id}`. This keeps list responses small.

---

## C.5 — File History Query Flow

```
Client                 FileHistoryEndpoints    QueryRepository         SQLite Shard
  │                         │                       │                      │
  │  GET /api/jobs/          │                       │                      │
  │  Diced_10.0.4511/        │                       │                      │
  │  history/                │                       │                      │
  │  S1/Recipes/R1/Recipe.ini│                       │                      │
  │─────────────────────────►│                       │                      │
  │                          │ Decode URL path        │                      │
  │                          │ → rel_filepath =       │                      │
  │                          │ "S1\Recipes\R1\        │                      │
  │                          │  Recipe.ini"           │                      │
  │                          │──────────────────────►│                      │
  │                          │                       │ SELECT * FROM         │
  │                          │                       │   audit_log           │
  │                          │                       │ WHERE rel_filepath    │
  │                          │                       │   LIKE @p             │
  │                          │                       │ ORDER BY changed_at   │
  │                          │                       │   ASC                 │
  │                          │                       │──────────────────────►│
  │                          │                       │◄──────────────────────│
  │                          │◄──────────────────────│                       │
  │                          │                       │                       │
  │◄─────────────────────────│                       │                       │
  │  200 OK                  │                       │                       │
  │  [                       │                       │                       │
  │    { id:1,  event:"Created",  hash:"a1b2...",    │                       │
  │      machine:"FALCON-01", changed_at:"..." },    │                       │
  │    { id:7,  event:"Modified", hash:"c3d4...",    │                       │
  │      machine:"FALCON-01", diff_text:"@@ -1..." },│                       │
  │    { id:38, event:"Modified", hash:"e5f6...",    │                       │
  │      machine:"FALCON-02", diff_text:"@@ -3..." } │                       │
  │  ]                       │                       │                       │
```

---

## C.6 — Job Discovery Flow (Startup + Refresh)

```
WebServer startup
      │
      ▼
JobDiscoveryService.EnumerateJobs()
      │
      ├─ Directory.GetDirectories(@"c:\job")
      │        returns: ["Diced_10.0.4511", "AnotherJob", "OldJob_archived"]
      │
      ├─ For each subdirectory:
      │       does  <dir>\.audit\audit.db  exist?
      │       Yes → include in known jobs
      │       No  → skip (not a managed job)
      │
      ├─ Populate _knownJobs set
      │
      └─ Start background timer (30 s interval)
              On each tick: re-enumerate, detect additions/removals
              New job detected → QueryRepository.RegisterJob(jobName, shardPath)
              Job removed      → QueryRepository.CloseConnection(jobName)


QueryRepository.RegisterJob(jobName, shardPath)
      │
      └─ _connections.TryAdd(jobName,
             new SqliteConnection($"Data Source={shardPath};Mode=ReadOnly"))
         → connection opened lazily on first query
```

---

## C.7 — Manifest Query Flow

```
Client                   JobsEndpoints          ManifestReader       File System
  │                           │                      │                    │
  │  GET /api/jobs/           │                      │                    │
  │  Diced_10.0.4511/manifest │                      │                    │
  │──────────────────────────►│                      │                    │
  │                           │ ReadManifest(         │                    │
  │                           │  "Diced_10.0.4511")   │                    │
  │                           │─────────────────────►│                    │
  │                           │                      │ Read               │
  │                           │                      │ c:\job\Diced_...\  │
  │                           │                      │ .audit\manifest.json│
  │                           │                      │───────────────────►│
  │                           │                      │◄───────────────────│
  │                           │                      │ Deserialize        │
  │                           │◄─────────────────────│                    │
  │                           │                      │                    │
  │◄──────────────────────────│                      │                    │
  │  200 OK                   │                      │                    │
  │  {                        │                      │                    │
  │    "jobName": "Diced_10.0.4511",                 │                    │
  │    "created": {           │                      │                    │
  │      "machine": "FALCON-01",                     │                    │
  │      "at": "2026-03-10T08:00:00Z"                │                    │
  │    },                     │                      │                    │
  │    "history": [           │                      │                    │
  │      { "machine": "FALCON-01",                   │                    │
  │        "from": "2026-03-10T08:00:00Z",           │                    │
  │        "to":   "2026-04-15T14:00:00Z",           │                    │
  │        "events": 1420 },  │                      │                    │
  │      { "machine": "FALCON-02",                   │                    │
  │        "from": "2026-04-15T14:05:00Z",           │                    │
  │        "to":   null,      │                      │                    │
  │        "events": 38 }     │                      │                    │
  │    ]                      │                      │                    │
  │  }                        │                      │                    │
```

---

## C.8 — Response Schemas

### GET /api/jobs

```json
[
  {
    "jobName": "Diced_10.0.4511",
    "shardPath": "c:\\job\\Diced_10.0.4511\\.audit\\audit.db",
    "totalEvents": 1458,
    "firstEvent": "2026-03-10T08:01:32Z",
    "lastEvent":  "2026-04-23T09:14:05Z",
    "machines": ["FALCON-01", "FALCON-02"],
    "shardSizeBytes": 2097152
  }
]
```

### GET /api/jobs/{jobName}/events (list item — no content)

```json
{
  "id": 38,
  "changedAt": "2026-04-16T07:42:11Z",
  "eventType": "Modified",
  "filepath": "c:\\job\\Diced_10.0.4511\\S1\\Recipes\\R1\\Recipe.ini",
  "relFilepath": "S1\\Recipes\\R1\\Recipe.ini",
  "module": "Recipe",
  "ownerService": "RMS",
  "monitorPriority": "P1",
  "machineName": "FALCON-02",
  "sha256Hash": "e5f6a7b8c9d0e1f2..."
}
```

### GET /api/jobs/{jobName}/events/{id} (single event — includes content)

```json
{
  "id": 38,
  "changedAt": "2026-04-16T07:42:11Z",
  "eventType": "Modified",
  "filepath": "c:\\job\\Diced_10.0.4511\\S1\\Recipes\\R1\\Recipe.ini",
  "relFilepath": "S1\\Recipes\\R1\\Recipe.ini",
  "module": "Recipe",
  "ownerService": "RMS",
  "monitorPriority": "P1",
  "machineName": "FALCON-02",
  "sha256Hash": "e5f6a7b8c9d0e1f2...",
  "oldContent": "[Recipe]\nVersion=4\nThreshold=120\n...",
  "diffText": "@@ -2,3 +2,3 @@\n Version=4\n-Threshold=120\n+Threshold=135\n ScanSpeed=50\n"
}
```

---

## C.9 — SQLite Queries Reference

### List jobs with stats
```sql
-- Run against each shard: c:\job\{jobName}\.audit\audit.db
SELECT
    COUNT(*)                          AS total_events,
    MIN(changed_at)                   AS first_event,
    MAX(changed_at)                   AS last_event,
    GROUP_CONCAT(DISTINCT machine_name) AS machines
FROM audit_log;
```

### Paginated events with filter
```sql
SELECT
    id, changed_at, event_type, filepath, rel_filepath,
    module, owner_service, monitor_priority, machine_name, sha256_hash
FROM audit_log
WHERE
    (@module   IS NULL OR module            = @module)
    AND (@priority IS NULL OR monitor_priority = @priority)
    AND (@service  IS NULL OR owner_service    = @service)
    AND (@type     IS NULL OR event_type       = @type)
    AND (@machine  IS NULL OR machine_name     = @machine)
    AND (@from     IS NULL OR changed_at      >= @from)
    AND (@to       IS NULL OR changed_at      <= @to)
    AND (@path     IS NULL OR filepath        LIKE '%' || @path || '%')
ORDER BY changed_at DESC
LIMIT @pageSize OFFSET @offset;
```

### Count for pagination header
```sql
SELECT COUNT(*) FROM audit_log
WHERE
    (@module   IS NULL OR module            = @module)
    AND (@priority IS NULL OR monitor_priority = @priority)
    AND (@service  IS NULL OR owner_service    = @service)
    AND (@type     IS NULL OR event_type       = @type)
    AND (@machine  IS NULL OR machine_name     = @machine)
    AND (@from     IS NULL OR changed_at      >= @from)
    AND (@to       IS NULL OR changed_at      <= @to)
    AND (@path     IS NULL OR filepath        LIKE '%' || @path || '%');
```

### Full file history (single file, oldest-first)
```sql
SELECT
    id, changed_at, event_type, machine_name,
    sha256_hash, old_content, diff_text
FROM audit_log
WHERE rel_filepath = @relFilepath
ORDER BY changed_at ASC;
```

### Distinct files ever changed in a job
```sql
SELECT DISTINCT rel_filepath, module, owner_service, monitor_priority
FROM audit_log
ORDER BY rel_filepath;
```

---

## C.10 — Thread Model & Connection Safety

```
HTTP Thread Pool (ASP.NET Core Kestrel)
─────────────────────────────────────────────────────────────────────
  Request 1 ──► QueryRepository.GetEvents("Diced")
  Request 2 ──► QueryRepository.GetEvents("Diced")    ← concurrent OK
  Request 3 ──► QueryRepository.GetFileHistory("Diced", ...)

QueryRepository
  _connections["Diced"] = SqliteConnection (ReadOnly, WAL)
       │
       │  SQLite WAL mode: unlimited concurrent readers
       │  ReadOnly connection: cannot issue writes → no locking conflict
       │  with FalconAuditService writer
       ▼
  c:\job\Diced_10.0.4511\.audit\audit.db   ← WAL reader sees consistent snapshot
                                              of all committed rows


 Rule: one SqliteConnection per shard, opened once, reused for all reads.
 SqliteConnection in Microsoft.Data.Sqlite is NOT thread-safe — each
 endpoint handler acquires a per-query SqliteCommand from the shared
 connection inside a lock, or uses connection pooling (one conn per thread).

 Recommended pattern: SqliteConnectionPool per shard
   → _pools[jobName] = new DbConnectionPool(shardPath, Mode=ReadOnly, size=4)
```

---

## C.11 — Project Structure (Web Server)

```
FalconAuditWebServer\
├─ FalconAuditWebServer.csproj
│     <PackageReference Include="Microsoft.AspNetCore.OpenApi" />
│     <PackageReference Include="Microsoft.Data.Sqlite" />
│     <PackageReference Include="Serilog.AspNetCore" />
│
├─ Program.cs                         ← builder, DI, app.Map*, app.Run
├─ appsettings.json                   ← WatchPath, GlobalDbPath, Port
│
├─ Services\
│   ├─ JobDiscoveryService.cs         ← enumerates c:\job\*\.audit\audit.db
│   └─ QueryRepository.cs            ← read-only SQLite access layer
│
├─ Endpoints\
│   ├─ JobsEndpoints.cs              ← /api/jobs + /api/jobs/{j}/manifest
│   ├─ EventsEndpoints.cs            ← /api/jobs/{j}/events[/{id}]
│   └─ FileHistoryEndpoints.cs       ← /api/jobs/{j}/history/{*path}
│
└─ Models\
    ├─ JobSummary.cs
    ├─ AuditEventSummary.cs           ← list item (no content fields)
    ├─ AuditEventDetail.cs            ← single item (includes old_content, diff_text)
    ├─ FileHistoryItem.cs
    └─ EventFilter.cs                 ← parsed query params
```

---

## C.12 — Hosting Options

```
Option 1: Same Windows Service (recommended for single-machine deployment)
──────────────────────────────────────────────────────────────────────────
  Worker.cs (BackgroundService)
  Program.cs
    builder.Services.AddHostedService<Worker>()       ← file watcher
    builder.WebHost.UseUrls("http://localhost:5100")  ← web server
    app.MapGroup("/api")...

  Pros:  single service, single install, shared ShardRegistry in-process
  Cons:  web traffic could delay audit write loop (use separate thread pools)


Option 2: Separate Process
──────────────────────────────────────────────────────────────────────────
  FalconAuditService.exe    ← writes, port none
  FalconAuditWebServer.exe  ← reads only, port 5100

  Pros:  complete isolation, web server crash does not affect audit writes
  Cons:  two services to install/manage; ShardRegistry not shared (each
         process opens its own read-only connections to the same shards —
         safe under WAL mode)


Option 3: Reverse proxy (production / multi-machine dashboard)
──────────────────────────────────────────────────────────────────────────
  Each Falcon machine runs FalconAuditWebServer on port 5100.
  Central dashboard machine runs nginx/IIS reverse proxy:
    /falcon-01/api/* → http://FALCON-01:5100/api/*
    /falcon-02/api/* → http://FALCON-02:5100/api/*

  Client queries both machines from one UI.
```

---

## C.13 — Security & Access

```
┌──────────────────────┬────────────────────────────────────────────────────┐
│ Concern              │ Recommendation                                     │
├──────────────────────┼────────────────────────────────────────────────────┤
│ Network binding      │ Bind to 127.0.0.1 (loopback) by default;           │
│                      │ expose on LAN only when explicitly configured       │
├──────────────────────┼────────────────────────────────────────────────────┤
│ Authentication       │ Windows Authentication (IIS/Kestrel) for LAN use;  │
│                      │ API key header for automated tooling                │
├──────────────────────┼────────────────────────────────────────────────────┤
│ Read-only guarantee  │ SQLite Mode=ReadOnly; no INSERT/UPDATE/DELETE       │
│                      │ routes exposed                                      │
├──────────────────────┼────────────────────────────────────────────────────┤
│ old_content exposure │ P1 file content may contain recipe IP — restrict   │
│                      │ single-event endpoint to authorised roles only      │
├──────────────────────┼────────────────────────────────────────────────────┤
│ Path traversal       │ rel_filepath param must be validated against        │
│                      │ regex  ^[\w\-. \\\/]+$  before use in query        │
└──────────────────────┴────────────────────────────────────────────────────┘
```
