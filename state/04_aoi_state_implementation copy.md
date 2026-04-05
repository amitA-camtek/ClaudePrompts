# AOI Main State — Prompt 4: Implementation Plan & Code Generation

> **Prerequisites:** Prompt 3 Design Document is complete and approved.  
> **Goal:** Generate the full, production-ready implementation — one file at a time,  
> in dependency order, with every class, enum, and interface complete.  
> Run this prompt iteratively: complete one phase, validate, then continue.

---

You are a **senior software engineer**.  
You have the approved design document from Prompt 3. Now implement it.  
All code targets **.NET Framework 4.8 / C# 7.3** (the BIS constraint).  
No `record` types. No C# 9+ features. Use `class` with readonly fields.

---

## Phase 0 — Project Setup

Before writing any code, answer these questions from the codebase:

1. Should the state system live **inside** `Falcon.Net` (local), in a **new project** `Falcon.Net.StateShell`, or in a shared project referenced by Falcon.Net?  
    Recommendation: new project `Falcon.Net.StateShell` referenced by `BIS/Sources/apps/Falcon.Net/Falcon.Net.csproj`.

2. What **assembly references** does the new project need?
   - From BIS `c:\bis\bin\`: list the COM interop assemblies needed by each bridge
   - NuGet: none (design avoids external deps)
   - Project references: `TestAutomationSDK` (if it defines common types used by AOI_Main)

3. Create the project file stub:
```xml
<!-- Falcon.Net.StateShell.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net48</TargetFramework>
    <LangVersion>7.3</LangVersion>
    <AssemblyName>Falcon.Net.StateShell</AssemblyName>
    <RootNamespace>Camtek.Falcon.StateShell</RootNamespace>
    <Nullable>disable</Nullable>
  </PropertyGroup>
  <!-- Add COM interop references per bridge -->
</Project>
```

---

## Phase 1 — Core Infrastructure (no BIS dependencies)

Implement in this order. Each file is self-contained.

### 1.1 `AoiThreadOption.cs`
```csharp
namespace Camtek.AOIMain.StateEngine
{
    public enum AoiThreadOption
    {
        PublisherThread,
        BackgroundThread,
        UIThread
    }
}
```
Generate the complete file. No placeholders.

### 1.2 Payload base class + sequence counter
```csharp
// AoiStatePayloadBase.cs
// All payload classes inherit from this.
// Provides: TimestampUtc (set at construction), SequenceNo (global atomic counter).
```
Generate the complete file for `AoiStatePayloadBase` with a static `Interlocked.Increment` counter.

### 1.3 All 8 payload types
Generate one file per payload. Fill in every field from the Prompt 3 design. No placeholder comments.

Files: `ScanStatePayload.cs`, `RobotStatePayload.cs`, `CameraLightPayload.cs`, `JobStatePayload.cs`, `AlignmentPayload.cs`, `CleanRefPayload.cs`, `CmmStatePayload.cs`, `DieEditPayload.cs`

Each file must include:
- All enums used by that payload (e.g., `ScanStatus`, `RobotStatus`, `CmmPhase`)
- Readonly properties, constructor that sets all fields
- `ToString()` override for logging
- XML doc comments on every public member

### 1.4 Event wrapper classes
```csharp
// AoiStateEventBase.cs — generic wrapper
// ScanStateChangedEvent.cs, RobotStateChangedEvent.cs, ... (one per domain)
```
Generate all 9 files (base + 8 domain events).

### 1.5 `AoiStateSnapshot.cs`
Immutable struct holding the latest payload per domain.  
Must support lock-free reads via `Volatile.Read`.  
Include a static `Empty` instance (all domains null).

### 1.6 `IAoiEventAggregator.cs`
```csharp
public interface IAoiEventAggregator
{
    void Publish<TEvent>(TEvent evt) where TEvent : class;
    IDisposable Subscribe<TEvent>(Action<TEvent> handler, AoiThreadOption threadOption = AoiThreadOption.BackgroundThread) where TEvent : class;
    AoiStateSnapshot GetCurrentState();
}
```
Generate the complete interface file.

### 1.7 `AoiEventAggregator.cs`
The concrete implementation. This is the most critical file. Requirements:
- Thread-safe `Publish()` that completes in O(1) for the calling thread
- `BackgroundThread` dispatch via `ThreadPool.QueueUserWorkItem` — fire and forget
- `UIThread` dispatch via `SynchronizationContext.Post` (captured at construction) — falls back to BackgroundThread if null
- `PublisherThread` dispatch: direct invocation (caller is responsible for thread safety)
- Weak references for subscriptions — `keepAlive = false` by default, subscriber is GC-safe
- `GetCurrentState()` — lock-free read using `Volatile.Read<AoiStateSnapshot>`
- State snapshot updated atomically after each `Publish()` call using `Interlocked.Exchange`
- Per-subscriber exception isolation: catch, log, continue
- Subscribe returns `IDisposable` — `Dispose()` removes the subscription weak ref

Generate the **complete file**. No incomplete methods. No `// TODO` comments.

