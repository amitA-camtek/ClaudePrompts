# Audit Log — Output 4: Recommended Design & Implementation Plan

> **Input:** `output/03_alternatives.md` + `output/02_file_summary.md`  
> **Date:** 2026-04-10  
> **Role:** Senior software architect and tech lead, Camtek Falcon BIS platform

---

## Section 1 — Scoring & Decision

| Criterion | Weight | Option A (Embedded) | Option B (Win Service) | Option C (Script) | Option D (Hybrid) |
|---|---|---|---|---|---|
| Isolation from Falcon process | 25 % | 1 | **5** | 5 | 5 |
| Change detection completeness | 20 % | 5 | **5** | 2 | 5 |
| SQLite write safety | 15 % | 3 | **5** | 3 | 5 |
| Handles service downtime | 15 % | 2 | **4** | 4 | 4 |
| Deployment & maintenance simplicity | 15 % | 3 | **4** | 5 | 2 |
| Implementation effort (lower = better) | 10 % | 3 | 3 | **5** | 1 |
| **Weighted total** | 100 % | **2.80** | **4.55** | **3.90** | **4.10** |

> Score calculation: A = 1×0.25+5×0.20+3×0.15+2×0.15+3×0.15+3×0.10 = 2.80  
> B = 5×0.25+5×0.20+5×0.15+4×0.15+4×0.15+3×0.10 = **4.55**  
> C = 5×0.25+2×0.20+3×0.15+4×0.15+5×0.15+5×0.10 = 3.90  
> D = 5×0.25+5×0.20+5×0.15+4×0.15+2×0.15+1×0.10 = 4.10

**Recommendation: Option B — External Standalone Windows Service (.NET 6+)**

