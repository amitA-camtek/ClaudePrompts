# Claude Script — Audit StateShell State Changes to C:\AuditLog.txt

You are a **senior software engineer**.

In `AOI_main`, when any state in `StateShell` changes, define and implement a solution to write the change into `C:\AuditLog.txt`.

## Goal

Design a minimal, reliable, non-breaking audit logging mechanism for `StateShell` state changes.

The solution must:
- Detect every relevant state change in `StateShell`
- Write an audit entry to `C:\AuditLog.txt`
- Avoid duplicate noise where possible
- Be safe for multi-threaded callbacks/events
- Use only assembly references already present in `AOI_Main.csproj`
- Fit the existing architecture and naming style
- Keep `StateAuditLogger` **outside** `StateShell`
- Treat `StateAuditLogger` as an external listener/subscriber to `StateShell` changes
- Do **not** put file-writing logic inside `StateShell` core classes or state models
- Prefer observer/subscriber wiring over direct logging calls from state model setters

---

## What to analyze first

Inspect and document these parts before proposing changes:

- `StateShellBootstrapper`
- All existing `*StateBridge` classes
- State models / enums / contracts used by `StateShell`
- Any existing state change notification mechanism
- `IFalconGuiCB` and related callback interfaces
- Logging utilities already in the solution
- Threading / dispatcher / synchronization patterns already used

For each relevant artifact, capture:

| Symbol | File | Responsibility | Emits Changes? | Receives Changes? | Thread Context |
|---|---|---|---|---|---|

---

## Design requirements

### 1. Define what counts as a state change

For each tracked subsystem/state field, define:

| Subsystem | State Field | Type | Old Value | New Value | Change Trigger | Should Log? |
|---|---|---|---|---|---|---|

Only log real transitions. Do not log if value did not change unless repository evidence shows current behavior requires it.

### 2. Define audit log format

Each line in `C:\AuditLog.txt` should include at minimum:
- Timestamp in ISO 8601 format
- Subsystem / domain name
- State field name
- Old value
- New value
- Source bridge / source callback
- Thread ID
- Correlation or sequence ID if available

Example format:

```text
2026-04-08T14:52:31.245Z | Job | State | Idle -> Loaded | Source=JobStateBridge | Thread=12 | Correlation=abc123
```

If the codebase already has a logging format, reuse it.

### 3. Reliability requirements

The design must address:
- Concurrent writes from multiple callbacks
- File locking / append safety
- Log directory/file creation if missing
- Error handling if file is temporarily unavailable
- Avoid blocking high-frequency state updates
- Prevent log storms for rapidly changing values

---

## Required solution design

## Architectural constraint

`StateAuditLogger` must live **outside** the `StateShell` implementation boundary.

That means:
- `StateShell` should expose state change notifications, events, callbacks, or a subscription point
- `StateAuditLogger` should subscribe/listen to those changes from the outside
- `StateShell` must not depend on `StateAuditLogger`
- Avoid coupling core state logic to file system concerns
- Prefer a one-way dependency: `StateAuditLogger` depends on `StateShell` change notifications

If the current architecture has no central change notification, propose the smallest non-breaking extension that adds one.

Choose the best approach based on repository evidence:

Choose the best approach based on repository evidence:

### Option A — Central audit service
- Add `IStateAuditLogger` + `StateAuditLogger`
- `StateAuditLogger` stays outside `StateShell`
- Bridges or a central notifier publish state changes, and the logger listens externally

### Option B — Central StateShell observer
- Hook into one central state-changed event
- Audit in one place after all state updates pass through StateShell
- `StateAuditLogger` subscribes from outside the `StateShell` boundary

### Option C — Hybrid
- Central observer for common cases + bridge-level logging for source-specific metadata
- `StateAuditLogger` remains external and consumes notifications from both paths where needed

You must:
1. Compare the options using the actual architecture
2. Pick one recommended approach
3. Explain why it is best for this codebase

Provide this table:

| Option | Pros | Cons | Fit to current architecture | Recommended |

Also explicitly state for the chosen design:
- Where the `StateShell` boundary is
- Which component raises the state-changed notification
- How `StateAuditLogger` subscribes without introducing reverse dependency
- Why the chosen approach keeps audit logging outside the core state engine
|---|---|---|---|---|

---

## Implementation requirements

Generate implementation-ready code for:

1. Audit logger abstraction/service
2. State change model (if needed)
3. External subscription/listener wiring in `StateShellBootstrapper`
4. Integration points in existing bridges or a central state-changed publisher
5. Safe append-to-file logic for `C:\AuditLog.txt`
6. Minimal diagnostics if logging fails

### Code constraints

- Use real types/names from the repository
- No pseudo-code
- No new external NuGet packages
- Keep changes minimal and non-breaking
- If interface changes are required, explain compatibility impact
- `StateAuditLogger` must not be placed in the `StateShell` namespace/project layer if that would make it part of the core state engine
- Prefer introducing an event/subscription contract rather than direct `StateAuditLogger` calls from `StateShell`

---

## Validation plan

Provide a verification checklist:

1. Start app and confirm audit logger initializes
2. Trigger several known state changes
3. Verify one log line per true transition
4. Verify no duplicate lines for unchanged values
5. Verify log file survives concurrent updates
6. Verify app behavior remains unchanged if file write fails

Also define test cases for:
- Startup transition
- Job load transition
- Scan state transition
- Robot/camera/alignment transitions if present
- Rapid repeated updates

---

## Output format

Return exactly these sections:

1. Executive summary
2. Current state-change flow
3. Audit logging design options
4. Recommended design
5. Audit log format
6. File-by-file code changes
7. Bootstrapper wiring changes
8. Risks and mitigations
9. Validation checklist

For code output, use this exact format:

```text
---
FILE: relative/path/FileName.cs
---
[full compilable code]
---
```

If repository evidence is missing for any required integration point, mark it as:
- `ASSUMPTION:` for a reasonable inference
- `FALLBACK:` for a safe alternative implementation
