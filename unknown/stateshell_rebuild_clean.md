# Claude Build Script — Rebuild StateShell from Documentation (AOI_main)

You are a **senior software engineer**.

Reverse-engineer and document `StateShell` so completely that it can be rebuilt from this document alone.

## CRITICAL: File Output Format

When you produce code files, use **EXACTLY THIS FORMAT**:

```
---
FILE: path/to/FileName.cs
---
[EXACT CODE HERE - compilable, no placeholders]
---
```

Example:
```
---
FILE: Infrastructure/Bridges/AlignmentStateBridge.cs
---
using System;
namespace AOI.Infrastructure;

public class AlignmentStateBridge : IStateBridge
{
    // Full code
}
---
```

Save each file in a separate code block. Do NOT nest code blocks or mix narrative with code.

---

## Constraints

- Use only code evidence from repository.
- Use only assemblies in `AOI_Main.csproj`.
- Label assumptions as `ASSUMPTION:` with impact.
- No placeholder stubs.

---

## Phase 1 — Discovery

Map all StateShell artifacts:
- `StateShellBootstrapper` (code + lifecycle)
- All `*StateBridge` or bridge equivalent (name, what they monitor, what they publish)
- Callback interfaces: `IFalconGuiCB`, manager callbacks (`IAutoCycleManagerCB`, `IScanManagerCB`, etc.)
- State enums/models
- Event dispatch mechanism
- DI/IoC registration pattern
- Threading model

Output a table:

| Symbol | Location | Role | Inputs | Outputs | Threading |
|---|---|---|---|---|---|

---

## Phase 2 — Architecture Document

Write a 1-2 page architecture narrative covering:

1. **Component overview** — what each piece does
2. **Lifecycle** — construction → registration → start → update → stop → dispose
3. **Data ownership** — for each state field, who owns it, who writes it, who reads it
4. **Threading** — what runs on UI thread, what on background, marshaling points
5. **Current gaps** — what state exists but isn't bridged to StateShell

---

## Phase 3 — Runtime Flow Diagrams

Provide text/ASCII sequence diagrams for:

1. **Startup flow** — how bridges register and subscribe
2. **State update flow** — subsystem → event → bridge → callback → GUI
3. **Error path** — timeout or unexpected callback
4. **Shutdown flow** — unsubscribe and cleanup

---

## Phase 4 — Communication Protocol

Specify:

| Channel | Producer | Consumer | Message | Payload | Reliability |
|---|---|---|---|---|---|

Also define:
- Idempotency (can same message be received twice safely?)
- Ordering (must callbacks arrive in order?)
- High-frequency throttling (position updates every millisecond?)
- Thread affinity (which thread fires each event?)

---

## Phase 5 — Risk Register

| Risk | Trigger | Impact | Detection | Mitigation |
|---|---|---|---|---|

Must cover:
- Wrong DI scope (transient vs singleton causing event source mismatch)
- Subscription before source ready
- COM apartment/thread marshaling failures
- Race condition on state update
- Silent exceptions in callbacks
- Event storms

---

## Phase 6 — Code Files

Produce implementation files for existing gaps.

For each file, generate FULL compilable code using the format above (---FILE: ... ---).

Include:
- Bridge classes (one per domain/subsystem missing)
- Bootstrapper changes
- State model updates
- Protocol adapters (if mapping between callback payloads and state model)
- Diagnostics/logging methods

---

## Phase 7 — Rebuild Playbook

Numbered steps for another engineer to rebuild from this document:

1. Create files (in order)
2. Update csproj (if needed)
3. Register in DI container
4. Start app and verify logs
5. Validation checklist

---

## FINAL DELIVERABLES — Produce EXACTLY these sections:

1. **Executive Summary** (1 paragraph)
2. **Architecture Inventory** (table with all symbols)
3. **Architecture Document** (2–3 pages narrative)
4. **Runtime Flow Diagrams** (text diagrams, 4 scenarios)
5. **Communication Protocol Table**
6. **Risk Register Table**
7. **Code Files** (each in ---FILE: ... --- format)
8. **Rebuild Playbook** (numbered steps)
9. **Assumptions** (if any, clearly labeled)

If any part cannot be documented from code evidence, state exactly what is missing and provide a FALLBACK implementation marked clearly as FALLBACK.

---

## Output Size Constraint

- Keep narrative sections focused (max 1 page each).
- Trim tables to essentials.
- Code should be real, not pseudo.
- Total response target: ~15–25 KB (not 100+ KB).
