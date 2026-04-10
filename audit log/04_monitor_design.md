# Audit Log — Prompt 4: Recommended Design & Implementation Plan

> **Goal:** Score the alternatives from Prompt 3, select the best solution, and deliver a
> complete SQLite schema, project structure, and phased implementation plan.
> **Input required:** `output/03_alternatives.md` + `output/02_file_summary.md`

---

You are a **senior software architect and tech lead** for the Camtek Falcon BIS platform.
You have the alternatives analysis from Prompt 3 (`output/03_alternatives.md`) and the file classification from Prompt 2 (`output/02_file_summary.md`).

Your task is to:
1. Score each option objectively
2. Recommend one option (or a justified hybrid)
3. Deliver a complete, buildable design for the winning solution

---

## Section 1 — Scoring & Decision

Score each option from Prompt 3 on a 1–5 scale for each criterion:

| Criterion | Weight | Option A | Option B | Option C | Option D |
|---|---|---|---|---|---|
| Isolation from Falcon process (failure independence) | 25% | | | | |
| Change detection completeness (no missed events) | 20% | | | | |
| SQLite write safety (no data loss on crash) | 15% | | | | |
| Handles service downtime (catch-up on restart) | 15% | | | | |
| Deployment & maintenance simplicity | 15% | | | | |
| Implementation effort (lower = better) | 10% | | | | |
| **Weighted total** | 100% | | | | |

**Recommendation:** State the winning option and give a 3–5 sentence justification.
If the recommendation is a hybrid, state exactly which parts of which options are combined and why.

---

## Section 2 — SQLite Database Schema

Design the complete SQLite schema for the winning solution.

### Required tables:

**`audit_log`** — one row per file change event:

```sql
CREATE TABLE audit_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    filepath    TEXT    NOT NULL,
    filename    TEXT    NOT NULL,
    extension   TEXT    NOT NULL,
    change_type TEXT    NOT NULL CHECK(change_type IN ('Created','Modified','Deleted','Renamed')),
    old_hash    TEXT,                      -- SHA-256 of file before change (NULL for Created)
    new_hash    TEXT,                      -- SHA-256 of file after change (NULL for Deleted)
    old_content TEXT,                      -- Full content snapshot before (P1 files only)
    new_content TEXT,                      -- Full content snapshot after (P1 files only)
    diff_text   TEXT,                      -- Unified diff (P1 Modified events)
    module      TEXT,                      -- From classification: Job/Recipe/Config/Log/etc.
    owner_service TEXT,                    -- From classification: RMS/Falcon.Net/AOI_Main/etc.
    monitor_priority TEXT,                 -- P1/P2/P3
    detected_at TEXT    NOT NULL,          -- ISO-8601 UTC timestamp
    machine_name TEXT   NOT NULL           -- hostname
);
```

**`file_baseline`** — last-known state per file (for catch-up on restart):

```sql
CREATE TABLE file_baseline (
    filepath        TEXT PRIMARY KEY,
    last_hash       TEXT NOT NULL,
    last_seen       TEXT NOT NULL,         -- ISO-8601 UTC
    last_size       INTEGER,
    module          TEXT,
    monitor_priority TEXT
);
```

**`monitor_config`** — runtime configuration (editable without recompile):

```sql
CREATE TABLE monitor_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- Seed rows:
-- ('watch_path',         'c:\job')
-- ('db_path',            'c:\bis\auditlog\audit.db')
-- ('poll_interval_ms',   '500')
-- ('store_content_p1',   'true')
-- ('max_content_bytes',  '1048576')
```

Add any indexes you consider necessary for query performance.
Explain your index choices.

---

## Section 3 — Project Structure

Provide the full project/file layout for the winning solution:

```
<ProjectName>/
├── <ProjectName>.csproj  (or .sln)
├── Program.cs / Worker.cs
├── FileMonitorService.cs
├── FileChangeHandler.cs
├── HashHelper.cs
├── DiffHelper.cs         (for P1 unified diff)
├── SqliteRepository.cs
├── FileClassifier.cs     (maps path → module + owner + priority)
├── CatchUpScanner.cs     (on-start scan for missed changes)
├── Models/
│   ├── AuditLogEntry.cs
│   ├── FileBaseline.cs
│   └── MonitorConfig.cs
├── appsettings.json      (or config from SQLite monitor_config table)
└── install.ps1           (Windows Service registration script)
```

