# Service Review Report (Re-Review) — jobMonitorManagment (FalconAuditService)

> **Reviewed folder:** `C:\Users\me_admin\claude-prompts\audit log\output\jobMonitorManagment`
> **Review date:** 2026-04-26
> **Pass:** 2 of 2 (verification re-review after fix-generator pass)
> **service-context.md:** NOT FOUND — generic checks applied; `service_name` inferred from the design folder + design document.

---

## Executive Summary

**Status of fixes:** the `fix-patches.md` produced in pass 1 documented patches as text but the underlying source-code documents (`appendix_B_code.md`, `appendix_C_webserver.md`) were not amended. As a consequence every finding from pass 1 still applies verbatim. The most critical risk remains: `CatchUpScanner.ReadIfP1Async()` references a non-existent `_config.StoreContentP1` property, which still prevents the project from compiling. Recommended first action: actually apply Fix 1 (add the property to `MonitorConfig.cs`) into the source markdown so the published code listing compiles.

A second observation from this pass: `appendix_E_implementation_deployment.md` is now present in the folder (it was not produced by this reviewer in pass 1). It is documentation only — no source code — and does not change any of the previously raised findings.

---

## Prioritised Action Plan

| #  | Priority | Issue                                                                                                                                              | Agent(s)                | Req ID  | File:Line                                                  | Fix Pass 1 Status |
|----|----------|----------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------|---------|------------------------------------------------------------|-------------------|
| 1  | CRITICAL | `MonitorConfig.StoreContentP1` referenced but not defined — compile failure                                                                        | requirements, storage   | REC-001 | appendix_B_code.md:2209 (CatchUpScanner.ReadIfP1Async)     | Not applied       |
| 2  | CRITICAL | Rename event handling: `DeleteBaselineAsync(oldPath)` and `InsertAuditEventAsync` run in separate transactions — partial-failure loses baseline   | security, storage       | REC-002 | appendix_B_code.md:1611–1613 (FileChangeHandler)           | Not applied       |
| 3  | HIGH     | `LoadConfig()` writes `parameter_descriptions_path` default; verify read-back path persists user value across restart                              | requirements, storage   | REC-003 | appendix_B_code.md:1071–1083 (SqliteRepository.LoadConfig) | Verified present  |
| 4  | HIGH     | `audit_log.monitor_priority` CHECK forbids `P4`; default classification can yield `P4` entries → insert throws at runtime                          | requirements, storage   | REC-004 | appendix_B_code.md:843 (EnsureSchema) + design Section 1   | Not applied       |
| 5  | HIGH     | `ShardRegistry.GetOrCreate`: race-loser repo (constructed but `TryAdd` failed) is never disposed → SqliteConnection leak                           | storage                 | REC-005 | appendix_B_code.md:1190–1192                               | Not applied       |
| 6  | HIGH     | `_readConn` not opened with `Mode=ReadOnly` — accidental write through it would acquire write lock; dangerous footgun                              | storage                 | REC-006 | appendix_B_code.md:803                                     | Not applied       |
| 7  | HIGH     | Path traversal: `ExtractJob` does not canonicalise/verify result is inside `WatchPath`; symlink/junction escape possible                           | security                | REC-007 | appendix_B_code.md:1677–1689                               | Not applied       |
| 8  | MEDIUM   | `ContentCache.Set` holds `_lock` across full eviction loop — under burst can block all FSW debounce callbacks                                      | storage                 | REC-008 | appendix_B_code.md:234–258                                 | Not applied       |
| 9  | MEDIUM   | `EnsureSchema` `INSERT OR IGNORE INTO schema_meta` for `created_at_utc` is inside the same SQL block as `monitor_config` creation — confusing      | storage                 | REC-009 | appendix_B_code.md:879–884                                 | Not applied       |
| 10 | MEDIUM   | FSW overflow `RecoveryDelayMs` default 30 s creates a 30 s blind window between watcher restart and catch-up start                                 | requirements, security  | REC-010 | appendix_B_code.md:1856–1864 (FileMonitorService.OnError)  | Not applied       |
| 11 | MEDIUM   | `HashHelper.ComputeSha256` swallows all non-IO exceptions and returns null — `UnauthorizedAccessException` masquerades as "skip"                   | security                | REC-011 | appendix_B_code.md:309–311                                 | Not applied       |
| 12 | MEDIUM   | `FileClassifier.LoadRules` re-creates `_configWatcher` only on first call; if rules file is moved/recreated FSW silently stops firing              | requirements            | REC-012 | appendix_B_code.md:495–514                                 | Not applied       |
| 13 | MEDIUM   | Web-server doc (Appendix C.13) calls for `[Authorize(Policy="AuditorOnly")]` on single-event endpoint, but only `FallbackPolicy` is implemented    | security                | REC-013 | appendix_C_webserver.md:560–579                            | Not applied       |
| 14 | LOW      | Missing index on `(rel_filepath, changed_at)` and `(filepath, changed_at)` — common forensic "history of one file" query needs sort                | storage                 | REC-014 | appendix_B_code.md:854–862                                 | Not applied       |
| 15 | LOW      | No `PRAGMA wal_autocheckpoint` tuning — default 1000 pages can stall writers during catch-up burst                                                 | storage                 | REC-015 | appendix_B_code.md:807–812                                 | Not applied       |
| 16 | LOW      | `ManifestManager.WriteManifest` does not delete leftover `.tmp` if previous attempt crashed between WriteAllText and File.Move                     | storage                 | REC-016 | appendix_B_code.md:1370–1390                               | Not applied       |
| 17 | LOW      | `FileClassificationRules.json` has no integrity check (HMAC/signature); a writeable rules file is a privilege-escalation vector if ACL is weakened | security                | REC-017 | jobMonitorManagmentDesign.md Section 1                     | Not applied       |