Option B scores highest across all weighted criteria. It provides full process isolation from `AOI_Main` (a crash in the audit service cannot destabilize the inspection machine), uses `FileSystemWatcher` for subsecond event detection (unlike Option C's 30-second poll), and has a built-in `CatchUpScanner` to handle any downtime gaps. Option D would add value if operator attribution is required, but that can be retrofitted later by adding a gRPC subscriber module to the Option B service — it is not needed for the initial audit requirement. Option A is ruled out because a fault in audit code could directly crash the machine application.

---

## Section 2 — SQLite Database Schema

```sql
-- ─────────────────────────────────────────────
--  TABLE: audit_log
--  One row per file change event detected
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
    id               INTEGER  PRIMARY KEY AUTOINCREMENT,
    filepath         TEXT     NOT NULL,
    filename         TEXT     NOT NULL,
    extension        TEXT     NOT NULL,
    change_type      TEXT     NOT NULL CHECK(change_type IN ('Created','Modified','Deleted','Renamed')),
    old_hash         TEXT,                    -- SHA-256 hex before change  (NULL for Created)
    new_hash         TEXT,                    -- SHA-256 hex after change   (NULL for Deleted)
    old_content      TEXT,                    -- Full text before (P1 files, Modified/Deleted only)
    new_content      TEXT,                    -- Full text after  (P1 files, Created/Modified only)
    diff_text        TEXT,                    -- Unified diff     (P1 Modified only)
    module           TEXT,                    -- Job|Recipe|Config|AlignmentData|ScanResult|Log|DieMap|Sequence|Unknown
    owner_service    TEXT,                    -- RMS|Falcon.Net|AOI_Main|DataServer|JobSelect.Net|External|Unknown
    monitor_priority TEXT     NOT NULL,       -- P1|P2|P3
    detected_at      TEXT     NOT NULL,       -- ISO-8601 UTC  e.g. 2026-04-10T14:32:01.123Z
    machine_name     TEXT     NOT NULL,       -- NETBIOS hostname
    note             TEXT                     -- NULL for live events; 'catch-up' for offline-detected changes
);

-- Query patterns: "all changes to Recipe.ini in last 7 days", "all P1 events today"
CREATE INDEX IF NOT EXISTS idx_al_filepath   ON audit_log(filepath);
CREATE INDEX IF NOT EXISTS idx_al_detected   ON audit_log(detected_at);
CREATE INDEX IF NOT EXISTS idx_al_priority   ON audit_log(monitor_priority, detected_at);
CREATE INDEX IF NOT EXISTS idx_al_module     ON audit_log(module, detected_at);
CREATE INDEX IF NOT EXISTS idx_al_note       ON audit_log(note);

-- ─────────────────────────────────────────────
--  TABLE: file_baseline
--  Last-known state per file — used for CatchUpScanner
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS file_baseline (
    filepath         TEXT     PRIMARY KEY,
    last_hash        TEXT     NOT NULL,
    last_seen        TEXT     NOT NULL,       -- ISO-8601 UTC of last hash computation
    last_size        INTEGER,
    module           TEXT,
    monitor_priority TEXT
);

-- ─────────────────────────────────────────────
--  TABLE: monitor_config
--  Runtime configuration — editable without recompile
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS monitor_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT OR IGNORE INTO monitor_config VALUES
    ('watch_path',          'C:\job'),
    ('db_path',             'C:\bis\auditlog\audit.db'),
    ('poll_interval_ms',    '500'),
    ('store_content_p1',    'true'),
    ('max_content_bytes',   '1048576'),
    ('debounce_ms',         '500'),
    ('fsw_buffer_bytes',    '65536'),
    ('machine_name',        '');             -- empty = auto-detect via Dns.GetHostName()
```

**Index rationale:**

| Index | Reason |
|---|---|
| `filepath` | Lookup all events for a specific file (primary audit query) |
| `detected_at` | Time-range queries: "events in last 24 h" |
| `(monitor_priority, detected_at)` | Dashboard query: "all P1 events today" — covering index avoids table scan |
| `(module, detected_at)` | Classification queries: "all Recipe changes this week" |

`file_baseline` uses `filepath` as PRIMARY KEY — lookups are always by exact path.

---

## Section 3 — Project Structure

```
FalconAuditService/
├── FalconAuditService.csproj
├── FalconAuditService.sln
├── Program.cs
├── Worker.cs
├── FileMonitorService.cs
├── FileChangeHandler.cs
├── HashHelper.cs
├── DiffHelper.cs
├── SqliteRepository.cs
├── FileClassifier.cs
├── CatchUpScanner.cs
├── Models/
│   ├── AuditLogEntry.cs
│   ├── FileBaseline.cs
│   └── MonitorConfig.cs
├── appsettings.json
└── install.ps1
```

### Class responsibilities

| Class | Responsibility | Key methods | Dependencies |
|---|---|---|---|
| `Program.cs` | Host builder — configures DI, Windows Service host, Serilog | `Main(string[])` | `Worker`, `SqliteRepository`, `FileClassifier` |
| `Worker.cs` | `BackgroundService` entry point — orchestrates startup/shutdown | `ExecuteAsync(CancellationToken)`, `StartAsync`, `StopAsync` | `FileMonitorService`, `CatchUpScanner`, `SqliteRepository` |
| `FileMonitorService.cs` | Owns `FileSystemWatcher` instance; debounces events; posts to write queue | `Start()`, `Stop()`, `OnChanged(object, FileSystemEventArgs)`, `OnError(object, ErrorEventArgs)` | `FileChangeHandler`, `FileClassifier` |
| `FileChangeHandler.cs` | Reads file content and hash; builds `AuditLogEntry`; stores to DB | `HandleAsync(ChangeEvent ct)` | `HashHelper`, `DiffHelper`, `SqliteRepository`, `FileClassifier` |
| `HashHelper.cs` | Computes SHA-256 of a file safely (shared-read, retry on lock) | `static string ComputeSha256(string path)` | — |
| `DiffHelper.cs` | Generates unified diff between old and new content strings | `static string UnifiedDiff(string oldText, string newText, string filePath)` | `DiffPlex` NuGet |
| `SqliteRepository.cs` | All SQLite read/write operations; WAL mode; serialized via `SemaphoreSlim(1)` | `InsertAuditLogAsync(AuditLogEntry)`, `UpsertBaselineAsync(FileBaseline)`, `GetBaselineAsync(string path)`, `GetAllBaselinesAsync()`, `DeleteBaselineAsync(string path)` | `Microsoft.Data.Sqlite` |
| `FileClassifier.cs` | Maps a file path to `(module, ownerService, monitorPriority)` | `ClassificationResult Classify(string filePath)` | — |
| `CatchUpScanner.cs` | On-start reconciliation scan — detects changes while service was stopped | `Task RunAsync(string watchPath, CancellationToken ct)` | `SqliteRepository`, `HashHelper`, `FileClassifier` |
| `AuditLogEntry.cs` | Plain record: all columns of `audit_log` table | Properties only | — |
| `FileBaseline.cs` | Plain record: all columns of `file_baseline` table | Properties only | — |
| `MonitorConfig.cs` | Typed config loaded from `monitor_config` table on startup | Properties only | — |

---

## Section 4 — FileClassifier Logic

### Path-to-classification mapping table

| Path pattern | Extension(s) | Module | Owner service | Priority |
|---|---|---|---|---|
| `c:\job\status.ini` (exact) | `.ini` | Config | Falcon.Net | P1 |
| `c:\job\*\Metadata.ini` | `.ini` | Job | RMS | P1 |
| `c:\job\*\*\Metadata.ini` | `.ini` | Job | RMS | P1 |
| `c:\job\*\*\ProductionInfo.ini` | `.ini` | Job | RMS | P1 |
| `c:\job\*\*\MultiRecipe.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\ScanCondition.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\WaferMapRecipe.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\DefectsClustering.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\Recipe.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\GlobalRTP.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\RTP.txt` | `.txt` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\ZoomLevels.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\zones.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\Zones\*.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\ProductInfo.ini` | `.ini` | Recipe | AOI_Main | P1 |
| `c:\job\*\*\Recipes\*\Waferinfo.ini` | `.ini` | Recipe | AOI_Main | P1 |
| `c:\job\*\*\Wafer2Table.ini` | `.ini` | AlignmentData | AOI_Main | P1 |
| `c:\job\*\*\Recipes\*\Wafer2Table.ini` | `.ini` | AlignmentData | AOI_Main | P1 |
| `c:\job\*\*\Recipes\*\Alignment.ini` | `.ini` | AlignmentData | AOI_Main | P1 |
| `c:\job\*\*\Recipes\*\AlignRtp.ini` | `.ini` | AlignmentData | RMS | P1 |
| `c:\job\*\*\Recipes\*\Params_AlignRTP.ini` | `.ini` | AlignmentData | RMS | P1 |
| `c:\job\*\*\Recipes\*\Params_SystemInfo.ini` | `.ini` | Config | RMS | P1 |
| `c:\job\*\*\Recipes\*\Params_WaferInfo.ini` | `.ini` | Recipe | RMS | P1 |
| `c:\job\*\*\Recipes\*\OpticPreset.ini` | `.ini` | Config | DataServer | P1 |
| `c:\job\*\*\Recipes\*\JobIllumLimits.ini` | `.ini` | Config | DataServer | P1 |
| `c:\job\*\*\Recipes\*\OpticToVCamStorage.json` | `.json` | Config | AOI_Main | P1 |
| `c:\job\*\*\Recipes\*\WaferAlignData\AlignmentData.ini` | `.ini` | AlignmentData | AOI_Main | P1 |
| `c:\job\*\*\DefaultWafer2Table.ini` | `.ini` | AlignmentData | RMS | P2 |
| `c:\job\*\*\Recipes\*\AlignmentData.ini` | `.ini` | AlignmentData | RMS | P2 |
| `c:\job\*\*\Recipes\*\WaferAlignData\Alignment_*.txt` | `.txt` | AlignmentData | AOI_Main | P2 |
| `c:\job\*\*\Recipes\*\FocusMapping\*` | `.ini`, `.json`, `.xml` | AlignmentData | AOI_Main | P2 |
| `c:\job\*\*\Recipes\*\TrainData\Die.ini` | `.ini` | Recipe | AOI_Main | P2 |
| `c:\job\*\*\Recipes\*\TrainData\FrameToChuck.ini` | `.ini` | AlignmentData | AOI_Main | P2 |
| `c:\job\*\*\Recipes\*\.dc_cache\TransactionsHistory.ini` | `.ini` | Log | RMS | P2 |
| `c:\job\*\*\Recipes\*\ReferencesInfo.json` | `.json` | Recipe | RMS | P2 |
| `c:\job\*\*\Recipes\*\OpticLightMetadata\config.ini` | `.ini` | Config | DataServer | P2 |
| `c:\job\*\*\CurrWaferSurfaceInterpolation.*` | `.ini`, `.md` | AlignmentData | AOI_Main | P2 |
| `c:\job\*\*\DieAlignment.dat` | `.dat` | AlignmentData | AOI_Main | P2 |
| `c:\job\*\*\Recipes\*\DieMapping.dat` | `.dat` | DieMap | RMS | P2 |
| `c:\job\*\*\Recipes\*\DieRegPos.dat` | `.dat` | DieMap | RMS | P2 |
| `c:\job\*\*\Recipes\*\DieMapRegPos.dat` | `.dat` | DieMap | RMS | P2 |
| `c:\job\*\*\Recipes\*\WaferInfo.dat` | `.dat` | Recipe | RMS | P2 |
| `c:\job\*\*\Recipes\*\zones.dat` | `.dat` | Recipe | RMS | P2 |
| `c:\job\*\*\Recipes\*\WaferDataReadSettings.xml` | `.xml` | Config | RMS | P2 |
| All others (fallback) | any included ext | Unknown | Unknown | P3 |

### `Classify` method signature and algorithm

```csharp
public record ClassificationResult(
    string Module,
    string OwnerService,
    string MonitorPriority  // "P1" | "P2" | "P3"
);

public ClassificationResult Classify(string filePath)
{
    // Normalise to lowercase with forward slashes for matching
    var norm = filePath.ToLowerInvariant().Replace('\\', '/');

    // 1. Exact match
    if (_exactRules.TryGetValue(norm, out var exact)) return exact;

    // 2. Glob pattern match (ordered — most-specific first)
    foreach (var (pattern, result) in _patternRules)
        if (GlobMatch(pattern, norm)) return result;

    // 3. Extension fallback
    var ext = Path.GetExtension(filePath).ToLowerInvariant();
    if (_extensionRules.TryGetValue(ext, out var byExt)) return byExt;

    // 4. Default
    return new ClassificationResult("Unknown", "Unknown", "P3");
}
```

Pattern rules are loaded once at startup from the embedded mapping table (hardcoded or from a JSON config file). `GlobMatch` uses `Regex` compiled from glob patterns (e.g., `*` → `[^/]*`, `**` → `.*`).

---

## Section 5 — FileSystemWatcher Configuration

```csharp
var watcher = new FileSystemWatcher(@"C:\job")
{
    // Only notify on filename or last-write changes — ignore attribute/security changes
    NotifyFilters = NotifyFilters.FileName
                  | NotifyFilters.LastWrite
                  | NotifyFilters.DirectoryName,

    // Watch entire c:\job\ tree
    IncludeSubdirectories = true,

    // 64 KB buffer — default 8 KB causes overflow with many simultaneous job operations
    InternalBufferSize = 65536,

    // No filter — classify in handler to avoid re-creating watcher per extension
    Filter = "*.*",

    EnableRaisingEvents = true
};

watcher.Changed  += OnFileEvent;
watcher.Created  += OnFileEvent;
watcher.Deleted  += OnFileEvent;
watcher.Renamed  += OnFileRenamed;
watcher.Error    += OnWatcherError;
```

**`NotifyFilters` rationale:**
- `FileName` — catches creates and deletes
- `LastWrite` — catches content modifications (the only metadata that matters for content auditing)
- `DirectoryName` — catches directory renames (a job directory rename is a significant event)
- Omit `Attributes`, `Security`, `Size`, `CreationTime`, `LastAccess` — these fire spuriously without content change

**`IncludeSubdirectories = true`** — required; the entire `c:\job\` tree is the monitoring scope including all job/setup/recipe subdirectories.

### Debounce

Many applications (including RMS) write files by: open → truncate → write → close → set attributes. This produces 2–4 FSW events per logical write. Without debouncing, one recipe save generates dozens of duplicate hash operations.

```csharp
// Debounce: per-filepath timer, fires once after 500 ms of quiet
private readonly ConcurrentDictionary<string, Timer> _debounceTimers = new();

private void OnFileEvent(object sender, FileSystemEventArgs e)
{
    _debounceTimers.AddOrUpdate(
        e.FullPath,
        _ => new Timer(ProcessChange, e, 500, Timeout.Infinite),
        (_, existing) => { existing.Change(500, Timeout.Infinite); return existing; }
    );
}

private void ProcessChange(object? state)
{
    var e = (FileSystemEventArgs)state!;
    _debounceTimers.TryRemove(e.FullPath, out var t);
    t?.Dispose();
    _changeQueue.Add(new ChangeEvent(e.FullPath, e.ChangeType, DateTime.UtcNow));
}
```

**Debounce window: 500 ms** — chosen because RMS recipe save operations complete within 200–300 ms; 500 ms provides a comfortable margin without introducing noticeable audit delay for operators.

### Error Event (Buffer Overflow)

```csharp
private void OnWatcherError(object sender, ErrorEventArgs e)
{
    _logger.LogWarning("FSW buffer overflow or error: {msg}. Restarting watcher.", 
                        e.GetException().Message);
    // Restart watcher
    _watcher.EnableRaisingEvents = false;
    _watcher.Dispose();
    InitialiseWatcher();    // re-create and start
    // Trigger catch-up scan to detect any missed changes
    _ = Task.Run(() => _catchUpScanner.RunAsync(_watchPath, _cts.Token));
}
```

**`InternalBufferSize = 65536`** — the default 8 KB can overflow if >~50 files change simultaneously (e.g., a job import). 64 KB handles bursts of ~400 events before overflow. If overflow persists, the catch-up scan provides the safety net.

---

## Section 6 — Catch-Up Scan Algorithm

```
procedure CatchUpScan(watchPath, db):

    currentFiles = RecursiveList(watchPath, includedExtensions)
    allBaselines = db.GetAllBaselines()
    baselineMap  = Dictionary keyed by filepath

    // --- Phase 1: scan current files ---
    for each file in currentFiles:
        baseline = baselineMap.Get(file.FullPath)
        
        // Race condition: file may be deleted between enumeration and hash
        // → catch IOException, treat as transient; skip this file
        try:
            currentHash = SHA256(file)
            currentSize = file.Length
        catch IOException:
            continue   // file was deleted mid-scan; FSW will catch the Delete event

        if baseline == null:
            // New file — appeared while service was stopped
            content = ReadIfP1(file, db)
            db.InsertAuditLog(filepath=file, changeType=Created,
                              newHash=currentHash, newContent=content,
                              detectedAt=UtcNow, note="catch-up")
            db.UpsertBaseline(file, currentHash, currentSize)

        elif currentHash != baseline.LastHash:
            // File was modified while service was stopped
            content_new = ReadIfP1(file, db)
            db.InsertAuditLog(filepath=file, changeType=Modified,
                              oldHash=baseline.LastHash, newHash=currentHash,
                              newContent=content_new,
                              detectedAt=UtcNow, note="catch-up")
            db.UpsertBaseline(file, currentHash, currentSize)

        else:
            // Unchanged — just touch last_seen timestamp
            db.UpsertBaselineTimestamp(file.FullPath, UtcNow)

    // --- Phase 2: detect deletions ---
    currentPaths = Set of file.FullPath for all files in currentFiles

    for each baseline in allBaselines:
        if baseline.Filepath NOT IN currentPaths:
            // File was deleted while service was stopped
            db.InsertAuditLog(filepath=baseline.Filepath, changeType=Deleted,
                              oldHash=baseline.LastHash,
                              detectedAt=UtcNow, note="catch-up")
            db.DeleteBaseline(baseline.Filepath)

    // --- Phase 3: start FSW ---
    // Start FileSystemWatcher AFTER catch-up completes to avoid double-processing
    fileMonitorService.Start()
```

**Race conditions identified:**

| Race | Mitigation |
|---|---|
| File deleted between `RecursiveList` and `SHA256` | Wrap hash in `try/catch IOException`; skip file; FSW will capture the Delete event after watcher starts |
| File modified between `SHA256` read and `InsertAuditLog` | Acceptable — catch-up records the state at scan time; FSW will detect the subsequent modification |
| Two catch-up scans run concurrently (e.g., service restart loop) | Prevent with a `SemaphoreSlim(1)` guard on `CatchUpScanner.RunAsync` |
| FSW starts before catch-up finishes, double-counting a change | Start FSW only after `CatchUpScanner.RunAsync` completes (see Phase 3 above) |

---

## Section 7 — Phased Implementation Plan

| Phase | Deliverable | Acceptance criteria |
|---|---|---|
| **1** | SQLite schema + `SqliteRepository` + unit tests | All CRUD operations work; DB is auto-created on first run; WAL mode confirmed via `PRAGMA journal_mode`; 100 % of unit tests pass |
| **2** | `FileClassifier` + classification table | All 77 file patterns from `02_file_summary.md` covered; P1 files in test fixture are classified P1; unknown paths return `Unknown / P3`; no regex exceptions on edge-case paths |
| **3** | `FileSystemWatcher` + debounce + `FileChangeHandler` | Create/Modify/Delete events on test files appear in `audit_log` within 1 second; rapid write (10 writes in 100 ms) produces exactly 1 audit row per file; `old_hash` / `new_hash` are correct SHA-256 values |
| **4** | `CatchUpScanner` | Stop service; manually modify 3 test files; start service; all 3 appear as `Modified` in `audit_log` with `note="catch-up"` within 10 seconds of service start |
| **5** | Windows Service wrapper + `install.ps1` | Service starts on boot (confirmed after reboot); survives 3 consecutive reboots; `status.ini` changes appear in DB after each reboot without manual intervention |
| **6** | P1 content snapshot + unified diff | For a P1 `Recipe.ini` change: `old_content`, `new_content`, and `diff_text` (unified format) are stored; `new_content` is byte-for-byte identical to the file on disk; diff correctly identifies changed lines |

---

## Section 8 — Risk & Rollout Notes

### 1. Filesystem performance risk

`FileSystemWatcher` events fire on the ThreadPool. Hashing a 200 KB `.dat` file takes ~2 ms on typical Falcon hardware. With 190 monitored files and the debounce, worst-case throughput is bounded by the queue drain rate, not the FSW callback rate.

**Mitigation:** Hash computation is always done on the writer thread (dequeued from `BlockingCollection`), never in the FSW callback. If a P1 file changes at high frequency (e.g., `status.ini` during a busy scan), the debounce timer resets and only one hash is computed per 500 ms burst. At 2 events/second maximum, CPU impact is <1 %.

### 2. SQLite write contention

Only one thread writes to SQLite (the `FileChangeHandler` consumer draining `BlockingCollection`). WAL mode (`PRAGMA journal_mode=WAL`) allows concurrent readers without blocking the writer. `SqliteRepository` uses a single long-lived `SqliteConnection` held open for the service lifetime — no connection pool overhead.

For extra safety: `PRAGMA synchronous=NORMAL` (not FULL) — reduces fsync overhead with WAL mode while maintaining crash-safe durability at the transaction boundary.

The writer thread uses a dedicated `_conn` write connection; the HTTP API and baseline reads use a separate `_readConn` connection. WAL mode allows `_readConn` to read concurrently without blocking the writer. `PRAGMA busy_timeout=3000` is set on both connections so any unexpected contention retries for up to 3 seconds before failing. The `SemaphoreSlim(1)` on `InsertAuditLogAsync` / `UpsertBaselineAsync` / `DeleteBaselineAsync` prevents any future multi-thread write collision.

### 3. Large file risk

`DieMapping.dat` can be 200 KB; an extreme future file could be 50 MB. Content snapshot for P1 files is controlled by `max_content_bytes` (default 1 MB, configurable in `monitor_config`).

```csharp
private async Task<string?> ReadContentIfEligible(string path, string priority, long sizeBytes)
{
    if (priority != "P1") return null;
    if (!_config.StoreContentP1) return null;
    if (sizeBytes > _config.MaxContentBytes) return null;  // skip oversized files

    // Stream read, not ReadAllText — avoids double-buffering
    using var reader = new StreamReader(path, detectEncodingFromByteOrderMarks: true);
    return await reader.ReadToEndAsync();
}
```

Files exceeding `max_content_bytes` get hash-only records; the `new_content` column is left NULL and a note is added to the `diff_text` column: `"[content omitted: size {n} bytes exceeds max_content_bytes limit]"`.

### 4. Rollout order

```
Phase 1–4:  Dev/test machine (no production impact)
            → validate DB schema, classify logic, FSW events, catch-up

Phase 5:    Staging Falcon machine (service install)
            → requires machine-admin rights
            → validate reboot survival over 48 h

Phase 6:    Opt-in per machine via monitor_config:
            UPDATE monitor_config SET value='true'  WHERE key='store_content_p1';
            → enable only after confirming Phase 5 is stable
            → monitor DB growth rate; rotate if >500 MB
```

**DB rotation policy (recommended, implement post-Phase 6):**  
Add a `max_audit_log_rows` config key (default 1,000,000). A daily maintenance job trims the oldest rows and runs `VACUUM` in WAL mode to reclaim space.

---

## Section 9 — End-to-End Event Flows

### Flow 1 — INI key value changed (live, service running)

This is the primary steady-state scenario: an operator or RMS saves a recipe file while the service is already watching.

```
  RMS / AOI_Main                  OS / NTFS                FalconAuditService
       │                               │                          │
       │  1. Open file for write       │                          │
       │──────────────────────────────>│                          │
       │  2. Truncate + write new INI  │                          │
       │──────────────────────────────>│                          │
       │                               │  3. FSW Changed event    │
       │                               │ ─────────────────────── >│
       │  4. Flush + close handle      │                          │  OnFileEvent()
       │──────────────────────────────>│                          │  → start/reset 500 ms
       │                               │  5. FSW Changed event    │    debounce timer
       │                               │ ─────────────────────── >│  (timer resets)
       │                               │                          │
       │                               │   [500 ms quiet window]  │
       │                               │                          │
       │                               │                          │  6. Debounce fires
       │                               │                          │  → enqueue ChangeEvent
       │                               │                          │     to BlockingCollection
       │                               │                          │
       │                               │                          │  7. Writer thread dequeues
       │                               │                          │  → FileClassifier.Classify()
       │                               │                          │     = {Recipe, RMS, P1}
       │                               │                          │
       │                               │                          │  8. HashHelper.ComputeSha256()
       │                               │                          │     newHash = "a3f2..."
       │                               │                          │
       │                               │                          │  9. SqliteRepository
       │                               │                          │     .GetBaselineAsync()
       │                               │                          │     oldHash = "7e91..."
       │                               │                          │
       │                               │                          │  10. Read full content
       │                               │                          │      (P1 → store_content=true)
       │                               │                          │      old_content from baseline
       │                               │                          │      new_content from disk
       │                               │                          │
       │                               │                          │  11. DiffHelper.UnifiedDiff()
       │                               │                          │      → diff_text
       │                               │                          │
       │                               │                          │  12. SqliteRepository
       │                               │                          │      .InsertAuditLogAsync()
       │                               │                          │      → audit_log row written
       │                               │                          │
       │                               │                          │  13. SqliteRepository
       │                               │                          │      .UpsertBaselineAsync()
       │                               │                          │      oldHash ← newHash
       │                               │                          │
       ▼                               ▼                          ▼
  [recipe continues                [file stable]          [audit_log row #N
   to run normally]                                        in audit.db]
```

**Key timing:** Steps 1–5 happen in ~50–300 ms (RMS write). The 500 ms debounce window starts after step 5. Steps 6–13 complete in <20 ms. Total detection latency from file-close to DB write: **~520–800 ms**.

---

### Flow 2 — Service startup with catch-up scan

The service was stopped (reboot, update). A recipe file was changed while it was down.

```
  Windows SCM                FalconAuditService             file_baseline (SQLite)
       │                            │                               │
       │  StartService              │                               │
       │ ─────────────────────────> │                               │
       │                            │  Worker.StartAsync()          │
       │                            │  → CatchUpScanner.RunAsync()  │
       │                            │                               │
       │                            │  Enumerate c:\job\ (all       │
       │                            │  included extensions)         │
       │                            │                               │
       │                            │  For Recipe.ini:              │
       │                            │  SHA256(current) = "a3f2..."  │
       │                            │  GetBaseline("Recipe.ini") ──>│
       │                            │  <── last_hash = "7e91..."    │
       │                            │                               │
       │                            │  MISMATCH → Modified event    │
       │                            │  old_hash = "7e91..."         │
       │                            │  new_hash = "a3f2..."         │
       │                            │  note     = "catch-up"        │
       │                            │  → InsertAuditLog()           │
       │                            │  → UpsertBaseline("a3f2...")──>│
       │                            │                               │
       │                            │  [remaining files checked...] │
       │                            │                               │
       │                            │  For deleted_file.ini:        │
       │                            │  (file no longer on disk)     │
       │                            │  GetAllBaselines() finds it──>│
       │                            │  → Deleted event              │
       │                            │  → DeleteBaseline() ─────────>│
       │                            │                               │
       │                            │  CatchUpScanner done          │
       │                            │  → FileMonitorService.Start() │
       │                            │    (FSW begins watching)      │
       │                            │                               │
       ▼                            ▼                               ▼
  [service running]          [live monitoring active]      [baseline up to date]
```

---

### Flow 3 — File deleted (job recipe removed)

```
  RMS (job delete)           OS / NTFS              FalconAuditService
       │                          │                         │
       │  Delete directory tree   │                         │
       │ ────────────────────────>│                         │
       │                          │  FSW Deleted event      │
       │                          │  (per file in tree)     │
       │                          │ ───────────────────────>│  OnFileEvent()
       │                          │                         │  → debounce 500 ms
       │                          │                         │
       │                          │                         │  Debounce fires
       │                          │                         │  → ChangeEvent{Deleted}
       │                          │                         │
       │                          │                         │  Writer thread:
       │                          │                         │  Classify(path) = {Recipe,RMS,P1}
       │                          │                         │  GetBaseline() → oldHash="7e91..."
       │                          │                         │  (cannot read file — it is gone)
       │                          │                         │  new_hash    = NULL
       │                          │                         │  new_content = NULL
       │                          │                         │
       │                          │                         │  InsertAuditLog(Deleted)
       │                          │                         │  DeleteBaseline(path)
       │                          │                         │
       ▼                          ▼                         ▼
  [job gone from             [file absent]           [audit row: change_type=Deleted
   RMS inventory]                                     old_hash=7e91... new_hash=NULL]
```

---

### Flow 4 — New job imported (directory tree created)

```
  RMS (job import)           OS / NTFS              FalconAuditService
       │                          │                         │
       │  Copy job tree into      │                         │
       │  c:\job\NewJob\          │                         │
       │ ────────────────────────>│                         │
       │                          │  FSW Created events     │
       │                          │  (burst: ~80–120 files) │
       │                          │ ───────────────────────>│  OnFileEvent() × N
       │                          │                         │  → N debounce timers started
       │                          │                         │
       │                          │   [copy finishes]       │
       │                          │                         │  [500 ms quiet per file]
       │                          │                         │
       │                          │                         │  Writer thread drains queue:
       │                          │                         │  For each new file:
       │                          │                         │   Classify() → P1 or P2
       │                          │                         │   GetBaseline() → null
       │                          │                         │   SHA256(file) → newHash
       │                          │                         │   old_hash=NULL (Created)
       │                          │                         │   ReadContent() if P1
       │                          │                         │   InsertAuditLog(Created)
       │                          │                         │   UpsertBaseline(newHash)
       │                          │                         │
       ▼                          ▼                         ▼
  [job available             [~80 new files]         [~80 audit rows: Created
   in RMS]                                            one per monitored file]
```

---

### Flow 5 — FSW buffer overflow and recovery

```
  Mass operation                 OS                  FalconAuditService
  (e.g. job export)              │                         │
       │                         │                         │
       │  ~500 file writes        │                         │
       │  in <1 second            │                         │
       │ ───────────────────────> │                         │
       │                          │  FSW internal 64KB      │
       │                          │  buffer FULL            │
       │                          │  → Error event fired    │
       │                          │ ───────────────────────>│  OnWatcherError()
       │                          │                         │  Log WARNING to
       │                          │                         │  Windows Event Log
       │                          │                         │  + Serilog file
       │                          │                         │
       │                          │                         │  _watcher.Dispose()
       │                          │                         │  InitialiseWatcher()
       │                          │                         │   → new FSW, enabled
       │                          │                         │
       │                          │                         │  Task.Run(
       │                          │                         │   CatchUpScanner.RunAsync)
       │                          │                         │  → hash all files
       │                          │                         │  → detect what changed
       │                          │                         │    during the overflow window
       │                          │                         │
       ▼                          ▼                         ▼
  [operation complete]       [FSW healthy]          [missed changes recovered
                                                     via catch-up; no audit gap]
```

---

### Flow 6 — INI key changed: detailed internal state transitions

This shows the internal state of the service data structures for one `Recipe.ini` modification.

```
BEFORE CHANGE
─────────────
  file_baseline table:
  ┌──────────────────────────────────────┬────────────┬──────────────────────┐
  │ filepath                             │ last_hash  │ last_seen            │
  ├──────────────────────────────────────┼────────────┼──────────────────────┤
  │ C:\job\Diced_10.0.4511\S1\Recipes\   │ 7e91bc4a   │ 2026-04-10T08:00:00Z │
  │ R1\Recipe.ini                        │            │                      │
  └──────────────────────────────────────┴────────────┴──────────────────────┘

  _debounceTimers: {}   (empty)
  _changeQueue:    []   (empty)

─── RMS writes Recipe.ini ──────────────────────────────────────────────────────

  _debounceTimers: { "...\Recipe.ini" → Timer(fires in 500ms) }
  _changeQueue:    []

─── 500 ms elapses with no further events ──────────────────────────────────────

  _debounceTimers: {}   (timer fired, removed)
  _changeQueue:    [ ChangeEvent{Path="...\Recipe.ini", Type=Changed, At=14:32:01Z} ]

─── Writer thread processes ChangeEvent ─────────────────────────────────────────

  FileClassifier.Classify("...\Recipe.ini")
    → ClassificationResult { Module="Recipe", OwnerService="RMS", Priority="P1" }

  HashHelper.ComputeSha256("...\Recipe.ini")
    → "a3f2e91b..."

  SqliteRepository.GetBaselineAsync("...\Recipe.ini")
    → FileBaseline { LastHash="7e91bc4a...", LastSeen="2026-04-10T08:00:00Z" }

  ReadContent(path, "P1", sizeBytes=412)  → new_content = "[AutoCycle]\n..."
  old_content retrieved from baseline store = "[AutoCycle]\n..."

  DiffHelper.UnifiedDiff(old, new, "Recipe.ini")
    → see diff_text example in Section 10

  SqliteRepository.InsertAuditLogAsync(entry)
    → new row in audit_log (id=1042)

  SqliteRepository.UpsertBaselineAsync(baseline)
    → last_hash updated to "a3f2e91b..."

AFTER CHANGE
────────────
  file_baseline table:
  ┌──────────────────────────────────────┬────────────┬──────────────────────┐
  │ filepath                             │ last_hash  │ last_seen            │
  ├──────────────────────────────────────┼────────────┼──────────────────────┤
  │ C:\job\Diced_10.0.4511\S1\Recipes\   │ a3f2e91b   │ 2026-04-10T14:32:01Z │
  │ R1\Recipe.ini                        │            │                      │
  └──────────────────────────────────────┴────────────┴──────────────────────┘

  audit_log row #1042 written  (see Section 10 for full example)
  _changeQueue: []   (empty)
```

---

## Section 10 — Sample Log & Database Output

### 10.1 — Serilog structured log (service console / log file)

The service writes structured logs via Serilog to `C:\bis\auditlog\FalconAudit.log` and to the Windows Event Log. Below is what the log stream looks like for a typical INI key change.

```
2026-04-10 14:31:58.412 +00:00 [INF] FalconAuditService starting. WatchPath=C:\job  DB=C:\bis\auditlog\audit.db
2026-04-10 14:31:58.430 +00:00 [INF] CatchUpScanner: starting reconciliation scan. Files=237
2026-04-10 14:31:59.103 +00:00 [INF] CatchUpScanner: complete. Unchanged=237 Created=0 Modified=0 Deleted=0 Elapsed=671ms
2026-04-10 14:31:59.105 +00:00 [INF] FileMonitorService: FileSystemWatcher enabled. Path=C:\job IncludeSubdirs=True Buffer=65536
2026-04-10 14:31:59.106 +00:00 [INF] FalconAuditService running.

--- [operator saves Recipe.ini via RMS at 14:32:01] ---

2026-04-10 14:32:01.214 +00:00 [DBG] FSW event received. Type=Changed Path=C:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini
2026-04-10 14:32:01.216 +00:00 [DBG] FSW event received. Type=Changed Path=C:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini  (debounce reset)
2026-04-10 14:32:01.714 +00:00 [DBG] Debounce fired. Path=C:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini  Enqueued.
2026-04-10 14:32:01.717 +00:00 [DBG] Processing change. Path=...\Recipe.ini  ChangeType=Changed
2026-04-10 14:32:01.718 +00:00 [DBG] Classified. Module=Recipe OwnerService=RMS Priority=P1
2026-04-10 14:32:01.720 +00:00 [DBG] Hash computed. OldHash=7e91bc4a... NewHash=a3f2e91b...  HashChanged=True
2026-04-10 14:32:01.721 +00:00 [DBG] Reading content for P1 file. SizeBytes=412
2026-04-10 14:32:01.722 +00:00 [DBG] Diff computed. LinesAdded=1 LinesRemoved=1
2026-04-10 14:32:01.724 +00:00 [INF] Audit event written. Id=1042 File=Recipe.ini ChangeType=Modified Module=Recipe Priority=P1 OldHash=7e91bc4a NewHash=a3f2e91b
2026-04-10 14:32:01.725 +00:00 [DBG] Baseline updated. Path=...\Recipe.ini  NewHash=a3f2e91b

--- [operator loads a different job — status.ini updated] ---

2026-04-10 14:35:10.001 +00:00 [DBG] FSW event received. Type=Changed Path=C:\job\status.ini
2026-04-10 14:35:10.502 +00:00 [DBG] Debounce fired. Path=C:\job\status.ini  Enqueued.
2026-04-10 14:35:10.503 +00:00 [DBG] Processing change. Path=C:\job\status.ini  ChangeType=Changed
2026-04-10 14:35:10.504 +00:00 [DBG] Classified. Module=Config OwnerService=Falcon.Net Priority=P1
2026-04-10 14:35:10.505 +00:00 [DBG] Hash computed. OldHash=9a12de7f... NewHash=c8b34f21...  HashChanged=True
2026-04-10 14:35:10.507 +00:00 [INF] Audit event written. Id=1043 File=status.ini ChangeType=Modified Module=Config Priority=P1 OldHash=9a12de7f NewHash=c8b34f21

--- [service stop] ---

2026-04-10 18:00:01.000 +00:00 [INF] StopAsync requested. Draining queue (0 items).
2026-04-10 18:00:01.002 +00:00 [INF] FileMonitorService: FileSystemWatcher disabled.
2026-04-10 18:00:01.003 +00:00 [INF] FalconAuditService stopped.
```

---

### 10.2 — SQLite audit_log row: INI key change

The full row inserted to `audit_log` for the `Recipe.ini` modification above. Shown as a formatted record for readability.

```
id               : 1042
filepath         : C:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini
filename         : Recipe.ini
extension        : .ini
change_type      : Modified
old_hash         : 7e91bc4ac8f342b19d4e05a3d62fe710c7a5b9280f1de398cc1047aef5ba4211
new_hash         : a3f2e91b0cd7453fa98e126d0b47f9882c3451789acde6b5f012e034d98a7c53
old_content      : [AutoCycle]
                   AutoCycleType=SinglePass
                   NumOfScans=1
                   PostProcessMode=Online
                   ScanMode=Normal
                   UseGlobalRTP=True
                   [ScanArea]
                   ScanAreaType=FullWafer

new_content      : [AutoCycle]
                   AutoCycleType=SinglePass
                   NumOfScans=2
                   PostProcessMode=Online
                   ScanMode=Normal
                   UseGlobalRTP=True
                   [ScanArea]
                   ScanAreaType=FullWafer

diff_text        : --- Recipe.ini  2026-04-10T14:32:00Z (before)
                   +++ Recipe.ini  2026-04-10T14:32:01Z (after)
                   @@ -3,7 +3,7 @@
                    AutoCycleType=SinglePass
                   -NumOfScans=1
                   +NumOfScans=2
                    PostProcessMode=Online

module           : Recipe
owner_service    : RMS
monitor_priority : P1
detected_at      : 2026-04-10T14:32:01.724Z
machine_name     : FALCON-82134
```

**Reading this row:** `NumOfScans` was changed from `1` to `2` in `Recipe.ini` at 14:32:01 UTC. The unified diff in `diff_text` shows exactly which line changed. Both full before and after file contents are stored (`old_content`, `new_content`). The SHA-256 hashes provide tamper evidence.

---

### 10.3 — SQLite audit_log row: Alignment key change (P1)

```
id               : 1055
filepath         : C:\job\Diced_10.0.4511\S1\Recipes\R1\WaferAlignData\AlignmentData.ini
filename         : AlignmentData.ini
extension        : .ini
change_type      : Modified
old_hash         : 3dc14e77...
new_hash         : b8f201a9...
old_content      : [General]
                   AlignmentStatus=Success
                   OffsetX=0.4812
                   OffsetY=-0.2174
                   Theta=0.00031

new_content      : [General]
                   AlignmentStatus=Success
                   OffsetX=0.5103
                   OffsetY=-0.1988
                   Theta=0.00029

diff_text        : --- AlignmentData.ini  2026-04-10T16:46:00Z (before)
                   +++ AlignmentData.ini  2026-04-10T17:38:04Z (after)
                   @@ -2,5 +2,5 @@
                    AlignmentStatus=Success
                   -OffsetX=0.4812
                   -OffsetY=-0.2174
                   -Theta=0.00031
                   +OffsetX=0.5103
                   +OffsetY=-0.1988
                   +Theta=0.00029

module           : AlignmentData
owner_service    : AOI_Main
monitor_priority : P1
detected_at      : 2026-04-10T17:38:04.812Z
machine_name     : FALCON-82134
```

**Reading this row:** Wafer alignment offsets shifted between two scan runs (OffsetX: 0.4812 → 0.5103 mm, OffsetY: -0.2174 → -0.1988 mm). This drift is now permanently recorded — useful for tracking mechanical stage drift over time.

---

### 10.4 — SQLite audit_log row: file deleted

```
id               : 1107
filepath         : C:\job\OldJob\S1\Recipes\R1\Recipe.ini
filename         : Recipe.ini
extension        : .ini
change_type      : Deleted
old_hash         : 9f3c8a12...
new_hash         : NULL
old_content      : [AutoCycle]
                   AutoCycleType=SinglePass
                   NumOfScans=1
                   ...

new_content      : NULL
diff_text        : NULL
module           : Recipe
owner_service    : RMS
monitor_priority : P1
detected_at      : 2026-04-10T18:15:22.001Z
machine_name     : FALCON-82134
```

---

### 10.5 — SQLite audit_log row: P2 file (hash only, no content)

For P2-priority files, `old_content`, `new_content`, and `diff_text` are NULL. Only the hash change is recorded.

```
id               : 1043
filepath         : C:\job\Diced_10.0.4511\S1\Recipes\R1\AlignmentData.ini
filename         : AlignmentData.ini
extension        : .ini
change_type      : Modified
old_hash         : f4d8229c...
new_hash         : 88a1b307...
old_content      : NULL
new_content      : NULL
diff_text        : NULL
module           : AlignmentData
owner_service    : RMS
monitor_priority : P2
detected_at      : 2026-04-10T14:33:05.018Z
machine_name     : FALCON-82134
```

---

### 10.6 — diff_text format explained

The `diff_text` field uses **unified diff** format (same as `git diff`):

```
--- Recipe.ini  2026-04-10T14:32:00Z (before)    ← old file label + timestamp
+++ Recipe.ini  2026-04-10T14:32:01Z (after)     ← new file label + timestamp
@@ -3,7 +3,7 @@                                  ← hunk: old starts at line 3 (7 lines),
                                                          new starts at line 3 (7 lines)
 AutoCycleType=SinglePass                         ← context line (space prefix)
-NumOfScans=1                                     ← removed line (minus prefix)
+NumOfScans=2                                     ← added line  (plus prefix)
 PostProcessMode=Online                           ← context line
```

For a multi-key change (e.g., two keys in different sections of the same `.ini`):

```
--- ProductInfo.ini  2026-04-10T17:37:00Z (before)
+++ ProductInfo.ini  2026-04-10T17:38:00Z (after)
@@ -2,7 +2,7 @@
 [AutoFocus]
-AFMode=Static
+AFMode=Dynamic
 AFStep=0.5

@@ -12,6 +12,6 @@
 [ScanSpeed]
-PixelRate=200
+PixelRate=250
 LineRate=1000
```

Two separate `@@ ... @@` hunks — one per changed region. Lines with no prefix are context (unchanged). This format is human-readable and can be applied with `patch` to reconstruct any version from any prior version.

---

### 10.7 — Useful SQL queries against audit.db

```sql
-- All changes to Recipe files in the last 7 days
SELECT id, filepath, change_type, old_hash, new_hash, detected_at
FROM   audit_log
WHERE  module = 'Recipe'
  AND  detected_at >= datetime('now', '-7 days')
ORDER  BY detected_at DESC;

-- All P1 events today with before/after diff
SELECT id, filename, change_type, diff_text, detected_at
FROM   audit_log
WHERE  monitor_priority = 'P1'
  AND  detected_at >= datetime('now', 'start of day')
ORDER  BY detected_at;

-- Alignment drift over time for a specific recipe
SELECT detected_at, old_hash, new_hash, new_content
FROM   audit_log
WHERE  filepath LIKE '%WaferAlignData\AlignmentData.ini'
ORDER  BY detected_at;

-- Which files changed most frequently this month?
SELECT filename, COUNT(*) AS change_count, MAX(detected_at) AS last_changed
FROM   audit_log
WHERE  detected_at >= datetime('now', 'start of month')
GROUP  BY filepath
ORDER  BY change_count DESC
LIMIT  20;

-- All changes to a specific job's recipe files
SELECT filename, change_type, diff_text, detected_at
FROM   audit_log
WHERE  filepath LIKE '%Diced_10.0.4511%'
  AND  monitor_priority IN ('P1', 'P2')
ORDER  BY detected_at;

-- Show the last known state of every baseline file (current inventory)
SELECT filepath, last_hash, last_seen, module, monitor_priority
FROM   file_baseline
ORDER  BY module, filepath;
```

---

### 10.8 — Windows Event Log entries

The service writes to the **Application** event log (source: `FalconAuditService`) for conditions visible to machine administrators.

```
Event ID: 1000  Level: Information
Source:   FalconAuditService
Message:  FalconAuditService started. WatchPath=C:\job  DB=C:\bis\auditlog\audit.db
          CatchUpScanner: 0 changes detected since last run.

Event ID: 1001  Level: Warning
Source:   FalconAuditService
Message:  FileSystemWatcher buffer overflow detected. Restarting watcher and
          initiating catch-up scan to recover any missed events.
          Path=C:\job  BufferSize=65536

Event ID: 1002  Level: Warning
Source:   FalconAuditService
Message:  SQLite busy_timeout (3000 ms) exceeded — write connection timed out.
          File=Recipe.ini  ChangeType=Modified  DetectedAt=2026-04-10T14:32:01Z
          Action: audit event dropped; monitoring continues.
          (Investigate: disk full, filesystem stall, or antivirus lock on audit.db)

Event ID: 1003  Level: Error
Source:   FalconAuditService
Message:  SQLite write failed. Audit event DROPPED.
          File=Recipe.ini  ChangeType=Modified  DetectedAt=2026-04-10T14:32:01Z
          Error=disk full

Event ID: 1004  Level: Information
Source:   FalconAuditService
Message:  FalconAuditService stopped gracefully. Queue drained. Items written=1042.
```

---

### 10.9 — Worked example: `OnScanFail=1` → `OnScanFail=0` in `Recipe.ini`

> **Real file:** `C:\job\Diced_10.0.4511\S1\Recipes\R2\Recipe.ini`  
> **Context:** `OnScanFail` controls what the machine does when a wafer scan fails during an auto-cycle run.  
> Value `1` = *Continue to next wafer*; value `0` = stop (behaviour depends on recipe version).  
> An operator changes the key via RMS and saves the recipe at 14:32:01 UTC.

#### Serilog log stream

```
2026-04-10 14:32:01.214 [DBG] FSW event received. Type=Changed  Path=C:\job\Diced_10.0.4511\S1\Recipes\R2\Recipe.ini
2026-04-10 14:32:01.216 [DBG] FSW event received. Type=Changed  Path=C:\job\Diced_10.0.4511\S1\Recipes\R2\Recipe.ini  (debounce reset)
2026-04-10 14:32:01.716 [DBG] Debounce fired.  Path=...\R2\Recipe.ini  Enqueued.
2026-04-10 14:32:01.718 [DBG] Processing change.  Path=...\R2\Recipe.ini  ChangeType=Changed
2026-04-10 14:32:01.719 [DBG] Classified.  Module=Recipe  OwnerService=RMS  Priority=P1
2026-04-10 14:32:01.721 [DBG] Hash computed.  OldHash=7e91bc4a...  NewHash=a3f2e91b...  HashChanged=True
2026-04-10 14:32:01.722 [DBG] Reading content for P1 file.  SizeBytes=3021
2026-04-10 14:32:01.724 [DBG] Diff computed.  LinesAdded=1  LinesRemoved=1
2026-04-10 14:32:01.726 [INF] Audit event written.  Id=1042  File=Recipe.ini  ChangeType=Modified
                               Module=Recipe  Priority=P1
                               OldHash=7e91bc4a...  NewHash=a3f2e91b...
```

**Timing breakdown:**  
RMS writes the file (~50–300 ms) → FSW fires two `Changed` events → debounce resets → 500 ms quiet window expires → hash + read + diff + SQLite write in <10 ms. **Total detection latency: ~520–810 ms.**

#### SQLite `audit_log` row

```
id               : 1042
filepath         : C:\job\Diced_10.0.4511\S1\Recipes\R2\Recipe.ini
filename         : Recipe.ini
extension        : .ini
change_type      : Modified

old_hash         : 7e91bc4ac8f342b19d4e05a3d62fe710c7a5b9280f1de398cc1047aef5ba4211
new_hash         : a3f2e91b0cd7453fa98e126d0b47f9882c3451789acde6b5f012e034d98a7c53

old_content      : [AutoCycle]
                   AutoFocusBeforeAlignment=0 ; Before Alignment
                   AutoFocusEvery=1 ; None
                   CleanReferenceEvery=1 ; None
                   UnloadToAnotherCassette=0 ; Move wafers from Loadport A to Loadport B
                   NewCleanReferenceOption=1
                   StoreSamplingHeight=0
                   EnableDieLevelPostProcessing=1
                   ImportResults=0 ; Import Results in AutoCycle (KLARF)
                   SaveReferenceInResults=0
                   OnScanResultExist=1 ; Overwrite
                   OnPickFromCarrierFail=2 ; Stop with an Error
                   OnHoldOnChuckFail=1 ; Stop with an Error
                   OnWaferIdAcquireFail=1 ; Continue with that wafer
                   OnOCRFail=1 ; Stop cycle - with Error
                   OnAlignmentFail=1 ; Continue to next wafer
                   OnCleanReferenceFail=1 ; Continue to next wafer
                   OnCTSZCorrectionFail=1 ; Continue
                   OnScanFail=1 ; Continue to next wafer        ← value before change
                   OnFocusMapFail=2 ; Stop with an Error
                   OnRepeatedDefectsFail=1 ; Continue to next wafer
                   ... (remainder of file unchanged)

new_content      : [AutoCycle]
                   AutoFocusBeforeAlignment=0 ; Before Alignment
                   AutoFocusEvery=1 ; None
                   CleanReferenceEvery=1 ; None
                   UnloadToAnotherCassette=0 ; Move wafers from Loadport A to Loadport B
                   NewCleanReferenceOption=1
                   StoreSamplingHeight=0
                   EnableDieLevelPostProcessing=1
                   ImportResults=0 ; Import Results in AutoCycle (KLARF)
                   SaveReferenceInResults=0
                   OnScanResultExist=1 ; Overwrite
                   OnPickFromCarrierFail=2 ; Stop with an Error
                   OnHoldOnChuckFail=1 ; Stop with an Error
                   OnWaferIdAcquireFail=1 ; Continue with that wafer
                   OnOCRFail=1 ; Stop cycle - with Error
                   OnAlignmentFail=1 ; Continue to next wafer
                   OnCleanReferenceFail=1 ; Continue to next wafer
                   OnCTSZCorrectionFail=1 ; Continue
                   OnScanFail=0                                 ← value after change
                   OnFocusMapFail=2 ; Stop with an Error
                   OnRepeatedDefectsFail=1 ; Continue to next wafer
                   ... (remainder of file unchanged)

diff_text        : --- Recipe.ini  2026-04-10T14:31:55Z (before)
                   +++ Recipe.ini  2026-04-10T14:32:01Z (after)
                   @@ -17,7 +17,7 @@
                    OnCleanReferenceFail=1 ; Continue to next wafer
                    OnCTSZCorrectionFail=1 ; Continue
                   -OnScanFail=1 ; Continue to next wafer
                   +OnScanFail=0
                    OnFocusMapFail=2 ; Stop with an Error
                    OnRepeatedDefectsFail=1 ; Continue to next wafer

module           : Recipe
owner_service    : RMS
monitor_priority : P1
detected_at      : 2026-04-10T14:32:01.726Z
machine_name     : FALCON-82134
```

#### What the diff tells you at a glance

| Diff element | Meaning |
|---|---|
| `--- Recipe.ini  ...T14:31:55Z` | The file as it existed before the save |
| `+++ Recipe.ini  ...T14:32:01Z` | The file after the save — 6-second gap between open and close |
| `@@ -17,7 +17,7 @@` | Change is in a single hunk at line 17; 7 lines of context shown |
| `-OnScanFail=1 ; Continue to next wafer` | Removed line (was: silently skip failed wafers and continue the lot) |
| `+OnScanFail=0` | Added line (operator also stripped the inline comment when editing) |
| All surrounding lines unchanged | Only this one key was modified — no other recipe parameters were touched |

#### Note on the stripped comment

The original value was `OnScanFail=1 ; Continue to next wafer` (with an inline comment). The operator saved it as `OnScanFail=0` with no comment. The diff captures both changes — the numeric value **and** the removal of the comment string. This means the diff is a complete and truthful record of exactly what bytes were written, not just a semantic summary.

#### SQL query to find this event

```sql
-- Find all OnScanFail changes across all jobs and recipes
SELECT id, filepath, detected_at, diff_text
FROM   audit_log
WHERE  diff_text LIKE '%OnScanFail%'
ORDER  BY detected_at DESC;

-- Find all Recipe.ini changes on machine FALCON-82134 this week
SELECT id, filepath, change_type, diff_text, detected_at
FROM   audit_log
WHERE  filename      = 'Recipe.ini'
  AND  machine_name  = 'FALCON-82134'
  AND  detected_at  >= datetime('now', '-7 days')
ORDER  BY detected_at DESC;
```

---

**What we are building:** A small Windows background service (`FalconAuditService`) that watches the `c:\job\` directory tree and records every file change to a local SQLite database — who changed what recipe, when, and what it looked like before and after.

**Key decisions and rationale:**

- **Standalone Windows Service (not embedded in `AOI_Main`)** — if the audit service crashes or has a bug, the inspection machine keeps running. This is the most important safety property.

- **FileSystemWatcher, not polling** — changes are detected within 1 second. A 30-second poll would miss rapid recipe edits and show incorrect "change time" timestamps.

- **SQLite local database** — no server to install, no network dependency, works on an air-gapped machine. The audit database lives at `C:\bis\auditlog\audit.db`.

- **~190 files monitored** (P1 + P2 priority) out of 237 total non-binary files found in `c:\job\`. Critical recipe files (P1, ~80 files) get full before/after content snapshots and unified diff. Configuration and supporting files (P2, ~110 files) get hash-only records.

- **Catch-up scan on every service start** — if the service is stopped (reboot, update), it computes the SHA-256 of every file on restart and compares to the last-known state. Any changes during downtime are recorded as catch-up events.

- **Phased delivery** — 6 phases, each independently testable. Phases 1–4 run on a dev machine. Phase 5 (production install) requires admin rights. Phase 6 (content snapshots) is opt-in per machine.

**Effort and dependencies:**

- ~900 lines of C# (.NET 6)
- NuGet packages: `Microsoft.Data.Sqlite`, `DiffPlex`, `Microsoft.Extensions.Hosting.WindowsServices`
- One `install.ps1` script for service registration
- No changes to `AOI_Main`, `RMS`, or any existing Falcon component

**What this delivers to the business:**

- Full audit trail of recipe changes: who changed `Recipe.ini` at what time, before and after
- Alignment drift detection: `WaferAlignData\AlignmentData.ini` is recorded after every scan run
- Illumination change tracking: `OpticPreset.ini` and `JobIllumLimits.ini` changes are captured on every recipe load
- Machine state history: `status.ini` changes create a timestamped log of which job/recipe was active
- Compliance evidence: tamper-evident SHA-256 hashes for every P1 recipe file

---

## Appendix A — Source Code

> All files are in the `FalconAuditService/` project root unless a subdirectory is shown.  
> Target: **.NET 6**, C# 10, `net6.0-windows`.  
> NuGet dependencies: `Microsoft.Data.Sqlite`, `DiffPlex`, `Microsoft.Extensions.Hosting.WindowsServices`, `Serilog.Extensions.Hosting`, `Serilog.Sinks.File`, `Serilog.Sinks.EventLog`.

---

### A.1 — `FalconAuditService.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Worker">

  <PropertyGroup>
    <TargetFramework>net6.0-windows</TargetFramework>
    <RootNamespace>FalconAuditService</RootNamespace>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>true</SelfContained>
    <PublishSingleFile>true</PublishSingleFile>
    <AssemblyName>FalconAuditService</AssemblyName>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Data.Sqlite"
                      Version="7.0.*" />
    <PackageReference Include="DiffPlex"
                      Version="1.7.*" />
    <PackageReference Include="Microsoft.Extensions.Hosting.WindowsServices"
                      Version="7.0.*" />
    <PackageReference Include="Serilog.Extensions.Hosting"
                      Version="7.0.*" />
    <PackageReference Include="Serilog.Sinks.File"
                      Version="5.0.*" />
    <PackageReference Include="Serilog.Sinks.EventLog"
                      Version="3.1.*" />
  </ItemGroup>

</Project>
```

---

### A.2 — `appsettings.json`

```json
{
  "AuditService": {
    "DbPath": "C:\\bis\\auditlog\\audit.db"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "FalconAuditService": "Debug"
      }
    },
    "WriteTo": [
      {
        "Name": "File",
        "Args": {
          "path": "C:\\bis\\auditlog\\FalconAudit.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30,
          "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}"
        }
      },
      {
        "Name": "EventLog",
        "Args": {
          "source": "FalconAuditService",
          "restrictedToMinimumLevel": "Warning"
        }
      }
    ]
  }
}
```

---

### A.3 — `Models/AuditLogEntry.cs`

```csharp
namespace FalconAuditService.Models;

