# Audit Log — Output 6: Design Comparison

> **Compares:** Option B (External Windows Service + SQLite) vs. Option E (Git Mirror + LibGit2Sharp + optional SQLite index)
> **Source documents:** `output/04_recommended_design.md`, `output/05_git_alternative_design.md`
> **Date:** 2026-04-11

---

## Summary Verdict

| | Option B | Option E2 (Git + index) |
|---|---|---|
| **Recommended for Falcon BIS?** | **Yes — primary recommendation** | Viable alternative; best suited if forensic browsability or rollback matters more than simplicity |
| **Best fit** | Standard production audit requirement; minimal ops overhead | Environments where engineers want to browse history with Git tools or perform recipe rollback |

---

## Scoring

The same weighted criteria used in `output/04_recommended_design.md` are extended with two new rows that are relevant when comparing these two options.

| Criterion | Weight | Option B (SQLite) | Option E2 (Git + index) |
|---|---|---|---|
| Isolation from Falcon process | 25 % | **5** | **5** |
| Change detection completeness | 20 % | **5** | **5** |
| SQLite write safety | 15 % | 5 | 4 ¹ |
| Handles service downtime | 15 % | 4 | 3 ² |
| Deployment & maintenance simplicity | 15 % | **4** | 2 ³ |
| Implementation effort (lower = better) | 10 % | 3 | 2 ⁴ |
| **Weighted total** | 100 % | **4.55** | **3.65** |

> ¹ Git adds a second write path (mirror file copy + commit). An IOError on the copy does not corrupt the index, but the event may be missed.
> ² Catch-up produces a single batch commit, not per-file rows. Individual-change granularity during downtime is lost unless Option B's hash-compare is retained alongside Git.
> ³ Requires `libgit2` native bundling, mirror path logic, `.gitattributes` tuning, GC policy, and stale-lock handling — none of which exist in Option B.
> ⁴ More new components, a new NuGet dependency with a native binary, and two separate storage systems to reason about.

---

## Dimension-by-Dimension Comparison

### 1. Detection mechanism

Both options use the same `FileSystemWatcher` + 500 ms debounce + `BlockingCollection` pipeline. This dimension is equal.

---

### 2. Tamper evidence / integrity