### 1.8 Unit Tests for Phase 1
File: `Falcon.Net.StateShell.Tests/AoiEventAggregatorTests.cs`  
Use NUnit 3 (already used in BIS/CMM).

Test cases to generate (all complete, not stubs):
- `Publish_OnBackgroundThread_HandlerInvokedOnThreadPool`
- `Publish_OnUIThread_HandlerInvokedOnSyncContext`
- `Subscribe_ThenDispose_HandlerNotInvokedAfterDispose`
- `GetCurrentState_AfterPublish_ReturnsLastPayload`
- `Publish_SequenceNumbers_AreMonotonicallyIncreasing`
- `Publish_SubscriberThrows_DoesNotCrashPublisher`
- `Publish_WeakRef_GcedSubscriberNotInvoked`

---

## Phase 2 — Bridge Infrastructure (no hardware required)

### 2.1 `IAoiStateBridge.cs`
```csharp
public interface IAoiStateBridge
{
    string DomainName { get; }
    void Start();
    void Stop();
}
```

### 2.2 `AoiStateBridgeOrchestrator.cs`
- Takes `IEnumerable<IAoiStateBridge>` via constructor (DI-friendly)
- `Start()` calls all bridges, catches per-bridge exceptions, logs and continues
- `Stop()` calls all bridges in reverse order
- Implements `IDisposable` — `Dispose()` calls `Stop()`

### 2.3 Bridge stubs (Phase 2 — safe to run without hardware)
Generate a **stub** implementation for each bridge that:
- Logs `"[BridgeName] Start() called — stub mode, no hardware connected"`
- Exposes a `public void SimulateEvent(TPayload payload)` method for testing
- Calls `_eventAggregator.Publish(new TEvent { Payload = payload })`

Files: `ScanStateBridge.cs`, `RobotStateBridge.cs`, `CameraLightBridge.cs`, `JobStateBridge.cs`, `AlignmentBridge.cs`, `CleanRefBridge.cs`, `CmmBridge.cs`, `DieEditBridge.cs`

### 2.4 Unit Tests for Phase 2
File: `Falcon.Net.StateShell.Tests/BridgeOrchestratorTests.cs`

Test cases:
- `Start_AllBridgesStarted`
- `Stop_AllBridgesStopped_InReverseOrder`
- `SimulateEvent_PublishesCorrectEventType`
- `BridgeThrowsOnStart_OtherBridgesStillStart`

---

## Phase 3 — Real Bridge Implementations (requires hardware COM refs)

> **Note:** Complete Phase 1 and Phase 2 first. Hardware bridges are added one domain at a time.  
> Use the stub from Phase 2 as the template — replace `SimulateEvent` with the real COM/WCF wiring.

For each bridge, generate the real implementation using the integration point discovered in Prompt 1.  
Fill in the `[FILL FROM PROMPT 1]` items from the Prompt 3 integration map.

### 3.1 `ScanStateBridge.cs` (real)
- Wire COM event: `[exact COM interface and event name from Prompt 1]`
- Handle: scan-start, scan-progress, scan-complete, scan-abort, color-grab-start, color-grab-complete
- Thread: COM STA — return immediately, enqueue payload, dispatch via aggregator

### 3.2 `RobotStateBridge.cs` (real)
- Wire: `[TCP message / COM event from Prompt 1]`
- Parse robot status codes into `RobotStatus` enum

### 3.3 `CameraLightBridge.cs` (real)
- Wire: `[COM event / driver callback from Prompt 1]`
- Support all relevant camera types from the 17 documented

### 3.4 `JobStateBridge.cs` (real)
- Wire: `[COM event / WCF callback from Prompt 1]`
- Handle: job-loaded, job-deleted, job-running, job-complete

### 3.5 `AlignmentBridge.cs` (real)
- Wire: `[COM event from Prompt 1]`
- Map alignment result fields to `AlignmentPayload`

### 3.6 `CleanRefBridge.cs` (real)
- Wire: direct post-operation API call (no COM event needed)
- Expose: `public void NotifyCleanReference(string cameraId, string filePath, bool isValid, string reason)`

