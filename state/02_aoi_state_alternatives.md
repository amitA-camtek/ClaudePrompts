# Falcon.Net State Shell — Prompt 2: Alternative Solutions

> **Prerequisites:** `01_aoi_state_discovery.md` findings are complete and in hand.  
> **Goal:** Propose **3 distinct architectural alternatives** for a `Falcon.Net`-owned state shell.  
> Evaluate each honestly. Do not pick a winner yet — that is Prompt 3.

---

You are a **senior software architect**.  
You have completed the discovery phase (structured_findings.md) and now have a full picture of:
- The 8 state domains (Scan/Grab, Robot, Camera/Lights, Job, Alignment, Clean Reference, CMM, Die Edit)
- The existing threading model (COM STA/MTA, UI thread, grabbing pipeline)
- The existing event infrastructure (COM events, WCF duplex callbacks, RabbitMQ, `GrabIPC`/`AcqIPC`/`DdsIPC`)
- The constraints (frozen COM interfaces, WCF contracts, latency requirements)

Now propose **3 alternative architectures** for a `Falcon.Net`-managed state. Each must be:
- **Non-blocking** — never stalls the COM STA pump, grabbing pipeline, or UI thread
- **Event-driven** — consumers subscribe to state changes; polling is not acceptable
- **Composable** — the 8 domains can be observed independently or together
- **Testable** — can be unit-tested without requiring live hardware or COM servers

---

## Alternative 1 — Centralized Immutable State Store (Redux-style)

### Concept
A single `AoiStateStore` class holds the complete system state as an **immutable snapshot**.  
Every change is applied by dispatching a `StateAction` which produces a new snapshot.  
Subscribers receive the new snapshot via `event AoiStateChanged`.

### Structure
```
AoiStateStore
├── AoiState (immutable record)
│   ├── ScanState         (enum: Idle | Grabbing | ColorGrab | Aborting | Complete | Error)
│   ├── RobotState        (enum: Unknown | Idle | Loading | Unloading | Homing | Error)
│   ├── CameraLightState  (CameraId, Channel, Intensity, Objective, IsIlluminationActive)
│   ├── JobState          (JobName, JobPath, Status: None|Loaded|Running|Deleted)
│   ├── AlignmentState    (OffsetX, OffsetY, Angle, WaferId, IsValid, Timestamp)
│   ├── CleanRefState     (IsValid, CameraId, Timestamp, FilePath)
│   ├── CmmState          (TicketId, Phase: Idle|Open|Exporting|Done|Error, LastExportPath)
│   └── DieEditState      (WaferId, EditCount, LastEditTimestamp, LastDieCoord)
│
├── Dispatch(IStateAction action) → void  [thread-safe, non-blocking]
├── event EventHandler<AoiStateChangedArgs> StateChanged
└── AoiState Current { get; }
```

### How Each Domain Feeds In
| Domain | Source event/callback | Bridge mechanism |
|---|---|---|
| Scan/Grab | COM event from `DdsIPC`/`GrabIPC` | COM event handler posts `ScanAction` to `ConcurrentQueue`, worker thread drains |
| Robot | WinSock TCP or COM event from `PizzaServer.exe` | Same pattern — async receive → `RobotAction` |
| Camera/Lights | COM event or polling from BIS camera driver | `CameraAction` dispatched on change |
| Job | WCF duplex callback or COM event from Job.NET | `JobAction` dispatched |
| Alignment | COM event from Alignment module | `AlignmentAction` dispatched |
| Clean Ref | Direct call after clean operation | `CleanRefAction` dispatched synchronously |
| CMM | WCF duplex `CmmServiceNotifierProxy` | `CmmAction` dispatched on callback |
| Die Edit | COM event or file-watch on ticket directory | `DieEditAction` dispatched |

### Threading Model
```
COM callback thread (STA)
    ↓ (marshal-free: just enqueue)
ConcurrentQueue<IStateAction>
    ↓ (dedicated background thread — MTA)
AoiStateStore.Dispatch()
    ↓ (produce new immutable AoiState snapshot)
event StateChanged — fired on background thread
    ↓
Subscriber marshals to UI thread if needed (Dispatcher.BeginInvoke)
```

