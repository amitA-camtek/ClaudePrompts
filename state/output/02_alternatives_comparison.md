# Alternatives Comparison — Falcon.Net Managed State Architecture

> **Date:** 2026-04-05  
> **Input:** `structured_findings.md` (discovery phase)  
> **Output:** Scored comparison for Prompt 3 detailed design  
> **Status:** Evaluation only — no implementation code

---

## 1. One-Paragraph Summaries

### Alternative 1 — Centralized Immutable State Store (Redux-style)

A single `AoiStateStore` singleton holds the complete system state as an immutable snapshot object (`AoiState`) containing all 8 domain sub-states. Every change is applied by dispatching a typed `IStateAction` into a `ConcurrentQueue`, which a dedicated background thread drains to produce a new snapshot. A single `StateChanged` event fires for every mutation, delivering the full new snapshot. The pattern is borrowed from frontend Redux/Flux architectures and excels at time-travel debugging and state serialization. The primary technical challenge in this codebase is that C# 9 `record` types are unavailable on .NET Framework 4.8, requiring manual immutable class implementations with copy-constructor/`With()` patterns. Additionally, every domain fires a single shared event, so high-frequency scan ticks would needlessly wake CMM or DieEdit subscribers unless filtered.

### Alternative 2 — Per-Domain Reactive Subjects (Rx.NET / IObservable)

Each of the 8 state domains is modeled as an independent `BehaviorSubject<T>` stream exposed via `IObservable<T>`. An `AoiStateService` class holds 8 observable properties. Bridge adapters convert COM callbacks, gRPC receiver events, and internal .NET events into `OnNext()` calls. Consumers choose their own threading via Rx schedulers (`ObserveOn(DispatcherScheduler)` for UI, `ObserveOn(TaskPoolScheduler)` for background). Domain streams can be composed with `CombineLatest`, `Merge`, `Throttle`, and `DistinctUntilChanged`. The primary concern is that `System.Reactive` is **not currently used anywhere** in the Falcon.Net codebase or the broader BIS monorepo — introducing it adds a new NuGet dependency and a significant learning curve for a team whose threading patterns are built on `NonBlockingUITask.Execute` and `Dispatcher.BeginInvoke`.

### Alternative 3 — Event Aggregator with Typed Domain Events (Prism-style)

A lightweight in-process event bus (`IAoiEventAggregator`) publishes strongly-typed `PubSubEvent<TPayload>` per domain. Bridge adapters convert COM callbacks and gRPC events into `Publish()` calls. Subscribers declare their threading preference via `ThreadOption.UIThread`, `ThreadOption.BackgroundThread`, or `ThreadOption.PublisherThread`. An optional `AoiStateCache` companion subscribes to all 8 events to maintain a queryable last-known-value per domain. This pattern already exists in the BIS monorepo: `Microsoft.Practices.Prism.PubSubEvents` (v1.0) is **already a referenced DLL** in `AOI_Main.csproj` / `AOI_Main_x64.csproj`, and `SystemCalibration` uses `IEventAggregator` with `PubSubEvent<T>` throughout its ViewModels. The MDC shell also uses typed `PubSubEvent` classes. The pattern requires zero new dependencies and zero team ramp-up.

---

## 2. Evaluation Matrix

### Scoring Rules

Each criterion is scored 1 (poor) through 5 (excellent). Scores are justified by facts from `structured_findings.md` and the csproj/code analysis.

| Criterion | Weight | Alt 1: Redux Store | Alt 2: Rx.NET | Alt 3: Event Aggregator |
|---|---|---|---|---|
| **Non-blocking (COM/UI thread safety)** | 30% | **5** | **4** | **5** |
| **Fits existing .NET 4.8 + COM constraints** | 25% | **2** | **3** | **5** |
| **Team familiarity / learning curve** | 15% | **2** | **1** | **5** |
| **Testability** | 15% | **5** | **5** | **4** |
| **Composability across domains** | 10% | **3** | **5** | **2** |
| **Zero new external dependencies** | 5% | **4** | **1** | **5** |
| **Weighted total** | 100% | **3.45** | **3.15** | **4.55** |

### Criterion-by-Criterion Justification

#### Non-blocking (COM/UI thread safety) — Weight 30%

