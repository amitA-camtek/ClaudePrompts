# Claude Build Script — Rebuild StateShell from Documentation (AOI_main)

You are a **senior software engineer**.

I have run `AOI_main`.
Your task is to reverse-engineer and document `StateShell` so completely that the system can be rebuilt from this document alone.

## Critical constraints

- Use only code evidence from the repository (no guessing).
- Use only assembly references already present in `AOI_Main.csproj`.
- Keep changes minimal and non-breaking unless explicitly marked as breaking.
- If assumptions are required, label them as `ASSUMPTION` and explain impact.

---

## Mission

Produce a **rebuild package** containing:
1. StateShell architecture documentation
2. Design and runtime flow
3. Communication protocol specification
4. Risk analysis and mitigation
5. Implementation-ready code (not pseudo-only)
6. Step-by-step rebuild instructions

The output must let me ask Claude later: **“Build StateShell again from this document”** and get the same result.

---

## Phase 1 — Discover and Map Current StateShell

Audit all StateShell-related code and collect:

- `StateShellBootstrapper`
- All existing bridges (`*StateBridge`, or equivalent)
- Callback interfaces (`IFalconGuiCB`, other CB interfaces)
- Manager callbacks (e.g., `IAutoCycleManagerCB`, `IScanManagerCB`, others found)
- State contracts/models/enums
- Event dispatch / callback wiring
- DI/IoC registration and lifecycle
- Threading model and synchronization points

For each artifact capture:

| Symbol | File | Assembly | Responsibility | Inputs | Outputs | Dependencies | Lifecycle |
|---|---|---|---|---|---|---|---|

---

## Phase 2 — StateShell Design Document

Generate a complete design doc with these sections:

### 2.1 Components and responsibilities

- Bootstrapper responsibilities
- Bridge responsibilities
- State model responsibilities
- Callback/notification responsibilities

### 2.2 Data ownership

For every state field, define:

| State Field | Owner | Source of Truth | Updated By | Read By | Consistency Rule |
|---|---|---|---|---|---|

### 2.3 Lifecycle model

Document ordered stages:
- Construction
- Registration
- Start/subscribe
- Runtime updates
- Stop/unsubscribe
- Dispose

### 2.4 Threading model

- Thread source of each callback/event
- Marshaling requirements (UI thread/worker thread/COM apartment)
- Synchronization mechanisms currently used

---

## Phase 3 — Flow and Protocol Specification

### 3.1 Runtime flow diagrams

Provide sequence diagrams (Mermaid or ASCII) for:
1. App startup and bridge registration
2. State update propagation to GUI callback
3. Command → subsystem → callback → state update cycle
4. Error/fault path (timeout, COM exception, disconnected dependency)

### 3.2 Communication protocol specification

Define protocol used between components (callbacks/events/commands), including:

| Channel | Producer | Consumer | Message/Event Name | Payload Schema | Correlation ID | Ordering | Retry | Timeout | Error Contract |
|---|---|---|---|---|---|---|---|---|---|

Also define:
- Versioning strategy for messages/callback payloads
- Backward compatibility policy
- Idempotency rules for repeated events
- De-duplication strategy if duplicate callbacks happen
- High-frequency update strategy (throttle/debounce/coalesce)

### 3.3 State transition rules

For each subsystem tracked by StateShell:

| Subsystem | State Enum/Class | Allowed Transitions | Invalid Transitions | Recovery Path |
|---|---|---|---|---|

---

## Phase 4 — Risk Analysis

Create a structured risk section focused on runtime reliability.

### 4.1 Risk register

| Risk ID | Risk | Trigger | Impact | Detection | Mitigation | Residual Risk |
|---|---|---|---|---|---|---|

Must include at minimum:
- Wrong DI scope causing event source mismatch
- Registration race condition
- Callback not registered / stale target
- COM apartment or marshaling mismatch
- Thread-safety/data race in state updates
- Event storms causing lag
- Silent exception swallowing
- Partial startup failure with inconsistent bridge state

### 4.2 Observability

Define required logs/metrics/traces:
- Startup wiring logs
- Subscription audit logs
- State-change audit logs
- Error and retry logs
- Health heartbeat/logging

Include exact suggested log keys and sample lines.

---

## Phase 5 — Implementation Code Pack

Generate implementation-ready code with file-by-file structure.

### Requirements for generated code

- Use real names from discovered architecture.
- Keep compatibility with existing contracts where possible.
- No placeholder-only stubs.
- Include:
  - bridge classes
  - bootstrapper registration changes
  - state model updates
  - protocol adapters/mappers
  - callback handlers
  - cleanup/unsubscribe logic
  - diagnostics hooks

### Required code output format

For each file:

1. `File: <relative/path>`
2. Full compilable code block
3. Notes on why this file changed

Also include:
- Any `AOI_Main.csproj` edits (if needed, but do not add new external packages)
- Migration notes for interface changes

---

## Phase 6 — Rebuild Playbook (Deterministic)

Create deterministic instructions that another Claude session can follow exactly.

### 6.1 Rebuild steps

Provide numbered steps:
1. Create/update files in exact order
2. Register dependencies and bootstrap order
3. Build verification commands
4. Runtime verification checklist

### 6.2 Acceptance criteria

Define pass/fail checks:

| Check | Expected Result | How to Verify |
|---|---|---|

### 6.3 Regression checklist

- Existing bridge behavior unchanged
- New state surfaces correctly
- No startup deadlocks/races
- No leaked subscriptions on shutdown

---

## Final Output Contract (strict)

Return exactly these sections:

1. Executive Summary
2. Architecture Inventory Table
3. StateShell Design Document
4. Runtime Flows (diagrams)
5. Communication Protocol Spec
6. Risk Register + Mitigations
7. Implementation Code Pack (file-by-file)
8. Rebuild Playbook
9. Acceptance + Regression Checklists
10. Assumptions and Open Questions

If repository evidence is missing for any required part, state exactly what is missing and provide a fallback implementation strategy clearly marked as `FALLBACK`.