public record AuditLogEntry
{
    public string  Filepath         { get; init; } = "";
    public string  Filename         { get; init; } = "";
    public string  Extension        { get; init; } = "";
    public string  ChangeType       { get; init; } = "";   // Created|Modified|Deleted|Renamed
    public string? OldHash          { get; init; }
    public string? NewHash          { get; init; }
    public string? OldContent       { get; init; }         // full text before  (P1 only)
    public string? NewContent       { get; init; }         // full text after   (P1 only)
    public string? DiffText         { get; init; }         // unified diff      (P1 Modified only)
    public string  Module           { get; init; } = "Unknown";
    public string  OwnerService     { get; init; } = "Unknown";
    public string  MonitorPriority  { get; init; } = "P3";
    public string  DetectedAt       { get; init; } = "";   // ISO-8601 UTC
    public string  MachineName      { get; init; } = "";
    public string? Note             { get; init; }         // null for live events; "catch-up" for offline-detected
}
```

### A.4 — `Models/FileBaseline.cs`

```csharp
namespace FalconAuditService.Models;

public record FileBaseline
{
    public string  Filepath         { get; init; } = "";
    public string  LastHash         { get; init; } = "";
    public string  LastSeen         { get; init; } = "";   // ISO-8601 UTC
    public long    LastSize         { get; init; }
    public string  Module           { get; init; } = "";
    public string  MonitorPriority  { get; init; } = "";
}
```

### A.5 — `Models/MonitorConfig.cs`

```csharp
namespace FalconAuditService.Models;

