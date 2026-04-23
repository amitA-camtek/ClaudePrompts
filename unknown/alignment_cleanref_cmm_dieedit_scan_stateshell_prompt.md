# Claude Script — Audit Alignment/CleanRef/CMM/DieEdit/ScanState and Integrate into StateShell

You are a **senior software engineer**.

I have run `AOI_main`.
Your task is to collect all technical information about these domains in `AOI_main`:

- Alignment
- CleanRef
- CMM (`IAutoCycleManagerCB` and related)
- DieEdit
- ScanState (`IScanManagerCB` and related)

You must analyze interfaces, COM interop, state models, commands, callbacks/events, and then define a practical solution to integrate their state into `StateShell`.

use only assembly references already present in AOI_Main.csproj. 
---

## Goal

1. Discover all relevant code artifacts for each domain.
2. Summarize findings in structured tables.
3. Design a non-breaking `StateShell` integration approach.
4. Provide implementation-ready skeletons and rollout checklist.

---

## Phase 1 — Code Discovery (All Domains)

Search the full solution for each domain and gather evidence.

### 1.1 Search terms

Use these keywords (and related names discovered during search):

- **Alignment**: `Alignment`, `Align`, `IAlignment*`, `AlignmentState`, `AlignmentCommand`
- **CleanRef**: `CleanRef`, `ICleanRef*`, `CleanRefState`, `CleanRefCommand`
- **CMM**: `Cmm`, `CMM`, `IAutoCycleManagerCB`, `AutoCycle`, `CmmState`, `CmmCommand`
- **DieEdit**: `DieEdit`, `IDieEdit*`, `DieEditState`, `DieEditCommand`
- **ScanState**: `ScanState`, `Scan`, `IScanManagerCB`, `ScanManager`, `ScanStateEnum`, `ScanCommand`
- Shared patterns: `Bridge`, `StateShell`, `StateShellBootstrapper`, `IFalconGuiCB`, `ComImport`, `Guid`, `InterfaceType`, `event`, `Callback`, `Command`, `Status`

### 1.2 For every discovered artifact, capture

- Symbol name
- File path + project/assembly
- Type (interface/class/enum/event/delegate/COM wrapper)
- Purpose
- Inbound callers (who uses it)
- Outbound dependencies (what it calls)

---

## Phase 2 — Interface and COM Audit

For each domain (Alignment, CleanRef, CMM, DieEdit, ScanState), produce:

### 2.1 Interface inventory table

| Domain | Interface | Assembly | Methods | Properties | Events | Implementations | Main Callers |
|---|---|---|---|---|---|---|---|

### 2.2 COM/Interop table

Find all COM-related definitions/wrappers for these domains.

| Domain | COM Interface/Class | GUID | InterfaceType | Apartment/Threading Notes | Marshal Attributes | Registration Source |
|---|---|---|---|---|---|---|

Also identify whether callbacks (`IAutoCycleManagerCB`, `IScanManagerCB`, etc.) are COM callbacks, .NET events, or adapter abstractions.

---

## Phase 3 — State and Command Audit

For each domain, identify all state producers/consumers and commands.

### 3.1 State table

| Domain | State Name | Kind (enum/class/property) | Values/Shape | Writer(s) | Reader(s) | Notification Mechanism (event/callback/polling) |
|---|---|---|---|---|---|---|

### 3.2 Command table

| Domain | Command/API | Signature | Sync/Async | Invoker | Target | Side Effects | Error Path |
|---|---|---|---|---|---|---|---|

### 3.3 Callback/event table

| Domain | Callback/Event | Signature | Publisher | Subscriber | Thread Affinity | Reliability Notes |
|---|---|---|---|---|---|---|

---

## Phase 4 — Current StateShell Coverage

Analyze existing `StateShell` architecture and list what is already integrated.

### 4.1 Existing bridge map

| Existing Bridge | Domain Covered | State Exposed | Callback/API Used | Registration Point | Lifecycle |
|---|---|---|---|---|---|

### 4.2 Gap analysis

For each target domain, mark:

- Is state currently captured in `StateShell`? (Yes/No/Partial)
- What data is missing?
- Where state is lost (source exists but not bridged / bridged but not published / published but not consumed)

Output table:

| Domain | Coverage Status | Missing State Fields | Root Cause Gap | Priority |
|---|---|---|---|---|

---

## Phase 5 — Integration Design for StateShell

Design a concrete solution to integrate state for:
- Alignment
- CleanRef
- CMM
- DieEdit
- ScanState

### 5.1 Bridge strategy

Choose per domain:
- Extend an existing bridge **or**
- Add a new dedicated bridge

Provide table:

| Domain | Proposed Bridge | Dependencies | Source Callbacks/Events | Published State Model | Update Strategy |
|---|---|---|---|---|---|

### 5.2 State model additions

Define all new fields to add into state shell contracts.

| Domain | Field | Type | Source | Update Trigger | Notes |
|---|---|---|---|---|---|

### 5.3 Bootstrapper and DI changes

Specify exact integration points:
- Changes to `StateShellBootstrapper`
- DI registration scope (prefer singleton for event sources)
- Initialization order requirements
- Start/stop/dispose behavior

### 5.4 Callback/interface evolution

If `IFalconGuiCB` (or equivalent) lacks methods for these states:
- Propose additional callbacks/signatures
- Mark breaking vs non-breaking changes
- Provide compatibility strategy (versioned interface, adapter, default no-op handler)

---

## Phase 6 — Implementation Skeletons

Generate architecture-aligned skeletons (based on discovered base classes), for example:

- `AlignmentStateBridge`
- `CleanRefStateBridge`
- `CmmStateBridge`
- `DieEditStateBridge`
- `ScanStateBridge`

Each skeleton must include:
- Constructor dependencies
- Subscription wiring
- State mapping handlers
- Publish-to-StateShell calls
- Thread marshaling strategy
- Unsubscribe/dispose

Also provide bootstrapper registration skeleton.

---

## Phase 7 — Validation Plan

Provide test/verification checklist:

1. Startup validation (all bridges wired)
2. State transition validation per domain
3. Callback fire verification (`IAutoCycleManagerCB`, `IScanManagerCB`, others)
4. High-frequency/event-storm handling test
5. Threading/race-condition test
6. Fault injection (disconnect, timeout, COM exception)

Include expected logs/telemetry points.

---

## Required Final Output Format

Return exactly these sections:

1. Executive summary (short)
2. Discovery tables (interfaces, COM, state, command, callback)
3. Current StateShell coverage and gaps
4. Proposed StateShell integration design
5. Code skeletons (bridges + bootstrapper)
6. Risks and mitigations
7. Step-by-step rollout plan

---

## Constraints

- Use code evidence from repository, no guessing.
- Explicitly label assumptions when unavoidable.
- Prefer minimal and non-breaking changes.
- Keep naming and patterns consistent with existing architecture.
- Highlight COM threading/marshaling caveats wherever relevant.
