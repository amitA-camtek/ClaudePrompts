````markdown
# Prompt 2 — Deep-Dive: Services & Communication Analysis

> **When to use:** After Prompt 1 (`output/system.md` is already built).  
> **Codebase:** Camtek Falcon monorepo (`CamtekGit`) — semiconductor wafer inspection (AOI / EBI / BSI-HR).  
> Use this prompt to drill deeper into one or more specific services or flows.  
> Pick the relevant Part(s) below and fill in the bracketed choices.

---

You are a **senior software architect**.
You have already completed an initial scan of the Camtek Falcon monorepo and produced `system.md`.
Now I need you to go **deeper** on the following areas.

---

## Part A — Service Deep Dive

Choose one of the services below and replace `[SERVICE]`:

| Choice | Service |
|---|---|
| A1 | **DataServer** (`CamtekSoftwareSolutions/dataserver/`) — WCF net.tcp host, 12 endpoints, SQLite + FileDB |
| A2 | **RMS** (`CamtekSoftwareSolutions/rms/`) — ASP.NET Core gRPC-Web + SignalR, JWT, EF Core SQLite |
| A3 | **BSIHR.MainServer** (`BSIHR/Sources/`) — ASP.NET Core Kestrel gRPC server |
| A4 | **MDC** (`CamtekSoftwareSolutions/mdc/`) — WPF Prism client, pure WCF consumer |
| A5 | **BIS / Falcon** (`BIS/Sources/`) — COM-based monolith, 943 C# + 272 C++ projects |
| A6 | **CMM.NET** (`CMM/Sources/`) — VB.NET WinForms, WCF consumer, 300+ converter pipeline |

For the chosen service **[SERVICE]**, analyze and document:

### A.1 — Exposed Interfaces

- **WCF services** (DataServer, CMM, MDC consumer): list every `[ServiceContract]` interface, its `[OperationContract]` methods, request/response types, and the `net.tcp` port it binds on (`8002`–`8272`). Flag duplex callbacks (`IDuplexChannel`).
- **gRPC services** (BSIHR, RMS): list every service in the `.proto` file (BSIHR) or C# `[ServiceContract]` with protobuf-net attributes (RMS). For each RPC: name, request message type, response message type, streaming mode (unary / server-streaming / client-streaming / bidirectional).
- **SignalR hub** (RMS only): hub route (`/notify`), hub methods, pushed DTO types (`ToolChangedDto`, `JobChangedDto`, `DeliveryPlanDto`), auth requirement.
- **COM servers** (BIS only): list DCOM local servers (`AlgManager_d.dll`, `AlgManagerPS_d.dll`, etc.), their IDL interfaces, and which consumers register them.
- **IPC channels** (BIS only): enumerate `GrabIPC`, `AcqIPC`, `DdsIPC` — what data flows, in what direction, at what rate.

### A.2 — Outbound Calls

For every call this service makes to another service or external system, document:
- Target service / SDK
- Trigger (startup, per-scan, per-recipe-deploy, on-demand, timer)
- Exact endpoint / port / topic / COM ProgID called
- Data sent (key fields)
- Data expected back
- Failure behavior (timeout, retry, fallback)

**Specific angles per service:**
- *DataServer*: when does it write to the file-system message queue (`FileSystemMessageProducer` / JSON on disk)? What triggers `CmmTicketCreationRequestMessage` vs `ScanReadyMessage` vs `UpdateInspectionResultsMessage`?
- *RMS Server*: when does it call **RMS Service4Tool** at `http://localhost:5020`? What gRPC method? What payload?
- *BIS*: when does `PizzaServer.exe` or `DdsSrv_d.exe` call into DataServer — which WCF port, which contract, what scan data?
- *CMM.NET*: what does it send to DataServer port `8032` (`Camtek.API.CMM`) per ticket? Fields, sequence.

### A.3 — Database Schema

Produce the full schema for any DB this service owns:

| Service | DB Technology | Known tables / entities |
|---|---|---|
| DataServer | SQLite via LinqToDB + `FileDB.INFS` | [UNCLEAR — enumerate tables] |
| BSIHR | SQLite via EF Core 6 | `RecipeDataContext`: `Recipes`, `Optics`, `AlgoScenarios` — get all columns + FK relationships |
| RMS | SQLite via EF Core 6 | `RMS.sqlite` at `C:\BIS\RMS\Server\RMSStorages` — enumerate all migrations and table columns |

