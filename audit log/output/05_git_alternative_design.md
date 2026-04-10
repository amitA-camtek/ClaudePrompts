# Audit Log — Output 5: Git-Based Alternative Design

> **Context:** Alternative to Option B (recommended Windows Service + SQLite) from `output/04_recommended_design.md`
> **Date:** 2026-04-11
> **Role:** Senior software architect and tech lead, Camtek Falcon BIS platform

---

## Overview

This design replaces SQLite as the primary storage layer with a **local Git repository** that mirrors the monitored `c:\job\` tree. Git's object store provides a tamper-evident, append-only history with built-in diff, content retrieval, and rollback. The detection mechanism (FileSystemWatcher + debounce) is identical to Option B.

Two variants are defined:

- **Option E1 — Pure Git**: Git is the sole store. All history, content, and diffs are derived from Git.
- **Option E2 — Git + SQLite index**: Git holds content and history; a lightweight SQLite table indexes metadata for fast structured queries.

Option E2 is the recommended variant within this design because Git log is not SQL and structured queries (e.g., "all P1 events in the last 24 h") require parsing commit messages without an index.

---

## Section 1 — Core Design Decision: Mirror Repository

The Git repository is **not** placed at `c:\job\`. Placing `.git/` inside the production job directory would:
- Pollute the directory watched by RMS and Falcon.Net with `.git/` objects
- Risk FSW event storms from Git's own index writes
- Expose `.git/` to accidental deletion by job management tools

Instead, a **dedicated mirror tree** at `C:\bis\auditlog\job-git\` is maintained. On each detected change, the service copies (or hard-links) the changed file into the mirror and commits.

```
C:\bis\auditlog\
├── job-git\              ← Git working tree (mirror of monitored files)
│   ├── .git\             ← Git object store
│   ├── job\              ← mirrors c:\job\ subtree
│   │   ├── status.ini
│   │   ├── Diced_10.0.4511\
│   │   │   └── S1\
│   │   │       └── Recipes\
│   │   │           └── R1\
│   │   │               └── Recipe.ini
│   │   └── ...
│   └── .gitattributes    ← force LF normalisation for .ini/.txt; treat .dat as binary
└── audit-index.db        ← (E2 only) lightweight SQLite metadata index
```

The mirror path for a file is computed as:

```csharp
string MirrorPath(string sourcePath)
{
    // sourcePath = C:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini
    // mirrorRoot = C:\bis\auditlog\job-git\job\
    var relative = Path.GetRelativePath(@"C:\", sourcePath);   // job\Diced...\Recipe.ini
    return Path.Combine(_mirrorRoot, relative);                // C:\bis\auditlog\job-git\job\...
}
```

---

## Section 2 — Architecture

```
Windows SCM
│
└── FalconAuditService.exe  (.NET 6+, same host process as Option B)
    │
    ├── Worker : BackgroundService
    │   ├── StartAsync()
    │   │   ├── GitRepository.EnsureInitialised()   ← git init if not exists
    │   │   ├── CatchUpScanner.RunAsync()            ← hash-compare current vs Git HEAD
    │   │   └── FileMonitorService.Start()
    │   └── StopAsync()
    │       └── FileMonitorService.Stop()
    │
    ├── FileMonitorService            (identical to Option B)
    │   ├── FileSystemWatcher(c:\job, recursive=true)
    │   ├── Debounce timers (500 ms)
    │   └── BlockingCollection<ChangeEvent> → GitAuditWriter
    │
    ├── FileClassifier                (identical to Option B)
    │   └── Classify(path) → (module, ownerService, priority)
    │
    ├── GitAuditWriter                (replaces SqliteRepository + HashHelper + DiffHelper)
    │   ├── LibGit2Sharp.Repository   ← in-process; no git.exe subprocess
    │   ├── HandleAsync(ChangeEvent)
    │   │   ├── Copy file into mirror tree (or mark deleted)
    │   │   ├── repo.Index.Add / Remove
    │   │   ├── repo.Commit(commitMessage: JSON metadata blob)
    │   │   └── (E2) SqliteIndexRepository.InsertAsync(summary row)
    │   └── SemaphoreSlim(1)          ← serialise all Git writes
    │
    ├── (E2) SqliteIndexRepository
    │   └── audit_index table — see Section 5
    │
    └── CatchUpScanner
        └── Compare c:\job\ files against Git HEAD tree
            → commit missed changes with note="catch-up"
```

**Key library:** `LibGit2Sharp` (NuGet: `LibGit2Sharp`, wraps `libgit2` native). This gives fully in-process Git operations — no `git.exe` on PATH required, no subprocess overhead, no shell injection risk.

---

## Section 3 — Commit Message Schema

Each commit records exactly one file change event. The commit message is a structured JSON blob to allow programmatic parsing:

```json
{
  "filepath":         "C:\\job\\Diced_10.0.4511\\S1\\Recipes\\R1\\Recipe.ini",
  "filename":         "Recipe.ini",
  "extension":        ".ini",
  "change_type":      "Modified",
  "module":           "Recipe",
  "owner_service":    "RMS",
  "monitor_priority": "P1",
  "detected_at":      "2026-04-11T09:14:22.317Z",
  "machine_name":     "FALCON-82134",
  "note":             ""
}
```

The first line of the commit message is a human-readable summary; the JSON follows after a blank line (standard Git convention):

```
Modified Recipe.ini [Recipe/RMS/P1]

{"filepath":"C:\\job\\...\\Recipe.ini","filename":"Recipe.ini","extension":".ini",
 "change_type":"Modified","module":"Recipe","owner_service":"RMS",
 "monitor_priority":"P1","detected_at":"2026-04-11T09:14:22.317Z",
 "machine_name":"FALCON-82134","note":""}
```

This makes `git log --oneline` human-readable while retaining full machine-parseable metadata.

---

## Section 4 — GitAuditWriter: Core Logic

```csharp
public class GitAuditWriter
{
    private readonly Repository _repo;          // LibGit2Sharp
    private readonly string _mirrorRoot;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private readonly Signature _author = new("FalconAuditService", "audit@falcon", DateTimeOffset.UtcNow);

    public async Task HandleAsync(ChangeEvent evt)
    {
        var classification = _classifier.Classify(evt.FilePath);
        var mirrorPath     = MirrorPath(evt.FilePath);

        await _lock.WaitAsync();
        try
        {
            switch (evt.ChangeType)
            {
                case WatcherChangeTypes.Created:
                case WatcherChangeTypes.Changed:
                    Directory.CreateDirectory(Path.GetDirectoryName(mirrorPath)!);
                    File.Copy(evt.FilePath, mirrorPath, overwrite: true);   // copy into mirror
                    Commands.Stage(_repo, MirrorRelative(mirrorPath));
                    break;

                case WatcherChangeTypes.Deleted:
                    if (File.Exists(mirrorPath)) File.Delete(mirrorPath);
                    Commands.Stage(_repo, MirrorRelative(mirrorPath));
                    break;

                case WatcherChangeTypes.Renamed:
                    var oldMirror = MirrorPath(evt.OldFullPath!);
                    if (File.Exists(oldMirror)) File.Delete(oldMirror);
                    Commands.Stage(_repo, MirrorRelative(oldMirror));
                    Directory.CreateDirectory(Path.GetDirectoryName(mirrorPath)!);
                    File.Copy(evt.FilePath, mirrorPath, overwrite: true);
                    Commands.Stage(_repo, MirrorRelative(mirrorPath));
                    break;
            }

            // Build commit — Git computes its own SHA; no separate HashHelper needed
            var sig     = new Signature("FalconAuditService", "audit@falcon", evt.DetectedAt);
            var message = BuildCommitMessage(evt, classification);
            _repo.Commit(message, sig, sig);

            // E2 only: write lightweight index row
            await _indexRepo.InsertAsync(new AuditIndexEntry
            {
                CommitSha     = _repo.Head.Tip.Sha,
                FilePath      = evt.FilePath,
                FileName      = Path.GetFileName(evt.FilePath),
                ChangeType    = evt.ChangeType.ToString(),
                Module        = classification.Module,
                OwnerService  = classification.OwnerService,
                Priority      = classification.MonitorPriority,
                DetectedAt    = evt.DetectedAt,
                MachineName   = Environment.MachineName
            });
        }
        catch (EmptyCommitException)
        {
            // File copy was byte-for-byte identical — nothing to commit; skip
        }
        finally
        {
            _lock.Release();
        }
    }
}
```

**`EmptyCommitException`** can occur if the file was touched (FSW event) but its content did not change. Git detects this automatically via tree comparison — no SHA pre-computation needed. The service catches this and skips the DB index write as well.

---

## Section 5 — SQLite Index Schema (Option E2 only)

The index stores metadata only — **no content, no diffs**. Content and diffs are always retrieved from Git.

```sql
CREATE TABLE IF NOT EXISTS audit_index (
    id               INTEGER  PRIMARY KEY AUTOINCREMENT,
    commit_sha       TEXT     NOT NULL,          -- Git commit SHA (40 hex chars)
    filepath         TEXT     NOT NULL,
    filename         TEXT     NOT NULL,
    extension        TEXT     NOT NULL,
    change_type      TEXT     NOT NULL CHECK(change_type IN ('Created','Modified','Deleted','Renamed')),
    module           TEXT,
    owner_service    TEXT,
    monitor_priority TEXT     NOT NULL,
    detected_at      TEXT     NOT NULL,          -- ISO-8601 UTC
    machine_name     TEXT     NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_filepath   ON audit_index(filepath);
CREATE INDEX IF NOT EXISTS idx_ai_detected   ON audit_index(detected_at);
CREATE INDEX IF NOT EXISTS idx_ai_priority   ON audit_index(monitor_priority, detected_at);
CREATE INDEX IF NOT EXISTS idx_ai_commit     ON audit_index(commit_sha);
```

`commit_sha` is the bridge: given any audit index row, full file content and diff are retrieved via:

```csharp
// Retrieve content of Recipe.ini at commit abc123
var blob  = (Blob)_repo.Lookup<Commit>("abc123")["job/Diced.../Recipe.ini"].Target;
var text  = blob.GetContentText();

// Compute diff between two commits
var patch = _repo.Diff.Compare<Patch>(parentCommit.Tree, thisCommit.Tree);
var diff  = patch["job/Diced.../Recipe.ini"].Patch;   // unified diff string
```

This means:
- The index is small (no content) — predictable, slow growth (~200–500 bytes/row)
- Full historical content is always available from Git
- Rollback is one LibGit2Sharp call: `repo.CheckoutPaths(commitSha, new[] { mirrorRelPath })`

---

## Section 6 — .gitattributes

Critical for reproducible diffs and correct binary handling:

```
# .gitattributes placed at root of job-git\
*            text=auto

# Text files — normalise line endings to LF on commit
*.ini        text eol=lf
*.txt        text eol=lf
*.json       text eol=lf
*.xml        text eol=lf
*.md         text eol=lf

# Binary files — no diff, no line-ending conversion
*.dat        binary
*.db         binary
*.exe        binary
*.dll        binary
```

Without this, Git may attempt text-diff on `.dat` binary files (noisy and misleading), and CRLF/LF fluctuations in Windows `.ini` files would generate false-positive diffs.

---

## Section 7 — CatchUpScanner (Git-based)

The catch-up algorithm is adapted to use Git HEAD as the baseline instead of a SQLite `file_baseline` table:

```
procedure CatchUpScan(watchPath, repo):

    headTree    = repo.Head.Tip.Tree   // null if no commits yet (fresh repo)
    currentFiles = RecursiveList(watchPath, includedExtensions)

    // --- Phase 1: scan current files against Git HEAD ---
    for each file in currentFiles:
        mirrorRelPath = MirrorRelative(MirrorPath(file.FullPath))
        headEntry     = headTree?[mirrorRelPath]    // null if file is new

        try:
            // Stage the current version
            File.Copy(file.FullPath, MirrorPath(file.FullPath), overwrite=true)
        catch IOException:
            continue   // file deleted mid-scan

        // Git detects content equality via tree hash comparison
        // Only commit if staging produces a change

    // Stage all current files in batch, then single commit
    Commands.Stage(repo, "*")
    treeId = repo.Index.WriteToTree()

    if headTree == null OR treeId != headTree.Id:
        // There are differences — commit them all as one catch-up commit
        repo.Commit("CatchUp: reconcile after service downtime", sig, sig)

    // --- Phase 2: detect deletions ---
    for each entry in headTree (if not null):
        if file NOT in currentFiles:
            File.Delete(MirrorPath(entry))
            Commands.Stage(repo, entry.Path)
    // (covered by the single catch-up commit above)

    // --- Phase 3: start FSW ---
    fileMonitorService.Start()
```

**Note:** The Git-based catch-up uses a single batch commit for all changes detected since downtime, rather than one commit per file. This is intentional: during downtime the sequence of individual changes is unknown, so a batch "reconciliation commit" is the correct semantic.

If individual-change granularity during downtime is required, the service can fall back to the hash-compare approach from Option B, using Git's `blob.Sha` as the hash rather than a separate SHA-256 computation.

---

## Section 8 — Query Patterns

### Via SQLite index (E2)

```sql
-- All P1 events in the last 24 h
SELECT * FROM audit_index
WHERE monitor_priority = 'P1'
  AND detected_at >= datetime('now', '-1 day')
ORDER BY detected_at DESC;

-- All changes to a specific file
SELECT * FROM audit_index
WHERE filepath = 'C:\job\Diced_10.0.4511\S1\Recipes\R1\Recipe.ini'
ORDER BY detected_at DESC;
```

### Via LibGit2Sharp (content / diff)

```csharp
// Full file content at any point in time
var commit = _repo.Lookup<Commit>(commitSha);
var blob   = (Blob)commit[mirrorRelPath].Target;
string content = blob.GetContentText();

// Unified diff for a specific commit
var parent = commit.Parents.First();
var patch  = _repo.Diff.Compare<Patch>(parent.Tree, commit.Tree);
string diff = patch[mirrorRelPath].Patch;

// Full history of one file
var filter = new CommitFilter { SortBy = CommitSortStrategies.Time };
foreach (var c in _repo.Commits.QueryBy(mirrorRelPath, filter))
    Console.WriteLine($"{c.Commit.Author.When}  {c.Commit.MessageShort}");
```

### Via standard Git tools (ops / forensics)

When SQL queries are not practical, a Falcon engineer can use any standard Git GUI or CLI directly on `C:\bis\auditlog\job-git\`:

```
git log --oneline -- job/Diced_10.0.4511/S1/Recipes/R1/Recipe.ini
git show <sha>:job/Diced_10.0.4511/S1/Recipes/R1/Recipe.ini
git diff <sha1>..<sha2> -- job/Diced_10.0.4511/S1/Recipes/R1/Recipe.ini
```

This is a capability that Option B (SQLite-only) cannot provide without a separate UI tool.

---

## Section 9 — Repository Maintenance

### Storage growth

Each Git commit stores the full snapshot of the changed file as a blob (compressed with zlib). For a `Recipe.ini` of ~5 KB, the first commit stores ~5 KB (compressed). Subsequent commits store only changed blobs; Git's pack algorithm delta-compresses similar blobs, so storage for INI files that change incrementally is very efficient.

For binary `.dat` files: each change stores a full new blob (no delta compression for binary). At 200 KB per `.dat` file and 10 changes per day, that is 2 MB/day from `.dat` blobs alone. Git GC (`git gc --auto`) packs loose objects periodically.

| File type | Size | 100 changes | Compressed (estimate) |
|---|---|---|---|
| `.ini` (text, small delta) | ~5 KB | ~50 KB raw | ~8–15 KB (delta pack) |
| `.dat` (binary) | ~200 KB | ~20 MB raw | ~18 MB (no delta) |
| `.json` (text) | ~10 KB | ~100 KB raw | ~20–40 KB (delta pack) |

**Recommendation:** Configure auto-prune for blobs older than 90 days if `.dat` history grows large:

```bash
git config gc.pruneExpire "90.days.ago"
git config gc.auto 256
```

This can be implemented as a `MaintenanceTask` that runs weekly in the Windows Service.

### No bare repository needed

The `job-git\` directory is a **working tree** repository (not bare). The working tree serves as the current mirror snapshot. A bare repository would remove the working tree, making file-by-file export harder.

---

## Section 10 — Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `libgit2` native DLL missing on target machine | Medium | Service fails to start | Bundle `libgit2` with the installer; it ships as a NuGet runtime asset — no separate install |
| Git index lock (`.git/index.lock`) left behind by crash | Low | Service fails to commit on next start | On startup: detect and delete stale `index.lock`; this is safe if no other process uses the repo |
| Mirror copy fails (file locked by RMS) | Medium | Change not committed | Retry up to 3× with 200 ms backoff; if still locked, log warning and skip — hash mismatch will be caught by next catch-up scan |
| Git GC runs during high-frequency write burst | Low | GC acquires write lock; brief commit delays | Disable `gc.auto` and run GC explicitly in the weekly maintenance window |
| Repo corruption from sudden power loss | Very Low | Partial commit on disk | WAL-like safety: Git writes to a temp object then renames atomically; partial objects are safely ignored by `git fsck`; recovery is `git fsck --unreachable` |
| Mirror diverges from production `c:\job\` | Low | False audit records | CatchUpScanner reconciles on every service start; periodic scheduled `git status` check in the maintenance task |
| Binary `.dat` files bloat the repository | High | Disk usage > 10 GB over months | Exclude `.dat` from Git content tracking (store hash-only commit messages for these); or set `max_content_bytes` equivalent via `.gitattributes filter` |

---

## Section 11 — Project Structure

```
FalconAuditService/               (same solution as Option B)
├── FalconAuditService.csproj
├── Program.cs
├── Worker.cs
├── FileMonitorService.cs         (unchanged from Option B)
├── FileClassifier.cs             (unchanged from Option B)
├── CatchUpScanner.cs             (modified: uses Git HEAD as baseline)
├── GitAuditWriter.cs             (new — replaces SqliteRepository + HashHelper + DiffHelper)
├── SqliteIndexRepository.cs      (new, E2 only — lightweight index)
├── MirrorPathResolver.cs         (new — maps c:\job paths to mirror paths)
├── GitMaintenanceTask.cs         (new — weekly GC + prune)
├── Models/
│   ├── AuditIndexEntry.cs        (new, E2 only)
│   ├── ChangeEvent.cs            (unchanged)
│   └── MonitorConfig.cs          (updated: add mirror_root, git_prune_days)
├── appsettings.json
└── install.ps1
```

**New NuGet dependency:** `LibGit2Sharp` (~3.5 MB, bundles `libgit2.dll` native).  
`DiffPlex`, `Microsoft.Data.Sqlite`, and dedicated `HashHelper`/`DiffHelper` classes from Option B are **not needed** in this design (Git subsumes those roles).

---

## Section 12 — Phased Implementation Plan

| Phase | Deliverable | Acceptance criteria |
|---|---|---|
| **1** | `MirrorPathResolver` + Git repo init + `GitAuditWriter` skeleton | Git repo created at `C:\bis\auditlog\job-git\`; manual file copy + commit via LibGit2Sharp succeeds; `git log` shows the commit |
| **2** | `FileClassifier` + `FileMonitorService` wired to `GitAuditWriter` | Create/Modify/Delete events on test files produce distinct Git commits within 1 s; `git show <sha>:<path>` returns correct content |
| **3** | E2: `SqliteIndexRepository` + metadata indexing | SQL query "all P1 events today" returns correct rows; `commit_sha` in each row resolves to correct Git object |
| **4** | `CatchUpScanner` (Git-based) | Stop service; modify 3 test files; start service; single catch-up commit appears in `git log`; all 3 changes visible in `git diff HEAD~1 HEAD` |
| **5** | Windows Service wrapper + `install.ps1` + stale-lock cleanup | Service starts on boot; survives 3 reboots; no stale `index.lock` errors |
| **6** | `GitMaintenanceTask` + `.gitattributes` binary handling | Weekly GC runs; `.dat` blobs handled per policy; `git fsck` reports no errors after 72 h of operation |
