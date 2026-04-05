# Falcon.Net State Shell — Prompt 3: Solution Selection & Full Design

> **Prerequisites:** Prompt 1 discovery findings + Prompt 2 evaluation matrix are complete.  
> **Goal:** Select the winning architecture, then produce the **complete design** —  
> class diagrams, data contracts, threading model, and integration map for all 8 domains.  
> Do NOT write implementation code yet — produce the design blueprint.

---

You are a **senior software architect**.  
Based on the discovery findings (Prompt 1) and the alternative evaluation (Prompt 2), select the best architecture for a `Falcon.Net`-owned state shell and produce a full design.

---

## Step 1 — Architecture Decision

State the chosen architecture and justify it in terms of:

1. **Why it wins** over the rejected alternatives (reference the evaluation matrix scores)
2. **Which constraints from Prompt 1 it best satisfies** (COM threading, .NET 4.8, no new deps, latency)
3. **Which trade-offs you are explicitly accepting** and why they are acceptable
4. **Whether the Hybrid (Event Aggregator + AoiStateCache + thin Rx wrapper) is adopted** — and which parts
5. **Ownership boundary after migration**: what is owned by `Falcon.Net` vs what remains in `AOI_Main`

Format as an **Architecture Decision Record (ADR)**:

```markdown
## ADR-001: Falcon.Net State Shell Architecture

**Status:** Accepted  
**Date:** [today]  
**Deciders:** [list]

### Context
[2-3 sentences from Prompt 1 discovery]

### Decision
[chosen approach in one sentence]

### Consequences
**Positive:** ...  
**Negative / trade-offs:** ...  
**Risks:** ...
```

---

## Step 2 — Complete Class Design

Produce the **full class diagram** (text UML or structured table) for every type in the state system.

### 2.1 State Data Types (one per domain)

For each domain, define the **payload/DTO** exactly:

```
ScanStatePayload
├── Status          : ScanStatus  (enum: Idle | Starting | Grabbing | ColorGrab | Aborting | Complete | Error)
├── WaferId         : string
├── ScanId          : Guid
├── ProgressPercent : int          (0-100)
├── CameraMode      : CameraMode  (enum: Mono | Color | CSP | TDI | ...)
├── StartTimeUtc    : DateTime
├── ElapsedMs       : long
└── ErrorMessage    : string       (null if no error)
```

Do the same for:
- `RobotStatePayload` — robot/EFEM/loader state
- `CameraLightPayload` — camera ID, channel, intensity values, objective, illumination active flag
- `JobStatePayload` — job name, path, status (None/Loaded/Running/Deleted), recipe parameters summary
- `AlignmentPayload` — offset X/Y (µm), angle (mrad), wafer ID, pass/fail, timestamp, algorithm used
- `CleanRefPayload` — is-valid flag, camera ID, capture timestamp, file path, reason for clean
- `CmmStatePayload` — phase (Idle/Open/Exporting/Done/Error), ticket ID, export path, error code
- `DieEditPayload` — wafer ID, die row/col coordinates, edit type (Reclassify/Exclude/Restore), before/after values, timestamp, operator ID