public class MonitorConfig
{
    public string WatchPath        { get; set; } = @"C:\job";
    public string DbPath           { get; set; } = @"C:\bis\auditlog\audit.db";
    public bool   StoreContentP1   { get; set; } = true;
    public long   MaxContentBytes  { get; set; } = 1_048_576;  // 1 MB
    public int    DebounceMs       { get; set; } = 500;
    public int    FswBufferBytes   { get; set; } = 65_536;
    public string MachineName      { get; set; } = System.Net.Dns.GetHostName();
}
```

---

### A.6 — `ContentCache.cs`

Shared singleton that holds the last-read text content of P1 files.  
`CatchUpScanner` populates it on startup; `FileChangeHandler` reads it as `old_content` and updates it after every write.

```csharp
namespace FalconAuditService;

using System.Collections.Concurrent;

/// <summary>
/// In-memory cache of the last-known text content for P1 files.
/// Populated by CatchUpScanner on startup so that the first live
/// Modified event has old_content available.
/// </summary>
public class ContentCache
{
    private readonly ConcurrentDictionary<string, string> _store =
        new(StringComparer.OrdinalIgnoreCase);

    public void Set(string path, string content)           => _store[path] = content;
    public string? Get(string path)                        => _store.TryGetValue(path, out var v) ? v : null;
    public void Remove(string path)                        => _store.TryRemove(path, out _);
}
```

---

### A.7 — `HashHelper.cs`

```csharp
namespace FalconAuditService;

using System.Security.Cryptography;

public static class HashHelper
{
    private const int MaxRetries    = 3;
    private const int RetryDelayMs  = 100;

    /// <summary>
    /// Compute SHA-256 of a file using a shared-read lock.
    /// Retries up to MaxRetries times if the file is locked.
    /// Returns null if the file cannot be read.
    /// </summary>
    public static string? ComputeSha256(string path)
    {
        for (int attempt = 0; attempt < MaxRetries; attempt++)
        {
            try
            {
                using var fs   = new FileStream(path, FileMode.Open,
                                                FileAccess.Read, FileShare.ReadWrite);
                using var sha  = SHA256.Create();
                byte[]    hash = sha.ComputeHash(fs);
                return Convert.ToHexString(hash).ToLowerInvariant();
            }
            catch (IOException) when (attempt < MaxRetries - 1)
            {
                Thread.Sleep(RetryDelayMs * (attempt + 1));
            }
            catch (Exception)   // UnauthorizedAccess, path-too-long, etc.
            {
                return null;
            }
        }
        return null;
    }
}
```

---

### A.8 — `DiffHelper.cs`

```csharp
namespace FalconAuditService;

using System.Text;
using DiffPlex.DiffBuilder;
using DiffPlex.DiffBuilder.Model;

public static class DiffHelper
{
    private const int ContextLines = 3;

    /// <summary>
    /// Produce a unified-diff string between oldText and newText.
    /// Returns null if either input is null or if there are no differences.
    /// Uses DiffPlex InlineDiffBuilder internally.
    /// </summary>
    public static string? UnifiedDiff(
        string?  oldText,
        string?  newText,
        string   fileName,
        DateTime oldTime,
        DateTime newTime)
    {
        if (oldText is null || newText is null) return null;

        var diff = InlineDiffBuilder.Diff(oldText, newText);
        if (!diff.HasDifferences) return null;

        var lines = diff.Lines;
        int n     = lines.Count;

        // Mark every line that lies within ContextLines of a changed line
        var inHunk = new bool[n];
        for (int i = 0; i < n; i++)
        {
            if (lines[i].Type == ChangeType.Unchanged) continue;
            for (int j = Math.Max(0, i - ContextLines);
                     j < Math.Min(n, i + ContextLines + 1); j++)
                inHunk[j] = true;
        }

        var sb    = new StringBuilder();
        sb.AppendLine($"--- {fileName}  {oldTime:O} (before)");
        sb.AppendLine($"+++ {fileName}  {newTime:O} (after)");

        // Walk through lines; when we enter a hunk region, emit @@ header + lines
        int oldNo = 1, newNo = 1;
        int i2 = 0;

        while (i2 < n)
        {
            if (!inHunk[i2])
            {
                // Outside any hunk — just advance line counters
                if (lines[i2].Type != ChangeType.Inserted) oldNo++;
                if (lines[i2].Type != ChangeType.Deleted)  newNo++;
                i2++;
                continue;
            }

            // Hunk starts at i2 — find where this hunk ends
            int start = i2;
            while (i2 < n && inHunk[i2]) i2++;
            int end = i2;

            // Count lines contributed to old/new files
            var   hunk    = lines.GetRange(start, end - start);
            int   oldCnt  = hunk.Count(l => l.Type != ChangeType.Inserted);
            int   newCnt  = hunk.Count(l => l.Type != ChangeType.Deleted);

            sb.AppendLine($"@@ -{oldNo},{oldCnt} +{newNo},{newCnt} @@");

            foreach (var line in hunk)
            {
                char pfx = line.Type switch
                {
                    ChangeType.Inserted => '+',
                    ChangeType.Deleted  => '-',
                    _                   => ' '
                };
                sb.AppendLine($"{pfx}{line.Text}");

                if (line.Type != ChangeType.Inserted) oldNo++;
                if (line.Type != ChangeType.Deleted)  newNo++;
            }
        }

        return sb.ToString().TrimEnd();
    }
}
```

---

### A.9 — `FileClassifier.cs`

```csharp
namespace FalconAuditService;

