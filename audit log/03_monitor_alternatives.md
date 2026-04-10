# Audit Log — Prompt 3: Monitoring Service Alternatives

> **Goal:** Propose 3–4 concrete architectures for a file monitoring service that watches `c:\job\`
> and writes changes to a SQLite audit database. Evaluate each option's trade-offs.
> **Input required:** `output/02_file_summary.md` + `system.md` + codebase

---

You are a **senior software architect** familiar with the Camtek Falcon BIS platform (.NET Framework 4.8, C# 7.3).
You have the file classification from Prompt 2 (`output/02_file_summary.md`) and the system context (`system.md`) and the codebase.

Your task is to propose and evaluate **3–4 distinct monitoring architectures**.
Do NOT recommend a winner yet — only present each option fairly with its trade-offs.

---

## Design Requirements (from Prompt 2 findings)

- Watch the files classified as P1 and P2 in `output/02_file_summary.md`
- Detect: **Create**, **Modify**, **Delete** events
- On change: record `filepath`, `change_type`, `old_hash` (SHA-256), `new_hash`, `timestamp`, `module`, `owner_service`
- For P1 files (Critical): also store the **full file content** at the time of change (or a diff)
- Database: **SQLite** (local file, no server)
- Must not interfere with normal Falcon machine operation (no locking files, no high CPU)
- Must survive a machine reboot and resume monitoring automatically

---

## Section 1 — Option A: Embedded FileSystemWatcher in `falcon.net.aoi_main`

Design a monitoring solution that runs **inside the existing `Falcon.Net` / `AOI_Main` process**.

Answer all of the following:

1. **Architecture sketch:** How does the watcher integrate into `AOI_Main` startup/shutdown?
   - Which class owns the `FileSystemWatcher` instance(s)?
   - How is the SQLite writer initialized and disposed?
   - How does this interact with the COM STA apartment thread constraint?

2. **SQLite access pattern:** Which thread writes to SQLite — the FSW callback thread, a dedicated background thread, or the COM STA thread? Justify why.

3. **Error handling:** What happens if SQLite is locked or the disk is full? Does the machine continue operating?

4. **Pros:** List at least 4.

5. **Cons:** List at least 4.

6. **Implementation complexity:** (Low / Medium / High) — estimate lines of new code and new dependencies.

7. **Risk to existing system:** Any risk of destabilizing `AOI_Main` or `Falcon.Net` COM callbacks?

---

## Section 2 — Option B: External Standalone Windows Service (.NET 6+)

Design a monitoring solution as a **separate Windows Service process** (.NET 6 or later, no dependency on Falcon assemblies).

Answer all of the following:

1. **Architecture sketch:**
   - Service entry point — how does it register with Windows SCM?
   - How does the `FileSystemWatcher` survive service pause/resume?
   - How does it handle files that change during service downtime (startup scan)?

2. **Startup scan:** On service start, how does it detect files that changed while the service was stopped?
   - Compare current file hashes against last-known hashes stored in SQLite.
   - What is the algorithm for this catch-up scan?

3. **SQLite schema (draft):** Propose a minimal schema:
   - `audit_log` table: columns, types, indexes
   - `file_baseline` table (for hash comparison): columns, types

4. **Pros:** List at least 4.

5. **Cons:** List at least 4.

6. **Implementation complexity:** (Low / Medium / High) — estimate lines of new code, NuGet packages needed.

7. **Deployment:** How is the service installed/uninstalled on a Falcon machine?

---

## Section 3 — Option C: PowerShell / Python Agent (Scheduled Task)

Design a lightweight monitoring agent using **PowerShell or Python**, run as a Windows Scheduled Task.

Answer all of the following:

1. **Architecture sketch:**
   - Poll-based (run every N seconds) vs event-based (Register-ObjectEvent)?
   - How is the last-seen state persisted between runs?
   - How is SQLite written from PowerShell/Python?

2. **Change detection algorithm:**
   - How are creates/modifies/deletes detected without a persistent watcher?
   - What is the minimum polling interval that won't flood the disk?

3. **SQLite access:** Which library — `System.Data.SQLite` (PowerShell), `sqlite3` (Python), other?

4. **Pros:** List at least 4.

5. **Cons:** List at least 4.

6. **Implementation complexity:** (Low / Medium / High).

7. **Limitations vs a real FileSystemWatcher:** What events or edge cases does polling miss?

---

## Section 4 — Option D: Hybrid — Lightweight Windows Service + RMS gRPC Hook (Optional)

Design a solution that combines **Option B** (Windows Service + FileSystemWatcher) with an **RMS gRPC interceptor** that notifies the service of job lifecycle events.

Answer all of the following:

1. **Architecture sketch:**
   - How does the Windows Service subscribe to RMS gRPC events (job create/load/delete)?
   - How do gRPC events complement `FileSystemWatcher` — what does each source cover?
   - If RMS is not running, does the service fall back gracefully to FSW-only?

2. **Additional value over Option B:** What audit data is richer because of the gRPC hook (e.g., job name, user who triggered the change)?

3. **Pros:** List at least 3 beyond Option B.

4. **Cons / added complexity:** List at least 3.

5. **Is this complexity justified?** Give a yes/no with a one-sentence rationale.

---

## Output Format

For each option, use this structure:

```
## Option [X]: [Name]

### Architecture Sketch
[ASCII or text diagram + description]

### SQLite Schema (if applicable)
[SQL CREATE TABLE statements]

### Pros
- ...

### Cons
- ...

### Complexity
- Estimated new code: ~N lines
- New dependencies: [list]
- Deployment steps: [list]

### Risk to Falcon operation
[Low / Medium / High] — [explanation]
```

End with a **Comparison Matrix**:

| Criterion | Option A (Embedded) | Option B (Win Service) | Option C (Script) | Option D (Hybrid) |
|---|---|---|---|---|
| Isolation from Falcon process | | | | |
| Catches all change events | | | | |
| Handles service downtime | | | | |
| SQLite write safety | | | | |
| Deployment simplicity | | | | |
| Maintenance burden | | | | |
| Implementation effort | | | | |
| Overall risk | | | | |

Do NOT pick a winner yet. That is Prompt 4.

Save the final document to:

`output/03_alternatives.md`