**Rules for all payloads:**
- Immutable (readonly properties, set only via constructor)
- Serializable (`[Serializable]` or JSON-friendly) for logging
- Must compile on .NET Framework 4.8 (no C# 9 `record` — use class with readonly fields)
- Override `ToString()` for diagnostic logging

### 2.2 Event Classes

```
AoiStateEventBase<TPayload>
├── Payload    : TPayload
├── TimestampUtc : DateTime
└── SequenceNo : long  (monotonic counter — detects missed events)

ScanStateChangedEvent    : AoiStateEventBase<ScanStatePayload>
RobotStateChangedEvent   : AoiStateEventBase<RobotStatePayload>
CameraLightChangedEvent  : AoiStateEventBase<CameraLightPayload>
JobStateChangedEvent     : AoiStateEventBase<JobStatePayload>
AlignmentChangedEvent    : AoiStateEventBase<AlignmentPayload>
CleanRefChangedEvent     : AoiStateEventBase<CleanRefPayload>
CmmStateChangedEvent     : AoiStateEventBase<CmmStatePayload>
DieEditChangedEvent      : AoiStateEventBase<DieEditPayload>
```

### 2.3 Core Infrastructure

```
IAoiEventAggregator
├── Publish<TEvent>(TEvent evt)    : void   [thread-safe, non-blocking]
├── Subscribe<TEvent>(Action<TEvent> handler, AoiThreadOption thread) : IDisposable
└── GetCurrentState()             : AoiStateSnapshot  [returns last known state per domain]

AoiThreadOption  (enum)
├── PublisherThread    — handler runs on the thread that called Publish()
├── BackgroundThread   — handler dispatched to ThreadPool
└── UIThread           — handler dispatched via SynchronizationContext

AoiStateSnapshot  (read-only struct)
├── Scan        : ScanStatePayload       (last known, or null if not yet received)
├── Robot       : RobotStatePayload
├── CameraLight : CameraLightPayload
├── Job         : JobStatePayload
├── Alignment   : AlignmentPayload
├── CleanRef    : CleanRefPayload
├── Cmm         : CmmStatePayload
└── DieEdit     : DieEditPayload

AoiEventAggregator : IAoiEventAggregator
├── [internal] ConcurrentDictionary<Type, List<WeakReference<Delegate>>>   subscriptions
├── [internal] AoiStateSnapshot _currentState  (written under lock, read lock-free via Interlocked)
└── [internal] long _sequenceCounter           (Interlocked.Increment)
```

### 2.4 Bridge Adapters (one per domain)

Each bridge (hosted by `Falcon.Net` state shell):
- Wires to the **existing** COM event / WCF callback / IPC channel (from Prompt 1 findings)
- Converts raw BIS data to the typed payload
- Calls `_eventAggregator.Publish()` — never blocks

```
IAoiStateBridge
├── Start() : void   [subscribe to source events]
└── Stop()  : void   [unsubscribe, clean up]

ScanStateBridge      : IAoiStateBridge   → wires DdsIPC / GrabIPC COM events
RobotStateBridge     : IAoiStateBridge   → wires PizzaServer TCP / COM events
CameraLightBridge    : IAoiStateBridge   → wires camera driver COM events
JobStateBridge       : IAoiStateBridge   → wires Job.NET COM events or WCF callback
AlignmentBridge      : IAoiStateBridge   → wires Alignment COM events
CleanRefBridge       : IAoiStateBridge   → called directly after clean operation
CmmBridge            : IAoiStateBridge   → wires CmmServiceNotifierProxy WCF duplex callback
DieEditBridge        : IAoiStateBridge   → wires DieEdit COM event or ticket file watcher

AoiStateBridgeOrchestrator
├── Start()  — starts all bridges
├── Stop()   — stops all bridges
└── [internal] List<IAoiStateBridge> _bridges
```

### 2.5 Consumer API

```
// Subscription — returns IDisposable for clean unsubscribe
IDisposable scanSub = _eventAgg.Subscribe<ScanStateChangedEvent>(
    evt => HandleScan(evt.Payload),
    AoiThreadOption.BackgroundThread);

// Query current state without waiting for next event
AoiStateSnapshot snap = _eventAgg.GetCurrentState();
ScanStatePayload current = snap.Scan;   // null if not yet received

// Unsubscribe
scanSub.Dispose();
```

---

## Step 3 — Threading Model (Formal Specification)

Produce a **thread-flow diagram** for each source type:

### 3.1 COM Event Path (STA → non-blocking publish)
```
[COM STA Thread — GrabIPC callback]
    ↓
ScanStateBridge.OnGrabComplete(comArgs)  ← must return in <1ms, never block
    ↓
map comArgs → ScanStatePayload
    ↓
AoiEventAggregator.Publish<ScanStateChangedEvent>(evt)
    ↓ (non-blocking: update snapshot under spinlock, then)
    ↓ → BackgroundThread subscribers: ThreadPool.QueueUserWorkItem
    ↓ → UIThread subscribers: SynchronizationContext.Post
    ↓ → PublisherThread subscribers: invoke directly (still on STA — use with care)
return immediately to COM pump ✓
```

### 3.2 WCF Duplex Callback Path (CMM)
```
[WCF I/O Thread — CmmServiceNotifierProxy.OnCmmStateChanged()]
    ↓
CmmBridge.OnCmmStateChanged(cmmArgs)
    ↓
map → CmmStatePayload
    ↓
AoiEventAggregator.Publish<CmmStateChangedEvent>(evt)
    ↓ (same non-blocking dispatch as above)
return immediately ✓
```

### 3.3 Direct Call Path (CleanRef, Die Edit via file watcher)
```
[Caller thread — any]
    ↓
CleanRefBridge.NotifyCleanReference(cameraId, filePath, isValid)
    ↓
AoiEventAggregator.Publish<CleanRefChangedEvent>(evt)
return immediately ✓
```

### 3.4 Invariants (must be enforced by design, not convention)
- `Publish()` **MUST** complete in O(1) — regardless of subscriber count
- No subscriber can block `Publish()` — all `BackgroundThread` and `UIThread` dispatches are fire-and-forget
- `GetCurrentState()` **MUST** be lock-free for reads (use `Volatile.Read` or `Interlocked`)
- If a `BackgroundThread` subscriber throws, it **MUST** be caught and logged — never crash the bridge
- Weak references prevent memory leaks when subscribers are GC'd without explicit unsubscribe

---

## Step 4 — Integration & Ownership Map

For each of the 8 domains, specify the **exact integration point** (from Prompt 1 findings) and how the bridge connects to it:

| Domain | BIS Source Component | Integration Mechanism | Bridge Method | Payload Fields Mapped |
|---|---|---|---|---|
| Scan/Grab | `DdsSrv_d.exe` via `DdsIPC` | COM event: `[FILL FROM PROMPT 1]` | `ScanStateBridge.OnScanEvent()` | Status, WaferId, ProgressPercent |
| Color Grab | `Sources/Grabbing/` Color grabber | COM event: `[FILL FROM PROMPT 1]` | `ScanStateBridge.OnColorGrabEvent()` | Status=ColorGrab, CameraMode=Color |
| Robot | `PizzaServer.exe` | `[FILL FROM PROMPT 1]` | `RobotStateBridge.OnRobotMessage()` | Status, ErrorCode |
| Camera/Lights | BIS camera driver (17 types) | COM event: `[FILL FROM PROMPT 1]` | `CameraLightBridge.OnIlluminationChanged()` | CameraId, Channel, Intensity |
| Job | `Job.NET` in `Sources/objects/` | `[FILL FROM PROMPT 1]` | `JobStateBridge.OnJobChanged()` | JobName, Status |
| Alignment | `Sources/objects/Alignment` | `[FILL FROM PROMPT 1]` | `AlignmentBridge.OnAlignmentChanged()` | OffsetX, OffsetY, Angle, IsValid |
| Clean Ref | Post-operation direct call | Explicit API call | `CleanRefBridge.Notify()` | IsValid, CameraId, FilePath |
| CMM | `CmmServiceNotifierProxy` WCF port 8032 | WCF duplex callback | `CmmBridge.OnCmmStateChanged()` | Phase, TicketId |
| Die Edit | `DieEdit.sln` | `[FILL FROM PROMPT 1]` | `DieEditBridge.OnDieEditApplied()` | WaferId, DieCoord, EditType |

Instruction: fill every `[FILL FROM PROMPT 1]` cell with the exact COM interface/event name, TCP message type, or WCF operation discovered in Prompt 1.

### 4.1 Ownership Transfer Map (MANDATORY)

Provide a concrete move map for migration to Falcon.Net:

| Item | Current location | New location | Action (Move / Wrap / Keep) |
|---|---|---|---|
| State shell bootstrap | ... | ... | ... |
| COM callback registration | ... | ... | ... |
| `IAutoCycleManagerCB` sink ownership | ... | ... | ... |
| `IScanManagerCB` sink ownership | ... | ... | ... |
| `IFalconGuiCB` sink ownership | ... | ... | ... |
| AOI_Main consumer API/adapters | ... | ... | ... |

Add a second table with exact callback ownership after migration:

| Callback family | Register method | Owner class in Falcon.Net | Downstream publisher |
|---|---|---|---|
| Scan | `RegisterScanEvent` | ... | ... |
| Robot/CMM | `RegisterAutoCycleEvent` | ... | ... |
| GUI/Job/Camera | `RegisterFalconGuiEvent` | ... | ... |

---

## Step 5 — Testability Contract

Design the test seams:

```
IAoiEventAggregator             ← inject mock in unit tests
IAoiStateBridge                 ← inject stub bridges; trigger via Publish() directly
AoiStateBridgeOrchestrator      ← inject bridge list; call Start()/Stop() in test setup/teardown
```

**Unit test patterns:**
1. **Bridge test** — given a simulated COM event, assert correct payload is published
2. **Consumer test** — subscribe, publish a known event, assert handler invoked with correct payload
3. **Threading test** — publish from Thread A, assert BackgroundThread handler runs on ThreadPool, UIThread handler runs on captured SynchronizationContext
4. **Current state test** — publish 3 sequential events for same domain, assert `GetCurrentState()` returns last

**No hardware, no COM server required for any test.**

---

## Step 6 — Error Handling & Diagnostics

| Failure scenario | Handling |
|---|---|
| Bridge fails to connect to COM server at startup | Log warning, set domain state to `Unknown`, retry on next poll (bridge-specific) |
| Bridge receives malformed COM event data | Log error with raw event dump, publish `ScanStatePayload { Status = Error }` |
| Subscriber throws exception in BackgroundThread handler | Catch in dispatcher loop, log with subscriber type name, continue dispatching to remaining subscribers |
| UIThread subscriber SynchronizationContext is null (headless/test) | Fall back to BackgroundThread dispatch, log diagnostic |
| Sequence number gap detected by consumer | Consumer may optionally query `GetCurrentState()` for a fresh snapshot |

---

## Output Required from This Prompt

Produce a **Design Document** containing:

1. The ADR (Section 2.1 format above)
2. All data type definitions (Section 2 — precise field names, types, enums)
3. The threading invariants table
4. The completed integration map (with Prompt 1 findings filled in)
5. The testability contract
6. A **one-page architecture summary diagram** (ASCII or Mermaid) showing:
   - The 8 BIS source components
   - The 8 bridge adapters
   - The `AoiEventAggregator`
   - `AoiStateSnapshot`
   - Consumer examples (ViewModel, TestRunner, Logger)
   - Thread boundaries clearly marked

This document is the **input to Prompt 4** (implementation).