---

## Findings by agent

### Requirements Checker

The design document (`jobMonitorManagmentDesign.md`) defines explicit design constraints (Section 5 "Verification") and architecture requirements that the source-code listings in Appendix B must satisfy. Re-confirmed in this pass:

- **REC-001 (compile failure):** Section 5 row "Roles preserved" requires P1 files store `old_content`, `new_content`, `diff_text`. `CatchUpScanner.ReadIfP1Async` (line 2209) gates the read on `_config.StoreContentP1`. `MonitorConfig` (B.5, lines 138–153) declares only `CaptureContent`. Code as written cannot compile. (Re-confirmed by re-reading the source markdown.)
- **REC-003 (config round-trip):** On verification, line 1074 of `appendix_B_code.md` does include `if (data.TryGetValue("parameter_descriptions_path", out s)) cfg.ParameterDescriptionsPath = s;`. Pass 1 had flagged this as missing — it is in fact present. **Reclassified as resolved.** Keep the verification step (set the SQL value, restart, confirm it survives).
- **REC-004 (P4 schema mismatch):** Design Section 1 `rules[]` array contains a `P4` entry (`ImageProcessing.log`). The DDL (line 843) restricts `monitor_priority` to `('P1','P2','P3')`. `FileChangeHandler.HandleAsync` does not filter P4 before insert; first P4 hit throws at runtime.
- **REC-010 (recovery gap):** With `RecoveryDelayMs = 30_000`, there is a 30-second window between FSW restart and catch-up start. Live events arriving during that window are queued (good) but events that occurred during the overflow itself rely on catch-up. Document the rationale or shrink the delay (suggest 5 s).
- **REC-012 (FSW reload):** `FileClassifier.StartConfigWatcher` short-circuits via `if (_configWatcher is not null) return;`. Editors that save via temp + rename invalidate the FSW handle and silently break further reloads. Section 5 row "JSON hot-reload" silently fails after one such save.

### Security Reviewer

- **REC-002 (rename atomicity / data loss):** `FileChangeHandler.HandleAsync` Renamed branch (lines ~1604–1616):
  ```
  await repo.DeleteBaselineAsync(ev.OldPath);   // tx 1
  // ...
  await repo.InsertAuditEventAsync(entry, bl);   // tx 2 (later, same writer thread but distinct tx)
  ```
  These are independent transactions. A crash between them deletes the prior baseline and emits no audit row for the rename — the file's history is silently truncated. Either move the delete into the same transaction as the insert (recommended), or write the "Renamed" audit row first and then delete the old baseline.