### 3.7 `CmmBridge.cs` (real)
- Wire: `CmmServiceNotifierProxy` WCF duplex callback on port `8032`
- Handle: ticket-opened, export-started, export-complete, export-error

### 3.8 `DieEditBridge.cs` (real)
- Wire: `[COM event / file watcher from Prompt 1]`
- Map die coordinates and edit type to `DieEditPayload`

---

## Phase 4 — Integration into Falcon.Net (state shell owner)

### 4.1 Bootstrapper / Composition Root
Show exactly where in `Falcon.Net` startup/composition root the state engine is wired up:

```csharp
// In Falcon.Net startup / composition root
var syncContext = SynchronizationContext.Current;  // capture UI/STA context if available

var eventAgg = new AoiEventAggregator(syncContext);

var bridges = new List<IAoiStateBridge>
{
    new ScanStateBridge(eventAgg, logger),
    new RobotStateBridge(eventAgg, logger),
    new CameraLightBridge(eventAgg, logger),
    new JobStateBridge(eventAgg, logger),
    new AlignmentBridge(eventAgg, logger),
    new CleanRefBridge(eventAgg, logger),
    new CmmBridge(eventAgg, logger, cmmProxy),
    new DieEditBridge(eventAgg, logger),
};

var orchestrator = new AoiStateBridgeOrchestrator(bridges, logger);
orchestrator.Start();

// In AOI_Main adapter — consume state only
_eventAgg.Subscribe<ScanStateChangedEvent>(evt =>
{
    _logger.Info($"Scan state: {evt.Payload.Status} — wafer {evt.Payload.WaferId}");
}, AoiThreadOption.BackgroundThread);
```

Generate the complete bootstrapper code with `using` directives.

### 4.2 Logging Integration
All bridges and the aggregator use `log4net` (already in BIS / DataServer):
- Bridge `Start()`/`Stop()` — log at INFO
- Bridge event receive — log at DEBUG with payload `ToString()`
- Subscriber exception — log at ERROR with stack trace
- Sequence gap detected — log at WARN

Show the logger setup: named loggers (`LogManager.GetLogger(typeof(ScanStateBridge))`).

### 4.3 Cleanup / Shutdown
```csharp
// In Falcon.Net teardown
orchestrator.Dispose();  // stops all bridges, releases COM event handlers
// No dangling COM references, no ThreadPool orphans
```

---

## Phase 5 — End-to-End Smoke Test

Generate a complete NUnit test class `AoiStateEngineIntegrationTest.cs` that:

1. Creates `AoiEventAggregator` with a test `SynchronizationContext`
2. Creates all stub bridges
3. Starts the orchestrator
4. For each of the 8 domains:
   - Calls `bridge.SimulateEvent(testPayload)`
   - Asserts event is received within 200ms (use `ManualResetEventSlim`)
   - Asserts `GetCurrentState()` returns the correct payload
   - Asserts `SequenceNo` is monotonically increasing
5. Stops the orchestrator
6. Verifies no further events are delivered after stop

This test requires **no hardware**, **no COM servers**, **no WCF services**.

---

## Delivery Checklist

Before marking this prompt complete, verify:

- [ ] All 8 payload types compile on .NET Framework 4.8 (`net48` TFM)
- [ ] `AoiEventAggregator.Publish()` returns in <0.1ms (no blocking operations)
- [ ] All bridges implement `IAoiStateBridge` — `Start()` never throws (catches internally)
- [ ] Disposing a subscription stops handler invocation within one event cycle
- [ ] `GetCurrentState()` always returns a non-null snapshot (uses `AoiStateSnapshot.Empty` as default)
- [ ] All Phase 1 and Phase 2 unit tests pass
- [ ] No `Thread.Sleep`, no `Thread.Join`, no blocking `await` in any bridge's event handler path
- [ ] `log4net` logger created per class (not a static global)
- [ ] Project compiles without warnings on LangVersion `7.3`

---

## Iteration Instructions

Run this prompt in the following sequence:

1. **Phase 0** — confirm project location and references with the team
2. **Phase 1** — generate and run unit tests; do not proceed until all pass
3. **Phase 2** — generate stub bridges; run orchestrator tests; do not proceed until all pass
4. **Phase 3** — one bridge at a time, real hardware integrations, in order of priority:
   - Highest priority: Scan (B1 flow), Job (B1 flow), CMM (B4 flow)
   - Medium: Alignment, Robot, Camera/Lights
   - Lower: Clean Reference, Die Edit
5. **Phase 4** — wire into Falcon.Net entry point; verify AOI_Main consumes state via adapter only
6. **Phase 5** — run integration test suite in CI (headless, stub mode)
