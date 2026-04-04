# AOI Main State — Prompt 1: Codebase Discovery

> **Goal:** Understand the current AOI_Main structure and identify every integration point  
> that will feed into the state model before proposing any solution.  
> **Run this first.** Do not propose solutions yet — only gather facts.

---

You are a **senior software architect**.  
You have access to the Camtek Falcon monorepo (`CamtekGit`). The `system.md` document has already been produced and describes the top-level architecture.

Your task now is to **deeply analyze the `AOI_Main` component** inside `BIS/Sources/TestAutomationAPI/AOI_Main/` and answer every question below with **exact file paths, class names, method signatures, and existing event/callback mechanisms** found in the code.

---

## Section 1 — AOI_Main Structure

1. What is the **entry point** of `AOI_Main`? (exe / library / test runner?)
2. What is the **top-level class** that orchestrates the system? List all its public members.
3. How is `AOI_Main` **launched** — standalone, hosted inside `RunnerGui`, or called by `TestAutomationSDK`?
4. What **dependencies** does `AOI_Main` reference? (DLLs from `c:\bis\bin\`, COM servers, WCF proxies, any direct BIS module reference)
5. Does `AOI_Main` currently have **any state model** (class, enum, dictionary, flags)? List it exactly.

---

## Section 2 — The 8 State Domains: Current Implementation

For each domain below, search the `AOI_Main` source and the BIS modules it calls into. Document:
- The **current mechanism** used (polling, COM event, WCF callback, direct method call, file watch)
- The **class/interface** that owns the operation
- The **data returned or changed** (exact fields/types)
- Whether it is **synchronous or asynchronous** today

### 2.1 Scan / Grab / Color Grabbing
- Which BIS module drives scanning? (`DdsSrv_d.exe`, `Sources/Grabbing/`, `Sources/dds/`?)
- What COM interface or IPC channel (`GrabIPC`, `AcqIPC`, `DdsIPC`) does `AOI_Main` use to trigger or observe a scan?
- What events/callbacks exist today for scan-start, scan-progress, scan-complete, scan-abort?
- What data describes a scan state? (scan ID, wafer ID, progress %, camera mode, color vs mono?)

### 2.2 Robot Setup
- Which module controls the robot/EFEM/loader? (`PizzaServer.exe`, `Sources/machine/`, E84 driver?)
- How does `AOI_Main` interact with it — COM, WinSock TCP, WCF, named pipe?
- What robot states are observable today? (idle, loading, unloading, error, homing)
- What events/callbacks exist?

### 2.3 Camera & Lights / Illumination Change
- Which module manages camera configuration and illumination? (`Sources/system/` camera drivers, `Sources/calibration/`, `SystemCalibration`?)
- 17 camera types are documented — which ones are relevant to `AOI_Main`?
- How does `AOI_Main` know when illumination or camera settings change?
- What data describes the camera/light state? (channel, intensity, objective, wavelength)

### 2.4 Job Created / Deleted
- Which module owns the Job/Recipe lifecycle? (`Sources/objects/Job.NET`, `RMS`, `BIS/Sources/JobParts/`?)
- What is the **Job data model** as seen from `AOI_Main`? (job name, path, status, parameters)
- Is there an existing job-changed event/callback? If so, what interface/delegate?
- Does `AOI_Main` call into RMS (`gRPC port 5001`) or directly into BIS job objects?

### 2.5 Alignment Modification
- Which module owns alignment? (`Sources/objects/Alignment`, `Sources/dds/`?)
- What triggers an alignment change? (user action, auto-alignment algorithm, recipe load?)
- What data is in an alignment state? (offset X/Y, angle, reference point, pass/fail, wafer ID)
- Does any event currently fire when alignment is modified?

### 2.6 Clean Reference
- What is a "Clean Reference" in the Falcon domain? (golden image, reference frame, calibration baseline?)
- Which module owns it? (`Sources/dds/`, `Sources/calibration/`, `Sources/system/`?)
- What triggers a reference clean/reset? (user command, new job, periodic?)
- What data represents the reference state? (valid/invalid, timestamp, camera, path)

### 2.7 CMM Integration
- How does `AOI_Main` interact with CMM? (via DataServer WCF port `8032`, `Camtek.API.CMM`, or direct CMM.NET call?)
- What CMM events/callbacks exist? (`CmmServiceNotifierProxy`, duplex WCF callback?)
- What CMM state is relevant? (ticket open, export running, export complete, error, file path)
- Is the `ScanReadyMessage` queue message involved — who publishes, who consumes?

### 2.8 Die Edit Modification
- Which module owns die editing? (`DieEdit.sln`, `Sources/Components/`, `Sources/objects/`?)
- What constitutes a "die edit"? (die re-classification, die exclusion, coordinate change?)
- How does `AOI_Main` learn that a die edit occurred?
- What data represents a die edit state? (wafer ID, die coordinates, old value, new value, timestamp)

---

## Section 3 — Threading & Concurrency Model

1. Does `AOI_Main` run on a **STA or MTA** COM apartment? (critical for WPF/WinForms interop)
2. Are there existing `BackgroundWorker`, `Task`, `Thread`, or `async/await` patterns in `AOI_Main`?
3. Does the BIS IPC (COM events, `GrabIPC`) deliver callbacks on a **specific thread**? Which one?
4. Are there existing **synchronization primitives** (`lock`, `Mutex`, `SemaphoreSlim`, `ConcurrentQueue`) in use?
5. Does `AOI_Main` interact with a **UI thread** (WPF Dispatcher, WinForms `Invoke`)? Where?

---

## Section 4 — Existing Event Infrastructure

1. Does BIS use **RabbitMQ PubSub** (`docker-compose.yml` — `amqp://localhost:5672`) from `AOI_Main`? If so, what topics?
2. Does `AOI_Main` use **WCF duplex callbacks** from DataServer? Which notifier proxies?  
   (`ScanResultsNotifierProxy`, `VerificationNotifierProxy`, `CmmServiceNotifierProxy`)
3. Are there any **C# events/delegates** (`event EventHandler<T>`) already defined in the TestAutomationSDK that `AOI_Main` builds on?
4. Does `AOI_Main` use `log4net` or Serilog? Where are log files written?
5. Any use of `System.Reactive` (Rx.NET) or `IObservable<T>` patterns?

---

## Section 5 — Constraints & Non-Negotiables

After your analysis, explicitly state:

1. **Threading constraints**: What threads must not be blocked? (COM STA pump, UI thread, grabbing pipeline thread?)
2. **COM apartment constraints**: What COM callbacks fire on which thread, and what marshalling is required?
3. **Latency requirements**: Which state domains need <10ms notification? Which can tolerate 100ms+?
4. **Existing patterns to preserve**: Which patterns in the codebase must the new state model conform to (to avoid a total rewrite)?
5. **Integration points that cannot be changed**: Existing COM interfaces, WCF contracts, IPC channels — list what is frozen.

---

## Output Format

Produce a **structured findings document** with one section per domain above. Use this exact structure:

```
## [Domain Name]
- **Current mechanism:** ...
- **Owner class/interface:** ...
- **Data model:** (list fields + types)
- **Async/sync:** ...
- **Existing events:** (list or "none")
- **Threading notes:** ...
- **Gaps / unknowns:** ...
```

End with a **Constraints Summary** table:

| Constraint | Details | Impact on state design |
|---|---|---|
| COM STA thread | ... | ... |
| ... | ... | ... |

Do NOT propose solutions yet. Only facts.