- **REC-007 (path traversal / junction escape):** `ExtractJob` uses string-prefix matching only and does not call `Path.GetFullPath` or check for reparse points. A symlink/junction in `c:\job\` can let `ShardRegistry.GetOrCreate` create a shard at a path the service does not own. Add `Path.GetFullPath` canonicalisation and `(DirectoryInfo.Attributes & ReparsePoint) == 0` check.
- **REC-011 (silent permission failure):** `HashHelper.ComputeSha256` catch-all (`catch (Exception)`) returns null. `UnauthorizedAccessException` is forensically meaningful — it indicates the service account cannot read a file that should be auditable. Today this becomes a silent skip with only DEBUG-level logging upstream. Distinguish UnauthorizedAccessException and log at WARN level.
- **REC-013 (auditor role not enforced):** Appendix C.13 documents `[Authorize(Policy="AuditorOnly")]` on the single-event endpoint that returns `old_content`. The C.13 snippet only sets a `FallbackPolicy = RequireAuthenticatedUser()` — that lets any authenticated Windows user retrieve recipe IP. The per-endpoint policy attribute is not applied anywhere in C.14. Add `RequireAuthorization("AuditorOnly")` on `GET /api/jobs/{jobName}/events/{id}`.
- **REC-017 (rules file integrity):** `FileClassificationRules.json` is the sole authority for whether a recipe file is P1 (snapshotted) or P4 (ignored). Anyone with write access can mass-demote files to silence the auditor. Add (a) a structured log line summarising rule-set diffs on every reload (added/removed patterns) so a SIEM can alert on suspicious changes; (b) consider an HMAC-protected rules file in production deployments.

### Storage Reviewer

- **REC-005 (connection leak):** `ShardRegistry.GetOrCreate` constructs a new `SqliteRepository` and then calls `_shards.TryAdd`. When two threads race, the loser's repo (already opened two SqliteConnections + WAL files) is never disposed. Use `ConcurrentDictionary.GetOrAdd(key, factory)` so the factory runs at most once per key.
- **REC-006 (read connection writeability):** `_readConn = new SqliteConnection($"Data Source={dbPath}");` — no `Mode=ReadOnly`. The connection is "read" by convention only. Any future write through it would acquire a write lock and serialise against `_writeLock`. Append `;Mode=ReadOnly` to the connection string and reorder ctor so the writer creates the file first.
- **REC-008 (cache eviction blocks debounce):** `ContentCache.Set` evicts under `_lock` in a tight `while` loop. With 200 MB / 5 KB-per-entry = 40 000 entries, a single eviction round can take many ms; under burst this serialises all `Set` callers, including FSW debounce callbacks. Switch to coarser eviction (drop down to 90% in one pass) or use a dedicated trim background task.
- **REC-009 (schema_meta misuse):** `EnsureSchema` SQL inserts `created_at_utc` into `schema_meta` immediately after creating `monitor_config` — visually misleading. Move the insert above the `monitor_config` block.
- **REC-014 (missing index for file-history):** `GET /api/jobs/{jobName}/history/{*filePath}` issues `WHERE rel_filepath = @p ORDER BY changed_at ASC`. Existing index `ix_audit_log_rel_filepath` covers the WHERE only; the ORDER BY then forces a sort. Composite index `(rel_filepath, changed_at)` removes the sort. Same for `(filepath, changed_at)`.
- **REC-015 (WAL checkpoint tuning):** Default `wal_autocheckpoint = 1000` pages (~4 MB at 4 KB pages). During `CatchUpScanner.RunAllJobsParallelAsync` thousands of writes per second per shard cause the WAL to grow faster than checkpoints fire, eventually stalling writers. Add `PRAGMA wal_autocheckpoint = 4000;` on the write connection.
- **REC-016 (orphan tmp file):** `ManifestManager.WriteManifest` writes `manifest.tmp` then `File.Move`. If the process crashes between the two, the `.tmp` lingers. Next `WriteManifest` overwrites it (because `WriteAllText` truncates) — benign for correctness but visible to operators and possibly support staff. Add a startup pass that deletes any `manifest.json.tmp` older than 1 minute.

#### Cross-agent contradictions

None. REC-002 and REC-007 are flagged by both Security and Storage and are listed once each above; the joint Agent column in the action plan reflects that.

---

## What looks good (re-confirmed)

- **WAL mode + per-shard `SemaphoreSlim(1)`** matches the documented "writer never blocks readers" claim.
- **Atomic manifest writes via temp + rename** (with explicit cross-volume warning) — well-reasoned.
- **JSON hot-reload via `Interlocked.Exchange(ref _rules, …)` on `ImmutableList`** — lock-free, race-free read path; only the FSW renewal path (REC-012) is fragile.
- **Schema migration via `MigrateSchema` + try/catch on `ALTER TABLE ADD COLUMN`** — correctly idempotent for SQLite.
- **Bounded `Channel<ChangeEvent>` with `BoundedChannelFullMode.Wait`** plus 1-second writer timeout that triggers CatchUp — sound back-pressure design.
- **Per-shard architecture aligned with the documented job-portability requirement** — moving a folder moves its history without operator action.
- **Append-only `audit_log` schema with `is_backfill` discriminator** — distinguishes live events from CatchUp-derived events for forensic analysis.
- **`SHA-256` analysis (B.23)** — alternatives matrix and verdict to keep SHA-256 are well-reasoned.
- **Configuration round-trip for `parameter_descriptions_path`** — confirmed present in `LoadConfig` (REC-003 reclassified as resolved during this pass).

---

## Re-Review Conclusion

The fix-patches.md generated in pass 1 did not modify the source-code markdown documents; it produced a documentation-only patch description. As a result, all 16 outstanding findings from pass 1 (CRITICAL × 2, HIGH × 5, MEDIUM × 6, LOW × 3) are still present, and one finding (REC-003) was reclassified to "resolved" after closer reading.

**Next concrete step:** apply Fix 1 from the (now deleted) fix-patches.md by editing `appendix_B_code.md` to add `public bool StoreContentP1 { get; set; } = true;` to `MonitorConfig`. That single change moves the codebase from "does not compile" to "compiles, with HIGH-priority issues remaining."
