# Structured Findings — Falcon.Net / AOI_Main Deep Analysis

> **Date:** 2026-04-05  
> **Scope:** `BIS/Sources/apps/Falcon.Net/` (producer side, COM callback owner candidate)  
> **Status:** Facts only — no proposals

---

## Section 1 — AOI_Main + Falcon.Net Structure

### 1.1 Entry Point

- **Executable:** `AOI_Main.exe` (assembly product name per `AssemblyInfo.cs`)
- **Entry method:** `Falcon.Net.Program.Main()` in `BIS/Sources/apps/Falcon.Net/Program.cs`
- **Attribute:** `[STAThread]` — runs on STA COM apartment
- **Framework:** .NET Framework 4.8 (`app.config` → `<supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/>`)
- **Bootstrap sequence:**
  1. `Application.EnableVisualStyles()` + `SetCompatibleTextRenderingDefault(false)`
  2. Capture `Dispatcher.CurrentDispatcher` (WPF dispatcher on STA thread)
  3. Install low-level keyboard hook (global hotkeys)
  4. `Application.Run(new clsInitAOI())` — WinForms message loop with `ApplicationContext`

### 1.2 Top-Level Orchestrator Class

**`MainContext`** — singleton in `BIS/Sources/apps/Falcon.Net/MainContext/MainContextModule.cs` (5701 lines)

- **Pattern:** Thread-safe double-checked locking singleton (`MainContext.Instance`)
- **Implements:** `IMainContextModule` (interface in `IMainContextModule.cs`, ~170+ properties, ~130+ methods)

**Key public members (abridged — exhaustive list gathered):**

| Category | Members |
|---|---|
| **Sub-systems** | `Modules : IMainModules`, `Forms : IForms`, `UIEvents : IUIEvents` |
| **Hardware** | `GHardwareObj : IMachineObj`, `Table : IXYTableBase`, `MotionService : IMachineMotionService`, `gCtsCamera : ICTSCamera` |
| **Job/Setup** | `ScenJobData : CSetupData`, `SetupData : ISetupData`, `WaferGeometry : IWaferGeometry`, `WaferType : IWaferType`, `ScenJobSelectMgr : IJobSelectManager` |
| **Scan state** | `ScanResult : eScanManagerScanStatus`, `ScanDone : bool`, `PhysicalScanDone : bool`, `IsGrab : bool`, `Break : bool` |
| **Automation** | `RobotUI : IRobotUIConnector`, `InProductionMode : bool`, `InWaferByWaferScan : bool`, `CycleCompleted : bool`, `gCompletionCode : eCycleCompletionCode` |
| **Wafer** | `GetScanWafer : IAutomationWafer`, `Wafer2Display : clsWaferToDisplay`, `DispDies : clsDies`, `WaferSift : SWaferShift` |
| **Mode flags** | `VVRMode : bool`, `SimMode : bool`, `CmmMode : bool`, `IsHw : bool`, `OfflineViewer : bool`, `IsCTS : bool`, `IsStil : bool`, `IsCLIP : bool`, `mIsCSP : bool` |
| **Optics** | `PixelSizeX/Y : float`, `JobPixelsize : double`, `CameraChanged : bool`, `LastCam : eCAMERA_TYPE` |
| **CMM** | `mCMM : clsCMM` |
| **Login** | `LoginUser : IExtendUser`, `InLogIn : bool` |
| **Calibration** | `clsCalibrationManager`, `m_PeriodicCalib : clsPeriodicCalib` |
| **Logging** | `gWaferProcessingLogger`, `gWaferScanLogger`, `gWaferAlignmentLogger : ITimingLogger` |
| **COM interop** | `CFileUtils : IFileUtils`, `CSystem : ICSystem`, `CForms : IForms` (via CamtekUtils COM) |

### 1.3 Launch Mode

- **Standalone WinForms application.** `Application.Run(new clsInitAOI())` with `clsInitAOI : ApplicationContext`.
- Process singleton enforced via `Process.GetProcessesByName()` check.
- Can receive command-line arg `"production"` → `bInAutomaticProductionMode = true` (skips login).
- Debug attach backdoor: if `c:\bis\AOI_Debug` file exists → `Debugger.Launch()`.

### 1.4 Dependencies

**COM servers (out-of-proc or in-proc):**
- `CamtekUtils.CamtekUtilsConnector` → `ICamtekUtilsWrapper` (CFileUtils, CSystem, CForms)
- `InspectionMngServiceConnector` → `IInspectionMng`, `ISPCDB`
- `WafersDatabase.WafersDBConnector` → `IWafersDB`
- `ScenarioManager.CScanManager` (scan orchestration — COM)
- `FalconWrapper.CFalconEvents` (ATL C++ singleton COM coclass) → `IFalconFireEvents`
- `FalconWrapper.CFalconExternalControl` → `IFalconExternalControl`
- `EfemSrv.IAutoLoader` (EFEM/robot COM server)
- `WaferHandlingManagerConnector.Instance.AutomationManager` (wafer handling automation COM)
- `AutomationBatchExecuterConnector` (batch execution COM)
- `RobotUIControls.IRobotUIConnector` (robot UI COM)
- `ToolManager` COM interfaces
- `Machine.NET` / `MachineDataTypesLib` COM interop

