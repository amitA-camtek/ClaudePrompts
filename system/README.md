# Claude System Knowledge Prompts

A plug-and-play prompt kit to make Claude an expert on **your specific codebase** — including every service, how they communicate, and all the architecture decisions — so you never have to re-explain the system at the start of a session.

---

## How It Works

```
Your Codebase
      │
      ▼
 [Run Prompt 1] ──► Claude reads & maps everything
      │
      ▼
 [Run Prompt 2] ──► Claude digs deeper per service
      │
      ▼
 [Run Prompt 3] ──► Claude writes system.md
      │
      ▼
 [Every New Session] ──► [Run Prompt 4] ──► Claude reads system.md → instantly context-aware
```

---

## Files in This Folder

| File | Purpose |
|------|---------|
| `01_initial_discovery.md` | **First-time only.** Paste this to make Claude map the entire system |
| `02_deep_dive.md` | Drill deeper into a specific service or trace an end-to-end flow |
| `03_write_system_md.md` | Ask Claude to produce or update the `system.md` file |
| `04_session_start.md` | **Every session.** Load `system.md` so Claude hits the ground running |
| `system.md` | The living knowledge base — gets populated and updated over time |

---

## Quick Start

### First time with a new codebase

1. Open a Claude session and share your codebase (attach files, use a tool, or paste code).
2. Copy and paste the entire content of **`01_initial_discovery.md`** as your first message.
3. Claude will analyze everything. When it's done, paste **`03_write_system_md.md`**.
4. Take the output and save it as **`system.md`** in your project root (or here in this folder).

### Every subsequent session

1. Open a new Claude session.
2. Share your `system.md` file (attach it or paste it).
3. Paste one of the **Option A/B/C/D** blocks from **`04_session_start.md`**.
4. Claude will confirm it understands the system, then you describe today's task.

---

## Workflow Tips

### Keeping system.md accurate
- After any significant change (new service, new endpoint, refactor, new event), run **Option D** from `04_session_start.md`.
- Commit `system.md` to your repo so the whole team benefits.
- Treat it like a living architecture document — update it whenever the system changes.

### Using with large codebases
- If the codebase is too large to paste, use a tool like [Repomix](https://github.com/yamadashy/repomix) to pack the repo into a single file for Claude.
- Or share only the relevant service folders + key config files (docker-compose, package.json, proto files).

### Combining with Claude Projects (Claude.ai)
- Create a **Claude Project** and attach `system.md` as a project file.
- Claude will automatically have this context in every conversation in that project — no manual loading needed.

### Team usage
- Store this entire `claude-prompts/` folder in your repo (e.g. `docs/claude-prompts/`).
- Every engineer can use the same prompts and contribute to `system.md`.

---

## Prompt Chaining Reference

```
Session 1: 01 → 02 → 03 → save system.md
Session 2+: 04 (Option A or B) → work → 04 (Option D if changes made)
Anytime:    02 → new findings → 04 (Option D) to update system.md
```

---

## Customizing the Prompts

All prompts are plain Markdown — edit them freely:
- Add your team's specific conventions to Prompt 1 (Step 6).
- Add your stack-specific protocols (e.g. tRPC, GraphQL federation) to the communication map in Prompt 2.
- Add custom sections to `system.md` (e.g. a "Deployment runbook" or "On-call notes" section).
