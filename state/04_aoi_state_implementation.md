# Falcon.Net State Shell — Prompt 4: Implementation Plan & Code Generation

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
    - Project references: `Falcon.Net` app dependencies only; AOI_Maim references this state shell as consumer-only

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
>
> **Assembly references required for all bridges** (from `c:\bis\bin\`):
> - `FalconWrapperPS.Interop.dll` — COM PIA, `EmbedInteropTypes=true`
> - `FalconWrapper.NET.dll` — `CFalconExternalControlClass`, `IFalconEvents`, `IFalconGui`
> - `CamtekSystem.dll` — PubSub (`EventKey`, `IEventMessage`, `SubscriberFactory`)
> - `ComSingletonUtils.dll` — COM singleton helpers
>
> **COM registration pattern for all 3 COM callback families:**
> ```csharp
> _externalControl = new CFalconExternalControlClass();
> _externalControl.Init();
> // Then call the appropriate Register method per bridge (see each 3.x section).
> ```
> `CFalconExternalControl` is `DECLARE_CLASSFACTORY_SINGLETON` — all bridges share the same instance.
> `IFalconEvents` GUID: `{407BC9F7-301A-4096-BA88-522531C8BE1D}`.
> COM objects use `threading(both)` — callbacks fire on the MTA COM threadpool thread.
> **Bridge rule:** COM callback methods MUST return immediately — only map + `Publish()`, never block.

---

### 3.1 `ScanStateBridge.cs` (real)

**Source:** COM `IScanManagerCB` via `IFalconEvents.RegisterScanEvent()`  
**Also wires:** `IFalconGuiCB.ManualScanDone()` via `IFalconEvents.RegisterFalconGuiEvent()`  
**COM interface GUIDs:** `IScanManagerCB` = `{7ADB9160-CCD3-4e97-A083-30924C444740}`

Implement `IScanManagerCB` and `IFalconGuiCB` on the bridge class (partial implementation — only the methods needed).

**Event wiring:**

| COM callback | Signature | Maps to |
|---|---|---|
| `IScanManagerCB.OperationStarted` | `(eScanManagerOperation op, IWaferData* pWaferData)` | `ScanStatus.Starting` (alignment ops filtered out — those go to AlignmentBridge) |
| `IScanManagerCB.OperationStarted` | op == `eSMO_ImageGrabbing` | `ScanStatus.ColorGrab` |
| `IScanManagerCB.OperationStarted` | op == `eSMO_2DScan` or `eSMO_3DScan` or `eSMO_Overlay_Scan` | `ScanStatus.Grabbing` |
| `IScanManagerCB.OperationCompleted` | `(eScanManagerOperation op, IWaferData* pWaferData, eCycleCompletionCode code, VARIANT v, VARIANT_BOOL* pAbort)` | `ScanStatus.Complete` (code == Success) or `ScanStatus.Error` (other codes) |
| `IScanManagerCB.OperationCompleted` | code == `Stopped` or `Aborted` | `ScanStatus.Aborting` then `ScanStatus.Idle` |
| `IFalconGuiCB.ManualScanDone` | `()` | `ScanStatus.Complete` |

**Payload population from `IWaferData`:**
- `WaferId` ← `pWaferData.WaferId` (string, null-safe: catch `COMException` and use `null`)
- `LotId` ← `pWaferData.LotId`
- `CompletionCode` ← `code.ToString()` (enum name)
- `StartTimeUtc` ← `DateTime.UtcNow` on `OperationStarted`
- `ElapsedMs` ← `(DateTime.UtcNow - _startTime).TotalMilliseconds` on `OperationCompleted`

**eScanManagerOperation → ScanOperationType mapping** (full enum):
```csharp
private static ScanOperationType MapOperation(eScanManagerOperation op)
{
    switch (op)
    {
        case eScanManagerOperation.eSMO_Alignment:       return ScanOperationType.Alignment;
        case eScanManagerOperation.eSMO_2DScan:           return ScanOperationType.Scan2D;
        case eScanManagerOperation.eSMO_3DScan:           return ScanOperationType.Scan3D;
        case eScanManagerOperation.eSMO_InkMarking:       return ScanOperationType.InkMarking;
        case eScanManagerOperation.eSMO_ImageGrabbing:    return ScanOperationType.ImageGrabbing;
        case eScanManagerOperation.eSMO_Overlay_Scan:     return ScanOperationType.OverlayScan;
        case eScanManagerOperation.eSMO_Layer3D_Scan:     return ScanOperationType.Layer3DScan;
        case eScanManagerOperation.eSMO_AutoFocus:        return ScanOperationType.AutoFocus;
        case eScanManagerOperation.eSMO_WaferMapImport:   return ScanOperationType.WaferMapImport;
        case eScanManagerOperation.eSMO_WaferMapExport:   return ScanOperationType.WaferMapExport;
        case eScanManagerOperation.eSMO_InkDotScan:       return ScanOperationType.InkDotScan;
        default:                                          return ScanOperationType.Other;
    }
}
```

**Registration in `Start()`:**
```csharp
_externalControl = new CFalconExternalControlClass();
_externalControl.Init();
_falconEvents = (IFalconEvents)_externalControl;
_falconEvents.RegisterScanEvent(this);       // IScanManagerCB
_falconEvents.RegisterFalconGuiEvent(this);  // IFalconGuiCB (for ManualScanDone)
```

**Unregistration in `Stop()`:**
```csharp
_falconEvents?.UnRegisterScanEvent(this);
_falconEvents?.UnRegisterFalconGuiEvent(this);
Marshal.ReleaseComObject(_externalControl);
_externalControl = null;
_falconEvents = null;
```

**Thread safety:** Callbacks arrive on COM threadpool thread (MTA). `Publish()` is lock-free — safe to call directly. Store `_startTime` in a `volatile DateTime` field (set on `OperationStarted`, read on `OperationCompleted`).

**Unimplemented `IFalconGuiCB` methods:** Add stub implementations that return immediately for all `IFalconGuiCB` methods not used by this bridge (`JobLoaded`, `Set2dOpticsDone`, etc.) — they are handled by other bridges.

---

### 3.2 `RobotStateBridge.cs` (real)

**Source:** COM `IAutoCycleManagerCB` via `IFalconEvents.RegisterAutoCycleEvent()`  
**COM interface GUID:** `IAutoCycleManagerCB` = `{8DC69B05-313B-4321-A3D2-AB7DA95DA355}`  
**NOT TCP/PizzaServer** — AOI_Main has no TCP connection to `PizzaServer.exe`. Robot state comes exclusively from COM callbacks.

**Event wiring:**

| COM callback | Signature | Maps to |
|---|---|---|
| `IAutoCycleManagerCB.WaferInspectionStarted` | `()` | `RobotStatus.Loading` |
| `IAutoCycleManagerCB.WaferScanResultsAreReady` | `()` | `RobotStatus.Idle` |
| `IAutoCycleManagerCB.StateChanged` | `(eManagerState state)` | Map `eManagerState` → `ManagerState` enum → `RobotStatus` (see table below) |
| `IAutoCycleManagerCB.PeriodicCalibrationCompleted` | `()` | No-op (not a robot state change) |

**`eManagerState` → `RobotStatus` mapping:**
```csharp
private static RobotStatus MapManagerState(eManagerState state)
{
    switch (state)
    {
        case eManagerState.eMS_Idle:          return RobotStatus.Idle;
        case eManagerState.eMS_Executing:     return RobotStatus.Loading;   // general executing
        case eManagerState.eMS_Pausing:
        case eManagerState.eMS_Paused:        return RobotStatus.Idle;
        case eManagerState.eMS_Stopping:
        case eManagerState.eMS_Aborting:      return RobotStatus.Error;
        case eManagerState.eMS_Initializing:  return RobotStatus.Homing;
        default:                              return RobotStatus.Unknown;
    }
}
```

**Payload population:**
- `Status` ← from mapping above
- `AutoCycleState` ← `MapManagerState` converted to `ManagerState` enum (parallel field)
- `HasWaferOnChuck` ← NOT available from this callback — set to `false` (unknown); can be polled separately
- `PortId` ← `-1` (not exposed by `IAutoCycleManagerCB` callbacks — unknown without UI automation)
- `SlotId` ← `-1` (same reason)
- `Timestamp` ← `DateTime.UtcNow`

**Registration in `Start()`:**
```csharp
_externalControl = new CFalconExternalControlClass();
_externalControl.Init();
_falconEvents = (IFalconEvents)_externalControl;
_falconEvents.RegisterAutoCycleEvent(this);   // IAutoCycleManagerCB
```

**Unregistration in `Stop()`:**
```csharp
_falconEvents?.UnRegisterAutoCycleEvent(this);
Marshal.ReleaseComObject(_externalControl);
```

**Thread safety:** Same rule as ScanStateBridge — callback returns immediately. All state writes via `Publish()` only.

---

### 3.3 `CameraLightBridge.cs` (real)

**Primary source:** COM `IFalconGuiCB` via `IFalconEvents.RegisterFalconGuiEvent()`  
**COM interface GUID:** `IFalconGuiCB` = `{BD86796B-D767-44e9-A1B4-428CBD28DE38}`  
**Fallback source:** PubSub `EventKey{ Context=Lcc, SubContext=IllumChannelCalib }` via `CamtekSystem.PubSub.SubscriberFactory`  
**NOT camera driver DLLs** — AOI_Main has no reference to BIS camera driver assemblies.

**Event wiring:**

| Source | Callback / Key | Signature | Maps to |
|---|---|---|---|
| COM `IFalconGuiCB` | `Set2dOpticsDone()` | `()` | `OpticMode = "2D"`, `IsIlluminationError = false` |
| COM `IFalconGuiCB` | `LCCPeriodicCalibAlert(b)` | `(VARIANT_BOOL bAlert)` | `LccCalibAlert = (bAlert != 0)` |
| PubSub (fallback) | `EventKey{ Context=Lcc, SubContext=IllumChannelCalib }` | `IEventMessage msg` | `IsIlluminationError = true` if message indicates error |

**PubSub setup in `Start()`:**
```csharp
// COM primary
_falconEvents.RegisterFalconGuiEvent(this);

// PubSub fallback (may return NullableSubscriber if disabled in system.ini)
var lccKey = new EventKey
{
    Context    = EventContext.Lcc,
    SubContext = EventSubContext.IllumChannelCalib,
    Action     = EventAction.All
};
_lccSubscriber = SubscriberFactory.Create(lccKey);
if (!(_lccSubscriber is NullableSubscriber))
{
    _lccSubscriber.Subscribe(OnLccPubSubEvent);
    _logger.Info("CameraLightBridge: PubSub LCC fallback subscribed.");
}
else
{
    _logger.Info("CameraLightBridge: PubSub disabled — using COM IFalconGuiCB only.");
}
```

**`OnLccPubSubEvent` handler:**
```csharp
private void OnLccPubSubEvent(IEventMessage msg)
{
    // PubSub fires on publisher's thread — use Publish() directly (non-blocking)
    _eventAggregator.Publish(new CameraLightChangedEvent(
        new CameraLightPayload(
            opticMode:           null,   // not known from this event
            isIlluminationError: true,
            lccCalibAlert:       false,
            timestamp:           DateTime.UtcNow,
            errorMessage:        "PubSub LCC illumination calib alert"),
        BridgeName));
}
```

**Unimplemented `IFalconGuiCB` stubs:** All other `IFalconGuiCB` methods (`JobLoaded`, `ManualScanDone`, `FalconGuiLifeCycleChanged`, etc.) — add empty stub implementations that return immediately.

**Unregistration in `Stop()`:**
```csharp
_falconEvents?.UnRegisterFalconGuiEvent(this);
_lccSubscriber?.Unsubscribe();
```

---

### 3.4 `JobStateBridge.cs` (real)

**Source:** COM `IFalconGuiCB` via `IFalconEvents.RegisterFalconGuiEvent()`  
**COM interface GUID:** `IFalconGuiCB` = `{BD86796B-D767-44e9-A1B4-428CBD28DE38}`  
**NOT WCF** — AOI_Main has no `System.ServiceModel` reference. No WCF proxies used here.

**Event wiring:**

| COM callback | Signature | Maps to |
|---|---|---|
| `IFalconGuiCB.JobLoaded` | `(BSTR JobName, BSTR SetupName, BSTR RecipeName, long CompletionCode)` | `JobStatus.Loaded` (CompletionCode == 0) or `JobStatus.Error` (CompletionCode != 0) |
| `IFalconGuiCB.FalconGuiLifeCycleChanged` | `(eFalconGuiLifeCycle lifecycle)` | `lifecycle == eFalconTerminating` → `JobStatus.None` (Falcon shutting down) |

**`JobLoaded` handler:**
```csharp
void IFalconGuiCB.JobLoaded(string jobName, string setupName, string recipeName, long completionCode)
{
    // Return *immediately* — never block the COM apartment thread
    var status  = completionCode == 0 ? JobStatus.Loaded : JobStatus.Error;
    var payload = new JobStatePayload(
        status:         status,
        jobName:        jobName,
        setupName:      setupName,
        recipeName:     recipeName,
        completionCode: completionCode,
        timestamp:      DateTime.UtcNow,
        errorMessage:   completionCode != 0 ? $"Load failed, code={completionCode}" : null);
    _eventAggregator.Publish(new JobStateChangedEvent(payload, BridgeName));
}
```

**`FalconGuiLifeCycleChanged` handler:**
```csharp
void IFalconGuiCB.FalconGuiLifeCycleChanged(eFalconGuiLifeCycle lifecycle)
{
    if (lifecycle == eFalconGuiLifeCycle.eFalconTerminating)
    {
        _eventAggregator.Publish(new JobStateChangedEvent(
            new JobStatePayload(JobStatus.None, null, null, null, 0,
                                DateTime.UtcNow, "Falcon terminating"),
            BridgeName));
    }
}
```

**Registration in `Start()`:**
```csharp
_externalControl = new CFalconExternalControlClass();
_externalControl.Init();
_falconEvents = (IFalconEvents)_externalControl;
_falconEvents.RegisterFalconGuiEvent(this);
```

**Note on shared `IFalconGuiCB` registration:** `ScanStateBridge`, `CameraLightBridge`, and `JobStateBridge` all call `RegisterFalconGuiEvent(this)`.  
COM `CFalconExternalControl` supports multiple sinks — each bridge registers its own sink independently. No conflict.

---

### 3.5 `AlignmentBridge.cs` (real)

**Source:** COM `IScanManagerCB` via `IFalconEvents.RegisterScanEvent()`  
**COM interface GUID:** `IScanManagerCB` = `{7ADB9160-CCD3-4e97-A083-30924C444740}`  
**Shares registration interface with ScanStateBridge** — each registers its own sink.  
**NOT log file parsing** — replaces `FalconLogParser.VerifyAlignmentPassed()` with real COM callbacks.

**Event wiring (only `eSMO_Alignment` operations):**

| COM callback | Condition | Maps to |
|---|---|---|
| `IScanManagerCB.OperationStarted` | `op == eSMO_Alignment` | `AlignmentResult.InProgress` |
| `IScanManagerCB.OperationCompleted` | `op == eSMO_Alignment && code == Success` | `AlignmentResult.Passed` |
| `IScanManagerCB.OperationCompleted` | `op == eSMO_Alignment && code != Success` | `AlignmentResult.Failed` |

All other `eScanManagerOperation` values MUST be ignored in this bridge (handled by `ScanStateBridge`).

**Handler implementation:**
```csharp
void IScanManagerCB.OperationStarted(eScanManagerOperation op, IWaferData pWaferData)
{
    if (op != eScanManagerOperation.eSMO_Alignment) return;  // ignore — ScanStateBridge handles
    _eventAggregator.Publish(new AlignmentChangedEvent(
        new AlignmentPayload(
            result:         AlignmentResult.InProgress,
            waferId:        SafeGetWaferId(pWaferData),
            operationType:  ScanOperationType.Alignment,
            completionCode: null,
            timestamp:      DateTime.UtcNow,
            errorMessage:   null),
        BridgeName));
}

void IScanManagerCB.OperationCompleted(eScanManagerOperation op, IWaferData pWaferData,
    eCycleCompletionCode code, object extraData, ref bool abort)
{
    if (op != eScanManagerOperation.eSMO_Alignment) return;
    var passed  = code == eCycleCompletionCode.eCCC_Success;
    var result  = passed ? AlignmentResult.Passed : AlignmentResult.Failed;
    _eventAggregator.Publish(new AlignmentChangedEvent(
        new AlignmentPayload(
            result:         result,
            waferId:        SafeGetWaferId(pWaferData),
            operationType:  ScanOperationType.Alignment,
            completionCode: code.ToString(),
            timestamp:      DateTime.UtcNow,
            errorMessage:   passed ? null : $"Alignment failed: {code}"),
        BridgeName));
}

private static string SafeGetWaferId(IWaferData wd)
{
    try { return wd?.WaferId; } catch (COMException) { return null; }
}
```

**Registration in `Start()`:**
```csharp
_externalControl = new CFalconExternalControlClass();
_externalControl.Init();
_falconEvents = (IFalconEvents)_externalControl;
_falconEvents.RegisterScanEvent(this);
```

---

### 3.6 `CleanRefBridge.cs` (real)

**Source 1:** Direct API call from `ReferenceCreation` page object (no COM event exists for this domain)  
**Source 2:** `FileSystemWatcher` on the die mapping output folder  
**No COM callbacks available** — confirmed by discovery (no `IAutoCycleManagerCB` or `IFalconGuiCB` event fires for clean reference).

**Public API (called directly from `ReferenceCreation` page object methods):**
```csharp
/// <summary>Called by ReferenceCreation.CleanReferenceSeq() at each phase transition.</summary>
public void NotifyPhaseChange(string phase, int diceCount = 0, string errorMessage = null)
{
    _eventAggregator.Publish(new CleanRefChangedEvent(
        new CleanRefPayload(
            isValid:         errorMessage == null,
            phase:           phase,
            diceCount:       diceCount,
            filesystemEvent: null,
            timestamp:       DateTime.UtcNow,
            errorMessage:    errorMessage),
        BridgeName));
}
```

**Valid `phase` string values** (called from page object at each step):
- `"Creating"` — `ReferenceCreation.cs` Create checkbox enabled, sequence starting
- `"DieMapping"` — die mapping scan started
- `"CleanReference"` — clean reference scan started
- `"Complete"` — `ReferenceGeneration` OK button appeared (success)
- `"Error"` — any error popup detected during sequence

**FileSystemWatcher for die mapping file detection:**

`Start()` wires a `FileSystemWatcher` on the die mapping output folder (configurable path from `TestAutomationConfig`; default: same folder as ReferenceCreation watches today in the page object).

```csharp
_watcher = new FileSystemWatcher(_dieMappingFolderPath, "*.dm")
{
    NotifyFilter = NotifyFilters.FileName,
    EnableRaisingEvents = true
};
_watcher.Created += OnDieMappingFileCreated;
```

```csharp
private void OnDieMappingFileCreated(object sender, FileSystemEventArgs e)
{
    // FileSystemWatcher fires on threadpool thread — safe to Publish() directly
    _eventAggregator.Publish(new CleanRefChangedEvent(
        new CleanRefPayload(
            isValid:         true,
            phase:           "DieMapping",
            diceCount:       0,
            filesystemEvent: e.FullPath,
            timestamp:       DateTime.UtcNow,
            errorMessage:    null),
        BridgeName));
}
```

**`Start()` / `Stop()`:** `Start()` initialises the watcher. `Stop()` sets `EnableRaisingEvents = false` and disposes the watcher. No COM registration needed.

---

### 3.7 `CmmBridge.cs` (real)

**Source:** COM `IAutoCycleManagerCB` via `IFalconEvents.RegisterAutoCycleEvent()`  
**COM interface GUID:** `IAutoCycleManagerCB` = `{8DC69B05-313B-4321-A3D2-AB7DA95DA355}`  
**NOT WCF** — AOI_Main has no `System.ServiceModel` reference. `CmmServiceNotifierProxy` is a DataServer component, not available here. CMM state comes from `IAutoCycleManagerCB` COM callbacks.

**Event wiring:**

| COM callback | Signature | Maps to |
|---|---|---|
| `IAutoCycleManagerCB.CmmImport` | `()` | `CmmPhase.Importing`, `OperationType = "CmmImport"` |
| `IAutoCycleManagerCB.CmmImportCompleted` | `(eCycleCompletionCode code)` | `CmmPhase.Done` (code == Success) or `CmmPhase.Error` (other) |
| `IAutoCycleManagerCB.CmmUpdateCompleted` | `(eCycleCompletionCode code)` | `CmmPhase.Done` (code == Success) or `CmmPhase.Error` (other), `OperationType = "CmmUpdate"` |

**Handler implementations:**
```csharp
void IAutoCycleManagerCB.CmmImport()
{
    _eventAggregator.Publish(new CmmStateChangedEvent(
        new CmmStatePayload(CmmPhase.Importing, "CmmImport", null,
                            DateTime.UtcNow, null), BridgeName));
}

void IAutoCycleManagerCB.CmmImportCompleted(eCycleCompletionCode code)
{
    var ok = code == eCycleCompletionCode.eCCC_Success;
    _eventAggregator.Publish(new CmmStateChangedEvent(
        new CmmStatePayload(
            phase:          ok ? CmmPhase.Done : CmmPhase.Error,
            operationType:  "CmmImport",
            completionCode: code.ToString(),
            timestamp:      DateTime.UtcNow,
            errorMessage:   ok ? null : $"CMM import failed: {code}"),
        BridgeName));
}

void IAutoCycleManagerCB.CmmUpdateCompleted(eCycleCompletionCode code)
{
    var ok = code == eCycleCompletionCode.eCCC_Success;
    _eventAggregator.Publish(new CmmStateChangedEvent(
        new CmmStatePayload(
            phase:          ok ? CmmPhase.Done : CmmPhase.Error,
            operationType:  "CmmUpdate",
            completionCode: code.ToString(),
            timestamp:      DateTime.UtcNow,
            errorMessage:   ok ? null : $"CMM update failed: {code}"),
        BridgeName));
}
```

**Shares `RegisterAutoCycleEvent` with `RobotStateBridge`** — each registers its own sink; COM supports multiple sinks per callback family.

**`WaferInspectionStarted` / `WaferScanResultsAreReady` / `StateChanged` / `PeriodicCalibrationCompleted`:** Add empty stub implementations (handled by `RobotStateBridge`).

**Registration / unregistration:** Same pattern as `RobotStateBridge` (see 3.2).

---

### 3.8 `DieEditBridge.cs` (real)

**Source:** Direct API call from `DieEditMain` page object  
**No COM event available** — confirmed by discovery. `DieEdit.sln` is a separate BIS solution with no COM event interface. AOI_Main drives die edit exclusively via FlaUI UI automation (`DieEditMain`, `LayersSection`, `Layer`).

**Public API (called directly from `DieEditMain` page object after each user action):**

```csharp
/// <summary>
/// Called by DieEditMain after a layer action completes.
/// </summary>
/// <param name="editType">The type of die edit operation.</param>
/// <param name="layerIndex">Zero-based layer index from LayersSection.GetLayer(index). -1 if unknown.</param>
/// <param name="layerName">Layer label text from the tree item. Null if not available.</param>
/// <param name="isSaved">True after DieEditMain.ClickSave() completes successfully.</param>
public void NotifyDieEdit(DieEditType editType, int layerIndex, string layerName, bool isSaved)
{
    _eventAggregator.Publish(new DieEditChangedEvent(
        new DieEditPayload(
            editType:    editType,
            layerIndex:  layerIndex,
            layerName:   layerName,
            isSaved:     isSaved,
            timestamp:   DateTime.UtcNow,
            errorMessage: null),
        BridgeName));
}

/// <summary>Called by DieEditMain when a die edit error popup is detected.</summary>
public void NotifyDieEditError(string errorMessage)
{
    _eventAggregator.Publish(new DieEditChangedEvent(
        new DieEditPayload(
            editType:    DieEditType.Unknown,
            layerIndex:  -1,
            layerName:   null,
            isSaved:     false,
            timestamp:   DateTime.UtcNow,
            errorMessage: errorMessage),
        BridgeName));
}
```

**Call sites in `DieEditMain` page object** (add these after each existing UI action):

| Existing `DieEditMain` method | `NotifyDieEdit` call to add |
|---|---|
| After `Layer.CBtn.Click()` | `_dieEditBridge.NotifyDieEdit(DieEditType.Reclassify, layer.Index, layer.Name, false)` |
| After `Layer.RDLBtn.Click()` | `_dieEditBridge.NotifyDieEdit(DieEditType.LayerEdit, layer.Index, layer.Name, false)` |
| After `DieEditMain.ClickSave()` succeeds | `_dieEditBridge.NotifyDieEdit(DieEditType.Unknown, -1, null, true)` |
| On error popup detection | `_dieEditBridge.NotifyDieEditError(popupText)` |

**`Start()` / `Stop()`:** No-op — no COM registration or file watchers. Bridge is always "active" once constructed. `Stop()` logs shutdown only.

---

## Phase 3.9 — Callback Ownership Transfer (MANDATORY)

Implement the ownership move to `Falcon.Net` explicitly:

1. **Move COM callback registration owner to Falcon.Net state shell host**
    - `RegisterScanEvent` owner: Falcon.Net state shell host
    - `RegisterAutoCycleEvent` owner: Falcon.Net state shell host
    - `RegisterFalconGuiEvent` owner: Falcon.Net state shell host

2. **Move bridge lifecycle to Falcon.Net**
    - `AoiStateBridgeOrchestrator.Start()`/`Stop()` run inside Falcon.Net process lifecycle
    - AOI_Main no longer creates COM sinks directly

3. **Keep AOI_Main as consumer only**
    - AOI_Main can subscribe/query state via adapter API
    - AOI_Main must not call `Register*Event()` directly after migration

4. **Deliver two explicit artifacts**
    - `MoveMap.md` section in output: what moved vs what stayed
    - `CallbackOwnershipTable` section with exact owner classes and registration points

---

## Phase 4 — Integration into Falcon.Net (state shell owner)

### 4.1 Bootstrapper / Composition Root
Show exactly where in `Falcon.Net` startup/composition root the state shell is wired up:

```csharp
// In Falcon.Net startup/composition root
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

// In AOI_Main/TestAutomation adapter — consume state only
_stateShellClient.Subscribe<ScanStateChangedEvent>(evt =>
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