### Pros
- Single source of truth — trivial to serialize/snapshot for debugging and test replay
- Completely thread-safe: COM STA thread only enqueues, never waits
- Time-travel debugging: log every action → replay to reproduce bugs
- Easy to unit test: inject actions, assert resulting state

### Cons
- Every state change allocates a new immutable record (GC pressure in high-frequency scan loops)
- All 8 domains are coupled in one `AoiState` — a Scan tick fires StateChanged even for CMM subscribers
- Adds an abstraction layer on top of existing COM/WCF events — double event wiring required
- Requires `with`-expression support (C# 9+ records) or manual clone — check .NET Framework 4.8 compatibility

### .NET Framework 4.8 Compatibility Notes
- `record` types require C# 9 — **not available on .NET Framework 4.8** without workarounds  
- Must use **manual immutable classes** with copy constructors or `Clone()` methods  
- `ConcurrentQueue<T>` ✅ available since .NET 4.0  
- `event EventHandler<T>` ✅ standard

---

## Alternative 2 — Per-Domain Reactive Subjects (Rx.NET / IObservable)

### Concept
Each of the 8 state domains is an **independent observable stream**.  
A `BehaviorSubject<T>` per domain holds the latest value and replays it to new subscribers.  
Consumers can subscribe to individual domains or compose them with LINQ (`CombineLatest`, `Merge`, `Throttle`).

No central store — each domain is self-contained.

### Structure
```
AoiStateService
├── IObservable<ScanState>        Scan        { get; }
├── IObservable<RobotState>       Robot       { get; }
├── IObservable<CameraLightState> CameraLight { get; }
├── IObservable<JobState>         Job         { get; }
├── IObservable<AlignmentState>   Alignment   { get; }
├── IObservable<CleanRefState>    CleanRef    { get; }
├── IObservable<CmmState>         Cmm         { get; }
├── IObservable<DieEditState>     DieEdit     { get; }
└── [internal] BehaviorSubject<T> per domain — OnNext() called from bridge adapters
```

### How Each Domain Feeds In
```
COM event handler (STA thread)
    → Observable.FromEvent(...).ObserveOn(TaskPoolScheduler.Default)
    → Map to domain state DTO
    → subject.OnNext(newState)
    → subscribers receive on their chosen scheduler
```

Consumers control their own threading via `.ObserveOn(DispatcherScheduler.Current)` (UI) or `.ObserveOn(NewThreadScheduler.Default)` (background processing).

### Example Usage
```csharp
// Subscribe to scan state changes only
_stateService.Scan
    .DistinctUntilChanged()
    .ObserveOn(DispatcherScheduler.Current)
    .Subscribe(s => UpdateScanIndicator(s));

// Compose: alert when scan completes AND CMM is not busy
Observable.CombineLatest(
    _stateService.Scan,
    _stateService.Cmm,
    (scan, cmm) => scan == ScanState.Complete && cmm.Phase == CmmPhase.Idle)
    .Where(ready => ready)
    .Subscribe(_ => TriggerCmmExport());
```

### Threading Model
```
COM callback (STA)
    ↓ Observable.FromEvent — no blocking
TaskPoolScheduler (background pool)
    ↓ state mapping
BehaviorSubject.OnNext()
    ↓
Each subscriber's chosen scheduler (UI / background / test)
```

### Pros
- Per-domain isolation — subscribing to CMM never fires for Scan events
- Composability via LINQ — no custom event aggregator needed
- `BehaviorSubject` provides current value on subscribe — no "missed event at startup" problem
- Excellent for test: `TestScheduler` allows virtual-time testing of race conditions

### Cons
- `System.Reactive` (Rx.NET) is an **external NuGet dependency** — requires approval for BIS monorepo
- Rx learning curve for team members unfamiliar with reactive programming
- `Observable.FromEvent` over COM events requires careful STA marshalling — easy to deadlock if scheduler is wrong
- Exception handling in Rx chains can silently terminate subscriptions (`OnError` terminates the stream)
- Debugging Rx pipelines is harder than debugging plain C# events

### .NET Framework 4.8 Compatibility Notes
- `System.Reactive` 5.x supports .NET Framework 4.8 ✅  
- `BehaviorSubject<T>` ✅  
- `DispatcherScheduler` requires `System.Reactive.Windows.Threading` ✅

---

## Alternative 3 — Event Aggregator with Typed Domain Events (Prism-style, no external deps)

### Concept
A lightweight **in-process event bus** (`IAoiEventAggregator`) with strongly-typed events per domain.  
Each domain has its own event class (`ScanStateChangedEvent`, `RobotStateChangedEvent`, etc.).  
Publishers call `eventAggregator.GetEvent<T>().Publish(payload)`.  
Subscribers call `eventAggregator.GetEvent<T>().Subscribe(handler, threadOption)`.

This mirrors the **Prism EventAggregator** pattern already used in MDC (Prism 6 / Unity) and SystemCalibration (Prism 5 / MEF) — so it is already a known pattern in this codebase.

No external dependencies beyond what BIS already uses.

### Structure
```
IAoiEventAggregator
├── GetEvent<ScanStateChangedEvent>()    → PubSubEvent<ScanStatePayload>
├── GetEvent<RobotStateChangedEvent>()   → PubSubEvent<RobotStatePayload>
├── GetEvent<CameraLightChangedEvent>()  → PubSubEvent<CameraLightPayload>
├── GetEvent<JobStateChangedEvent>()     → PubSubEvent<JobStatePayload>
├── GetEvent<AlignmentChangedEvent>()    → PubSubEvent<AlignmentPayload>
├── GetEvent<CleanRefChangedEvent>()     → PubSubEvent<CleanRefPayload>
├── GetEvent<CmmStateChangedEvent>()     → PubSubEvent<CmmStatePayload>
└── GetEvent<DieEditChangedEvent>()      → PubSubEvent<DieEditPayload>

AoiStateBridge (per domain)
├── Wires COM event / WCF callback / IPC message → eventAggregator.GetEvent<T>().Publish()
└── Runs on background thread (ThreadOption.BackgroundThread)

AoiStateCache (optional companion)
└── Subscribes to all events, maintains last-known value per domain
    (for "what is the current state?" queries without re-subscribing)
```

### Threading Model
```
COM callback (STA) or WCF duplex callback
    ↓ Bridge adapter — non-blocking, just calls Publish()
    ↓ PubSubEvent dispatches on ThreadOption.BackgroundThread (System.Threading.ThreadPool)
    ↓ or ThreadOption.UIThread (if subscriber is a WPF ViewModel)
Subscriber handler — runs on requested thread option
```

`Publish()` is non-blocking for `BackgroundThread` subscribers (fire-and-forget onto ThreadPool).  
For `UIThread` subscribers, Prism marshals via `SynchronizationContext` — no manual `Dispatcher.Invoke`.

### How Each Domain Feeds In
| Domain | Bridge class | Trigger | Publish call |
|---|---|---|---|
| Scan/Grab | `ScanStateBridge` | COM event from `DdsIPC` | `Publish(new ScanStatePayload { Status = ScanStatus.Grabbing, ... })` |
| Robot | `RobotStateBridge` | TCP message from `PizzaServer.exe` | `Publish(new RobotStatePayload { ... })` |
| Camera/Lights | `CameraLightBridge` | COM event from camera driver | `Publish(new CameraLightPayload { CameraId, Intensity, ... })` |
| Job | `JobStateBridge` | COM event or WCF callback | `Publish(new JobStatePayload { JobName, Status, ... })` |
| Alignment | `AlignmentBridge` | COM event from Alignment module | `Publish(new AlignmentPayload { OffsetX, OffsetY, ... })` |
| Clean Ref | `CleanRefBridge` | Direct post-operation call | `Publish(new CleanRefPayload { IsValid, Timestamp })` |
| CMM | `CmmBridge` | `CmmServiceNotifierProxy` WCF callback | `Publish(new CmmStatePayload { Phase, TicketId })` |
| Die Edit | `DieEditBridge` | COM event or ticket file-watch | `Publish(new DieEditPayload { WaferId, DieCoord, ... })` |

### Example Usage
```csharp
// In a ViewModel or test runner
_eventAggregator.GetEvent<ScanStateChangedEvent>()
    .Subscribe(OnScanStateChanged, ThreadOption.UIThread, keepSubscriberAlive: false);

_eventAggregator.GetEvent<CmmStateChangedEvent>()
    .Subscribe(OnCmmChanged, ThreadOption.BackgroundThread);

// Current state query (via AoiStateCache)
var currentScan = _stateCache.Current.Scan;
```

### Pros
- **No new dependencies** — Prism EventAggregator is already in MDC and SystemCalibration
- Pattern is already **familiar to the team** — zero learning curve
- `ThreadOption` handles marshalling — subscribers declare their threading need declaratively
- Weak references supported — `keepSubscriberAlive: false` prevents memory leaks
- Easy to unit test: inject mock `IEventAggregator`, assert `Publish()` calls
- Completely non-blocking: `Publish()` puts work on ThreadPool and returns immediately

### Cons
- No built-in "current value on subscribe" — new subscribers miss events until the next change  
  (mitigated by `AoiStateCache` companion)
- No composability across domains without manual coordination (unlike Rx `CombineLatest`)
- Global event bus can become an untraceable "who published this?" debugging problem at scale
- If Prism is not already referenced by `Falcon.Net`, it adds a dependency (though a well-understood one)

### .NET Framework 4.8 Compatibility Notes
- Prism 6.x supports .NET Framework 4.8 ✅  
- Can also implement a **custom lightweight event aggregator** with zero dependencies (100 lines of C#) if adding Prism to `Falcon.Net` is undesirable

---

## Evaluation Matrix

Score each criterion 1 (poor) → 5 (excellent):

| Criterion | Weight | Alt 1: Redux Store | Alt 2: Rx.NET | Alt 3: Event Aggregator |
|---|---|---|---|---|
| Non-blocking (COM/UI thread safety) | 30% | 5 | 4 | 5 |
| Fits existing .NET 4.8 + COM constraints | 25% | 3 (record workaround) | 4 | 5 |
| Team familiarity / learning curve | 15% | 2 | 2 | 5 |
| Testability | 15% | 5 | 5 | 4 |
| Composability across domains | 10% | 3 | 5 | 2 |
| Zero new external dependencies | 5% | 4 | 2 | 5 |
| **Weighted total** | | **~3.8** | **~3.7** | **~4.7** |

---

## Hybrid Option (for Prompt 3 consideration)

A **hybrid of Alt 2 + Alt 3** may be optimal:
- Use the **Event Aggregator** (Alt 3) as the primary publish/subscribe bus (no new deps, team-familiar)
- Add an `AoiStateCache` that subscribes to all 8 events and maintains current state (solves "no current value on subscribe")
- For consumers that need **cross-domain composition**, wrap the cache in thin `IObservable<AoiState>` that only requires Rx on the consumer side (not the infrastructure)

This gives 95% of Rx benefits with 0% of the infrastructure risk.

---

## Output Required from This Prompt

Produce a **scored comparison document** for Prompt 3, structured as:
1. One paragraph summary of each alternative
2. The filled evaluation matrix with your scores and justification
3. Two or three sentences on whether the Hybrid option is worth pursuing
4. The **2 alternatives you recommend taking to Prompt 3** for detailed design
5. A short migration impact note per alternative:
    - What moves into `Falcon.Net`
    - What remains in `AOI_Main`
    - Who owns COM callback registration after migration

Save the final document to:

`alternatives_comparison.md`

Do NOT write implementation code yet.