using System.Text.RegularExpressions;

public class FileClassifier
{
    public record ClassificationResult(
        string Module,           // Job|Recipe|Config|AlignmentData|DieMap|ScanResult|Log|Unknown
        string OwnerService,     // RMS|Falcon.Net|AOI_Main|DataServer|Unknown
        string MonitorPriority   // P1|P2|P3
    );

    // Rules ordered most-specific first; first match wins
    private static readonly (string Glob, ClassificationResult Result)[] RawRules =
    {
        // ── Root ────────────────────────────────────────────────────────────
        ("c:/job/status.ini",                                                  new("Config",        "Falcon.Net", "P1")),
        // ── Job-level ───────────────────────────────────────────────────────
        ("c:/job/*/metadata.ini",                                              new("Job",           "RMS",        "P1")),
        ("c:/job/*/*/metadata.ini",                                            new("Job",           "RMS",        "P1")),
        ("c:/job/*/*/productioninfo.ini",                                      new("Job",           "RMS",        "P1")),
        // ── Setup-level ─────────────────────────────────────────────────────
        ("c:/job/*/*/multirecipe.ini",                                         new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/scancondition.ini",                                       new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/wafermaprecipe.ini",                                      new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/defectsclustering.ini",                                   new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/wafer2table.ini",                                         new("AlignmentData", "AOI_Main",   "P1")),
        ("c:/job/*/*/defaultwafer2table.ini",                                  new("AlignmentData", "RMS",        "P2")),
        ("c:/job/*/*/diealignment.dat_block.ini",                              new("Recipe",        "RMS",        "P2")),
        // ── Recipe-level P1 ─────────────────────────────────────────────────
        ("c:/job/*/*/recipes/*/recipe.ini",                                    new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/globalrtp.ini",                                 new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/rtp.txt",                                       new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/zoomlevels.ini",                                new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/zones.ini",                                     new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/zones/*.ini",                                   new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/productinfo.ini",                               new("Recipe",        "AOI_Main",   "P1")),
        ("c:/job/*/*/recipes/*/waferinfo.ini",                                 new("Recipe",        "AOI_Main",   "P1")),
        ("c:/job/*/*/recipes/*/wafer2table.ini",                               new("AlignmentData", "AOI_Main",   "P1")),
        ("c:/job/*/*/recipes/*/alignment.ini",                                 new("AlignmentData", "AOI_Main",   "P1")),
        ("c:/job/*/*/recipes/*/alignrtp.ini",                                  new("AlignmentData", "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/params_alignrtp.ini",                           new("AlignmentData", "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/params_systeminfo.ini",                         new("Config",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/params_waferinfo.ini",                          new("Recipe",        "RMS",        "P1")),
        ("c:/job/*/*/recipes/*/opticpreset.ini",                               new("Config",        "DataServer", "P1")),
        ("c:/job/*/*/recipes/*/jobillumlimits.ini",                            new("Config",        "DataServer", "P1")),
        ("c:/job/*/*/recipes/*/optictovcamstorage.json",                       new("Config",        "AOI_Main",   "P1")),
        ("c:/job/*/*/recipes/*/waferaligndata/alignmentdata.ini",              new("AlignmentData", "AOI_Main",   "P1")),
        // ── Recipe-level P2 ─────────────────────────────────────────────────
        ("c:/job/*/*/recipes/*/defaultwafer2table.ini",                        new("AlignmentData", "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/alignmentdata.ini",                             new("AlignmentData", "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/waferaligndata/alignment_*.txt",                new("AlignmentData", "AOI_Main",   "P2")),
        ("c:/job/*/*/recipes/*/focusmapping/**",                               new("AlignmentData", "AOI_Main",   "P2")),
        ("c:/job/*/*/recipes/*/traindata/die.ini",                             new("Recipe",        "AOI_Main",   "P2")),
        ("c:/job/*/*/recipes/*/traindata/frametochuck.ini",                    new("AlignmentData", "AOI_Main",   "P2")),
        ("c:/job/*/*/recipes/*/.dc_cache/transactionshistory.ini",             new("Log",           "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/referencesinfo.json",                           new("Recipe",        "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/opticlightmetadata/config.ini",                 new("Config",        "DataServer", "P2")),
        ("c:/job/*/*/currwaferinterpolation.*",                                new("AlignmentData", "AOI_Main",   "P2")),
        ("c:/job/*/*/diealignment.dat",                                        new("AlignmentData", "AOI_Main",   "P2")),
        ("c:/job/*/*/recipes/*/diemapping.dat",                                new("DieMap",        "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/dieregpos.dat",                                 new("DieMap",        "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/diemapregpos.dat",                              new("DieMap",        "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/waferinfo.dat",                                 new("Recipe",        "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/zones.dat",                                     new("Recipe",        "RMS",        "P2")),
        ("c:/job/*/*/recipes/*/waferdatareadsettings.xml",                     new("Config",        "RMS",        "P2")),
    };

    private static readonly (Regex Regex, ClassificationResult Result)[] _compiled;

    static FileClassifier()
    {
        _compiled = RawRules
            .Select(r => (GlobToRegex(r.Glob), r.Result))
            .ToArray();
    }

    /// <summary>
    /// Convert a glob pattern (using * for single-segment wildcard, ** for multi-segment)
    /// into a compiled Regex anchored at both ends.
    /// </summary>
    private static Regex GlobToRegex(string glob)
    {
        var sb = new StringBuilder("^");
        int i  = 0;
        while (i < glob.Length)
        {
            if (glob[i] == '*' && i + 1 < glob.Length && glob[i + 1] == '*')
            {
                sb.Append(".*");    // ** — match anything including path separators
                i += 2;
                if (i < glob.Length && glob[i] == '/') i++;  // skip trailing /
            }
            else if (glob[i] == '*')
            {
                sb.Append("[^/]*"); // * — match within a single path segment
                i++;
            }
            else if (glob[i] == '?')
            {
                sb.Append("[^/]");
                i++;
            }
            else if (glob[i] == '.')
            {
                sb.Append("\\.");
                i++;
            }
            else
            {
                sb.Append(Regex.Escape(glob[i].ToString()));
                i++;
            }
        }
        sb.Append('$');
        return new Regex(sb.ToString(), RegexOptions.IgnoreCase | RegexOptions.Compiled);
    }

    /// <summary>
    /// Classify a file path into (Module, OwnerService, MonitorPriority).
    /// Normalises the path to lowercase forward slashes before matching.
    /// Falls through to (Unknown, Unknown, P3) if no rule matches.
    /// </summary>
    public ClassificationResult Classify(string filePath)
    {
        var norm = filePath.ToLowerInvariant().Replace('\\', '/');
        foreach (var (regex, result) in _compiled)
            if (regex.IsMatch(norm)) return result;
        return new ClassificationResult("Unknown", "Unknown", "P3");
    }
}
```

---

### A.10 — `SqliteRepository.cs`

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

public class SqliteRepository : IDisposable
{
    private readonly SqliteConnection _conn;
    private readonly SqliteConnection _readConn;
    private readonly SemaphoreSlim    _writeLock = new(1, 1);
    private readonly ILogger<SqliteRepository> _logger;

    public SqliteRepository(IConfiguration cfg, ILogger<SqliteRepository> logger)
    {
        _logger = logger;
        string dbPath = cfg["AuditService:DbPath"] ?? @"C:\bis\auditlog\audit.db";
        Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);

        _conn = new SqliteConnection($"Data Source={dbPath}");
        _conn.Open();

        _readConn = new SqliteConnection($"Data Source={dbPath}");
        _readConn.Open();
        using var rPragma = _readConn.CreateCommand();
        rPragma.CommandText = "PRAGMA journal_mode=WAL; PRAGMA busy_timeout=3000;";
        rPragma.ExecuteNonQuery();

        // Enable WAL mode for concurrent readers + single writer
        using var pragma = _conn.CreateCommand();
        pragma.CommandText = "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=3000;";
        pragma.ExecuteNonQuery();

        using var walCheck = _conn.CreateCommand();
        walCheck.CommandText = "PRAGMA journal_mode=WAL;";
        var mode = walCheck.ExecuteScalar()?.ToString();
        if (!string.Equals(mode, "wal", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                $"SQLite WAL mode could not be enabled (got '{mode}'). " +
                "Ensure the database is not on a network share or FAT32 volume.");

        EnsureSchema();

        using var probe = _conn.CreateCommand();
        probe.CommandText = "SELECT 1";
        probe.ExecuteScalar();
        logger.LogInformation("SqliteRepository: connection verified. DB={D}", dbPath);
    }

    // ── Schema ───────────────────────────────────────────────────────────────

    private void EnsureSchema()
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = @"
            CREATE TABLE IF NOT EXISTS audit_log (
                id               INTEGER  PRIMARY KEY AUTOINCREMENT,
                filepath         TEXT     NOT NULL,
                filename         TEXT     NOT NULL,
                extension        TEXT     NOT NULL,
                change_type      TEXT     NOT NULL
                                 CHECK(change_type IN ('Created','Modified','Deleted','Renamed')),
                old_hash         TEXT,
                new_hash         TEXT,
                old_content      TEXT,
                new_content      TEXT,
                diff_text        TEXT,
                module           TEXT,
                owner_service    TEXT,
                monitor_priority TEXT     NOT NULL,
                detected_at      TEXT     NOT NULL,
                machine_name     TEXT     NOT NULL,
                note             TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_al_filepath ON audit_log(filepath);
            CREATE INDEX IF NOT EXISTS idx_al_detected ON audit_log(detected_at);
            CREATE INDEX IF NOT EXISTS idx_al_priority ON audit_log(monitor_priority, detected_at);
            CREATE INDEX IF NOT EXISTS idx_al_module   ON audit_log(module, detected_at);
            CREATE INDEX IF NOT EXISTS idx_al_note     ON audit_log(note);

            CREATE TABLE IF NOT EXISTS file_baseline (
                filepath         TEXT PRIMARY KEY,
                last_hash        TEXT NOT NULL,
                last_seen        TEXT NOT NULL,
                last_size        INTEGER,
                module           TEXT,
                monitor_priority TEXT
            );

            CREATE TABLE IF NOT EXISTS monitor_config (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            INSERT OR IGNORE INTO monitor_config VALUES
                ('watch_path',        'C:\job'),
                ('store_content_p1',  'true'),
                ('max_content_bytes', '1048576'),
                ('debounce_ms',       '500'),
                ('fsw_buffer_bytes',  '65536'),
                ('machine_name',      '');
        ";
        cmd.ExecuteNonQuery();
    }

    // ── audit_log ────────────────────────────────────────────────────────────

    public async Task InsertAuditLogAsync(AuditLogEntry e)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO audit_log
                    (filepath, filename, extension, change_type,
                     old_hash, new_hash, old_content, new_content, diff_text,
                     module, owner_service, monitor_priority, detected_at, machine_name, note)
                VALUES
                    (@fp,@fn,@ext,@ct,@oh,@nh,@oc,@nc,@dt,@mod,@svc,@pri,@at,@mn,@note)";

            cmd.Parameters.AddWithValue("@fp",  e.Filepath);
            cmd.Parameters.AddWithValue("@fn",  e.Filename);
            cmd.Parameters.AddWithValue("@ext", e.Extension);
            cmd.Parameters.AddWithValue("@ct",  e.ChangeType);
            cmd.Parameters.AddWithValue("@oh",  (object?)e.OldHash        ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@nh",  (object?)e.NewHash        ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@oc",  (object?)e.OldContent     ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@nc",  (object?)e.NewContent     ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@dt",  (object?)e.DiffText       ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@mod", e.Module);
            cmd.Parameters.AddWithValue("@svc", e.OwnerService);
            cmd.Parameters.AddWithValue("@pri", e.MonitorPriority);
            cmd.Parameters.AddWithValue("@at",   e.DetectedAt);
            cmd.Parameters.AddWithValue("@mn",   e.MachineName);
            cmd.Parameters.AddWithValue("@note", (object?)e.Note ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    // ── file_baseline ────────────────────────────────────────────────────────

    public async Task UpsertBaselineAsync(FileBaseline b)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = @"
                INSERT INTO file_baseline
                    (filepath, last_hash, last_seen, last_size, module, monitor_priority)
                VALUES (@fp, @lh, @ls, @lz, @mod, @pri)
                ON CONFLICT(filepath) DO UPDATE SET
                    last_hash        = excluded.last_hash,
                    last_seen        = excluded.last_seen,
                    last_size        = excluded.last_size,
                    module           = excluded.module,
                    monitor_priority = excluded.monitor_priority";

            cmd.Parameters.AddWithValue("@fp",  b.Filepath);
            cmd.Parameters.AddWithValue("@lh",  b.LastHash);
            cmd.Parameters.AddWithValue("@ls",  b.LastSeen);
            cmd.Parameters.AddWithValue("@lz",  b.LastSize);
            cmd.Parameters.AddWithValue("@mod", b.Module);
            cmd.Parameters.AddWithValue("@pri", b.MonitorPriority);

            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    public async Task<FileBaseline?> GetBaselineAsync(string filepath)
    {
        using var cmd = _readConn.CreateCommand();
        cmd.CommandText =
            "SELECT filepath,last_hash,last_seen,last_size,module,monitor_priority " +
            "FROM file_baseline WHERE filepath=@fp";
        cmd.Parameters.AddWithValue("@fp", filepath);

        using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return null;

        return new FileBaseline
        {
            Filepath        = r.GetString(0),
            LastHash        = r.GetString(1),
            LastSeen        = r.GetString(2),
            LastSize        = r.IsDBNull(3) ? 0L   : r.GetInt64(3),
            Module          = r.IsDBNull(4) ? ""   : r.GetString(4),
            MonitorPriority = r.IsDBNull(5) ? "P3" : r.GetString(5)
        };
    }

    public async Task<List<FileBaseline>> GetAllBaselinesAsync()
    {
        var list = new List<FileBaseline>();
        using var cmd = _readConn.CreateCommand();
        cmd.CommandText =
            "SELECT filepath,last_hash,last_seen,last_size,module,monitor_priority " +
            "FROM file_baseline";

        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new FileBaseline
            {
                Filepath        = r.GetString(0),
                LastHash        = r.GetString(1),
                LastSeen        = r.GetString(2),
                LastSize        = r.IsDBNull(3) ? 0L   : r.GetInt64(3),
                Module          = r.IsDBNull(4) ? ""   : r.GetString(4),
                MonitorPriority = r.IsDBNull(5) ? "P3" : r.GetString(5)
            });

        return list;
    }

    public async Task DeleteBaselineAsync(string filepath)
    {
        await _writeLock.WaitAsync();
        try
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = "DELETE FROM file_baseline WHERE filepath=@fp";
            cmd.Parameters.AddWithValue("@fp", filepath);
            await cmd.ExecuteNonQueryAsync();
        }
        finally { _writeLock.Release(); }
    }

    // ── monitor_config ───────────────────────────────────────────────────────

    /// <summary>
    /// Load runtime configuration from the monitor_config table.
    /// Called synchronously once at service startup.
    /// </summary>
    public MonitorConfig LoadConfig()
    {
        var cfg = new MonitorConfig();
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = "SELECT key, value FROM monitor_config";
        using var r = cmd.ExecuteReader();

        while (r.Read())
        {
            var key = r.GetString(0);
            var val = r.GetString(1);
            switch (key)
            {
                case "watch_path":        cfg.WatchPath       = val; break;
                case "store_content_p1":  cfg.StoreContentP1  = val == "true"; break;
                case "max_content_bytes": cfg.MaxContentBytes  = long.TryParse(val, out var maxBytes) ? maxBytes : 1048576L; break;
                case "debounce_ms":       cfg.DebounceMs       = int.TryParse(val, out var debounceMs) ? debounceMs : 500; break;
                case "fsw_buffer_bytes":  cfg.FswBufferBytes   = int.TryParse(val, out var fswBuf) ? fswBuf : 65536; break;
                case "machine_name":
                    cfg.MachineName = string.IsNullOrWhiteSpace(val)
                        ? System.Net.Dns.GetHostName() : val;
                    break;
            }
        }
        return cfg;
    }

    public void Dispose()
    {
        _writeLock.Dispose();
        _conn.Dispose();
        _readConn.Dispose();
    }
}
```

---

### A.11 — `FileChangeHandler.cs`

The single writer thread calls `HandleAsync` for every debounced event.

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class FileChangeHandler
{
    private readonly SqliteRepository  _repo;
    private readonly FileClassifier    _classifier;
    private readonly ContentCache      _contentCache;
    private readonly MonitorConfig     _config;
    private readonly ILogger<FileChangeHandler> _logger;

    public FileChangeHandler(
        SqliteRepository repo, FileClassifier classifier,
        ContentCache contentCache, MonitorConfig config,
        ILogger<FileChangeHandler> logger)
    {
        _repo         = repo;
        _classifier   = classifier;
        _contentCache = contentCache;
        _config       = config;
        _logger       = logger;
    }

    /// <summary>
    /// Process one file-change event end-to-end:
    ///   classify → hash → read content → diff → write audit_log → update baseline
    /// Called from the single writer thread; no concurrent calls for the same file.
    /// </summary>
    public async Task HandleAsync(ChangeEvent ev)
    {
        _logger.LogDebug("Processing change. Path={P} ChangeType={T}", ev.FullPath, ev.ChangeType);

        var cls      = _classifier.Classify(ev.FullPath);
        var baseline = await _repo.GetBaselineAsync(ev.FullPath);

        _logger.LogDebug("Classified. Module={M} OwnerService={O} Priority={P}",
                          cls.Module, cls.OwnerService, cls.MonitorPriority);

        string? oldHash    = baseline?.LastHash;
        string? newHash    = null;
        string? oldContent = null;
        string? newContent = null;
        string? diffText   = null;
        string  changeType;

        switch (ev.ChangeType)
        {
            // ── Deleted ──────────────────────────────────────────────────
            case WatcherChangeTypes.Deleted:
                changeType = "Deleted";
                oldContent = _contentCache.Get(ev.FullPath);
                break;

            // ── Created / Changed ────────────────────────────────────────
            case WatcherChangeTypes.Created:
            case WatcherChangeTypes.Changed:
                newHash = HashHelper.ComputeSha256(ev.FullPath);
                if (newHash is null)
                {
                    _logger.LogWarning("Could not hash {P} — skipping.", ev.FullPath);
                    return;
                }

                _logger.LogDebug("Hash computed. OldHash={O} NewHash={N} HashChanged={C}",
                                  oldHash?[..8] ?? "null", newHash[..8],
                                  newHash != oldHash);

                // Hash unchanged → update last_seen only, no audit row
                if (newHash == oldHash)
                {
                    await _repo.UpsertBaselineAsync(MakeBaseline(ev.FullPath, newHash, cls));
                    return;
                }

                changeType = baseline is null ? "Created" : "Modified";

                // P1 files: read full content and produce diff
                if (cls.MonitorPriority == "P1" && _config.StoreContentP1)
                {
                    var fi = new FileInfo(ev.FullPath);
                    if (fi.Length <= _config.MaxContentBytes)
                    {
                        _logger.LogDebug("Reading content for P1 file. SizeBytes={S}", fi.Length);
                        newContent = await ReadTextAsync(ev.FullPath);
                        oldContent = _contentCache.Get(ev.FullPath);

                        if (changeType == "Modified" && oldContent is not null && newContent is not null)
                        {
                            diffText = DiffHelper.UnifiedDiff(
                                oldContent, newContent,
                                Path.GetFileName(ev.FullPath),
                                baseline!.LastSeen != null
                                    ? DateTime.Parse(baseline.LastSeen, null,
                                        System.Globalization.DateTimeStyles.RoundtripKind)
                                    : ev.DetectedAt.AddSeconds(-1),
                                ev.DetectedAt);

                            _logger.LogDebug("Diff computed. LinesAdded={A} LinesRemoved={R}",
                                              CountDiffLines(diffText, '+'),
                                              CountDiffLines(diffText, '-'));
                        }

                        if (newContent is not null)
                            _contentCache.Set(ev.FullPath, newContent);
                    }
                    else
                    {
                        diffText = $"[content omitted: size {fi.Length:N0} bytes " +
                                    "exceeds max_content_bytes limit]";
                    }
                }
                break;

            // ── Renamed ──────────────────────────────────────────────────
            case WatcherChangeTypes.Renamed:
                changeType = "Renamed";
                oldContent = _contentCache.Get(ev.OldPath ?? ev.FullPath);
                newHash    = HashHelper.ComputeSha256(ev.FullPath);
                if (ev.OldPath is not null)
                {
                    await _repo.DeleteBaselineAsync(ev.OldPath);
                    _contentCache.Remove(ev.OldPath);
                }
                break;

            default:
                return;
        }

        var entry = new AuditLogEntry
        {
            Filepath        = ev.FullPath,
            Filename        = Path.GetFileName(ev.FullPath),
            Extension       = Path.GetExtension(ev.FullPath).ToLowerInvariant(),
            ChangeType      = changeType,
            OldHash         = oldHash,
            NewHash         = newHash,
            OldContent      = oldContent,
            NewContent      = newContent,
            DiffText        = diffText,
            Module          = cls.Module,
            OwnerService    = cls.OwnerService,
            MonitorPriority = cls.MonitorPriority,
            DetectedAt      = ev.DetectedAt.ToString("O"),
            MachineName     = _config.MachineName
        };

        await _repo.InsertAuditLogAsync(entry);

        _logger.LogInformation(
            "Audit event written. File={F} ChangeType={C} Module={M} Priority={P} " +
            "OldHash={OH} NewHash={NH}",
            Path.GetFileName(ev.FullPath), changeType,
            cls.Module, cls.MonitorPriority,
            oldHash?[..8] ?? "null", newHash?[..8] ?? "null");

        // Update baseline (for Deleted: remove it)
        if (ev.ChangeType == WatcherChangeTypes.Deleted)
        {
            await _repo.DeleteBaselineAsync(ev.FullPath);
            _contentCache.Remove(ev.FullPath);
        }
        else if (newHash is not null)
        {
            await _repo.UpsertBaselineAsync(MakeBaseline(ev.FullPath, newHash, cls));
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static FileBaseline MakeBaseline(string path, string hash,
                                              FileClassifier.ClassificationResult cls) =>
        new()
        {
            Filepath        = path,
            LastHash        = hash,
            LastSeen        = DateTime.UtcNow.ToString("O"),
            LastSize        = new FileInfo(path).Exists ? new FileInfo(path).Length : 0,
            Module          = cls.Module,
            MonitorPriority = cls.MonitorPriority
        };

    private static async Task<string?> ReadTextAsync(string path)
    {
        try
        {
            using var fs = new FileStream(path, FileMode.Open,
                                          FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs, detectEncodingFromByteOrderMarks: true);
            return await sr.ReadToEndAsync();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    private static int CountDiffLines(string? diff, char prefix) =>
        diff?.Split('\n').Count(l => l.Length > 0 &&
                                     l[0] == prefix &&
                                     (l.Length < 2 || l[1] != prefix)) ?? 0;
}
```

---

### A.12 — `ChangeEvent.cs`

```csharp
namespace FalconAuditService;

internal record ChangeEvent(
    string             FullPath,
    WatcherChangeTypes ChangeType,
    DateTime           DetectedAt,
    string?            OldPath = null   // populated for Renamed events only
);
```

---

### A.13 — `FileMonitorService.cs`

```csharp
namespace FalconAuditService;

using System.Collections.Concurrent;
using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class FileMonitorService : IDisposable
{
    private FileSystemWatcher?                              _watcher;
    private readonly ConcurrentDictionary<string, Timer>   _debounce = new();
    private readonly BlockingCollection<ChangeEvent>        _queue    = new(1000);
    private readonly FileChangeHandler   _handler;
    private readonly CatchUpScanner      _catchUp;
    private readonly MonitorConfig       _config;
    private readonly ILogger<FileMonitorService> _logger;
    private CancellationToken            _ct;
    private Thread?                       _writerThread;

    public FileMonitorService(FileChangeHandler handler, CatchUpScanner catchUp,
                               MonitorConfig config, ILogger<FileMonitorService> logger)
    {
        _handler = handler;
        _catchUp = catchUp;
        _config  = config;
        _logger  = logger;
    }

    /// <summary>Start the FSW and launch the single writer thread.</summary>
    public void Start(CancellationToken ct)
    {
        _ct = ct;
        InitWatcher();
        _writerThread = new Thread(DrainQueue) { IsBackground = true, Name = "AuditWriter" }; _writerThread.Start();
        _logger.LogInformation(
            "FileMonitorService: FileSystemWatcher enabled. Path={P} Buffer={B}",
            _config.WatchPath, _config.FswBufferBytes);
    }

    /// <summary>Disable the FSW and signal the writer thread to drain and exit.</summary>
    public void Stop()
    {
        _watcher?.Dispose();
        _queue.CompleteAdding();
        _writerThread?.Join(TimeSpan.FromSeconds(10));
        _logger.LogInformation("FileMonitorService: FileSystemWatcher disabled.");
    }

    // ── FileSystemWatcher ─────────────────────────────────────────────────────

    private void InitWatcher()
    {
        _watcher?.Dispose();
        _watcher = new FileSystemWatcher(_config.WatchPath)
        {
            NotifyFilters         = NotifyFilters.FileName
                                  | NotifyFilters.LastWrite
                                  | NotifyFilters.DirectoryName,
            IncludeSubdirectories = true,
            InternalBufferSize    = _config.FswBufferBytes,
            Filter                = "*.*",
            EnableRaisingEvents   = true
        };
        _watcher.Changed += OnFileEvent;
        _watcher.Created += OnFileEvent;
        _watcher.Deleted += OnFileEvent;
        _watcher.Renamed += OnRenamed;
        _watcher.Error   += OnError;
    }

    private void OnFileEvent(object _, FileSystemEventArgs e)
    {
        _logger.LogDebug("FSW event received. Type={T} Path={P}", e.ChangeType, e.FullPath);

        // Per-path debounce timer — resets on every rapid successive event
        _debounce.AddOrUpdate(
            e.FullPath,
            key  => new Timer(FireDebounce, e, _config.DebounceMs, Timeout.Infinite),
            (key, existing) =>
            {
                existing.Change(_config.DebounceMs, Timeout.Infinite);
                _logger.LogDebug("FSW event received. Type={T} Path={P}  (debounce reset)",
                                  e.ChangeType, e.FullPath);
                return existing;
            });
    }

    private void OnRenamed(object _, RenamedEventArgs e)
    {
        _logger.LogDebug("FSW event received. Type=Renamed OldPath={O} NewPath={N}",
                          e.OldFullPath, e.FullPath);
        // Rename is atomic — no debounce needed
        TryEnqueue(new ChangeEvent(e.FullPath, WatcherChangeTypes.Renamed,
                                   DateTime.UtcNow, e.OldFullPath));
    }

    private void FireDebounce(object? state)
    {
        var e = (FileSystemEventArgs)state!;
        if (_debounce.TryRemove(e.FullPath, out var t)) t.Dispose();
        _logger.LogDebug("Debounce fired. Path={P}  Enqueued.", e.FullPath);
        TryEnqueue(new ChangeEvent(e.FullPath, e.ChangeType, DateTime.UtcNow));
    }

    private void OnError(object _, ErrorEventArgs e)
    {
        _logger.LogWarning("FSW buffer overflow or error: {M}. Restarting watcher.",
                            e.GetException().Message);
        InitWatcher();
        // Catch up on anything missed during the overflow window
        _ = Task.Run(() => _catchUp.RunAsync(_config.WatchPath, _ct));
    }

    private void TryEnqueue(ChangeEvent ev)
    {
        if (!_queue.IsAddingCompleted)
            _queue.TryAdd(ev);
    }

    // ── Writer thread ─────────────────────────────────────────────────────────

    /// <summary>
    /// Single dedicated thread that drains the BlockingCollection and calls
    /// FileChangeHandler.HandleAsync sequentially — one event at a time.
    /// This makes SQLite writes and content-cache access naturally serialised.
    /// </summary>
    private void DrainQueue()
    {
        foreach (var ev in _queue.GetConsumingEnumerable(_ct))
        {
            try   { _handler.HandleAsync(ev).GetAwaiter().GetResult(); }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled error processing event. Path={P}", ev.FullPath);
            }
        }
    }

    public void Dispose()
    {
        _watcher?.Dispose();
        _queue.Dispose();
        foreach (var t in _debounce.Values) t.Dispose();
    }
}
```

---

### A.14 — `CatchUpScanner.cs`

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Logging;

public class CatchUpScanner
{
    private readonly SqliteRepository  _repo;
    private readonly FileClassifier    _classifier;
    private readonly ContentCache      _contentCache;
    private readonly MonitorConfig     _config;
    private readonly ILogger<CatchUpScanner> _logger;
    private readonly SemaphoreSlim     _guard = new(1, 1);

    // Extensions to include — mirrors the FSW include-list
    private static readonly HashSet<string> IncludedExts =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ".txt", ".ini", ".json", ".xml", ".csv", ".log",
            ".yaml", ".yml", ".cfg", ".dat", ".seq", ".md",
            ".properties", ".conf", ".config", ".bat", ".cmd", ".ps1", ".sql"
        };

    public CatchUpScanner(SqliteRepository repo, FileClassifier classifier,
                           ContentCache contentCache, MonitorConfig config,
                           ILogger<CatchUpScanner> logger)
    {
        _repo         = repo;
        _classifier   = classifier;
        _contentCache = contentCache;
        _config       = config;
        _logger       = logger;
    }

    /// <summary>
    /// Compare every file under watchPath against the stored baseline.
    /// Insert audit rows for Created / Modified / Deleted events detected
    /// while the service was stopped.  Populates ContentCache for P1 files.
    /// </summary>
    public async Task RunAsync(string watchPath, CancellationToken ct)
    {
        if (!await _guard.WaitAsync(0))
        {
            _logger.LogWarning("CatchUpScanner: already running — skipping.");
            return;
        }
        try   { await CoreAsync(watchPath, ct); }
        finally { _guard.Release(); }
    }

    private async Task CoreAsync(string watchPath, CancellationToken ct)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        _logger.LogInformation("CatchUpScanner: starting reconciliation scan.");

        // Enumerate current files on disk
        var currentFiles = Directory
            .EnumerateFiles(watchPath, "*.*", SearchOption.AllDirectories)
            .Where(f => IncludedExts.Contains(Path.GetExtension(f)))
            .ToList();

        _logger.LogInformation("CatchUpScanner: found {N} candidate files.", currentFiles.Count);

        var allBaselines = await _repo.GetAllBaselinesAsync();
        var baselineMap  = allBaselines.ToDictionary(b => b.Filepath,
                                                      StringComparer.OrdinalIgnoreCase);
        var currentSet   = new HashSet<string>(currentFiles, StringComparer.OrdinalIgnoreCase);

        int created = 0, modified = 0, deleted = 0, unchanged = 0;

        // ── Phase 1: inspect current files ──────────────────────────────────
        foreach (var path in currentFiles)
        {
            ct.ThrowIfCancellationRequested();

            string? hash;
            long    size;
            try
            {
                hash = HashHelper.ComputeSha256(path);
                size = new FileInfo(path).Length;
            }
            catch (IOException)
            {
                // File deleted mid-scan; FSW will pick it up after Start()
                continue;
            }
            if (hash is null) continue;

            var cls = _classifier.Classify(path);
            baselineMap.TryGetValue(path, out var bl);

            if (bl is null)
            {
                // New file appeared while service was stopped
                string? content = await ReadIfP1Async(path, cls.MonitorPriority, size);
                if (content is not null) _contentCache.Set(path, content);

                await _repo.InsertAuditLogAsync(new AuditLogEntry
                {
                    Filepath        = path,
                    Filename        = Path.GetFileName(path),
                    Extension       = Path.GetExtension(path).ToLowerInvariant(),
                    ChangeType      = "Created",
                    NewHash         = hash,
                    NewContent      = content,
                    Module          = cls.Module,
                    OwnerService    = cls.OwnerService,
                    MonitorPriority = cls.MonitorPriority,
                    DetectedAt      = DateTime.UtcNow.ToString("O"),
                    MachineName     = _config.MachineName,
                    Note            = "catch-up"
                });
                created++;
            }
            else if (hash != bl.LastHash)
            {
                // File was modified while service was stopped
                string? newContent = await ReadIfP1Async(path, cls.MonitorPriority, size);
                if (newContent is not null) _contentCache.Set(path, newContent);

                await _repo.InsertAuditLogAsync(new AuditLogEntry
                {
                    Filepath        = path,
                    Filename        = Path.GetFileName(path),
                    Extension       = Path.GetExtension(path).ToLowerInvariant(),
                    ChangeType      = "Modified",
                    OldHash         = bl.LastHash,
                    NewHash         = hash,
                    NewContent      = newContent,
                    Module          = cls.Module,
                    OwnerService    = cls.OwnerService,
                    MonitorPriority = cls.MonitorPriority,
                    DetectedAt      = DateTime.UtcNow.ToString("O"),
                    MachineName     = _config.MachineName,
                    Note            = "catch-up"
                });
                modified++;
            }
            else
            {
                // Unchanged — populate content cache so first live Modified has old_content
                if (cls.MonitorPriority == "P1" && _config.StoreContentP1
                    && size <= _config.MaxContentBytes)
                {
                    var content = await ReadIfP1Async(path, cls.MonitorPriority, size);
                    if (content is not null) _contentCache.Set(path, content);
                }
                unchanged++;
            }

            await _repo.UpsertBaselineAsync(new FileBaseline
            {
                Filepath        = path,
                LastHash        = hash,
                LastSeen        = DateTime.UtcNow.ToString("O"),
                LastSize        = size,
                Module          = cls.Module,
                MonitorPriority = cls.MonitorPriority
            });
        }

        // ── Phase 2: detect deletions ────────────────────────────────────────
        foreach (var bl in allBaselines)
        {
            ct.ThrowIfCancellationRequested();
            if (currentSet.Contains(bl.Filepath)) continue;

            await _repo.InsertAuditLogAsync(new AuditLogEntry
            {
                Filepath        = bl.Filepath,
                Filename        = Path.GetFileName(bl.Filepath),
                Extension       = Path.GetExtension(bl.Filepath).ToLowerInvariant(),
                ChangeType      = "Deleted",
                OldHash         = bl.LastHash,
                Module          = bl.Module,
                MonitorPriority = bl.MonitorPriority,
                DetectedAt      = DateTime.UtcNow.ToString("O"),
                MachineName     = _config.MachineName,
                Note            = "catch-up"
            });
            await _repo.DeleteBaselineAsync(bl.Filepath);
            _contentCache.Remove(bl.Filepath);
            deleted++;
        }

        sw.Stop();
        _logger.LogInformation(
            "CatchUpScanner: complete. Unchanged={U} Created={C} Modified={M} Deleted={D} Elapsed={E}ms",
            unchanged, created, modified, deleted, sw.ElapsedMilliseconds);
    }

    private async Task<string?> ReadIfP1Async(string path, string priority, long size)
    {
        if (priority != "P1" || !_config.StoreContentP1) return null;
        if (size > _config.MaxContentBytes) return null;
        try
        {
            using var fs = new FileStream(path, FileMode.Open,
                                          FileAccess.Read, FileShare.ReadWrite);
            using var sr = new StreamReader(fs, detectEncodingFromByteOrderMarks: true);
            return await sr.ReadToEndAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ReadIfP1Async: could not read content for {P}", path);
            return null;
        }
    }
}
```

---

### A.15 — `Worker.cs`

```csharp
namespace FalconAuditService;

using FalconAuditService.Models;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

public class Worker : BackgroundService
{
    private readonly FileMonitorService _monitor;
    private readonly CatchUpScanner     _catchUp;
    private readonly MonitorConfig      _config;
    private readonly ILogger<Worker>    _logger;

    public Worker(FileMonitorService monitor, CatchUpScanner catchUp,
                  MonitorConfig config, ILogger<Worker> logger)
    {
        _monitor = monitor;
        _catchUp = catchUp;
        _config  = config;
        _logger  = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "FalconAuditService starting. WatchPath={W} DB={D}",
            _config.WatchPath, _config.DbPath);

        // Step 1: reconcile any changes that happened while the service was stopped
        if (!Directory.Exists(_config.WatchPath))
        {
            _logger.LogCritical(
                "WatchPath does not exist: {P} — service cannot start monitoring.", _config.WatchPath);
            return;
        }

        using var scanTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(60));
        using var scanCts     = CancellationTokenSource.CreateLinkedTokenSource(
                                    stoppingToken, scanTimeout.Token);
        try
        {
            await _catchUp.RunAsync(_config.WatchPath, scanCts.Token);
        }
        catch (OperationCanceledException) when (scanTimeout.IsCancellationRequested)
        {
            _logger.LogWarning(
                "CatchUpScanner exceeded 60 s startup limit — starting live monitor with partial catch-up.");
        }

        // Step 2: start live FSW monitoring (AFTER catch-up to avoid double-counting)
        _monitor.Start(stoppingToken);
        _logger.LogInformation("FalconAuditService running.");

        // Keep alive until cancellation is requested
        try { await Task.Delay(Timeout.Infinite, stoppingToken); }
        catch (TaskCanceledException) { /* normal shutdown */ }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("StopAsync requested. Draining queue.");
        _monitor.Stop();
        await base.StopAsync(cancellationToken);
        _logger.LogInformation("FalconAuditService stopped.");
    }
}
```

---

### A.16 — `Program.cs`

```csharp
using FalconAuditService;
using FalconAuditService.Models;
using Serilog;

// Bootstrap Serilog from appsettings.json before the host is built
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(
        new ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build())
    .CreateLogger();

try
{
    IHost host = Host.CreateDefaultBuilder(args)
        .UseWindowsService(o => o.ServiceName = "FalconAuditService")
        .UseSerilog()
        .ConfigureServices((ctx, services) =>
        {
            // SqliteRepository opened first — used to load MonitorConfig from DB
            services.AddSingleton<SqliteRepository>();

            // MonitorConfig loaded from monitor_config table at startup
            services.AddSingleton(sp =>
                sp.GetRequiredService<SqliteRepository>().LoadConfig());

            services.AddSingleton<ContentCache>();
            services.AddSingleton<FileClassifier>();
            services.AddSingleton<FileChangeHandler>();
            services.AddSingleton<CatchUpScanner>();
            services.AddSingleton<FileMonitorService>();
            services.AddHostedService<Worker>();
        })
        .Build();

    await host.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "FalconAuditService terminated unexpectedly.");
}
finally
{
    Log.CloseAndFlush();
}
```

---

### A.17 — `install.ps1`

```powershell
<#
.SYNOPSIS
    Install or uninstall the FalconAuditService Windows Service.
.EXAMPLE
    .\install.ps1 -Action Install
    .\install.ps1 -Action Uninstall
#>
#Requires -RunAsAdministrator

param(
    [ValidateSet('Install','Uninstall')]
    [string]$Action      = 'Install',
    [string]$InstallPath = 'C:\bis\bin\FalconAuditService',
    [string]$DbPath      = 'C:\bis\auditlog'
)

$ServiceName = 'FalconAuditService'
$DisplayName = 'Falcon Audit Log Service'
$Description = 'Monitors c:\job\ for file changes and writes an audit log to SQLite.'
$ExePath     = Join-Path $InstallPath 'FalconAuditService.exe'
$DbDir       = $DbPath

if ($Action -eq 'Install') {
    if (-not (Test-Path $ExePath)) {
        Write-Error "Executable not found: $ExePath"
        exit 1
    }

    # Create audit log directory if absent
    if (-not (Test-Path $DbDir)) {
        New-Item -ItemType Directory -Path $DbDir | Out-Null
        Write-Host "Created directory: $DbDir"
    }

    # Register the service with SCM
    # SECURITY NOTE: LocalSystem has full machine privileges.
    # On production machines replace 'LocalSystem' with a dedicated low-privilege
    # service account that has: read access to C:\job\, write access to $DbPath only.
    # Example: New-LocalUser 'svc_falconaudit' -NoPassword; sc.exe create ... obj= '.\svc_falconaudit'
    sc.exe create $ServiceName `
        binPath= "`"$ExePath`"" `
        start=   auto `
        obj=     LocalSystem

    sc.exe description $ServiceName $Description
    sc.exe failure      $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000

    Start-Service -Name $ServiceName
    Write-Host "Service '$ServiceName' installed and started."

} elseif ($Action -eq 'Uninstall') {
    if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)?.Status -eq 'Running') {
        Stop-Service -Name $ServiceName -Force
        Write-Host "Service stopped."
    }
    sc.exe delete $ServiceName
    Write-Host "Service '$ServiceName' uninstalled."
}
```

---

## Section 11 — Q&A

### Q1 — What happens if the service is stopped, someone manually edits files, and then the service starts again? Are the differences detected?

**Yes — this is the primary purpose of `CatchUpScanner`.**

Every time the service starts, `Worker.ExecuteAsync()` runs `CatchUpScanner.RunAsync()` to completion *before* the live `FileSystemWatcher` is enabled. The scanner computes the SHA-256 of every monitored file on disk and compares it to the last-known hash stored in the `file_baseline` table. Any discrepancy becomes an audit row.

#### Startup sequence

```
Windows SCM starts FalconAuditService
  └── Worker.ExecuteAsync()
        │
        ├── Step 1: CatchUpScanner.RunAsync()          ← runs BEFORE FSW starts
        │     │
        │     ├── Phase 1 — inspect every current file on disk:
        │     │     ├── hash ≠ baseline.last_hash
        │     │     │     → INSERT audit_log  ChangeType="Modified"
        │     │     │                         old_hash = baseline value
        │     │     │                         new_hash = current SHA-256
        │     │     │                         new_content = file text  (P1 files only)
        │     │     │                         detected_at = "<now>" (clean ISO-8601)
        │     │     │                         note        = "catch-up"
        │     │     │
        │     │     ├── file not in baseline (new file appeared)
        │     │     │     → INSERT audit_log  ChangeType="Created"
        │     │     │
        │     │     └── hash = baseline       → no audit row; populate ContentCache (P1)
        │     │
        │     └── Phase 2 — detect deletions:
        │           for each baseline row whose filepath no longer exists on disk
        │             → INSERT audit_log  ChangeType="Deleted"
        │                                 old_hash = baseline value
        │
        └── Step 2: FileMonitorService.Start()         ← FSW enabled only after catch-up
```

#### What is captured vs. what is lost

| Scenario during downtime | Detected on restart? | Notes |
|---|---|---|
| `Recipe.ini` edited | **Yes** | `Modified` row; `old_hash` / `new_hash`; `new_content` stored for P1 files |
| File deleted | **Yes** | `Deleted` row with `old_hash` from baseline |
| New file created | **Yes** | `Created` row with `new_hash` |
| File edited then restored to original | **No** | SHA-256 matches baseline — indistinguishable from no change |
| Exact timestamp of the manual edit | **No** | `detected_at` = service-start time; `note = "catch-up"` identifies the row as offline-detected |

#### The `note = "catch-up"` marker

Catch-up rows have `detected_at` set to a clean ISO-8601 timestamp (the moment the scan ran) and `note = "catch-up"` to distinguish them from live events:

```
detected_at = "2026-04-10T09:14:03.221Z"
note        = "catch-up"
```

This means: *"the change happened during a downtime window — we know the before/after state from hashes, but not the exact moment the edit occurred."* Querying `WHERE note = 'catch-up'` returns all offline-detected events without needing to parse the timestamp string.

#### Diff availability during catch-up

For P1 files (e.g., `Recipe.ini`), the catch-up row stores `new_content` (the full file text after the change). However, **`diff_text` is NULL** in catch-up rows. A unified diff requires `old_content`, which was held only in the in-memory `ContentCache` — that cache is lost on service shutdown. Only the `old_hash` (from the DB baseline) is available, not the old text.

The full diff is available again from the first live `Modified` event after restart, because `CatchUpScanner` re-populates `ContentCache` with the current file text before handing control to the `FileSystemWatcher`.

#### Sample log output — service restart after manual edit

```
2026-04-10 09:14:02.881 +00:00 [INF] FalconAuditService starting. WatchPath=C:\job  DB=C:\bis\auditlog\audit.db
2026-04-10 09:14:02.901 +00:00 [INF] CatchUpScanner: starting reconciliation scan.
2026-04-10 09:14:02.904 +00:00 [INF] CatchUpScanner: found 237 candidate files.
2026-04-10 09:14:03.219 +00:00 [INF] CatchUpScanner: complete. Unchanged=236 Created=0 Modified=1 Deleted=0 Elapsed=318ms
2026-04-10 09:14:03.221 +00:00 [INF] AuditEvent  ChangeType=Modified  Priority=P1
                                       File=C:\job\Diced_10.0.4511\S1\Recipes\R2\Recipe.ini
                                       OldHash=7e91bc4a...  NewHash=a3f2e91b...
                                       Note=catch-up  (diff unavailable — service was stopped)
2026-04-10 09:14:03.225 +00:00 [INF] FileMonitorService: FileSystemWatcher enabled. Path=C:\job
```

#### Resulting audit_log row

```
id               = 1087
filepath         = C:\job\Diced_10.0.4511\S1\Recipes\R2\Recipe.ini
filename         = Recipe.ini
extension        = .ini
change_type      = Modified
old_hash         = 7e91bc4a...          ← from file_baseline (last value before shutdown)
new_hash         = a3f2e91b...          ← freshly computed on restart
old_content      = NULL                 ← not available (service was stopped)
new_content      = [OnScanFail=0 ...]   ← full text of file as found on restart (P1)
diff_text        = NULL                 ← cannot produce diff without old_content
module           = Recipe
owner_service    = RMS
monitor_priority = P1
detected_at      = 2026-04-10T09:14:03.221Z
machine_name     = FALCON-BIS-01
note             = catch-up
```

---

## Section 12 — HTTP Report API

The service exposes a local HTTP API on `http://localhost:5100` so that other tools (dashboards, scripts, CI checks) can query the audit log without direct SQLite file access.

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/changes` | Paginated list of change events (no content/diff bodies) |
| `GET` | `/api/changes/{id}` | Single change event with full `old_content`, `new_content`, `diff_text` |
| `GET` | `/api/changes/summary` | Aggregate counts by change type, priority, and module |
| `GET` | `/health` | Service health check |

### Query filters — `GET /api/changes`

| Parameter | Type | Example | Description |
|---|---|---|---|
| `from` | ISO datetime | `2026-04-01` | Include events at or after this time |
| `to` | ISO datetime | `2026-04-10T23:59:59` | Include events at or before this time |
| `filepath` | string | `Recipe.ini` | Partial match against `filepath` column (case-insensitive LIKE) |
| `priority` | string | `P1` | Exact match: `P1`, `P2`, or `P3` |
| `change_type` | string | `Modified` | Exact match: `Created`, `Modified`, `Deleted`, `Renamed` |
| `module` | string | `Recipe` | Exact match: `Recipe`, `Config`, `AlignmentData`, etc. |
| `page` | int | `1` | Page number (1-based, default 1) |
| `page_size` | int | `50` | Items per page (default 50, max 200) |

### Example requests and responses

**List P1 recipe changes today:**
```
GET http://localhost:5100/api/changes?priority=P1&module=Recipe&from=2026-04-10&page=1&page_size=20
```
```json
{
  "totalCount": 3,
  "page": 1,
  "pageSize": 20,
  "totalPages": 1,
  "items": [
    {
      "id": 1042,
      "filepath": "C:\\job\\Diced_10.0.4511\\S1\\Recipes\\R2\\Recipe.ini",
      "filename": "Recipe.ini",
      "changeType": "Modified",
      "oldHash": "7e91bc4a...",
      "newHash": "a3f2e91b...",
      "module": "Recipe",
      "ownerService": "RMS",
      "monitorPriority": "P1",
      "detectedAt": "2026-04-10T14:32:01.817Z",
      "machineName": "FALCON-BIS-01"
    }
  ]
}
```

**Full detail with diff:**
```
GET http://localhost:5100/api/changes/1042
```
```json
{
  "id": 1042,
  "filepath": "C:\\job\\Diced_10.0.4511\\S1\\Recipes\\R2\\Recipe.ini",
  "filename": "Recipe.ini",
  "extension": ".ini",
  "changeType": "Modified",
  "oldHash": "7e91bc4a...",
  "newHash": "a3f2e91b...",
  "oldContent": "...[OnScanFail=1]...",
  "newContent": "...[OnScanFail=0]...",
  "diffText": "--- Recipe.ini  2026-04-10T08:00:00Z (before)\n+++ Recipe.ini  2026-04-10T14:32:01Z (after)\n@@ -17,7 +17,7 @@\n ...",
  "module": "Recipe",
  "ownerService": "RMS",
  "monitorPriority": "P1",
  "detectedAt": "2026-04-10T14:32:01.817Z",
  "machineName": "FALCON-BIS-01"
}
```

**Summary:**
```
GET http://localhost:5100/api/changes/summary
```
```json
{
  "totalChanges": 1087,
  "byChangeType": { "Modified": 842, "Created": 180, "Deleted": 65, "Renamed": 0 },
  "byPriority":   { "P1": 310, "P2": 620, "P3": 157 },
  "byModule":     { "Recipe": 418, "AlignmentData": 290, "Config": 201, "Log": 178 },
  "earliestChange": "2026-04-10T09:14:03Z",
  "latestChange":   "2026-04-10T14:32:01Z"
}
```

### Security and binding

- Bound to `http://localhost:5100` only — not exposed outside the machine.
- No authentication required; the endpoint is only reachable from processes on the same machine.
- Port is configurable via `appsettings.json` key `ApiPort` (default `5100`).

### Implementation notes

- Switch `.csproj` SDK from `Microsoft.NET.Sdk.Worker` to `Microsoft.NET.Sdk.Web` to enable Kestrel.
- `Program.cs` changes from `Host.CreateDefaultBuilder` to `WebApplication.CreateBuilder`; `UseWindowsService()` still works.
- The `Worker` `BackgroundService` is registered as before — FSW monitoring is unaffected.
- Minimal API style (`app.MapGet`) in a static `ReportEndpoints` extension class.
- List endpoint omits `old_content`, `new_content`, `diff_text` to keep response payloads small; detail endpoint includes them.

---

### A.18 — Updated `FalconAuditService.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">   <!-- changed from Sdk.Worker to Sdk.Web -->

  <PropertyGroup>
    <TargetFramework>net6.0-windows</TargetFramework>
    <RuntimeIdentifier>win-x64</RuntimeIdentifier>
    <SelfContained>true</SelfContained>
    <PublishSingleFile>true</PublishSingleFile>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Data.Sqlite"                          Version="7.0.*" />
    <PackageReference Include="DiffPlex"                                       Version="1.7.*" />
    <PackageReference Include="Microsoft.Extensions.Hosting.WindowsServices"   Version="7.0.*" />
    <PackageReference Include="Serilog.AspNetCore"                             Version="6.1.*" />
    <PackageReference Include="Serilog.Sinks.File"                             Version="5.0.*" />
    <PackageReference Include="Serilog.Sinks.EventLog"                         Version="3.1.*" />
  </ItemGroup>

</Project>
```

---

### A.19 — `ReportModels.cs`

```csharp
namespace FalconAuditService.Models;

// ── Query parameters ─────────────────────────────────────────────────────────

public record ChangeQuery(
    string? From       = null,
    string? To         = null,
    string? Filepath   = null,
    string? Priority   = null,
    string? ChangeType = null,
    string? Module     = null,
    int     Page       = 1,
    int     PageSize   = 50
);

// ── Response: list item (no large text fields) ───────────────────────────────

public record ChangeListItem(
    int     Id,
    string  Filepath,
    string  Filename,
    string  ChangeType,
    string? OldHash,
    string? NewHash,
    string  Module,
    string  OwnerService,
    string  MonitorPriority,
    string  DetectedAt,
    string  MachineName,
    string? Note             // null = live event; "catch-up" = detected on service restart
);

// ── Response: full detail (includes content + diff) ──────────────────────────

public record ChangeDetail(
    int     Id,
    string  Filepath,
    string  Filename,
    string  Extension,
    string  ChangeType,
    string? OldHash,
    string? NewHash,
    string? OldContent,
    string? NewContent,
    string? DiffText,
    string  Module,
    string  OwnerService,
    string  MonitorPriority,
    string  DetectedAt,
    string  MachineName,
    string? Note
);

// ── Response: aggregate summary ──────────────────────────────────────────────

public record ChangeSummary(
    int                      TotalChanges,
    Dictionary<string, int>  ByChangeType,
    Dictionary<string, int>  ByPriority,
    Dictionary<string, int>  ByModule,
    string?                  EarliestChange,
    string?                  LatestChange
);

// ── Response: paginated wrapper ──────────────────────────────────────────────

public record PagedResult<T>(
    int               TotalCount,
    int               Page,
    int               PageSize,
    int               TotalPages,
    IReadOnlyList<T>  Items
);
```

---

### A.20 — `SqliteRepository` — query additions

Add these methods to the existing `SqliteRepository` class (below `DeleteBaselineAsync`):

```csharp
// ── Report queries ────────────────────────────────────────────────────────────

public async Task<(int total, List<ChangeListItem> items)> QueryChangesAsync(ChangeQuery q)
{
    // Clamp page size to prevent runaway responses
    int pageSize = Math.Clamp(q.PageSize, 1, 200);
    int offset   = (Math.Max(q.Page, 1) - 1) * pageSize;

    const string whereBase = @"
        WHERE (@from       IS NULL OR detected_at >= @from)
          AND (@to         IS NULL OR detected_at <= @to)
          AND (@filepath   IS NULL OR filepath LIKE '%' || @filepathEsc || '%' ESCAPE '\')
          AND (@priority   IS NULL OR monitor_priority = @priority)
          AND (@changeType IS NULL OR change_type = @changeType)
          AND (@module     IS NULL OR module = @module)";

    int total;
    using (var cmd = _readConn.CreateCommand())
    {
        cmd.CommandText = $"SELECT COUNT(*) FROM audit_log {whereBase}";
        BindQueryParams(cmd, q);
        total = Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    var items = new List<ChangeListItem>();
    using (var cmd = _readConn.CreateCommand())
    {
        cmd.CommandText = $@"
            SELECT id, filepath, filename, change_type,
                   old_hash, new_hash, module, owner_service,
                   monitor_priority, detected_at, machine_name, note
            FROM audit_log
            {whereBase}
            ORDER BY detected_at DESC
            LIMIT @limit OFFSET @offset";

        BindQueryParams(cmd, q);
        cmd.Parameters.AddWithValue("@limit",  pageSize);
        cmd.Parameters.AddWithValue("@offset", offset);

        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            items.Add(new ChangeListItem(
                Id             : reader.GetInt32(0),
                Filepath       : reader.GetString(1),
                Filename       : reader.GetString(2),
                ChangeType     : reader.GetString(3),
                OldHash        : reader.IsDBNull(4)  ? null : reader.GetString(4),
                NewHash        : reader.IsDBNull(5)  ? null : reader.GetString(5),
                Module         : reader.IsDBNull(6)  ? ""   : reader.GetString(6),
                OwnerService   : reader.IsDBNull(7)  ? ""   : reader.GetString(7),
                MonitorPriority: reader.GetString(8),
                DetectedAt     : reader.GetString(9),
                MachineName    : reader.GetString(10),
                Note           : reader.IsDBNull(11) ? null : reader.GetString(11)
            ));
        }
    }

    return (total, items);
}

public async Task<ChangeDetail?> GetChangeByIdAsync(int id)
{
    using var cmd = _readConn.CreateCommand();
    cmd.CommandText = "SELECT * FROM audit_log WHERE id = @id";
    cmd.Parameters.AddWithValue("@id", id);

    using var reader = await cmd.ExecuteReaderAsync();
    if (!await reader.ReadAsync()) return null;

    return new ChangeDetail(
        Id             : reader.GetInt32(reader.GetOrdinal("id")),
        Filepath       : reader.GetString(reader.GetOrdinal("filepath")),
        Filename       : reader.GetString(reader.GetOrdinal("filename")),
        Extension      : reader.GetString(reader.GetOrdinal("extension")),
        ChangeType     : reader.GetString(reader.GetOrdinal("change_type")),
        OldHash        : Nullable(reader, "old_hash"),
        NewHash        : Nullable(reader, "new_hash"),
        OldContent     : Nullable(reader, "old_content"),
        NewContent     : Nullable(reader, "new_content"),
        DiffText       : Nullable(reader, "diff_text"),
        Module         : reader.IsDBNull(reader.GetOrdinal("module")) ? "" : reader.GetString(reader.GetOrdinal("module")),
        OwnerService   : reader.IsDBNull(reader.GetOrdinal("owner_service")) ? "" : reader.GetString(reader.GetOrdinal("owner_service")),
        MonitorPriority: reader.GetString(reader.GetOrdinal("monitor_priority")),
        DetectedAt     : reader.GetString(reader.GetOrdinal("detected_at")),
        MachineName    : reader.GetString(reader.GetOrdinal("machine_name")),
        Note           : Nullable(reader, "note")
    );
}

public async Task<ChangeSummary> GetSummaryAsync()
{
    var byType     = new Dictionary<string, int>();
    var byPriority = new Dictionary<string, int>();
    var byModule   = new Dictionary<string, int>();
    string? earliest = null, latest = null;

    using (var cmd = _readConn.CreateCommand())
    {
        cmd.CommandText =
            "SELECT change_type, COUNT(*) FROM audit_log GROUP BY change_type";
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            byType[r.GetString(0)] = r.GetInt32(1);
    }
    using (var cmd = _readConn.CreateCommand())
    {
        cmd.CommandText =
            "SELECT monitor_priority, COUNT(*) FROM audit_log GROUP BY monitor_priority";
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            byPriority[r.GetString(0)] = r.GetInt32(1);
    }
    using (var cmd = _readConn.CreateCommand())
    {
        cmd.CommandText =
            "SELECT module, COUNT(*) FROM audit_log WHERE module IS NOT NULL GROUP BY module";
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            byModule[r.GetString(0)] = r.GetInt32(1);
    }
    using (var cmd = _readConn.CreateCommand())
    {
        cmd.CommandText =
            "SELECT MIN(detected_at), MAX(detected_at) FROM audit_log";
        using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync())
        {
            earliest = r.IsDBNull(0) ? null : r.GetString(0);
            latest   = r.IsDBNull(1) ? null : r.GetString(1);
        }
    }

    int total = byType.Values.Sum();
    return new ChangeSummary(total, byType, byPriority, byModule, earliest, latest);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private static void BindQueryParams(SqliteCommand cmd, ChangeQuery q)
{
    cmd.Parameters.AddWithValue("@from",       (object?)q.From       ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@to",         (object?)q.To         ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@filepath",   (object?)q.Filepath   ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@filepathEsc",
        q.Filepath is null ? (object)DBNull.Value
        : q.Filepath.Replace(@"\", @"\\").Replace("%", @"\%").Replace("_", @"\_"));
    cmd.Parameters.AddWithValue("@priority",   (object?)q.Priority   ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@changeType", (object?)q.ChangeType ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@module",     (object?)q.Module     ?? DBNull.Value);
}

private static string? Nullable(SqliteDataReader r, string col)
{
    int i = r.GetOrdinal(col);
    return r.IsDBNull(i) ? null : r.GetString(i);
}
```

---

### A.21 — `ReportEndpoints.cs`

```csharp
using FalconAuditService.Models;
using Microsoft.AspNetCore.Mvc;

namespace FalconAuditService;

public static class ReportEndpoints
{
    public static void Map(WebApplication app)
    {
        // ── GET /api/changes ─────────────────────────────────────────────────
        app.MapGet("/api/changes", async (
            [FromServices] SqliteRepository repo,
            [FromQuery]    string? from        = null,
            [FromQuery]    string? to          = null,
            [FromQuery]    string? filepath    = null,
            [FromQuery]    string? priority    = null,
            [FromQuery]    string? change_type = null,
            [FromQuery]    string? module      = null,
            [FromQuery]    int     page        = 1,
            [FromQuery]    int     page_size   = 50) =>
        {
            var query = new ChangeQuery(from, to, filepath, priority, change_type, module,
                                        page, page_size);
            var (total, items) = await repo.QueryChangesAsync(query);
            int clampedSize    = Math.Clamp(page_size, 1, 200);
            int totalPages     = total == 0 ? 0 : (int)Math.Ceiling(total / (double)clampedSize);

            return Results.Ok(new PagedResult<ChangeListItem>(
                TotalCount: total,
                Page:       page,
                PageSize:   clampedSize,
                TotalPages: totalPages,
                Items:      items
            ));
        });

        // ── GET /api/changes/summary ─────────────────────────────────────────
        // NOTE: must be registered BEFORE /api/changes/{id} so "summary" is not
        //       parsed as an integer id.
        app.MapGet("/api/changes/summary", async (
            [FromServices] SqliteRepository repo) =>
        {
            var summary = await repo.GetSummaryAsync();
            return Results.Ok(summary);
        });

        // ── GET /api/changes/{id} ────────────────────────────────────────────
        app.MapGet("/api/changes/{id:int}", async (
            int id,
            [FromServices] SqliteRepository repo) =>
        {
            var detail = await repo.GetChangeByIdAsync(id);
            return detail is null
                ? Results.NotFound(new { error = $"No audit entry with id={id}" })
                : Results.Ok(detail);
        });

        // ── GET /health ──────────────────────────────────────────────────────
        app.MapGet("/health", ([FromServices] SqliteRepository repo) =>
            Results.Ok(new
            {
                status    = "healthy",
                service   = "FalconAuditService",
                timestamp = DateTime.UtcNow.ToString("O")
            }));
    }
}
```

---

### A.22 — Updated `Program.cs` (with API)

```csharp
using FalconAuditService;
using FalconAuditService.Models;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(
        new ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build())
    .CreateLogger();

try
{
    // WebApplication.CreateBuilder replaces Host.CreateDefaultBuilder so that
    // Kestrel (HTTP) is available alongside the Windows Service host.
    var builder = WebApplication.CreateBuilder(args);

    builder.Host
        .UseWindowsService(o => o.ServiceName = "FalconAuditService")
        .UseSerilog();

    // ── DI registrations (unchanged from original Program.cs) ────────────────
    builder.Services.AddSingleton<SqliteRepository>();
    builder.Services.AddSingleton(sp =>
        sp.GetRequiredService<SqliteRepository>().LoadConfig());
    builder.Services.AddSingleton<ContentCache>();
    builder.Services.AddSingleton<FileClassifier>();
    builder.Services.AddSingleton<FileChangeHandler>();
    builder.Services.AddSingleton<CatchUpScanner>();
    builder.Services.AddSingleton<FileMonitorService>();
    builder.Services.AddHostedService<Worker>();

    // ── Kestrel: bind to localhost only ──────────────────────────────────────
    int apiPort = builder.Configuration.GetValue<int>("ApiPort", defaultValue: 5100);
    builder.WebHost.ConfigureKestrel(k =>
        k.ListenLocalhost(apiPort));

    var app = builder.Build();

    // ── Register JSON serialization with camelCase ────────────────────────────
    app.MapGet("/", () => Results.Redirect("/health"));

    ReportEndpoints.Map(app);

    await app.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "FalconAuditService terminated unexpectedly.");
}
finally
{
    Log.CloseAndFlush();
}
```

Add `"ApiPort": 5100` to `appsettings.json`:

```json
{
  "ApiPort": 5100,
  "ConnectionStrings": {
    "AuditDb": "Data Source=C:\\bis\\auditlog\\audit.db"
  },
  "Serilog": {
    "MinimumLevel": { "Default": "Information", "Override": { "Microsoft": "Warning" } },
    "WriteTo": [
      { "Name": "File", "Args": { "path": "C:\\bis\\auditlog\\FalconAudit.log", "rollingInterval": "Day" } },
      { "Name": "EventLog", "Args": { "source": "FalconAuditService", "restrictedToMinimumLevel": "Warning" } }
    ]
  }
}
```