For each class, provide:
- **Responsibility** (one sentence)
- **Key methods** (name + signature)
- **Dependencies** (which other classes it calls)

---

## Section 4 — FileClassifier Logic

The `FileClassifier` maps a file path to its `module`, `owner_service`, and `monitor_priority` based on the rules from `output/02_file_summary.md`.

Produce a mapping table that `FileClassifier` must implement:

| Path pattern | Extension(s) | Module | Owner service | Priority |
|---|---|---|---|---|
| `c:\job\*.xml` | `.xml` | Job | RMS | P1 |
| `c:\job\<name>\*.ini` | `.ini` | Config | Falcon.Net | P1 |
| ... | | | | |

Then write the `Classify(string filePath)` method signature and describe its matching algorithm (exact match → glob pattern → extension fallback → default to `Unknown / P3`).

---

## Section 5 — FileSystemWatcher Configuration

Provide the exact `FileSystemWatcher` setup for the winning solution:

1. Which `NotifyFilters` flags to set and why (avoid over-triggering)
2. Should `IncludeSubdirectories` be `true`? Justify.
3. How to debounce rapid successive events on the same file (e.g., a write followed by a metadata flush)
   - Recommended debounce window: N ms — justify the value
   - Data structure for the debounce queue
4. How to handle the `Error` event (buffer overflow when too many changes queue up)
5. `InternalBufferSize` recommendation and justification

---

## Section 6 — Catch-Up Scan Algorithm

On service start (or after a crash), the service must detect changes that occurred while it was stopped.

Write the algorithm in pseudocode:

```
procedure CatchUpScan(watchPath, db):
    for each file in RecursiveList(watchPath, includedExtensions):
        baseline = db.GetBaseline(file.FullPath)
        currentHash = SHA256(file)
        if baseline == null:
            // New file appeared while service was down
            db.InsertAuditLog(file, changeType=Created, ...)
        elif currentHash != baseline.LastHash:
            // File was modified while service was down
            db.InsertAuditLog(file, changeType=Modified, oldHash=baseline, ...)
        db.UpsertBaseline(file, currentHash)
    for each baseline in db.AllBaselines():
        if not FileExists(baseline.Filepath):
            db.InsertAuditLog(baseline, changeType=Deleted, ...)
            db.DeleteBaseline(baseline.Filepath)
```

Identify any race conditions in this algorithm and how to handle them.

---

## Section 7 — Phased Implementation Plan

Break the implementation into phases that can each be tested independently:

| Phase | Deliverable | Acceptance criteria |
|---|---|---|
| 1 | SQLite schema + `SqliteRepository` + unit tests | All CRUD operations work; DB created on first run |
| 2 | `FileClassifier` + classification table | 100% of P1/P2 files in test data are classified correctly |
| 3 | `FileSystemWatcher` wiring + debounce + `FileChangeHandler` | Creates/Modifies/Deletes on test files appear in DB within 1 second |
| 4 | `CatchUpScanner` | Files changed during service-stopped period appear in DB on next start |
| 5 | Windows Service wrapper + `install.ps1` | Service starts on boot, survives reboot, resumes monitoring |
| 6 | P1 content snapshot + diff | Full content and unified diff stored for Critical files |

---

## Section 8 — Risk & Rollout Notes

1. **Filesystem performance risk:** `FileSystemWatcher` + SHA-256 hashing on every event — what is the worst-case CPU/disk impact on a running scan? Recommend a mitigation (e.g., defer hashing to a background queue).
2. **SQLite write contention:** If multiple events arrive simultaneously, how does the repository avoid SQLITE_BUSY errors? (WAL mode? Serialized write queue?)
3. **Large file risk:** A job file could be 50 MB+. How does the service handle `store_content_p1 = true` without exhausting memory?
4. **Rollout order:**
   - Phase 1–4 can be run on a dev/test machine first
   - Phase 5 (service install) requires machine admin rights
   - Phase 6 (content snapshot) should be opt-in per machine via `monitor_config`

---

## Output Format

Produce a **design document** using the section structure above.
Where SQL or code is required, provide complete, compilable snippets — no pseudocode except where Section 6 explicitly requests it.

End with a **one-page summary** (5–10 bullet points) suitable for presenting the decision to a non-technical stakeholder.

Save the final document to:

`output/04_recommended_design.md`