**Managed DLLs (from `c:\bis\bin\` and project references):**
- `FalconWrapperPS.Interop` (COM interop assembly)
- `CMM.Net.Api.dll`, `Cmm.Net.Infrastructure`
- `CamtekSystem` (PubSub, AsyncTask, Callback)
- `ScenarioManager`
- `DataAccess.DataLayer`
- `Job`, `JobParts.Base.Recipes`
- `AutomationManager.AutomationAPI`
- `WaferMap.Net`
- `System.Hardware.Cameras.Common`, `System.Hardware.Cameras.CameraTDI.Common`
- `MachineDataTypesLib`
- `EfemSrvUserTypes`, `EfemSecsInterfaces`
- `HWNotifications.Net`
- `Camtek.UI.Common.Base`, `Camtek.WaferInfo`
- `FalconExtender.Presentations`
- `Camtek.Hardware.CameraPanelControl`
- `Microsoft.Practices.Unity`, `Microsoft.Practices.Prism.PubSubEvents`
- `log4net`

**gRPC:**
- CMM receiver server on `localhost:50055` (`CmmReceiverServer` in `clsCMM.cs`)

### 1.5 State Model

AOI_Main does **not** have a single unified state model. State is scattered across:

**Enums defined inside `MainContext`:**
```csharp
public enum eMoveTo { eRefreshImage=-1, eNextDefect=0, ePrevDefect=1, eNextDie=2, ePrevDie=3, eNextFrame=4, ePrevFrame=5, eImageEnhance=9 }
public enum eOperatorAssistResult { eOperatorAssistResultUnknownField, eOperatorAssistNotSucceeded, eOperatorAssistAllowToProceedWithWafer }
public enum eSetMapScanAreaResult { Error=-1, MatchingFailed=-2, Ok=0 }
public struct tRecipeConditionStatus { public short recipeIndex; public bool Pass; }
```

**Scan mode constants in `MainContext`:**
```csharp
public const int gScanMode_2D = 0;
public const int gScanMode_3D = 1;
public const int gScanMode_Ink = 2;
public const int gScanMode_Bsi = 3;
public const int gScanMode_TNE = 4;
public const int gScanMode_EBR = 5;
public const int gScanMode_Macro = 6;
public const int gScanMode_DynamicEBR = 7;
public const int gScanMode_SamplingMetrology = 8;
public const int gScanMode_Ebi = 9;
public const int gScanMode_Csp = 10;
public const int gScanMode_BsiHR = 11;
public const int gScanMode_TSVI = 12;
public const int gScanMode_Overlay = 13;
```

**External enums used as state:**
- `ScenarioManager.eScanManagerScanStatus` — `Successful`, `Fail`, `CompleteWithQuotaExeeded`
- `ScenarioManager.eScanProgressStatus` — `eSPS_ReScanAQL`, `eSPS_PhysicalScanDone`
- `FalconWrapper.eScanManagerOperation` — 18 values (WaferMapImport, Alignment, Scan, WaferMapExport, etc.)
- `FalconWrapper.eFalconGuiLifeCycle` — `eFalconDown=0, eFalconInitializing=1, eFalconWorking=2, eFalconTerminating=3`
- `AutomationManager.eManagerState` — `eMS_Idle`, etc.
- `MachineDataTypesLib.eCAMERA_TYPE` — `HIGH_MAG_CAMERA`, `VERYHIGH_MAG_CAMERA`, `TDI_CAMERA`, `IR_SCAN_CAMERA`, `NO_CAMERA`

**Boolean flags as implicit state:**
```
gWaitForScanDone, gWaitForGrabbingDone, gWaitForBatchCompletion,
m_InOperatorAssistMode, mPhysicalScanDone, mCycleCompleted,
mDBGAutoCycleWithAL, mIsAutoLoader, mIsMarker, mScenStatus,
mInProductionMode, mMachineSimulatorMode, InMultiJobScan,
RefChanged, InRecipeChange, InWaferByWaferScan, InVerification,
InSetupTabCreateReference, CameraChanged, InLogIn, IsGrab,
Break, gDisableGUI, IsPreAligner, WasUnloadWaferStarted, ScanDone
```

### 1.6 Falcon Wrapper Callback Registration & Lifecycle

**Callback firing owner: `frmProduction`** in `BIS/Sources/apps/Falcon.Net/Forms/frmProduction.cs`

- **Field:** `private IFalconFireEvents mFalconFireEvents;`
- **Initialization:** In `FalconIsStartingUp()` (called during `clsInitAOI.InitAOI()`):
  ```csharp
  Task.Run(() => {
      // Created on MTA thread
      mFalconFireEvents = (IFalconFireEvents)new CFalconEvents();
  }).Wait();
  ```
- **`CFalconEvents`** is an ATL C++ COM singleton (declared in `BIS/Sources/ToolManagement/FalconWrapper/FalconEvents.h`).
- It implements both **`IFalconEvents`** (registration side) and **`IFalconFireEvents`** (firing side).
- **`frmProduction`** exposes: `public IFalconFireEvents FalconFireEvents => mFalconFireEvents;`
- **`clsFalconPresentation`** accesses it via: `public FalconWrapper.IFalconFireEvents FalconFireEvnt => MainContext.Instance.Forms.frmProduction.FalconFireEvents;`

**Registration API (for external subscribers):** defined in `IFalconEvents`:
```cpp
HRESULT RegisterAutoCycleEvent(eAutoCycleManagerEvent Id, BSTR Name, IAutoCycleManagerCB* pEventsHandler);
HRESULT UnRegisterAutoCycleEvent(eAutoCycleManagerEvent Id, IAutoCycleManagerCB* pEventsHandler);
HRESULT RegisterScanEvent(eScanManagerEvent Id, BSTR Name, IScanManagerCB* pEventsHandler);
HRESULT UnRegisterScanEvent(eScanManagerEvent Id, IScanManagerCB* pEventsHandler);
HRESULT RegisterFalconGuiEvent(eFalconGuiEvent Id, BSTR Name, IFalconGuiCB* pEventsHandler);
HRESULT UnRegisterFalconGuiEvent(eFalconGuiEvent Id, IFalconGuiCB* pEventsHandler);
```

**Lifecycle:**
1. `clsInitAOI.InitAOI()` → `frmProduction.FalconIsStartingUp()` → creates `CFalconEvents` on MTA thread
2. During operation: `frmProduction.Fire*()` methods call `mFalconFireEvents.*()` wrapped in `NonBlockingUITask.Execute`
3. Shutdown: `frmProduction.Terminate()` → fires `eFalconTerminating`, sets `mFalconFireEvents = null`

### 1.7 Callback Sink Ownership

| Callback Family | Interface | Ownership |
|---|---|---|
| `IAutoCycleManagerCB` | Auto-cycle events (wafer results ready, CMM import, periodic calib, etc.) | **External subscribers only** — SecsGemClient, NetTAC, TAC.Net implement this. Falcon.Net fires via `IFalconFireEvents`. |
| `IScanManagerCB` | Scan operation started/completed | **External subscribers only** — SecsGemClient (E30/E116), NetTAC implement this. Falcon.Net fires via `IFalconFireEvents`. |
| `IFalconGuiCB` | GUI lifecycle, job loaded, user login, manual mode | **External subscribers only** — ProductionGui.NET, SecsGemGui.Net, TAC.Net, TopiClient implement this. Falcon.Net fires via `IFalconFireEvents`. |

**Falcon.Net is purely the event SOURCE (producer).** It never implements or subscribes to `IAutoCycleManagerCB`, `IScanManagerCB`, or `IFalconGuiCB`. These are sink interfaces for external tools.

Additionally, **`ExternalControlCbUiWrapper`** in Falcon.Net implements `IFalconExternalControlCB` (a *different* callback — for external control commands INTO Falcon, not outward events). It registers via `mExternalControl.RegisterEvent(eFEE_AllFalconEvents, ...)`.

**`ScanManagerWrapper`** implements `ScenarioManager.IScanManagerInkingCB` (internal ScenarioManager callback, not the FalconWrapper version). Registered via `mScenScanMgr.RegisterEvent(eSCMEI_AllScanManagerEvents, "Falcon", this)`.

---

## Section 2 — The 8 State Domains

---

### 2.1 Scan / Grab / Color Grabbing

- **Current mechanism:** COM event subscription + .NET delegate events from `ScenarioManager.CScanManager`
- **Owner class/interface:** 
  - `ScenarioManager.CScanManager` — COM server that orchestrates scan operations
  - `ScanManagerWrapper` (`BIS/Sources/apps/Falcon.Net/CommonUtils/ComServerWrappers/ScanManagerWrapper.cs`) — .NET wrapper around COM scan manager
  - `frmMain` subscribes to `ScanManagerWrapper` events
  - `frmScanTab` publishes PubSub `EventMessage(EventContext.Scan, ...)` after scan completion
- **Data model:**
  - `eScanManagerScanStatus` — `{Successful, Fail, CompleteWithQuotaExeeded}`
  - `eScanProgressStatus` — `{eSPS_ReScanAQL, eSPS_PhysicalScanDone}`
  - `eScanManagerOperation` — 18 values (WaferMapImport=0 .. AllScanManagerOperation=17)
  - `MainContext.ScanResult : eScanManagerScanStatus`
  - `MainContext.ScanDone : bool`, `MainContext.PhysicalScanDone : bool`
  - `MainContext.IsGrab : bool`, `MainContext.gWaitForScanDone : bool`, `MainContext.gWaitForGrabbingDone : bool`
  - Scan mode constants: `gScanMode_2D` through `gScanMode_Overlay` (14 modes)
  - `IWaferData` — wafer ID, lot ID, result path, completion code
  - `sConnectionStatus` — pizza server connection (IP, port, connected)
- **Async/sync:** 
  - `ScanManagerWrapper` receives COM callbacks on unknown thread, marshals to UI via `dispatcher.BeginInvoke` (async)
  - `GetInkingParams` uses `dispatcher.Invoke` (sync — potential deadlock noted in code comment)
  - PubSub events are async (`PublishAsync`)
- **Existing events:**
  - `ScanManagerWrapper.OnScanDone : Action<eScanManagerScanStatus>`
  - `ScanManagerWrapper.OnScanProgressChange : Action<eScanProgressStatus>`
  - `ScanManagerWrapper.OnPizzasConnectionStatus : Action<List<sConnectionStatus>>`
  - `ScanManagerWrapper.OnCopyJobFilesIntoScanResult : Action<string,string>`
  - `ScanManagerWrapper.OnGetInkingParams` (delegate with ref params)
  - `UIEvents.PhysicalScanDone` (.NET event)
  - `UIEvents.ScanModeChanged` (.NET event)
  - `frmProduction.FireOperationStarted/Completed` (COM outward)
  - `frmProduction.FireManualScanDone` (COM outward)
  - `frmProduction.FireWaferScanResultsAreReady` (COM outward)
  - `frmProduction.FireWaferInspectionStarted` (COM outward)
  - PubSub: `EventMessage(EventContext.Scan, EventSubContext.Execution, EventAction.Finished)`
- **Threading notes:** COM callbacks from `CScanManager` arrive on MTA threads; `ScanManagerWrapper` marshals them to UI thread via `Dispatcher.BeginInvoke`. Sync callback `GetInkingParams` uses `Dispatcher.Invoke` (blocking).
- **Gaps / unknowns:** 
  - No scan ID or scan progress percentage field found — progress is event-based (`eScanProgressStatus`)
  - Color vs mono distinction not observable as state — it's a scan mode constant
  - `DdsSrv_d.exe`, `AcqIPC`, `DdsIPC`, `GrabIPC` are used by the hardware pipeline, not directly by `AOI_Main` — they operate as lower-level services

---

### 2.2 Robot Setup

- **Current mechanism:** COM interface (`EfemSrv.IAutoLoader`) + .NET delegate events via `RobotUIEventHandlerWrapper` and `AutoLoaderUIWrapper`
- **Owner class/interface:**
  - `EFEMModule` (`BIS/Sources/apps/Falcon.Net/Modules/EFEMModule.cs`) — facade to `EfemSrv.IAutoLoader`, `IPreAligner`
  - `RobotUIEventHandlerWrapper` (`BIS/Sources/apps/Falcon.Net/CommonUtils/ComServerWrappers/RobotUIEventHandlerWrapper.cs`, 1666 lines) — implements `IRobotUIConnector` + `IRobotUIConnectorCB`, 40+ event delegates
  - `AutoLoaderUIWrapper` — wraps `IAutoLoader` UI events
  - `Automation` module — wraps `WaferHandlingManagerConnector` and `AutomationBatchExecuterConnector`
- **Data model:**
  - `IRobotUIConnector` properties: `InAutoCycle : bool`
  - `eManagerState` — `eMS_Idle`, etc.
  - `eALStations` — station identifiers (BSI, EBI, BSIHR, TSVI)
  - `sALStation` — active autoloader station
  - `eWaferHandlingType`, `SideUp`, `eFLAT_POS` — wafer orientation
  - `eCassetteSize`, `eALStations` — load port types
  - `sConnectionStatus` — pizza server connection state
  - `EfemOperationResult` — result of EFEM operations
  - Wafer ID, Lot ID (string)
- **Async/sync:** 
  - All `Automation` module methods use `NonBlockingUITask.Execute` (offloads to MTA, polls with `Application.DoEvents()`)
  - `RobotUIEventHandlerWrapper` callbacks are invoked directly (appear to be on caller's thread, wrapped in `CallbackMonitor`/`CallMonitor`)
- **Existing events (40+ delegates in `RobotUIEventHandlerWrapper`):**
  - `OnWaferIdChange`, `OnLotChange`
  - `OnManualCassetteMappingRequest`
  - `OnAutoCycleExportWaferMaps`, `OnExportWaferMap`
  - `OnSetInProductionMode`, `OnProductionStarted`
  - `OnToolStateChange`, `OnSetBreak`
  - `OnAutoCycleStart`, `OnBatchCompleted`, `OnUserBatchCompleted`
  - `OnCalibratePeriodic`, `OnPeriodicCalibrationCompleted`
  - `OnSystemValidRequest`
  - `OnManualWaferMovementStarted`
  - `OnLoadJobRequest`
  - `OnWaferOrientationSettingChanged`
  - `OnGetChuckCenterForCamera`
  - `OnRobotUIVisiblityChanged`
  - `OnEnableAutoloaderScreenButton`
  - And 20+ more
- **Threading notes:** Callbacks arrive through COM (likely MTA). `CallbackMonitor`/`CallMonitor` RAII wrappers for diagnostics. No explicit UI marshaling; the wrappers appear to fire events on the calling thread.
- **Gaps / unknowns:**
  - Robot states (idle, loading, unloading, error, homing) are not exposed as a single enum in AOI_Main — they are managed internally by `EfemSrv` COM server
  - E84 driver is in `BIS/Sources/machine/E84Driver/` — not directly referenced from Falcon.Net

---

### 2.3 Camera & Lights / Illumination Change

- **Current mechanism:** Direct method calls into COM hardware objects via `OpticModule`, `CamerasModule`
- **Owner class/interface:**
  - `OpticModule` (`BIS/Sources/apps/Falcon.Net/Modules/OpticModule.cs`, 1197 lines) — manages optic roles, camera activation
  - `CamerasModule` (`BIS/Sources/apps/Falcon.Net/Modules/CamerasModule.cs`) — camera hardware queries
  - `MultipleLightChannelsFunctions` — multi-recipe light channel orchestration
  - `modCamerasButtons` — toolbar camera button mapping
  - `clsJobIlluminationValidity` — validates illumination for a job
- **Data model:**
  - `eCAMERA_TYPE` — `{HIGH_MAG_CAMERA, VERYHIGH_MAG_CAMERA, TDI_CAMERA, IR_SCAN_CAMERA, NO_CAMERA}`
  - `IOptics` — optic role (camera + magnification + settings)
  - `sXYCalibration` — pixel size, calibration data per magnification
  - `MainContext.LastCam : eCAMERA_TYPE`
  - `MainContext.CameraChanged : bool`
  - `MainContext.PixelSizeX/Y : float`, `JobPixelsize : double`
  - `OpticModule.ActivLiveCameraRole : IOptics`
  - Illumination: accessed via `areaCamera.get_Illumination(lightType, LCCVersion)` → `ActualGrayLevel`, `MinGrayLevel`, `MaxGrayLevel`
  - `FPOINT` — camera size
  - `eZOOM_RING_TYPE` — zoom ring enumeration
- **Async/sync:** Synchronous. `SetToMachine` / `TurnCameraOn` are blocking calls to hardware COM.
- **Existing events:**
  - `OpticModule.OpticsChanged : Action<IOptics>` — fires when active optics change
  - `UIEvents.CCSFormClosed` — CCS (3D camera) form closed event
- **Threading notes:** Hardware COM calls are synchronous and expected to be on UI/STA thread. `SetToMachine` goes through `GetOpticsService().SetActiveOpticsAdvance()`.
- **Gaps / unknowns:**
  - No push notification when illumination settings change externally — current model is poll/query
  - 17 camera types documented in system.md — only 5 values in `eCAMERA_TYPE` enum are directly referenced in AOI_Main. Additional camera types may be managed by lower-level drivers.

---

### 2.4 Job Created / Deleted

- **Current mechanism:** .NET delegate events via `UIEvents` + file-system based job/recipe persistence + COM `IFalconFireEvents.JobLoaded`
- **Owner class/interface:**
  - `RecipeModelManager` (`BIS/Sources/apps/Falcon.Net/Modules/RecipeModelManager.cs`, 1423 lines) — recipe UI model, template management
  - `clsUpdateJob` (`BIS/Sources/apps/Falcon.Net/Classes/clsUpdateJob.cs`, 805 lines) — job update orchestration
  - `CSetupData` / `ISetupData` — main job/setup data container (ScenarioManager COM)
  - `ISetupInfo` — setup info metadata
  - Job files on disk at `c:\job\` path hierarchy
  - `IJobSelectManager` (`MainContext.ScenJobSelectMgr`) — job selection manager (ScenarioManager COM)
  - `clsMultiRecipe` — multi-recipe management
- **Data model:**
  - `CSetupData` — `WaferGeometry`, `WaferMapRecipe`, `AutoCycleInfo`, `ProductionInfo`, `WaferTypeInfo`, `RecipeParts[]`
  - `RecipeModel` — `AutoFocusEvery`, `CleanReferenceEvery`, `UnloadToAnotherCassette`, `ApplyAQLRules`, `AllowScanWithoutDetection`, `WaferDefectsCount`, `WaferDefectDiceRatio`, `BatchPassCriteria`
  - Job path: string
  - Setup name: string
  - Recipe name: string
  - `eSETUP_DATA_TYPES` — flags enum: `eSETUP_OPTICS_PRESET_DATA`, `eSETUP_ALIGMENT`, `eSETUP_CLEAN_REF_DATA`, etc.
- **Async/sync:** Synchronous job load/save. `RecipeModelManager.Reload()` is sync.
- **Existing events:**
  - `UIEvents.JobLoadingStarted : VoidEventHandler`
  - `UIEvents.RecipeAdded : RecipeAddedEventHandler(bool, string, bool, bool, bool, bool, int, int)`
  - `UIEvents.RecipeDeleted : RecipeDeletedEventHandler(string)`
  - `UIEvents.RecipesLoaded : VoidEventHandler`
  - `UIEvents.SetupInfoLoaded : SetupInfoLoadedEventHandler(ref ISetupInfo, bool)`
  - `UIEvents.MultiRecipeFormSaved : VoidEventHandler`
  - `UIEvents.MultiRecipeFileDeleted : VoidEventHandler`
  - `RecipeModelManager.RecipeFormCloseRequested : Action`
  - `RecipeModelManager.OnNewTemplateAdded : Action<string>`
  - `frmProduction.FireJobLoaded()` → COM `IFalconFireEvents.JobLoaded(jobName, setupName, recipeName, completionCode)`
- **Threading notes:** Job operations are UI-thread synchronous.
- **Gaps / unknowns:**
  - No gRPC / RMS port 5001 references found in Falcon.Net — job management is fully COM/file-based
  - No job-deleted event at the COM level — only `UIEvents.RecipeDeleted` is internal .NET
  - `RecipeModelManager` uses `MainContext.Instance.mCMM.CMMServiceRawClient` to create `RecipeModel` — indirect CMM dependency

---

### 2.5 Alignment Modification

- **Current mechanism:** Direct method calls + COM operations. No push event when alignment changes.
- **Owner class/interface:**
  - `modWaferAlignment` (`BIS/Sources/apps/Falcon.Net/Modules/modWaferAlignment.cs`, 2101 lines) — main alignment orchestration
  - `ExternalCoordSystemsAlign` (`BIS/Sources/apps/Falcon.Net/Modules/ExternalCoordSystemsAlign.cs`) — external coordinate systems alignment
  - `CWaferStageAlign` (`MainContext.ScenJobAlignment`) — wafer-stage alignment data (ScenarioManager COM)
  - `frmWaferAlignmentSetup`, `frmDieAlignmentSetup` — setup UI forms
  - `AlignmentSetup/` classes — `DisplayImageProvider`, `RegModelsUtils`, `StageCalibUtils`
- **Data model:**
  - `CWaferStageAlign` — alignment data object (rotation, offset, grid data)
  - `GridLevelAlignData.SaveMaxUncertanty_um()` — uncertainty tracking
  - `SWaferShift` — wafer shift (X/Y offset)
  - `MainContext.WaferSift : SWaferShift`
  - Alignment-related setup parts: `eSETUP_DATA_TYPES.eSETUP_ALIGMENT`
  - Alignment optics: `Alignment` / `UniquePat` / `Scan2d` optic roles
  - Pass/fail: `eCycleCompletionCode.eCCC_ErrorAlignment`
  - `eWCE_ALIGNMENT_ERROR` — wafer error code
- **Async/sync:** Synchronous. Alignment is a blocking sequential pipeline.
- **Existing events:**
  - `frmProduction.FireOperationStarted(eSMO_Alignment, ...)` — COM event when alignment starts
  - `frmProduction.FireOperationCompleted(eSMO_Alignment, ..., CompletionCode)` — COM event when alignment completes
  - PubSub: alignment-related `EventMessage` published via `modWaferAlignment`
  - No .NET event specifically for "alignment data changed"
- **Threading notes:** Alignment runs on UI thread. Hardware calls are synchronous COM.
- **Gaps / unknowns:**
  - No granular "alignment state changed" event — completion is reported via `FireOperationCompleted`
  - Alignment data model details (exact offset X/Y, angle, reference point) are inside `CWaferStageAlign` COM object — not surfaced as .NET properties in `MainContext`

---

### 2.6 Clean Reference

- **Current mechanism:** Direct method calls + recipe part access. No push events.
- **Owner class/interface:**
  - `modCleanReferenceOptions` (`BIS/Sources/apps/Falcon.Net/Modules/modCleanReferenceOptions.cs`) — recipe part accessor
  - `clsCreateCleanForSingleDie` (`BIS/Sources/apps/Falcon.Net/Classes/clsCreateCleanForSingleDie.cs`, 516 lines) — single-die clean reference orchestration
  - `frmAdvCleanReference` — advanced clean reference UI form
  - `ICleanReferenceOptions` interface (from `JobParts.Recipe.CleanReference.Entities`)
  - Clean reference algorithms in `BIS/Sources/dds/CleanGpuImplementation/`, `CleanImplementationCS/`, `CleanReferenceComparison/`
- **Data model:**
  - `ICleanReferenceOptions` — accessed via `CurrentRecipe().RecipeParts["CleanReference"]`
  - `eSETUP_DATA_TYPES.eSETUP_CLEAN_REF_DATA` — setup data type for clean ref validation
  - `IsCleanReferenceValid()` — validation method
  - `CleanReferenceParamsCommon.CleanRefParamsJobFileName` — config file
  - `CleanFromSetupTabEnabled` — reads `"PerformCleanOnPizza"` from INI
  - `IsRequestedForCleanSingleDie` — static bool flag
  - `RecipeModel.CleanReferenceEvery : eDoActionEvery` — periodicity
  - `MainContext.RefChanged : bool` — flag indicating reference was changed
  - `MainContext.InSetupTabCreateReference : bool` — flag for setup-tab reference creation
- **Async/sync:** Synchronous. Clean reference is an auto-cycle step.
- **Existing events:**
  - `UIEvents.ResetScanModes : VoidEventHandler` — related but not specific
  - No specific "clean reference completed" .NET event
  - `FireOperationCompleted` would be called for the scan operation that includes clean reference
- **Threading notes:** Runs on UI thread as part of scan/auto-cycle pipeline.
- **Gaps / unknowns:**
  - Clean reference is a **golden image / reference frame** for defect detection — created by scanning a "clean" wafer
  - No timestamp or versioning of clean reference state found in `MainContext`
  - Validity is checked via `IsCleanReferenceValid()` on the recipe/setup data — not tracked as live state

---

### 2.7 CMM Integration

- **Current mechanism:** `CMM.Net.Api` managed client library + gRPC receiver server on port 50055
- **Owner class/interface:**
  - `clsCMM` (`BIS/Sources/apps/Falcon.Net/Cmm/clsCMM.cs`, 741 lines) — CMM client facade
  - `CmmReceiverApiRequetsHandler` (`BIS/Sources/apps/Falcon.Net/Cmm/CmmReceiverApiRequetsHandler.cs`, 437 lines) — gRPC inbound request handler (implements `ICmmReceiverApiContract`)
  - `MainContext.mCMM : clsCMM` — public field
- **Data model:**
  - `CmmInputMapResult` — import results (die-to-scan lists)
  - `ComExportSummary` / `IComExportSummary` — export summary data
  - `ExportMapsByTaskListReply` — batch export result
  - `eCmmExportRunningKind` — export running state
  - `eCmmAlertType` — alert type enum
  - `SBatchReportDefinition[]` — batch report definitions
  - `ExportMapConfirmationRequest` — confirmation data
  - `MainContext.mCMM.SourcePath`, `DestinationPath` — paths
  - `MainContext.mCMM.LastErrorDescription` — last error
  - `MainContext.mCMM.IsParallelCmmEnabled` — parallel CMM flag
  - `MainContext.CmmMode` — `mVVRMode == 3`
  - CMM gRPC server port: `50055`
- **Async/sync:**
  - Export operations use `NonBlockingUITask.Execute` (async offload to MTA, UI thread polls with `DoEvents()`)
  - Import is synchronous
  - gRPC receiver handles inbound requests asynchronously
- **Existing events:**
  - `frmProduction.FireCmmImport()` → COM `IAutoCycleManagerCB.CmmImport`
  - `frmProduction.FireCmmImportCompleted(bool)` → COM `IAutoCycleManagerCB.CmmImportCompleted`
  - `frmProduction.FireCmmUpdateCompleted(bool, lotId, waferId)` → COM `IAutoCycleManagerCB.CmmUpdateCompleted`
  - `CmmReceiverApiRequetsHandler.ExportMapEnd()` → fires `FireOperationCompleted(eSMO_WaferMapExport, ...)`
  - `CmmReceiverApiRequetsHandler.ExportMapStart()` — sets state
  - `CmmReceiverApiRequetsHandler.Alert()` — shows alert
  - `CmmReceiverApiRequetsHandler.DoWaferMapAutoMatch()` — wafer map matching
- **Threading notes:** gRPC server runs on its own thread pool. `NonBlockingUITask.Execute` offloads CMM API calls to MTA thread while pumping UI messages.
- **Gaps / unknowns:**
  - **AOI_Main does NOT use WCF duplex callbacks.** `CmmServiceNotifierProxy` is a DataServer component used by MDC, not by AOI_Main.
  - `ScanReadyMessage` — **not found** anywhere in the BIS codebase
  - CMM state (ticket open, export running) is not tracked as explicit state in `MainContext` — it's transient within method calls
  - `clsCMM.Init()` starts gRPC receiver server and registers with CMM via `ICmmClient.RegisterFalconReceiverService()`

---

### 2.8 Die Edit Modification

- **Current mechanism:** External process launch (`Camtek.DieEdit.exe`). File-based communication.
- **Owner class/interface:**
  - `DieEdit.sln` at `BIS/Sources/DieEdit/` — standalone WPF MVVM application
  - `DieEditJob/` — job data access layer (JobManager, JobSelector, Recipe, Setup, Layer, BinCodeModel)
  - `DieEditOperations/` at `BIS/Sources/dds/DieEditOperations/` — core operations library
  - `frmMain.OpenDieEditor()` — launches DieEdit.exe with recipe path and permission level
  - `frmJobTab` — "Convert Job" mode launches DieEdit with flag and waits for exit
- **Data model:**
  - Die edit operates on job recipe files on disk
  - `DieEditJob/CurrentJob.cs`, `JobManager.cs`, `JobStructure.cs`, `Recipe.cs`, `Setup.cs`
  - `Layer.cs`, `BaseLayer.cs` — layer model within recipes
  - `ImageMask.cs`, `ImageMaskContour.cs` — image mask operations
  - `BinCodeModel.cs` — die bin codes
  - `RtpData.cs` — RTP (Real-Time Processing) data
  - `UndoRedoManager/` — undo/redo support in DieEdit
  - `NotificationManager/` — DieEdit's internal notification system
  - Die coordinates: col/row within wafer map
  - Die classification: bin codes
- **Async/sync:** 
  - DieEdit is an **external process** — launched asynchronously
  - `frmJobTab` waits for DieEdit exit in "Convert Job" mode (`waitForExit`)
- **Existing events:**
  - **None** from DieEdit back to AOI_Main — DieEdit is a fire-and-forget external process
  - AOI_Main kills `dieedit` process on shutdown (`clsInitAOI.cs`)
  - No COM callback, no WCF callback, no PubSub from DieEdit to AOI_Main
- **Threading notes:** External process. No threading concern within AOI_Main.
- **Gaps / unknowns:**
  - AOI_Main has no way to know when a die edit occurred unless it re-reads job files from disk
  - Die edit is purely file-based — edits modify recipe/job files; AOI_Main must detect this via file timestamps or explicit refresh
  - No "die edit event" or "die edit state" exists in any current interface

---

## Section 3 — Threading & Concurrency Model

### 3.1 COM Apartment

**AOI_Main runs on STA thread** — `[STAThread]` attribute on `Program.Main()`.

- WPF `Dispatcher.CurrentDispatcher` is captured at startup
- `Application.Run(new clsInitAOI())` starts WinForms STA message pump
- **Critical:** `CFalconEvents` is created on an MTA thread (`Task.Run(() => { ... new CFalconEvents(); }).Wait()`) — this is intentional so COM callbacks fire on MTA threads, not blocking the STA UI thread

### 3.2 Existing Threading Patterns

| Pattern | Usage | Location |
|---|---|---|
| `NonBlockingUITask.Execute` | Offloads COM calls to MTA `Task.Run`, polls with `Application.DoEvents()` on UI thread | 30+ call sites in Falcon.Net — `frmProduction.Fire*`, `Automation.*`, `clsCMM.*`, `EFEMModule.*` |
| `Dispatcher.BeginInvoke` | Marshals MTA callbacks to STA/UI thread (async) | `ScanManagerWrapper`, `Program.cs` (keyboard hook), `DisplayControlWrapper` |
| `Dispatcher.Invoke` | Marshals MTA callbacks to STA/UI thread (sync) | `ScanManagerWrapper.GetInkingParams` (noted deadlock risk) |
| `InvokeIfRequired` | WinForms `Control.Invoke` wrapper for thread safety | `clsMultiRecipe`, `clsPeriodicCalib`, `clsResultList` |
| `Thread` | Single use: progress bar thread | `SetupTab.xaml.cs` |
| `Task.Run` | MTA offload for COM object creation | `frmProduction.FalconIsStartingUp()` |
| `Task.Run` + polling | ScenarioManager stop | `MainContextModule.ScenarioManagerStop()` |
| `Application.DoEvents()` | UI pump during blocking waits | `NonBlockingUITask`, `MainContext.FindFocusPosition`, `SPCDB.WaitForTaskDone` |
| `async/await` | SPCDB async operations | `SPCDB.WaitForTaskDone`, `SPCDB.AddNewRecordAsync` |
| `[CanRunNotOnUIThread]` | Annotation attribute marking methods safe for MTA | `frmProduction.Fire*`, `MainContextModule` (~40+ methods), `clsAutoFocus` |

**No `BackgroundWorker` usage found in Falcon.Net.**

### 3.3 COM Callback Thread Delivery

- **`CScanManager` COM events** (`ScanDone`, `ScanProgressChange`, `PizzasConnectionStatus`): Delivered on MTA pool threads. `ScanManagerWrapper` marshals to UI via `dispatcher.BeginInvoke`.
- **`IFalconExternalControlCB` callbacks** (from `CFalconExternalControl`): Delivered on COM thread. `ExternalControlCbUiWrapper` handles directly.
- **`IRobotUIConnectorCB` callbacks** (from robot UI): Delivered on caller's thread (likely MTA). Wrapped in `CallbackMonitor`/`CallMonitor` for diagnostics.
- **`IFalconFireEvents` outgoing calls**: Executed via `NonBlockingUITask.Execute` — `Task.Run` to MTA, UI thread polls with `DoEvents()`.

### 3.4 Synchronization Primitives

| Primitive | Location | Purpose |
|---|---|---|
| `lock (_instanceLocker)` | `MainContextModule.cs` | Singleton creation |
| `lock (_robotSync)` | `MainContextModule.cs` | RobotUI lazy initialization |
| `lock (lockDB)` | `MainContextModule.cs` | SPCDB access (declared) |
| `lock (lockMng)` | `MainContextModule.cs` | InspectionMng access (declared) |
| `lock (_safetyLocker)` | `frmMain.cs` | Safety-related operations |
| `lock (_actions)` | `BusyIndicatorAsyncService.cs` | Job grading async service |
| `Mutex("ProcessingMultiLightChannels")` | `MultipleLightChannelsFunctions.cs` | Cross-process mutex for multi-light processing |
| `Mutex` (P/Invoke `CreateMutex`) | `frmJobTab.cs` | Job folder locking |

**No `SemaphoreSlim`, `ConcurrentQueue`, or `ConcurrentDictionary` found in Falcon.Net.**

### 3.5 UI Thread Interaction

- **WinForms + WPF hybrid:** `Application.Run()` with WinForms, but `Dispatcher.CurrentDispatcher` (WPF) is used extensively.
- `Frms` class creates all forms on STA thread via `TryRunWithDispatcher<T>()` — if called from MTA, uses `disp.Invoke(action)`.
- `ElementHosts/` directory exists — WPF controls hosted in WinForms via `ElementHost`.
- `SetupTab.xaml` / `SetupTab.xaml.cs` — WPF UserControl hosted in WinForms.
- `InvokeIfRequired` pattern used for WinForms cross-thread access.
- `dispatcher.BeginInvoke` used for WPF dispatcher marshaling.

---

## Section 4 — Existing Event Infrastructure

### 4.1 RabbitMQ PubSub

**Yes, actively used.** Implementation: `CamtekSystem.PubSub` backed by RabbitMQ.

- **Docker compose:** `BIS/Sources/system/CamtekSystem/PubSub/env/docker-compose.yml` — RabbitMQ 3 (management-alpine), ports `5672`/`15672`
- **Transport configurable:** INI-based — `RabbitMQ | InProc | MSMQ`. `NullableSubscriber` when `Enabled=false`.
- **Publisher use in Falcon.Net:**
  - `clsInitAOI.cs`: `PublisherFactory.Get()` → `EventMessage(EventContext.Startup, EventSubContext.Init, EventAction.Start/Finished)`
  - `frmMain.cs`: `EventMessage(EventContext.Scan, EventSubContext.Execution, EventAction.Finished, ...)`
  - `frmScanTab.cs`: Multiple `EventMessage(EventContext.Scan, ...)` after scan completion
  - `modWaferAlignment.cs`, `modInkMarkWafer.cs`, `ExternalCoordSystemsAlign.cs`, `MultipleLightChannelsFunctions.cs`, `clsWaferError.cs`, `clsMultiRecipe.cs`, `clsCreateCleanForSingleDie.cs`
- **Subscriber use in Falcon.Net:** Not found — Falcon.Net is a publisher only for PubSub
- **Topics/Contexts used:** `EventContext.Startup`, `EventContext.Scan` with various `EventSubContext` and `EventAction` combinations

### 4.2 WCF Duplex Callbacks

**AOI_Main does NOT use any WCF duplex callbacks.** No `System.ServiceModel` WCF client usage found. No `ScanResultsNotifierProxy`, `VerificationNotifierProxy`, or `CmmServiceNotifierProxy` in Falcon.Net. These are DataServer components used by MDC (the web dashboard), not by AOI_Main.

The only WCF trace is a `<WCFMetadata>` MSBuild element in the `.csproj` pointing to an empty `Connected Services\` folder.

### 4.3 C# Events/Delegates in UIEvents

Defined in `BIS/Sources/apps/Falcon.Net/Classes/UIEvents.cs`:

| Delegate Signature | Event Name | Fire Method |
|---|---|---|
| `VoidEventHandler` | `CCSFormClosed` | `FireCCSFormClosed()` |
| `ReclassifyChangedEventHandler(bool)` | `ReclassifyChanged` | `FireReclassifyChanged(bool)` |
| `ScanModeChangedEventHandler(short, short)` | `ScanModeChanged` | `FireScanModeChanged(short, short)` |
| `SetupInfoLoadedEventHandler(ref ISetupInfo, bool)` | `SetupInfoLoaded` | `FireSetupInfoLoaded(ISetupInfo, bool)` |
| `RecipeAddedEventHandler(bool, string, bool, bool, bool, bool, int, int)` | `RecipeAdded` | `FireRecipeAdded(...)` |
| `RecipeDeletedEventHandler(string)` | `RecipeDeleted` | `FireRecipeDeleted(string)` |
| `VoidEventHandler` | `ResetScanModes` | `FireResetScanModes()` |
| `VoidEventHandler` | `JobLoadingStarted` | `FireJobLoadingStarted()` |
| `VoidEventHandler` | `MultiRecipeFormSaved` | `FireMultiRecipeFormSaved()` |
| `VoidEventHandler` | `RecipesLoaded` | `FireRecipesLoaded()` |
| `VoidEventHandler` | `MultiRecipeFileDeleted` | `FireMultiRecipeFileDeleted()` |
| `VoidEventHandler` | `PhysicalScanDone` | `FirePhysicalScanDone()` |

Additional events in `ScanManagerWrapper`:
| Event | Signature |
|---|---|
| `OnScanDone` | `Action<eScanManagerScanStatus>` |
| `OnScanProgressChange` | `Action<eScanProgressStatus>` |
| `OnPizzasConnectionStatus` | `Action<List<sConnectionStatus>>` |
| `OnCopyJobFilesIntoScanResult` | `Action<string,string>` |

Additional event in `OpticModule`:
| Event | Signature |
|---|---|
| `OpticsChanged` | `Action<IOptics>` |

### 4.4 Logging

- **Framework:** `log4net`
- **Config:** `[assembly: XmlConfigurator(ConfigFile = @"c:\bis\data\apps\Logging.xml", Watch = true)]` (in `AssemblyInfo.cs`)
- **Log file location:** Configured in `c:\bis\data\apps\Logging.xml` (external file, not in app.config)
- **Usage:** `private static ILog _logger = LogManager.GetLogger(typeof(ClassName));` — standard pattern across all files
- **No Serilog usage found.**

### 4.5 System.Reactive / IObservable

**Not used.** No `System.Reactive` or `IObservable<T>` references found in Falcon.Net.

---

## Section 5 — Constraints & Non-Negotiables

### 5.1 Threading Constraints

| Thread | Must Not Block | Reason |
|---|---|---|
| **STA/UI thread** | Must never block for extended periods | All WinForms/WPF rendering, COM STA message pump, user interaction. `Application.DoEvents()` is used to pump during waits — blocking would freeze the entire GUI. |
| **COM MTA callback threads** | Must not call STA UI code directly | Callbacks from `CScanManager`, `IRobotUIConnectorCB`, `IFalconExternalControlCB` arrive on MTA. Must marshal to STA via `Dispatcher.BeginInvoke` or `InvokeIfRequired`. |
| **gRPC receiver thread pool** | Must not call STA code directly | `CmmReceiverApiRequetsHandler` runs on gRPC thread pool. `ExportMapEnd` calls `FireOperationCompleted` which uses `NonBlockingUITask.Execute`. |
| **Grabbing pipeline threads** | Not directly managed by AOI_Main | GrabIPC, AcqIPC, DdsIPC operate in separate processes/threads — decoupled via IPC. |

### 5.2 COM Apartment Constraints

| COM Object | Apartment | Created Where | Marshaling Required |
|---|---|---|---|
| `CFalconEvents` (singleton) | MTA | `frmProduction.FalconIsStartingUp()` via `Task.Run` | No — intentionally MTA so `Fire*` calls via `NonBlockingUITask.Execute` work without STA marshal |
| `CFalconExternalControl` | MTA | `ExternalControlCbUiWrapper` constructor (called from MTA within `FalconIsStartingUp`) | No — MTA to MTA |
| `CScanManager` | Unknown (likely MTA) | ScenarioManager initialization | `ScanManagerWrapper` marshals callbacks to UI via `Dispatcher.BeginInvoke` |
| `CamtekUtils` COM objects | STA | `MainContext` constructor (on STA startup thread) | None — already on STA |
| `IAutoLoader` (EfemSrv) | Likely MTA | Lazy init in `EFEMModule.GetAutoLoader()` | `NonBlockingUITask.Execute` used for calls |
| WaferHandlingManager | MTA | `WaferHandlingManagerConnector.Instance` | All calls via `NonBlockingUITask.Execute` |
| `InspectionMngServiceConnector` | Unknown | `MainContext.InitInspectionMngService()` | None observed |

### 5.3 Latency Requirements

| State Domain | Estimated Latency Tolerance | Rationale |
|---|---|---|
| Scan / Grab state | **<50ms** | Physical scan progress drives real-time UI updates and pipeline coordination |
| Robot / EFEM | **<100ms** | Safety-critical — wafer handling must respond promptly to errors |
| Camera / Lights | **100-500ms** | Hardware switch is inherently slow (mechanical); notification can tolerate latency |
| Job Created/Deleted | **>500ms** | User-driven action; no real-time constraint |
| Alignment | **<100ms** | Part of scan pipeline; alignment completion triggers next scan step |
| Clean Reference | **>500ms** | Part of setup/auto-cycle; no real-time constraint |
| CMM Integration | **100-500ms** | Export operations are slow (seconds); notifications can tolerate latency |
| Die Edit | **>1000ms** | External process; file-based; no real-time constraint |

### 5.4 Existing Patterns to Preserve

| Pattern | Description | Why Preserve |
|---|---|---|
| `NonBlockingUITask.Execute` | Offload to MTA + poll STA with `DoEvents()` | Used at 30+ call sites for COM interop. Changing would require rewriting all Fire* methods and COM call wrappers. |
| `Dispatcher.BeginInvoke` for callback marshaling | MTA→STA async marshal | Well-established pattern in `ScanManagerWrapper`. |
| `[CanRunNotOnUIThread]` attribute | Marks methods safe for MTA | 40+ methods annotated. New state model methods should use this. |
| `CallbackMonitor` / `CallMonitor` RAII | Diagnostic wrappers for callback tracking | Used in `RobotUIEventHandlerWrapper`, `ScanManagerWrapper`. |
| `MainContext` singleton | Central state container | All code references `MainContext.Instance.*`. |
| `IMainModules` / `IForms` interfaces | Dependency boundaries | All modules accessed via interfaces. |
| `UIEvents` fire pattern | Internal .NET event broadcasting | Established pattern for intra-process events. |
| `IFalconFireEvents` → `CFalconEvents` | COM outward event broadcasting | External tools depend on this exact COM interface. |
| PubSub `EventMessage` | Async telemetry/monitoring | Used for startup and scan completion notifications. |

### 5.5 Integration Points That Cannot Be Changed

| Integration Point | Type | Frozen? | Details |
|---|---|---|---|
| `IFalconEvents` / `IFalconFireEvents` | COM IDL interface | **Frozen** | External tools (SecsGemClient, NetTAC, ProductionGui, TAC.Net, TopiClient) implement `IAutoCycleManagerCB`, `IScanManagerCB`, `IFalconGuiCB` and register via `IFalconEvents`. Changing these breaks all tool integrations. |
| `IFalconExternalControlCB` | COM IDL interface | **Frozen** | Inbound external control commands. |
| `ScenarioManager.CScanManager` events | COM + .NET events | **Frozen** | `ScanDone`, `ScanProgressChange`, `PizzasConnectionStatus`, `CopyJobFilesIntoScanResult` — low-level scan engine events. |
| `IRobotUIConnector` / `IRobotUIConnectorCB` | COM/.NET interface | **Frozen** | 40+ event delegates for robot UI integration. |
| `CamtekSystem.PubSub` | RabbitMQ-based | **Frozen** | `EventMessage` schema and transport. |
| `CMM.Net.Api` / gRPC port 50055 | gRPC | **Frozen** | CMM client API and receiver server. |
| `CamtekUtils` COM | COM interop | **Frozen** | CFileUtils, CSystem, CForms. |
| `log4net` config at `c:\bis\data\apps\Logging.xml` | File config | **Frozen** | Log infrastructure. |
| `c:\bis\data\` path conventions | File system | **Frozen** | INI files, job paths, calibration data. |

---

## Section 6 — Migration Baseline

### Constraints Summary Table

| Constraint | Details | Impact on state design |
|---|---|---|
| COM STA thread | AOI_Main runs `[STAThread]`. WinForms + WPF hybrid. `Application.DoEvents()` pumping during blocking waits. | State change notifications must not block STA thread. Must use `NonBlockingUITask` or `Dispatcher.BeginInvoke` pattern for any COM-originating state change. |
| COM MTA for `CFalconEvents` | Created on MTA thread intentionally. `Fire*` methods use `NonBlockingUITask.Execute`. | State model must be thread-safe for MTA access. Outbound COM events must continue using `NonBlockingUITask`. |
| `ScanManagerWrapper` thread marshaling | Callbacks arrive on MTA, marshaled to UI via `Dispatcher.BeginInvoke`. | Scan state changes originate on MTA. State model must handle MTA→STA transition. |
| `NonBlockingUITask` polling pattern | Uses `Application.DoEvents()` to pump UI while waiting for MTA task. | Cannot use `async/await` directly on UI thread in most Fire* code — must preserve `DoEvents()` pattern or introduce new async pipeline. |
| No `BackgroundWorker` or `IObservable` | Clean slate for threading patterns. | State model can introduce new patterns but should not conflict with existing `NonBlockingUITask` usage. |
| External tools depend on COM callback interfaces | `IAutoCycleManagerCB`, `IScanManagerCB`, `IFalconGuiCB` are IDL-defined and consumed by SecsGem, NetTAC, etc. | New state model must fire these COM callbacks at the same points where `frmProduction.Fire*` methods do today. |
| `MainContext` singleton is the universal state container | 5701 lines, 170+ properties. | State model should integrate with `MainContext` — either as a sub-module or by replacing specific property groups. |
| DieEdit is external process | No callback path exists today | Any die-edit state domain requires new infrastructure (file watcher, PubSub, or process monitoring). |
| CMM is gRPC-based | `clsCMM` uses `CMM.Net.Api` client + gRPC receiver on 50055 | CMM state events arrive via gRPC (`CmmReceiverApiRequetsHandler`), not COM. |

---

### Move / Keep Map

| Item | Current location | Target owner (`Falcon.Net` / `AOI_Main`) | Rationale (fact-based) |
|---|---|---|---|
| `mFalconFireEvents` field + all `Fire*` methods | `frmProduction.cs` (a form in Falcon.Net) | **Falcon.Net** (move from form to dedicated class) | Currently embedded in a WinForms form. Firing events is not a UI concern. Should be in a module/service class within Falcon.Net. |
| `IFalconFireEvents` COM object creation | `frmProduction.FalconIsStartingUp()` via `Task.Run` | **Falcon.Net** (dedicated lifecycle manager) | COM object lifecycle should not be tied to a form's lifecycle. |
| `ExternalControlCbUiWrapper` | `CommonUtils/ComServerWrappers/` in Falcon.Net | **Falcon.Net** (keep) | Already in Falcon.Net. Owns `IFalconExternalControl` registration. |
| `ScanManagerWrapper` | `CommonUtils/ComServerWrappers/` in Falcon.Net | **Falcon.Net** (keep) | Already in Falcon.Net. Wraps scan engine callbacks. |
| `RobotUIEventHandlerWrapper` | `CommonUtils/ComServerWrappers/` in Falcon.Net | **Falcon.Net** (keep) | Already in Falcon.Net. Wraps robot UI callbacks. |
| `MainContext` state properties (ScanResult, ScanDone, etc.) | `MainContextModule.cs` in Falcon.Net | **Falcon.Net** (keep, augment) | Singleton is already in Falcon.Net. State properties should be formally grouped but not moved out. |
| `UIEvents` (.NET events) | `Classes/UIEvents.cs` in Falcon.Net | **Falcon.Net** (keep) | Internal .NET event system. |
| `clsCMM` | `Cmm/clsCMM.cs` in Falcon.Net | **Falcon.Net** (keep) | CMM facade already in Falcon.Net. |
| `CmmReceiverApiRequetsHandler` | `Cmm/` in Falcon.Net | **Falcon.Net** (keep) | gRPC inbound handler already in Falcon.Net. |
| `clsFalconPresentation.FalconFireEvnt` | `Classes/clsFalconPresentation.cs` in Falcon.Net | **Falcon.Net** (keep, redirect) | Currently delegates to `frmProduction.FalconFireEvents`. Should redirect to new event owner. |
| `modCleanReferenceOptions` | `Modules/` in Falcon.Net | **Falcon.Net** (keep) | Recipe part accessor. |
| `clsCreateCleanForSingleDie` | `Classes/` in Falcon.Net | **Falcon.Net** (keep) | Clean reference orchestration. |
| `modWaferAlignment` | `Modules/` in Falcon.Net | **Falcon.Net** (keep) | Alignment orchestration. |
| `OpticModule` + `CamerasModule` | `Modules/` in Falcon.Net | **Falcon.Net** (keep) | Camera/optics management. |
| `RecipeModelManager` | `Modules/` in Falcon.Net | **Falcon.Net** (keep) | Recipe UI model. |
| `EFEMModule` | `Modules/` in Falcon.Net | **Falcon.Net** (keep) | Robot/EFEM facade. |
| `Automation` module | `Modules/` in Falcon.Net | **Falcon.Net** (keep) | Automation facade. |
| DieEdit external process launch | `frmMain.OpenDieEditor()` in Falcon.Net | **AOI_Main** (keep as consumer) | DieEdit is launched from UI action. AOI_Main remains the consumer. |
| TestAutomationSDK | `BIS/Sources/TestAutomationAPI/` | **AOI_Main** (consumer/adapter) | Test automation is an external consumer of AOI_Main state. |

---

### COM Callback Ownership Map

| Callback family | Register API | Current owner class | Target owner class (for migration) | Notes |
|---|---|---|---|---|
| **IAutoCycleManagerCB** (10 events) | `IFalconEvents.RegisterAutoCycleEvent` | `frmProduction` fires via `mFalconFireEvents` | Dedicated Falcon.Net event service class | Fire methods: `FireWaferScanResultsAreReady`, `FireCmmImport`, `FireCmmImportCompleted`, `FireCmmUpdateCompleted`, `FirePeriodicCalibrationCompleted`, `FireSpcBatchReportReady`, `FireWaferInspectionStarted`, `FireGetOnDemandJobName` (via `ExternalControlCbUiWrapper`) |
| **IScanManagerCB** (2 events) | `IFalconEvents.RegisterScanEvent` | `frmProduction` fires via `mFalconFireEvents` | Dedicated Falcon.Net event service class | Fire methods: `FireOperationStarted`, `FireOperationCompleted` |
| **IFalconGuiCB** (12 events) | `IFalconEvents.RegisterFalconGuiEvent` | `frmProduction` fires via `mFalconFireEvents` | Dedicated Falcon.Net event service class | Fire methods: `FireJobLoaded`, `FireUserLoggedIn/Out`, `FireManualInputMode`, `FireFalconGuiLifeCycleChanged`, `FireManualScanDone`, `FireExportMapAfterReviewAtOffline`, `FireInOutVerifyTabAtOffline`, `FireSetLotIdAndWaferIdAtOffline`, `FireScenScanMgrPizzasConnectionStatus`, `FireLCCPeriodicCalibAlert`. Also `Set2dOpticsDone` fired directly by `ExternalControlCbUiWrapper`. |
| **IFalconExternalControlCB** | `IFalconExternalControl.RegisterEvent` | `ExternalControlCbUiWrapper` | **Keep in `ExternalControlCbUiWrapper`** | This is an INBOUND callback (commands from external tools to Falcon). Not part of outward event system. |
| **IScanManagerInkingCB** (ScenarioManager) | `CScanManager.RegisterEvent` | `ScanManagerWrapper` | **Keep in `ScanManagerWrapper`** | Internal scan engine callback, not the FalconWrapper version. Wraps scan progress/done events. |
| **IRobotUIConnectorCB** | `IRobotUIConnector` initialization | `RobotUIEventHandlerWrapper` | **Keep in `RobotUIEventHandlerWrapper`** | 40+ robot event delegates. Inbound callbacks from robot UI. |

**Key finding for migration:** All `Fire*` methods currently in `frmProduction` (a WinForms form) should move to a dedicated service class in Falcon.Net. The `IFalconFireEvents` COM object creation (`new CFalconEvents()`) and its lifecycle should also move. `clsFalconPresentation.FalconFireEvnt` already provides an access path and would need to be redirected. The `ExternalControlCbUiWrapper` separately creates its own `CFalconEvents` reference but only calls `Set2dOpticsDone` on it — this should share the same instance.

**Currently implemented in Falcon.Net (reusable):**
- `ScanManagerWrapper` — fully wraps `ScenarioManager.IScanManagerInkingCB` with .NET events
- `RobotUIEventHandlerWrapper` — fully wraps `IRobotUIConnectorCB` with 40+ .NET events  
- `ExternalControlCbUiWrapper` — wraps `IFalconExternalControlCB` for inbound commands

**Must be added:**
- No sink implementation for `IAutoCycleManagerCB`, `IScanManagerCB`, or `IFalconGuiCB` exists in Falcon.Net — these are **fire-only** interfaces on the producer side. The sink implementations exist in external tools (SecsGem, NetTAC, etc.). No new sink implementations need to be added to Falcon.Net for migration.
