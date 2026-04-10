# Audit Log — File Monitor Prompt Series

> **Purpose:** Design and implement a service that monitors non-binary files under `c:\job\`
> and writes all changes (create, modify, delete) to a **SQLite** audit database.
> **Run prompts in order — each one builds on the previous output.**

---

## The 2 Phases

| Phase | Goal |
|---|---|
| **Phase 1 — Discovery** | Find every non-binary file under `c:\job\`, understand what writes it, and classify it by module/hardware/service |
| **Phase 2 — Design** | Propose monitoring solutions, analyze trade-offs, and deliver an implementation plan for the best approach |

---

## Prompt Sequence

| File | Phase | Goal | Input needed |
|---|---|---|---|
| [`01_file_discovery.md`](01_file_discovery.md) | Discovery | Recursively scan `c:\job\`, list all non-binary files with metadata | Access to `c:\job\` on a live or reference machine |
| [`02_file_summary.md`](02_file_summary.md) | Classification | Classify each file by module, owner service, write pattern, and sensitivity | Output of Prompt 1 |
| [`03_monitor_alternatives.md`](03_monitor_alternatives.md) | Architecture | Propose 3–4 monitoring solutions (embedded vs standalone) with pros/cons | Output of Prompt 2 + `system.md` + codebase |
| [`04_monitor_design.md`](04_monitor_design.md) | Design | Score alternatives, recommend best solution, deliver SQLite schema + implementation plan | Output of Prompt 3 |

---

## Key Design Constraints

- **Scope:** `c:\job\` only (RMS job/recipe directory)
- **Database:** SQLite — local embedded, no server dependency
- **File types tracked:** `.txt`, `.ini`, `.json`, `.xml`, `.csv`, `.log`, `.yaml`, `.cfg`, `.dat`, `.seq` — no binaries
- **Candidate host:** Either embedded inside `falcon.net.aoi_main` or as a separate Windows Service
- **Change detection:** Create / Modify / Delete events; store content hash + diff where applicable

---

## Expected Output Artefacts

After completing all 4 prompts:

```
audit log/output/
├── 01_discovered_files.md       ← Full file inventory table
├── 02_file_summary.md           ← Classified file groups with owner + write pattern
├── 03_alternatives.md           ← 3–4 designs with architecture sketch + pros/cons
└── 04_recommended_design.md     ← Winning design + SQLite schema + implementation plan
```