| | Option B | Option E |
|---|---|---|
| Mechanism | SHA-256 hash stored in `audit_log.new_hash` | Git SHA-1 DAG — every commit is cryptographically chained to its parent |
| Strength | Individual hashes are stored in a mutable SQLite table — an attacker with DB write access can alter a row and update its hash column | Git's DAG means altering any commit changes all subsequent SHAs; a simple `git fsck` or comparing the HEAD SHA against an off-machine record detects tampering |
| Practical risk on Falcon | Low — DB file is in `C:\bis\auditlog\`, not user-accessible | Very low — `C:\bis\auditlog\job-git\.git\` is equally protected; Git adds DAG chaining |

**Edge:** Option E has structurally stronger tamper evidence due to the hash chain, but in practice the threat model for an industrial inspection machine does not require cryptographic audit trails — both options are adequate.

---

### 3. Diff and content retrieval

| | Option B | Option E |
|---|---|---|
| Storage | `old_content`, `new_content`, `diff_text` columns in `audit_log` | Blobs stored in Git object store; diffs computed on demand via `repo.Diff.Compare<Patch>()` |
| Query | Single SQL row gives content + diff inline | Requires `commit_sha` lookup → LibGit2Sharp blob read |
| Retrieval speed | ~1 ms (single row read) | ~5–20 ms (Git object decompression + diff) |
| Content for deleted files | `old_content` stored at deletion time | Blob from parent commit — always available |
| Binary files | Stored as raw bytes in TEXT column (base64 or hex) — awkward | Stored as binary blobs natively; no content column confusion |

**Edge:** Option B is faster and simpler for inline diff retrieval. Option E handles binary blobs more naturally and does not require explicit `old_content` storage (Git always has the previous version).

---

### 4. Structured querying

| | Option B | Option E (E1) | Option E (E2) |
|---|---|---|---|
| Query language | SQL — full expressiveness | Git log with `--grep` / `--after` — limited | SQL on index table — same as Option B |
| Example: all P1 events today | `SELECT … WHERE priority='P1' AND …` | `git log --grep='"monitor_priority":"P1"' --after=…` — slow, regex only | `SELECT … WHERE priority='P1' AND …` — same as Option B |
| Example: all changes to one file | `SELECT … WHERE filepath=…` | `git log -- <mirror-path>` — fast | SQL on index — same as Option B |
| Example: content at a point in time | Not directly — requires reconstructing from `old_content`/`new_content` chain | `git show <sha>:<mirror-path>` — O(1) | `git show <sha>:<mirror-path>` via `commit_sha` from index |

**Edge:** Option B (and E2) win for structured SQL queries. Option E (either variant) wins for content-at-a-point-in-time retrieval. E1 without a SQLite index is impractical for production use.

---

### 5. Rollback capability

| | Option B | Option E |
|---|---|---|
| Can restore a file to a prior state? | Manually — retrieve `old_content` from DB, write to disk | `repo.CheckoutPaths(commitSha, new[] { mirrorRelPath })` then copy from mirror to `c:\job\` |
| Rollback of entire job directory | Not supported | `git checkout <sha> -- job/<job-dir>/` then bulk copy |
| Safety | Operator must manually copy content from DB viewer | Mirror copy isolates the rollback from production until the operator manually pushes it to `c:\job\` |

**Edge:** Option E provides a clear rollback path. Option B requires a custom UI or script to extract and re-apply content from the DB.

---

### 6. Storage efficiency

| | Option B | Option E |
|---|---|---|
| Per-row overhead | ~content size × 2 (old + new) + diff string + metadata (~150 bytes) | One blob per change (delta-compressed for text files); index row ~200 bytes (E2) |
| Text files (`.ini`, `.txt`) — incremental changes | Stores full old and new content every time | Stores full initial blob; subsequent changes stored as delta-compressed pack objects — typically 5–20× smaller for files that change one line at a time |
| Binary files (`.dat`, `.json`) | Stores raw binary in TEXT column (base64) — ~33 % inflation | Stores raw binary blob — no inflation; but no delta compression (full blob each change) |
| Growth per day (estimate, 10 P1 changes of ~5 KB each) | ~100 KB/day (content) + negligible metadata | ~10–20 KB/day (delta pack) + ~2 KB index (E2) |
| Pruning mechanism | `DELETE FROM audit_log WHERE detected_at < …` | `git gc --prune=<date>`; older blobs removed; index rows deleted manually |

**Edge:** Option E is significantly more storage-efficient for text files that change incrementally — exactly the profile of INI recipe files. Option B is simpler to prune (SQL DELETE vs. Git GC configuration).

---

### 7. Deployment and operational complexity

| Dimension | Option B | Option E |
|---|---|---|
| New executables / DLLs | `FalconAuditService.exe` + `Microsoft.Data.Sqlite.dll` + `SQLitePCLRaw` | Same + `LibGit2Sharp.dll` + `libgit2-{platform}.dll` (native, ~3.5 MB) |
| Git installation required? | No | No — `LibGit2Sharp` bundles `libgit2` native; no `git.exe` needed |
| Mirror directory setup | None | `C:\bis\auditlog\job-git\` must be created; `.gitattributes` must be deployed |
| Stale lock handling | None | On startup, detect and delete `C:\bis\auditlog\job-git\.git\index.lock` if present |
| Routine maintenance | Optional: periodic `DELETE` + `VACUUM` to control DB size | Required: `git gc` + `git prune` on schedule to control pack file growth |
| Failure mode visibility | SQLite errors visible in Serilog / Windows Event Log | Same, plus `git fsck` output needs periodic review |
| Ops tooling familiarity | DBBrowser / DBeaver — familiar to IT teams | Git CLI / GitExtensions / SourceTree — familiar to engineers, less familiar to IT/ops |

**Edge:** Option B is operationally simpler. The mirror directory, stale lock cleanup, and Git GC policy are non-trivial to set up and maintain on an industrial machine where the primary staff are EE/AMS engineers, not software developers.

---

### 8. Failure modes

| Failure | Option B behaviour | Option E behaviour |
|---|---|---|
| Service crashes mid-commit | SQLite transaction rolls back atomically; no partial row | Git object written to `.git/objects/` as loose object; commit did not finalize; no data loss, but index lock may remain |
| Disk full | `InsertAuditLogAsync` fails; event logged; service continues watching | `File.Copy` to mirror fails; event lost unless retry logic catches it; Git commit not attempted |
| Mirror file copy fails (source locked) | N/A — reads file directly on writer thread | Copy fails; Git commit skipped; catch-up scan on next restart recovers the change |
| SQLite DB corruption | Entire audit history inaccessible; requires restore from backup | Index corrupted (E2) but Git history is intact; rebuild index by replaying git log |
| Git repo corruption | N/A | `git fsck` detects; `git reflog` + `git gc --prune=now` can often recover; worst case: re-init repo and accept history loss from that point |

**Edge:** Option B has fewer moving parts and clearer failure boundaries. Option E has the advantage that Git repo corruption is rare and recoverable, but the additional `File.Copy` step introduces a failure path absent from Option B.

---

### 9. Audit trail quality

| | Option B | Option E |
|---|---|---|
| One record per change? | Yes — one `audit_log` row | Yes — one Git commit (live); batch commit for downtime catch-up |
| Downtime granularity | Per-file catch-up rows with `note="catch-up"` | Single batch commit covering all missed changes — individual change sequence during downtime is not preserved |
| Exact timestamp of change | `detected_at` (FSW event time) — stored in row | `committed_at` in Git commit author timestamp — same data, different form |
| Attribution (who changed it) | `owner_service` (derived from path, not from actual user) | Same — neither option has OS-level user attribution without integration with Windows audit events |
| Exportable / portable | `SELECT * FROM audit_log` → CSV/JSON | `git format-patch` or `git bundle` → portable archive |

**Edge:** Option B preserves per-file change granularity during service downtime. Option E's batch catch-up commit is semantically less precise.

---

### 10. Ecosystem and tooling

| | Option B | Option E |
|---|---|---|
| View audit history | Requires custom viewer or SQL client | Any Git GUI (GitExtensions, TortoiseGit, VS Code, GitHub Desktop) works directly on the repo |
| View file diff | Requires query + parsing `diff_text` column | `git diff <sha1>..<sha2>` — standard Git operation |
| Integrate with CI/CD | Custom export tool | `git push` to remote — standard |
| Remote backup | Copy `audit.db` file | `git push` to a bare remote (even a network share via `git remote add origin \\share\falcon-audit.git`) |
| Regulatory compliance export | SQL export + custom report | `git log --pretty=format:...` + standard diff tools |

**Edge:** Option E offers significantly richer tooling for engineers who are comfortable with Git. For a factory IT environment, Option B's SQL interface is more approachable.

---

## Risk Summary

| Risk | Option B | Option E |
|---|---|---|
| Production machine destabilized by audit component | Low — isolated service | Low — same isolation |
| Audit history lost due to storage failure | Medium — single SQLite file | Low — Git object store + optional remote push |
| Missed change during high-frequency burst | Low — catch-up scan recovers | Low — catch-up scan recovers (but batch commit only) |
| Stale lock prevents writes after crash | None | Low — stale `index.lock` blocks next commit until cleaned up |
| Binary file bloat | Medium — `.dat` stored twice (old + new) in TEXT column | Medium — `.dat` stored as full blob per change, but compresses better |
| Deployment complexity causes misconfiguration | Low | Medium — mirror path, `.gitattributes`, GC policy all require correct setup |
| Operator unfamiliar with tooling | Low — SQL is universal | Medium — Git is not universally known in factory-floor IT context |

---

## When to Choose Option E Instead of Option B

Option E (Git + index) is the better choice when **any** of the following apply:

1. **Recipe rollback** is a required feature — engineers need to restore a recipe file to a previous state without a custom UI.
2. **Browsable history** matters — engineering teams want to explore job/recipe changes using standard Git tools (e.g., during root-cause analysis of a yield event).
3. **Remote replication** is needed — the audit history must be pushed to a central server; `git push` requires no custom export tooling.
4. **Storage efficiency** is constrained — the machine has limited disk and INI/recipe files change frequently; Git's delta compression materially reduces storage.
5. **Long-term archive** is required — Git's pack format is a well-documented, open standard readable without proprietary tools decades from now.

Option B remains the better choice when:

1. **Simplicity of operation** is paramount — the machine is maintained by factory IT, not software engineers.
2. **Per-change granularity during downtime** is required — Option B's catch-up scan records each changed file individually.
3. **Structured query performance** matters — SQL on `audit_log` is faster and more expressive than git log parsing.
4. **Minimal new dependencies** are preferred — Option B does not require `libgit2` or a native DLL.
5. **Implementation timeline** is short — Option E has more components to build and test.

---

## Migration Path

If Option B is deployed first and Option E is desired later, migration is straightforward:

1. Replay `audit_log` rows into Git commits using the `old_content`/`new_content` columns — each row becomes one commit with its `detected_at` as the author timestamp.
2. The resulting Git repo has full history from the Option B deployment date onward.
3. Switch the service to `GitAuditWriter`; decommission `SqliteRepository` (or keep it as the E2 index).

This means **Option B does not foreclose Option E** — it is a valid incremental path.