- **Alt 1 (5/5):** Enqueue-only on STA thread — `ConcurrentQueue.Enqueue()` never blocks. Background drain thread produces snapshot. Clean separation. The existing `NonBlockingUITask.Execute` pattern (30+ call sites) is structurally compatible — COM callbacks enqueue and return immediately.
- **Alt 2 (4/5):** `Observable.FromEvent` on the STA thread is non-blocking for `BeginInvoke`-style delivery. However, `BehaviorSubject.OnNext()` is synchronous by default — if a subscriber callback does heavy work on the `OnNext` thread before `ObserveOn` kicks in, it can stall. Careful scheduler wiring is required on every subscription. The `GetInkingParams` sync callback pattern (`Dispatcher.Invoke`, noted deadlock risk in `ScanManagerWrapper`) adds risk when mixing Rx schedulers.
- **Alt 3 (5/5):** `Publish()` with `ThreadOption.BackgroundThread` is fire-and-forget onto `ThreadPool.QueueUserWorkItem` — the publishing thread returns immediately. This matches the existing `NonBlockingUITask.Execute` philosophy exactly. `ThreadOption.UIThread` uses `SynchronizationContext.Post` (async, non-blocking).

#### Fits existing .NET 4.8 + COM constraints — Weight 25%

- **Alt 1 (2/5):** C# 9 `record` types are **not available** on .NET Framework 4.8. Manual immutable class construction with copy-constructors or `With()` helper methods is required for all 8 domain state types plus the composite `AoiState`. This is verbose and error-prone: every new field means updating copy logic in 2+ places. `ConcurrentQueue<T>` itself works fine on 4.8, but the immutability infrastructure overhead is significant for a team that has no prior immutable-state patterns in the codebase.
- **Alt 2 (3/5):** `System.Reactive` 5.x supports .NET Framework 4.8. However, Rx is not currently referenced anywhere in the BIS monorepo. Adding a NuGet package to a monorepo that deploys to `c:\bis\bin\` with DLL hint paths (not PackageReference) requires build pipeline changes. COM interop with `Observable.FromEvent` on STA threads works but requires explicit scheduler management to avoid STA/MTA mismatches — a new failure mode for a team that currently uses the simpler `Dispatcher.BeginInvoke` pattern.
- **Alt 3 (5/5):** `Microsoft.Practices.Prism.PubSubEvents` v1.0 and `Microsoft.Practices.Prism.Composition` v5.0 are **already referenced** in both `AOI_Main.csproj` and `AOI_Main_x64.csproj` with hint paths to `c:\bis\bin\` and `c:\bis\bin\x64\`. The `System.ComPrismContainer` project reference exists. No build changes needed. The `PubSubEvent<T>` class, `IEventAggregator`, and `ThreadOption` enum are all available. .NET 4.8 standard delegate patterns (no C# 9 features needed).

#### Team familiarity / learning curve — Weight 15%

- **Alt 1 (2/5):** Redux/Flux state-store patterns are uncommon in .NET enterprise codebases. The BIS codebase has no precedent for action-dispatch-reducer patterns, immutable snapshots, or state replay. The team would need to learn action typing, reducer composition, and snapshot diffing — concepts foreign to the existing COM-callback + delegate-event model.
- **Alt 2 (1/5):** `System.Reactive` is not used anywhere in the BIS monorepo. The team's current async patterns are `NonBlockingUITask.Execute` (poll with `DoEvents`), `Dispatcher.BeginInvoke`, and `InvokeIfRequired`. Rx introduces schedulers, cold/hot observables, subscription lifecycle (`OnError` terminates streams), operator composition, and backpressure — a conceptual leap. Debugging Rx chains is notoriously harder than plain events. Exception handling differs fundamentally (unhandled `OnError` kills the subscription silently).
- **Alt 3 (5/5):** `IEventAggregator` with `PubSubEvent<T>` is already used in `SystemCalibration` (15+ ViewModels inject `IEventAggregator`; typed events like `PluginSelectedEvent : PubSubEvent<object>`, `ZoomChangedEvent : PubSubEvent<bool>`, etc. exist). MDC's `ShellInfrastructure/Events.cs` also uses `PubSubEvent`. The pattern of `GetEvent<T>().Subscribe(handler, ThreadOption.UIThread)` and `GetEvent<T>().Publish(payload)` is already reviewed and understood by the team.

#### Testability — Weight 15%

- **Alt 1 (5/5):** Inject actions, capture resulting snapshots. Deterministic: same sequence of actions always produces the same state. Snapshot serialization enables golden-file regression tests. No COM or hardware required.
- **Alt 2 (5/5):** Rx provides `TestScheduler` for virtual-time testing — advance time manually, verify subscriber received expected values. `BehaviorSubject` can be inspected for `.Value`. No COM or hardware required. `Observable.Return()` and `Subject<T>` make injection trivial.
- **Alt 3 (4/5):** `IEventAggregator` can be mocked. Test creates aggregator, publishes events, verifies subscriber handlers were called. Slightly weaker than Alt 1 (no built-in state snapshot to assert) and Alt 2 (no virtual-time testing). Testability gap is closed by the `AoiStateCache` companion — tests can publish, then query `_stateCache.Current.Scan`.

#### Composability across domains — Weight 10%

- **Alt 1 (3/5):** Full `AoiState` snapshot is available — consumers can react to any combination. But subscribing and filtering is manual: the single `StateChanged` event fires for every domain change. Consumers must diff old vs new state to determine what changed. No built-in "scan AND cmm" composition operator.
- **Alt 2 (5/5):** Rx excels here. `CombineLatest(scan$, cmm$)`, `Merge(scan$, robot$)`, `scan$.Throttle(100ms)`, `scan$.DistinctUntilChanged()` — all first-class. Cross-domain orchestration rules are declarative and concise.
- **Alt 3 (2/5):** Each domain is an independent event. No built-in composition. Cross-domain logic requires subscribing to multiple events and manually coordinating state. `AoiStateCache` helps (query current state of other domains inside a handler), but it's imperative, not declarative. For the 8 domains identified, the discovery found very few cross-domain composition needs in current code — the main one is CMM export triggering after scan completion, which is already handled procedurally in `frmProduction.FireWaferScanResultsAreReady`.

#### Zero new external dependencies — Weight 5%

- **Alt 1 (4/5):** No NuGet packages needed. `ConcurrentQueue<T>` is in `System.Collections.Concurrent`. But the immutable pattern infrastructure is custom code — effectively a "self-built dependency" that needs maintenance.
- **Alt 2 (1/5):** Requires adding `System.Reactive` (4 NuGet packages: `System.Reactive`, `System.Reactive.Core`, `System.Reactive.Linq`, `System.Reactive.Windows.Threading`). Not currently in the BIS monorepo. Build pipeline impact for a repo using raw DLL hint paths.
- **Alt 3 (5/5):** `Microsoft.Practices.Prism.PubSubEvents.dll` already in `c:\bis\bin\` and referenced by both `.csproj` files. Zero additions.

---

## 3. Hybrid Option Assessment

A hybrid of Alt 3 (Event Aggregator) + selective elements of Alt 1 (state cache) is worth pursuing. The foundation would use Prism `PubSubEvent<T>` as the in-process bus — this is zero-dependency, team-familiar, and already thread-safe. An `AoiStateCache` singleton subscribes to all 8 domain events and maintains a plain mutable snapshot of last-known values, solving the "no current value on subscribe" gap. For the rare cross-domain composition needs (e.g., "trigger CMM export when scan completes AND no other export is running"), the cache provides synchronous state queries inside event handlers without requiring Rx operators. This hybrid gives 95% of the capability for 10% of the integration risk and should be the design basis for Prompt 3.

---

## 4. Recommended Alternatives for Prompt 3 (Detailed Design)

### Primary Recommendation: Alternative 3 — Event Aggregator (Prism PubSubEvent)

**Rationale:** Highest weighted score (4.55). Zero new dependencies — the DLL is already deployed and referenced. Pattern is already used and reviewed in `SystemCalibration` and MDC. `ThreadOption` provides declarative threading that matches the codebase's existing STA/MTA marshaling needs. Non-blocking `Publish()` is structurally identical to the existing `NonBlockingUITask.Execute` fire-and-forget philosophy. The team has zero learning curve. Can be adopted incrementally (one domain at a time).

### Secondary Recommendation: Hybrid (Alt 3 + AoiStateCache)

**Rationale:** The `AoiStateCache` companion addresses Alt 3's primary weakness (no current value on subscribe) and provides a queryable state snapshot for cross-domain coordination. This does not introduce any new dependency — it's a plain C# class that subscribes to the 8 `PubSubEvent<T>` channels. For testing, the cache can be populated by publishing directly to the event aggregator, then asserting cache contents. This gives Alt 1's testability advantages without the immutability infrastructure burden.

### Not Recommended: Alternative 2 (Rx.NET)

**Rationale:** Lowest weighted score (3.15). Introduces a dependency never used in the monorepo. High learning curve for a team whose threading patterns are procedural (`NonBlockingUITask`, `Dispatcher.BeginInvoke`). The composability advantage (score 5/5) is underutilized — the codebase has very few cross-domain composition needs today. Rx's silent subscription termination on `OnError` is a production-safety risk in a system that handles wafers and robots.

### Not Recommended for standalone use: Alternative 1 (Redux Store)

**Rationale:** The immutable-state pattern does not fit .NET 4.8 ergonomically. Manual copy-constructor maintenance across 8 domain DTOs (with future growth) is error-prone. The single-event-for-all-domains model is a poor fit for a system where scan ticks at high frequency but CMM/DieEdit change rarely. However, the *concept* of a queryable current state feeds into the Hybrid recommendation via `AoiStateCache`.

---

## 5. Migration Impact Notes

### Alternative 3 — Event Aggregator

#### What moves into `Falcon.Net`

| Component | Description |
|---|---|
| `IAoiEventAggregator` wrapper | Thin façade over Prism `IEventAggregator` — singleton, registered in `MainContext` or `MainModules` |
| 8 typed event classes | `ScanStateChangedEvent : PubSubEvent<ScanStatePayload>`, etc. — one per domain |
| 8 payload DTOs | `ScanStatePayload`, `RobotStatePayload`, `CameraLightPayload`, `JobStatePayload`, `AlignmentPayload`, `CleanRefPayload`, `CmmStatePayload`, `DieEditPayload` |
| 8 bridge adapters | Wire existing COM/gRPC/internal events → `Publish()`. Each replaces scattered state-setting code |
| `Fire*` methods ownership | Move from `frmProduction` (WinForms form) to a dedicated `FalconEventService` class. `frmProduction.FalconFireEvents` property redirects to this service. |
| COM `IFalconFireEvents` lifecycle | Move from `frmProduction.FalconIsStartingUp()` to `FalconEventService` constructor |

#### What remains in `AOI_Main` (consumer side)

| Component | Description |
|---|---|
| `MainContext` singleton | Remains as the orchestration hub. Gains a reference to `IAoiEventAggregator` for publishing and subscribing. State *query* properties (`ScanResult`, `ScanDone`, etc.) remain but are fed by `AoiStateCache` instead of direct field writes. |
| `frmProduction` | Becomes a thin UI layer. Subscribes to events via `ThreadOption.UIThread`. No longer owns `Fire*` methods or `mFalconFireEvents`. |
| Form-level event handlers | All form-level handlers (`frmMain`, `frmScanTab`, `frmJobTab`) become subscribers to the event aggregator with `ThreadOption.UIThread`. |
| `ScanManagerWrapper` | Stays as-is — it already converts COM→.NET events. Its `.OnScanDone` event is now wired to `ScanStateBridge.Publish()` instead of `frmMain`'s handler directly. |
| `RobotUIEventHandlerWrapper` | Stays as-is — its 40+ delegate events are wired to `RobotStateBridge.Publish()`. |
| `ExternalControlCbUiWrapper` | Stays as-is — inbound callback handler. No change. |
| `clsCMM` + `CmmReceiverApiRequetsHandler` | Stay in Falcon.Net. gRPC inbound events publish to `CmmStateChangedEvent`. |

#### Who owns COM callback registration after migration

| Callback | Current Owner | Post-Migration Owner | Change |
|---|---|---|---|
| `IFalconFireEvents` (outward COM events) | `frmProduction` creates `CFalconEvents` on MTA thread | `FalconEventService` (new class in `Falcon.Net`) creates `CFalconEvents` on MTA thread | **Moves** from form to service |
| `IFalconExternalControl` registration | `ExternalControlCbUiWrapper` constructor | `ExternalControlCbUiWrapper` (unchanged) | **No change** |
| `CScanManager.RegisterEvent` | `ScanManagerWrapper` constructor | `ScanManagerWrapper` (unchanged) | **No change** |
| `IRobotUIConnector` initialization | `RobotUIEventHandlerWrapper.Initialize()` | `RobotUIEventHandlerWrapper` (unchanged) | **No change** |
| `ToolManager` registration | `ToolManagerUiWrapper` (owned by `frmProduction`) | `ToolManagerUiWrapper` stays with `frmProduction` or moves to `FalconEventService` | **Minor move** — depends on tool-state integration scope |

### Hybrid (Alt 3 + AoiStateCache)

Same migration impact as Alt 3 above, plus:

| Component | Description |
|---|---|
| `AoiStateCache` | New singleton in `Falcon.Net`. Subscribes to all 8 `PubSubEvent<T>` channels on `ThreadOption.BackgroundThread`. Maintains a thread-safe `AoiState` composite with last-known value per domain. Exposed via `MainContext.Instance.StateCache.Current` (replaces scattered boolean/enum state reads). |
| `AoiState` composite | Simple mutable POCO with `lock`-protected reads/writes. Not immutable — avoids .NET 4.8 record limitations. Thread-safe via `Interlocked` or `lock` per field group. |

The cache provides:
- `MainContext.Instance.StateCache.Current.Scan` — replaces `MainContext.Instance.ScanResult` + `ScanDone` + `PhysicalScanDone`
- `MainContext.Instance.StateCache.Current.Robot` — replaces `MainContext.Instance.RobotUI.InAutoCycle` queries
- Same pattern for remaining 6 domains

Existing property reads across the 5700-line `MainContext` can be migrated **incrementally** — each domain's properties are replaced one-at-a-time as bridge adapters come online. Properties not yet migrated continue working as-is (no big-bang cutover).

---

## Appendix: Factual Corrections to Proposed Architecture Inputs

The architecture proposal in the prompt contained several source-event assumptions that do not match the discovered codebase reality. These corrections informed the scoring:

| Prompt Assumption | Actual Finding (from `structured_findings.md`) | Impact on Design |
|---|---|---|
| Scan domain: "COM event from `DdsIPC`/`GrabIPC`" | AOI_Main does **not** directly use `DdsIPC`/`GrabIPC`/`AcqIPC`. Scan events come from `ScenarioManager.CScanManager` COM events via `ScanManagerWrapper` (.NET delegate events: `OnScanDone`, `OnScanProgressChange`). `DdsIPC` is a comment-only reference (`clsInitAOI` kills `DDSIpcLoader` on shutdown). | Bridge adapter wires to `ScanManagerWrapper.OnScanDone` — not to low-level IPC |
| Robot domain: "WinSock TCP or COM event from `PizzaServer.exe`" | AOI_Main uses `EfemSrv.IAutoLoader` COM interface + `RobotUIEventHandlerWrapper` (40+ delegate events) + `AutoLoaderUIWrapper`. No `PizzaServer.exe` reference in Falcon.Net code. | Bridge adapter wires to `RobotUIEventHandlerWrapper` events |
| CMM domain: "WCF duplex `CmmServiceNotifierProxy`" | AOI_Main does **not** use WCF duplex callbacks. CMM uses `CMM.Net.Api` client library + gRPC receiver on port 50055 (`CmmReceiverApiRequetsHandler`). `CmmServiceNotifierProxy` is a DataServer component used by MDC. | Bridge adapter wires to `CmmReceiverApiRequetsHandler` gRPC callbacks |
| Job domain: "WCF duplex callback or COM event from Job.NET" | No WCF usage in Falcon.Net. Job events are internal: `UIEvents.JobLoadingStarted`, `UIEvents.RecipeAdded/Deleted/Loaded`, `UIEvents.SetupInfoLoaded` (plain .NET delegates) + COM `IFalconFireEvents.JobLoaded` (outward). | Bridge adapter wires to existing `UIEvents` delegates |
| Die Edit domain: "COM event or ticket file-watch" | No COM event, no file-watch. DieEdit is an external process (`Camtek.DieEdit.exe`) launched fire-and-forget. Zero callback path back to AOI_Main. | Bridge adapter must be **new infrastructure**: either process exit detection, file-system watcher on recipe files, or a new PubSub channel from DieEdit |
| "AOI_Main uses `System.Reactive`" | No `System.Reactive` or `IObservable` anywhere in Falcon.Net. | Alt 2 (Rx.NET) requires a net-new dependency — not just "enabling something already there" |
| "Prism EventAggregator needs approval" | `Microsoft.Practices.Prism.PubSubEvents.dll` is **already referenced** in both `AOI_Main.csproj` and `AOI_Main_x64.csproj`, deployed to `c:\bis\bin\`. `SystemCalibration` already uses `IEventAggregator` + `PubSubEvent<T>` with 15+ ViewModel injections. | Alt 3 requires literally zero new dependency approvals |