For each table: column names, data types, primary key, indexes, nullable constraints, FK references.

### A.4 — Configuration & Environment

This codebase uses **no `.env` files**. Configuration is via `App.config`, `appsettings.json`, and INI files.

Document for the chosen service:
- Every `App.config` / `appsettings.json` key it reads
- Every INI file path it reads (e.g., `c:\falcon\data\machine\{MachineName}\config.ini`)
- Hard-coded deployment paths (e.g., `c:\bis\bin\`, `c:\Job\`, `c:\BIS\RMS\`) — flag as ⚠️ if not configurable
- Any `[UNCLEAR]` version dependencies (Matrox MIL version, LinqToDB version, BSIHR gRPC port)

### A.5 — Error Handling & Retry

| Area | Known strategy | Investigate further |
|---|---|---|
| WCF (DataServer) | `FaultException<T>` with custom fault contracts in `API/Common/Faults/` | What fault types exist? Are all operations wrapped? |
| gRPC (RMS) | gRPC status codes + Polly retry | Where exactly is Polly configured? What retry count/backoff? |
| File-system queue (DataServer) | Polly retry in `DiskMessageConsumer` | What happens when the disk queue grows unbounded? Is there a dead-letter path? |
| BIS (native COM) | COM `HRESULT` + VB6 `On Error` | Are HRESULT failures surfaced to UI? Any alerting? |
| MDC reconnect | 3-second polling via `ConnectionSwitchManager` | What is the maximum reconnect window? Does it alert the operator? |

### A.6 — Security

| Service | Known mechanism | Gaps to investigate |
|---|---|---|
| DataServer | `Camtek.Auth.Proxy` — `PermissionServiceProxy`, `UserAuthServiceProxy` on port `8012` | Are internal WCF endpoints (`8002`–`8272`) reachable without auth? No TLS on net.tcp? |
| RMS | JWT + OpenSSL X.509 PFX (`CA → server/client`) | Where are certs stored? Rotation process? Revocation? |
| BSIHR | gRPC metadata auth [UNCLEAR] | Determine exact mechanism — is it token, mutual TLS, or no auth? |
| MDC | Proxied through DataServer login dialog | Can a user bypass the dialog and call WCF endpoints directly? |
| BIS COM | DCOM local server | Is DCOM locked to localhost only? DCOM ACLs? |

---

## Part B — Communication Flow Trace

Trace the **complete end-to-end flow** for one of the following Camtek business events.  
Pick the one most relevant to your current work:

| # | Flow |
|---|---|
| B1 | **Wafer scan completes** — BIS finishes scanning a wafer and results propagate to DataServer, then to MDC |
| B2 | **Operator classifies a defect in MDC** — MDC sends verification data back through DataServer |
| B3 | **RMS deploys a recipe to a tool** — RMS Server pushes a job to RMS Service4Tool, tool acknowledges |
| B4 | **CMM processes an inspection ticket** — CMM reads from DataServer CMM API, runs converters, writes report |
| B5 | **BSIHR starts a BSI-HR inspection scan** — UI triggers job via gRPC, server controls hardware, result is stored |

For the chosen flow **[B#]**, show:

```
[1] Component/Service
      action taken (method call / WCF op / gRPC RPC / COM call / file write)
      → data sent { key fields }
    → [2] Next Component

[2] Next Component
      processing
      → data returned or event emitted
    → [3] ...

...continue until all state changes are captured
```

Include:
- Every service or process involved, in execution order
- The **exact** communication mechanism at each hop (WCF port + contract, gRPC service + method, COM ProgID, file-system path, RabbitMQ queue, SignalR hub method)
- Data shape at each hop (key fields, not full schema)
- Async branches (fire-and-forget COM events, WCF duplex callbacks, RabbitMQ publishes, SignalR pushes)
- Final state changes: DB rows written, files written to disk, UI panels updated

---

## Part C — Resolve [UNCLEAR] Items

The following items in `system.md` are marked `[UNCLEAR]`. Investigate each and provide the definitive answer:

| # | [UNCLEAR] item | Where to look |
|---|---|---|
| C1 | BSIHR gRPC port — not determined at build time | `BSIHR.MainServer` `appsettings.json` or `Program.cs` Kestrel config |
| C2 | BSIHR auth mechanism — token, mTLS, or none? | `BSIHR.Client`, `BSIHR.ServerServices` interceptors / headers |
| C3 | DataServer SQLite schema — tables not enumerated | LinqToDB mapping classes in `CamtekSoftwareSolutions/dataserver/` |
| C4 | LinqToDB version in DataServer | `ScanResultsServerAPI.sln` NuGet references |
| C5 | Matrox MIL version | `BIS/Sources/system/MilExt/` or MIL header files |
| C6 | RabbitMQ usage — `WebApiHelper` calls to port 15672 active or legacy? | `Camtek.Common.Tools/WebApiHelper.cs` callers |
| C7 | RMS test coverage — no test project found | Search for `*.Tests.csproj` or `xunit`/`nunit` refs in `rms/` |
| C8 | `pipeline_pr.yml` branch filter — triggers on `main` pushes or only PRs? | `xbuild/pipeline_pr.yml` + `PipelineRepo` `base_pipeline.yml` template |
| C9 | Telerik WPF version in MDC and SystemCalibration | `MDC.sln` and `SystemCalibration.sln` NuGet references |
| C10 | DataServer Polly retry config — count, backoff, what triggers retry | `DiskMessageConsumer` implementation |

---

## Part D — Identify Risks & Gaps

Review the architectural risks already flagged and confirm or expand each, then add any new ones found during this deep dive:

### Known Risks (confirm and expand)

- [ ] **Shared binary coupling**: `SystemCalibration` references `c:\bis\bin\` DLLs directly. `SystemCalibrationDllUpdater` syncs versions — what happens if versions diverge? Is there a version contract?
- [ ] **COM-based IPC in BIS**: `AlgManager`, `Alignment`, `Job`, `PreProc` proxy/stub DLLs — fragile COM registration. What is the registration sequence in `DeployUI2.ps1`? What fails silently if a DLL is unregistered?
- [ ] **File-system message queue in DataServer**: `FileSystemMessageProducer` / `DiskMessageConsumer` (JSON on disk). No DLQ. What is max queue depth? What monitoring exists?
- [ ] **No distributed tracing**: No Jaeger/Zipkin/OpenTelemetry found across 12 WCF endpoints + 9 gRPC services + COM IPC. How are cross-service request failures diagnosed today?
- [ ] **No metrics pipeline**: No Prometheus, Grafana, or similar. Confirm absence and identify what telemetry operators use instead.
- [ ] **Mixed .NET versions**: 4.6.1 / 4.8 / .NET 6 / .NET 7 in same repo. Shared libraries (`LightInfrastructure`, `Camtek.Common.*`) — which TFM do they target? Are there binary compatibility risks?
- [ ] **96 VB6 projects**: COM interop bridges required. What is the migration plan? Which VB6 projects are on the critical call path?
- [ ] **No TLS on WCF net.tcp**: DataServer endpoints (`8002`–`8272`) — confirm whether `NetTcpSecurity` mode is `None`, `Transport`, or `Message`.
- [ ] **Hard-coded deployment paths**: `c:\bis\bin\`, `c:\Job\`, `c:\BIS\RMS\`, `c:\falcon\data\` — list every hard-coded path found and assess reconfigurability.

### New Risk Template

For each new risk found:
```
**Risk:** [Name]
**Location:** [File/module/line reference]
**Impact:** [What breaks, when, and how severely]
**Suggested fix:** [Concrete remediation]
```

---

## Output

Update `system.md` with findings from this deep dive:
- Under each service section: add sub-section `#### [NEW] Deep Dive Findings — [date]`
- Under Section 3 (Communication Map): add any newly discovered hops
- Under Section 5.3 (Observability): add any telemetry found
- Resolve each `[UNCLEAR]` item inline — replace the tag with the discovered value
- Add a new **Section 10 — Risk Register** with all confirmed and new risks in priority order (Critical / High / Medium / Low)

Mark all new content with `[NEW]`.
````
