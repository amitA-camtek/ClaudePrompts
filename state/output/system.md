# system.md — Camtek Falcon Codebase Architecture

> **Generated:** 2026-04-04  
> **Repo:** `CamtekGit` (monorepo)  
> **CI/CD:** Azure DevOps Pipelines  
> **Domain:** Semiconductor Wafer Inspection (AOI / EBI / BSI-HR)

---

## 1. Repository & Project Layout

### 1.1 Top-Level Folder Structure

| Folder | Purpose |
|---|---|
| `BIS/` | **Board Inspection System** — the main Falcon AOI/EBI platform (largest component) |
| `BSIHR/` | **BSI High Resolution** — bump/wafer inspection, client-server architecture (gRPC) |
| `CMM/` | **Coordinate Measuring Machine** — ticket processing, converter engine, report generation |
| `CmmLightConverters/` | 300+ file-format converters for inspection results (KLARF, SEMI E142, CSV, Excel, etc.) |
| `CamtekSoftwareSolutions/` | Multi-project area: **DataServer**, **MDC**, **RMS**, shared utilities |
| `CamtekSoftwareSolutionsOld/` | Legacy snapshot of CamtekSoftwareSolutions (pre-.NET 4.8 upgrade) |
| `SystemCalibration/` | Hardware calibration desktop application (Prism/MEF + WPF) |
| `ToolAnalytics/` | Light Channel Calibration (LCC) validation tool (.NET 7 WPF) |
| `DevelopmentTools/` | `LogLens` — real-time log viewer/analyzer (.NET 7 WPF) |
| `Falcon/` | Machine data & configuration files (CDAT, Machine, ToolManagement) |
| `Install/` | Installer scripts, iTOOLS HTML vizualizations, Matlab utils, testing apps |
| `DeployUI/` | Developer workstation build & deployment orchestrator (PowerShell + WPF GUI) |
| `ExternalTools/` | FiltAir cleanroom system updater |
| `Packages/` | Locally committed NuGet packages (EF Core, etc.) |
| `UnitTestsData/` | Shared test fixture data files |
| `Logs/` | MSBuild binary logs and timing reports |
| `xbuild/` | Azure DevOps pipeline YAML definitions |
| `xgitscripts/` | `CreatePR.exe` — Azure DevOps PR creation CLI tool |
| `AZDO_72465/` | Investigation logs for Azure DevOps work item #72465 |
| `01-03-26_SW_QA-1_5.10.0-4501_Logs_GRAB_AFTER_MERGE/` | QA diagnostic log capture |

### 1.2 Project Type

**Monorepo** — a single Git repository containing ~15 distinct applications/services, shared libraries, build infrastructure, tooling, machine data, and 300+ converters. Uses **Git LFS** extensively for binary assets (`.dll`, `.exe`, `.ocx`, `.tlb`, `.lib`, `.pdb`, `.dat`, `.zip`).

### 1.3 Primary Languages & Frameworks per Area

| Area | Languages | Frameworks / Key Tech |
|---|---|---|
| **BIS** | C# (943 projs), C++ native (272 projs), VB.NET (24), VB6 (96) | WPF, WinForms, COM/ActiveX, Matrox MIL, OpenCL/GPU, ONNX, Prism, MSBuild |
| **BSIHR** | C#, C++/CLI, Protobuf | ASP.NET Core (Kestrel), gRPC, EF Core 6 (SQLite), WPF (.NET 6) |
| **CMM** | VB.NET, C# | WinForms, NUnit, .NET Framework 4.8 |
| **CmmLightConverters** | C# | .NET Framework 4.8, NUnit, Excel COM Interop |
| **DataServer** | C# | WCF (`net.tcp`), LinqToDB (SQLite), protobuf-net, .NET Framework 4.8 |
| **MDC** | C# | WPF, Prism 6 (Unity), WCF client proxies, .NET Framework 4.8 |
| **RMS** | C# | ASP.NET Core (.NET 6), gRPC (code-first protobuf-net), SignalR, EF Core 6 (SQLite), JWT, Serilog |
| **SystemCalibration** | C#, C++ (post-build) | WPF, Prism 5 (MEF), Telerik, .NET Framework 4.6.1 |
| **ToolAnalytics** | C# | WPF (.NET 7), CommunityToolkit.Mvvm, LiveCharts |
| **LogLens** | C# | WPF (.NET 7), .NET Standard 2.1, TCP streaming |
| **DeployUI** | PowerShell | WPF GUI (XAML), MSBuild orchestration |
| **Install/iTOOLS** | HTML/JavaScript | Plotly.js, math.js |

### 1.4 Configuration Files

| Type | Location | Notes |
|---|---|---|
| **CI/CD Pipelines** | `xbuild/pipeline_ci.yml` | CI build — extends `ci_pipeline.yml@PipelineRepo` (Azure DevOps) |
| | `xbuild/pipeline_pr.yml` | PR validation — extends `base_pipeline.yml@PipelineRepo` |
| | `xbuild/pipeline_rel.yml` | Release — extends `rel_pipeline.yml@PipelineRepo` |
| | `xbuild/pipeline_test.yml` | Compile test — params: singleThreaded, compileLoops, per-solution toggles |
| | `xbuild/sws.yml` | SWS (Software Solutions) build — extends `sws_pipeline.yml@PipelineRepo` |
| | `xbuild/sws_private.yml` | Private SWS build — params: MDC toggle, DATASERVER toggle |
| | `xbuild/sws_private_dev.yml` | Private SWS dev build |
| **Docker Compose** | `BIS/Sources/system/CamtekSystem/PubSub/env/docker-compose.yml` | RabbitMQ 3 (management-alpine), ports 5672/15672 |
| **MSBuild Props** | `BIS/build/Camtek.CSharp.Common.Properties.props` | Shared C# build properties |
| | `BIS/build/Camtek.Cpp.Common.Properties.props` | Shared C++ build properties |
| | `BIS/build/Camtek.VBNet.Common.Properties.props` | Shared VB.NET build properties |
| | `BIS/build/COMRegistration.targets` | COM registration post-build |
| | `BSIHR/build/Camtek.CSharp.Common.Properties.props` | BSIHR C# build properties |
| | `CamtekSoftwareSolutions/mdc/Directory.Packages.props` | Central NuGet package management for MDC |
| **NuGet** | `BIS/build/NuGet.config` | NuGet source configuration |
| | `ToolAnalytics/nuget.config` | Local `./packages` folder source only |
| **Git** | `.gitattributes` | Extensive LFS tracking (30+ binary extensions) |
| | `.gitignore` | 553 lines — VS standard + Camtek-specific (`/BIS/bin/x64`, `.claude/`) |
| **AI Workflows** | `.windsurf/workflows/req-verify.md` | Requirements verification workflow |
| | `.windsurf/workflows/coding.md` | Suggest-only coding assistant |
| | `.windsurf/workflows/code-review.md` | Pre-commit code review |
| | `req-build.md` | Requirements building/clarification command |
| **Kubernetes** | None | |
| **Terraform** | None | |
| **`.env` samples** | None found | Configuration via `App.config`, `appsettings.json`, INI files |

---

## 2. Service Inventory

### 2.1 BIS — Board Inspection System (Falcon)

| Field | Details |
|---|---|
| **Name** | BIS / Falcon |
| **Type** | Monolithic desktop application (AOI/EBI machine control) |
| **Language & Framework** | C# (WPF/WinForms), C++ native, C++/CLI, VB.NET, VB6 / .NET Framework 4.8 / COM/ActiveX |
| **Responsibility** | Core semiconductor wafer inspection — image acquisition, defect detection, alignment, calibration, recipe management, machine control, SECS/GEM tool management |
| **Entry Point** | Multiple: `Falcon.Net` (main app), `DdsSrv_d.exe` (DDS process), `PizzaServer.exe` (wafer handling), `StaminaUtils.exe`, `CamtekUtils.exe`, `ScenarioManager.exe`, `JobSelect.Net.exe`, and 60+ specialized apps in `Sources/apps/` |
| **Port** | COM-based IPC (DCOM/local servers), some TCP (WinSock), CAN bus, EtherCAT |
| **Database / Storage** | File-based (scan result files, ticket directories), `DataAccess.dll` (MDB/Access), INI files |

**Sub-module breakdown (key areas):**

| Sub-module | Type | Responsibility |
|---|---|---|
| `Sources/dds/` (~110 modules) | Processing Engine | Defect Detection Server — algorithm pipeline, GPU compute, frame processing |
| `Sources/machine/` (~130 modules) | Hardware Layer | EFEM/loader control, motion (Etel/EtherCAT), safety, IO, CAN bus, SECS/GEM |
| `Sources/objects/` (~65 modules) | Business Objects | Alignment, Job, AutoFocus, DataAccess, WaferInfo, ScanGeometry |
| `Sources/system/` (~120 modules) | Core System | Camera drivers (17 camera types), optics, MIL imaging, scenarios, calibration, PubSub |
| `Sources/Grabbing/` (~27 modules) | Image Acquisition | Camera frame grabbing for Area, Clip, Color, CSP, CTS, IR, TDI cameras |
| `Sources/calibration/` (~35 modules) | Calibration | System calibration algorithms, UI, gain/offset, objective, periodic |
| `Sources/UI/` (6 modules) | Frontend | Falcon WPF main UI, navigation, shared components |
| `Sources/Components/` (~45 modules) | Mid-tier | Display, WaferMap, RTP, ScanResults, Dialogs |
| `Sources/JobParts/` (~35 modules) | Recipe Engine | Job recipe parts — optics config per camera, recipe steps, zones, materials |
| `Sources/ToolManagement/` (~26 modules) | SECS/GEM | Semiconductor equipment integration: `SecsGemClient`, `SecsGemDriver`, `TAC.Net`, `TopiClient.Net` |
| `Sources/Tracing/` (8 modules) | Observability | `CamtekLogger.NET`, `Log4cpp`, `LogManager`, `SystemLogger` |
| `Sources/Automation.Mng/` (4 modules) | Automation | Batch execution, wafer loader, wafer database |
| `Sources/InspecTune/` (10 modules) | Tuning | Inspection parameter tuning system |
| `Sources/TestAutomationAPI/` (~29 modules) | Test Automation | `AOI_Main`, `Engine.FlaUI`, `RunnerGui`, `TestAutomationSDK`, `ReportGenerator` |
| `Sources/Compilation/` (19 tools) | Build Tools | AxInterop, TlbToIdl, VbAnalyzer, RegisterComponent |
| `Sources/Simulator/` (7 modules) | Simulation | Frame simulation, VCam, recording/playback |
| `Sources/Plugins/` (5 modules) | Office Integration | Excel 2003/2016, OpenOffice wrappers |

---

### 2.2 BSIHR — BSI High Resolution

| Field | Details |
|---|---|
| **Name** | BSIHR |
| **Type** | Client-Server desktop application |
| **Language & Framework** | C# (.NET 6), C++/CLI, Protobuf / ASP.NET Core (Kestrel), gRPC, WPF |
| **Responsibility** | BSI High Resolution bump/wafer inspection — image processing, calibration, hardware control |
| **Entry Point** | Server: `BSIHR.MainServer` (ASP.NET Core exe), Client: `BSIHR.UI` (WPF WinExe), DB: `BSIHR.Database` (ASP.NET Core web host) |
| **Port** | gRPC over HTTP/2 — default **`http://127.0.0.1:5678`** (configurable via `AppSettings.MainPortNumber`); ServiceControl on port **1234**; Database server on port **4578** [NEW] |
| **Database / Storage** | SQLite via EF Core 6.0 (`Microsoft.EntityFrameworkCore.Sqlite.Core` 6.0.11); `RecipeDataContext` with `Recipes`, `Optics`, `AlgoScenarios` tables; also SQL Server via `System.Data.SqlClient`. Auth: custom GUID-based ownership token over gRPC metadata — **no TLS, no JWT, no mTLS** (`ChannelCredentials.Insecure`). Client sends session GUID in `"Ownership"` metadata header; server validates via ASP.NET `IAuthorizationHandler` [NEW] |

**BSIHR Modules:**

| Module | Type | Responsibility |
|---|---|---|
| `BSIHR.MainServer` | API (gRPC server) | Central server — hosts all gRPC services |
| `BSIHR.ServerServices` | Library | Server-side service implementations |
| `BSIHR.ImageProc` | Library | Image processing engine with workflows |
| `BSIHR.ImageServices` | Library | Image acquisition/streaming |
| `Calibration.Service` | Library | Camera/system calibration |
| `CalibrationAlgoRunner` | Library | Calibration algorithm execution |
| `BSIHR.ServiceControl` | Library | Service lifecycle control |
| `BSIHR.Client` | Library | gRPC client proxy |
| `BSIHR.ClientServices` | Library | Client-side service layer |
| `BSIHR.UI` | Frontend (WPF) | Desktop application |
| `BSIHR.UI.Calibration` | Frontend Module | Calibration UI pages |
| `BSIHR.UI.Common` | Library | Shared UI controls |
| `BSIHR.UI.Themes` | Library | WPF themes/resource dictionaries |
| `BSIHR.UI.Infrastructure` | Library | UI DI, navigation |
| `BSIHR.SimDeployer` | Tool | Simulator deployment |
| `BSIHR.Common` | Library | Shared models, events, helpers |
| `BSIHR.Services.Common` | Library | **gRPC Protobuf service contracts** (`.proto` files) |
| `BSIHR.JobClient` | Library | Job scheduling client |
| `BSIHR.DataContext` | Library | EF Core `DbContext` (SQLite) |
| `BSIHR.Database` | API (web host) | Database server |
| `BSIHR.DataServices` | Library | Data service interfaces |
| `BSIHR.AppEntities` | Library | Domain entities (Job, Light, AlgoScenarios) |
| `BSIHR.Algo` suite (9 modules) | Library | Native algorithm wrappers: `BSIHR.Algo`, `BSIHR.Calib`, `BSIHR.Projections`, `BSIAlignImp`, `BSIEdgeDetect`, `NotchDetection`, `WaferMosaicCLI/Imp` |
| `BSIHR.HW` suite | Library | Hardware abstraction: drivers, chuck, scan routes, CAN bus, STIL camera |

---

### 2.3 DataServer (ScanResultsServerAPI)

| Field | Details |
|---|---|
| **Name** | DataServer / ScanResultsServerAPI |
| **Type** | Multi-service WCF host (Tier 1 architecture) |
| **Language & Framework** | C# / .NET Framework 4.8, WCF (`net.tcp`), LinqToDB, protobuf-net |
| **Responsibility** | Centralized data services for inspection results — scan results CRUD, verification, classification, wafer layout, images, CMM integration, user auth |
| **Entry Point** | `DataServer.Host` (WCF ServiceHost, `Tier1/Modules/DataServer/Host/`) |
| **Port** | See port table below |
| **Database / Storage** | SQLite via LinqToDB **2.6.4** (`SQLiteDataProvider`), file-based inspection DB (`FileDB.INFS`), file-system message queue (JSON on disk). DB path: `C:\bis\data\SWS\dataserver\DataServerDB.sqlite3`. Auth DB: `C:\bis\data\SWS\dataserver\Auth.db3` [NEW] |

**DataServer Port Map:**

| Port | Protocol | Service |
|---|---|---|
| `8002` | `net.tcp` | MainServer |
| `8012` | `net.tcp` | UserAuth |
| `8022` | `net.tcp` | Identification |
| `8032` | `net.tcp` | CMM |
| `8202` | `net.tcp` | T1.ScanResults |
| `8212` | `net.tcp` | T1.Classifiers |
| `8222` | `net.tcp` | T1.WaferLayout |
| `8232` | `net.tcp` | T1.DiceAttributes |
| `8242` | `net.tcp` | T1.Images |
| `8252` | `net.tcp` | T1.VerificationImages |
| `8262` | `net.tcp` | T1.Verification |
| `8272` | `net.tcp` | T1.InspectionResult |

Port naming convention: `8XY2` where X=priority, Y=service, 2=net.tcp.  
Default base address: `net.tcp://localhost:8000/DataServer`

**DataServer API Modules:**

| API Module | Responsibility |
|---|---|
| `Camtek.API.MainServer` | Master server coordination |
| `Camtek.API.ScanResults` | Scan results CRUD + events |
| `Camtek.API.InspectionResults` | Inspection result data |
| `Camtek.API.Verification` | Defect verification + events |
| `Camtek.API.VerificationImage` | Verification images |
| `Camtek.API.Images` | Image storage/retrieval |
| `Camtek.API.WaferLayout` | Wafer layout + models |
| `Camtek.API.Classifiers` | Defect classifiers |
| `Camtek.API.DiceAttributes` | Die-level attributes |
| `Camtek.API.Users` | User management |
| `Camtek.API.IIdentification` | Identity services |
| `Camtek.API.CMM` | CMM integration + events |
| `Camtek.API.VirtualData` | Virtual/plugin data |

---

### 2.4 MDC — Manual Defect Classification

| Field | Details |
|---|---|
| **Name** | MDC |
| **Type** | Frontend (WPF desktop client) |
| **Language & Framework** | C# / .NET Framework 4.8, WPF, Prism 6 (Unity), WCF client proxies |
| **Responsibility** | Manual defect classification — wafer/die/defect visualization, verification workflows, lot management, user auth |
| **Entry Point** | `MDC/App.xaml.cs` → Prism `UnityBootstrapper` → loads `MDC.MainModule` |
| **Port** | None (client-only) |
| **Database / Storage** | None directly — all data via WCF to DataServer; local XML/cache for snapshots |

---

### 2.5 RMS — Recipe Management System

| Field | Details |
|---|---|
| **Name** | RMS |
| **Type** | 3-tier: API Server + Tool Agent + WPF Client + Background Worker |
| **Language & Framework** | C# / .NET 6.0, ASP.NET Core, gRPC (protobuf-net code-first), SignalR, EF Core 6 (SQLite), JWT, Serilog |
| **Responsibility** | Recipe/job lifecycle — upload, deploy, archive, qualify, remove jobs across servers and tools |
| **Entry Point** | Server: `Camtek.RMS.Service/Program.cs`, Tool: `Camtek.RMS.Service4Tool/Program.cs`, Client: `Camtek.RMS/App.xaml.cs`, Worker: `Camtek.Rms.Worker/Program.cs` |
| **Port** | Server: `5001`, Tool Agent: `5020` |
| **Database / Storage** | SQLite via EF Core 6 (`Data Source={RMSPath}\RMS.sqlite`), file system storage (`C:\BIS\RMS\Server\RMSStorages` server, `C:\Job` tool) |

**RMS gRPC Services:**

| Service | Responsibility |
|---|---|
| `AuthService` | JWT authentication |
| `JobService` | Job/recipe CRUD and lifecycle |
| `ToolService` | Tool registration and management |
| `StorageService` | File storage operations |
| `NotifierService` | Real-time event notification |
| `HistoryService` | Job history and audit trail |
| `TimeService` | Server time synchronization |
| `ReportsService` | Recipe report generation |
| `SettingsService` | System settings management |

**RMS SignalR Hub:** `/notify` — pushes `ToolChangedDto`, `JobChangedDto`, `DeliveryPlanDto`

---

### 2.6 CMM — Coordinate Measuring Machine

| Field | Details |
|---|---|
| **Name** | CMM.NET |
| **Type** | Desktop application (WinForms) |
| **Language & Framework** | VB.NET (main app), C# (support modules) / .NET Framework 4.8, WinForms, NUnit |
| **Responsibility** | Inspection ticket processing — converter engine, report generation, wafer map matching, parallel export |
| **Entry Point** | `CMM.NET.Main` (VB.NET WinExe, `Sub Main` startup) |
| **Port** | None (desktop) |
| **Database / Storage** | MDB/Access via `DataAccess.dll`, file-based ticket directories, connects to DataServer via WCF (`Camtek.API.CMM`) |

**CMM Sub-modules:**

| Module | Responsibility |
|---|---|
| `CMM.NET` | Core converter engine, KLARF viewer, map parsing |
| `CMM_Parallel` | Parallel export/conversion (WinForms) |
| `CMM_Parallel_Runner` | WPF runner GUI for parallel CMM |
| `CMM_Parallel.Common` | Shared parallel execution types |
| `CMM_Utils` | Utilities (alerts, progress) |
| `CMMParamsCollection` | Parameter collection parsing |
| `CMMExecuteAssembly` | Console exe for converter execution |
| `CMM_BadTicketRestorator` | Corrupted ticket restoration |
| `GraphControls` | Wafer map / defect visualization WinForms controls |
| `LightInfrastructure` | Lightweight infrastructure shared with CmmLightConverters |
| `Plugins/` | Spreadsheet wrappers: Excel 2003/2016, LibreOffice, OpenOffice |

---

### 2.7 CmmLightConverters

| Field | Details |
|---|---|
| **Name** | CmmLightConverters |
| **Type** | Library (300+ converters) |
| **Language & Framework** | C# / .NET Framework 4.8 |
| **Responsibility** | File format conversion for semiconductor inspection results — KLARF, SEMI E142, SINF, CSV, Excel, TDX, and 300+ customer-specific formats (Samsung, TSMC, Intel, Hynix, Infineon, etc.) |
| **Entry Point** | Library: `CmmLightConverters.dll` (loaded by CMM.NET); CLI: `ExecuteMethod` console exe |
| **Port** | None |
| **Database / Storage** | File I/O (reads inspection data, writes converted reports) |

---

### 2.8 SystemCalibration

| Field | Details |
|---|---|
| **Name** | SystemCalibration |
| **Type** | Desktop application (WPF, plugin-based) |
| **Language & Framework** | C# / .NET Framework 4.6.1, WPF, Prism 5 (MEF), Telerik UI |
| **Responsibility** | Hardware calibration — cameras (2D, Clip, Clip2, Color, CTS, CSP, IRScan, TDI, CCS), optics, chuck, positions |
| **Entry Point** | `SystemCalibration.Shell/App.xaml.cs` → `NGSUIBootsrapper : MefBootstrapper` |
| **Port** | None |
| **Database / Storage** | None — interfaces with BIS hardware layer via DLL references from `c:\bis\bin\` |

**Dynamically loaded modules (from ModuleCatalog XAML):**
`System.DataContext`, `System.ModuleInits.Machine`, `System.Hardware.Chuck`, `CameraManager`, `System.Hardware.Cameras`, `Camera2D`, `CameraClip2`, `CameraClip`, `CameraColor`, `CameraCTS`, `CameraCSP`, `CameraIRScan`, `CameraTDI`, `CameraCCS`, `System.Optics.Converters`, `System.Optics.Services`, `IntegrationTests`, `CcsTools`, `HighMagCalPlugin`

---

### 2.9 ToolAnalytics

| Field | Details |
|---|---|
| **Name** | ToolAnalytics |
| **Type** | Desktop application (WPF standalone) |
| **Language & Framework** | C# / .NET 7.0, WPF, CommunityToolkit.Mvvm, LiveCharts.Wpf, MS.Extensions.DI |
| **Responsibility** | Light Channel Calibration (LCC) validation — reads machine config INI files, displays calibration parameters, color filter analysis, charting |
| **Entry Point** | `ToolAnalytics.Ui/App.xaml` → `Bootstrapper.cs` |
| **Port** | None |
| **Database / Storage** | File system — reads `c:\falcon\data\machine\{MachineName}\config.ini`, LCC files, color filter configs |

---

### 2.10 LogLens

| Field | Details |
|---|---|
| **Name** | LogLens |
| **Type** | Development tool (WPF + TCP sniffer agent) |
| **Language & Framework** | C# / .NET 7.0 (UI), .NET Standard 2.1 (Core) |
| **Responsibility** | Real-time log viewer — online TCP streaming from remote sniffers, offline file analysis, structured log parsing (log4net format), query language |
| **Entry Point** | `LogLens.Ui` (WPF WinExe) |
| **Port** | TCP (dynamic — sniffer-to-UI streaming) |
| **Database / Storage** | None — streams/reads log files |

---

### 2.11 DeployUI

| Field | Details |
|---|---|
| **Name** | DeployUI2 |
| **Type** | Developer Tool (PowerShell + WPF GUI) |
| **Language & Framework** | PowerShell |
| **Responsibility** | Developer workstation orchestrator — git pull, MSBuild compilation of all solutions (Falcon, EBI, FAR, TestAutomation, CMM, Common, SystemCalibration), COM registration, binary deployment, simulator mode |
| **Entry Point** | `DeployUI2.cmd` → `DeployUI2.ps1` |
| **Port** | None |
| **Database / Storage** | None |

---

## 3. Communication Map

### 3.1 Inter-Service Communication

| Source | Target | Protocol | Method/Endpoint | Auth | Notes |
|---|---|---|---|---|---|
| **MDC** | **DataServer** (MainServer) | WCF `net.tcp` | `net.tcp://localhost:8002/DataServer` | Auth proxy | Sync, duplex callbacks |
| **MDC** | **DataServer** (ScanResults) | WCF `net.tcp` | `net.tcp://localhost:8202/...` | Auth proxy | Duplex — `ScanResultsNotifierProxy` for push events |
| **MDC** | **DataServer** (Verification) | WCF `net.tcp` | `net.tcp://localhost:8262/...` | Auth proxy | Duplex — `VerificationNotifierProxy` |
| **MDC** | **DataServer** (CMM) | WCF `net.tcp` | `net.tcp://localhost:8032/...` | Auth proxy | Duplex — `CmmServiceNotifierProxy` |
| **MDC** | **DataServer** (InspectionResults) | WCF `net.tcp` | `net.tcp://localhost:8272/...` | Auth proxy | Sync |
| **MDC** | **DataServer** (DiceAttributes) | WCF `net.tcp` | `net.tcp://localhost:8232/...` | Auth proxy | Sync |
| **MDC** | **DataServer** (Classifiers) | WCF `net.tcp` | `net.tcp://localhost:8212/...` | Auth proxy | Sync |
| **MDC** | **DataServer** (VerificationImage) | WCF `net.tcp` | `net.tcp://localhost:8252/...` | Auth proxy | Sync |
| **MDC** | **DataServer** (Images) | WCF `net.tcp` | `net.tcp://localhost:8242/...` | Auth proxy | Sync |
| **MDC** | **DataServer** (WaferLayout) | WCF `net.tcp` | `net.tcp://localhost:8222/...` | Auth proxy | Sync |
| **MDC** | **DataServer** (Users) | WCF `net.tcp` | `net.tcp://localhost:8012/...` | Auth proxy | Sync |
| **CMM** | **DataServer** (CMM API) | WCF `net.tcp` | `Camtek.API.CMM` on port 8032 | Auth proxy | Sync — ticket operations |
| **BIS (Falcon)** | **DataServer** | WCF `net.tcp` | Various API contracts | Auth proxy | Scan result submission, image upload |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC (HTTP/2) | Protobuf services (see below) | gRPC metadata | Sync |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `CalibrationService` | gRPC metadata | Calibration operations |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `HardwareService` | gRPC metadata | Hardware control |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `JobService` | gRPC metadata | Job/recipe management |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `LoaderService` | gRPC metadata | Wafer handling |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `CameraServiceClient` | gRPC metadata | Camera control |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `NavigatorServiceClient` | gRPC metadata | Stage navigation |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `OwnershipServiceClient` | gRPC metadata | Resource ownership |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `ScenarioServiceClient` | gRPC metadata | Scan scenarios |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `ServiceControlClient` | gRPC metadata | Service lifecycle |
| **BSIHR.UI** | **BSIHR.MainServer** | gRPC | `AlgorithmsServiceClient` | gRPC metadata | Algorithm execution |
| **RMS Client** | **RMS Server** | gRPC-Web | `http://localhost:5001` (9 services) | JWT Bearer | Sync; all endpoints `.EnableGrpcWeb()` |
| **RMS Client** | **RMS Server** | SignalR | `http://localhost:5001/notify` | JWT Bearer | Async push — `ToolChangedDto`, `JobChangedDto`, `DeliveryPlanDto` |
| **RMS Server** | **RMS Service4Tool** | gRPC-Web | `http://localhost:5020` | JWT Bearer | Tool-to-server recipe sync |
| **LogLens.Sniffer** | **LogLens.Ui** | TCP | Raw TCP stream | None | Async — `OutputDebugString` capture |
| **BIS (PubSub)** | **RabbitMQ** | AMQP | Port 5672 | guest/guest | Async pub/sub messaging |
| **DataServer** internal | **File-system queue** | File I/O | JSON files on disk | None | Async — `FileSystemMessageProducer` / `DiskMessageConsumer` with Polly retry |
| **BIS (DDS)** | **BIS (main)** | COM IPC | DCOM local server | None | In-process / cross-process COM |
| **BIS (Grabbing)** | **BIS (DDS)** | IPC | `GrabIPC` / `AcqIPC` / `DdsIPC` | None | Named-pipe-style IPC for frame data |
| **BIS (machine)** | Hardware | CAN bus | `CanApi`, `CanSrv` | None | Hardware I/O |
| **BIS (machine)** | Hardware | EtherCAT | `EtherCATDriver` | None | Motion control |
| **BIS (machine)** | Hardware | Modbus | `ModBusIO` | None | I/O controller |
| **BIS (machine)** | Hardware | TCP/Socket | `WinSockTcp`, `CommunicationSrv` | None | Equipment comm |
| **BIS (machine)** | EFEM | E84 | `E84Driver` | None | Wafer load/unload |
| **BIS (ToolManagement)** | Factory Host | SECS/GEM (HSMS) | `SecsGemClient`, `SecsGemDriver` | None | Semiconductor equipment standard |
| **BIS** | **SystemCalibration** | DLL | Direct DLL references from `c:\bis\bin\` | None | ⚠️ **Shared binaries** — tight coupling |
| **CmmLightConverters** | **CMM** | DLL | `LightConvertersDllHandler` loads `CmmLightConverters.dll` | None | Library loading |
| **DataServer** | RabbitMQ mgmt | HTTP | `http://localhost:15672` (guest/guest) | Basic | Via `WebApiHelper` — [UNCLEAR if actively used or legacy] |

### 3.2 Code Smells / Architectural Notes

| Issue | Details |
|---|---|
| ⚠️ **Shared binary coupling** | SystemCalibration references BIS DLLs directly from `c:\bis\bin\`. `SystemCalibrationDllUpdater` syncs versions. |
| ⚠️ **COM-based IPC** | BIS relies heavily on COM inter-process communication with proxy/stub DLLs (AlgManager, Alignment, Job, PreProc) — fragile registration dependency |
| ⚠️ **File-system message queue** | DataServer uses JSON-on-disk queuing (`FileSystemMessageProducer` / `DiskMessageConsumer`) instead of a proper message broker for core messaging |
| ⚠️ **Mixed .NET versions** | .NET Framework 4.6.1 (SystemCalibration), 4.8 (BIS, DataServer, MDC, CMM), .NET 6 (BSIHR, RMS), .NET 7 (ToolAnalytics, LogLens) |
| ⚠️ **VB6 legacy** | 96 VB6 projects still in BIS, requiring COM interop bridges |

---

## 4. Data Models & Contracts

### 4.1 Core Domain Entities

| Entity | Owner Service | Notes |
|---|---|---|
| Wafer | BIS (WaferInfo), DataServer (WaferLayout) | Wafer identification, layout, die map |
| Die | BIS (objects), DataServer (DiceAttributes) | Die coordinates, classification, attributes |
| Defect | BIS (dds), DataServer (InspectionResults) | Detection results, classification, images |
| ScanResult | BIS, DataServer (ScanResults) | Full scan result sets |
| Ticket | DataServer, CMM | Inspection ticket lifecycle |
| Job / Recipe | BIS (Job.NET), BSIHR (AppEntities), RMS (JobService) | Inspection recipe definition |
| Verification | DataServer (Verification) | Manual review records |
| Classifier | DataServer (Classifiers) | Defect classification rules |
| User | DataServer (Users), RMS (AuthService) | Authentication & authorization |
| Frame | BIS (Grabbing, dds) | Acquired image frames |
| CalibrationData | BIS (calibration), BSIHR (CalibrationService) | Hardware calibration parameters |
| GoldenImage | BIS (processing) | Reference images for comparison |
| AlgoScenario | BSIHR (AppEntities) | Algorithm configuration |

### 4.2 Shared Contracts & Schemas

| Contract Type | Location | Format |
|---|---|---|
| **gRPC Protobuf** (BSIHR) | `BSIHR/Sources/BSIHR.Services.Common/` | `.proto` files: `CalibrationData.proto`, `CalibrationService.proto`, `HardwareData.proto`, `HardwareService.proto`, `JobData.proto`, `JobService.proto`, `LoaderData.proto`, `LoaderService.proto` |
| **gRPC code-first** (RMS) | `CamtekSoftwareSolutions/rms/Camtek.RMS.Contracts/` | C# interfaces with protobuf-net attributes (code-first, no `.proto` files) |
| **WCF Data Contracts** (DataServer) | `CamtekSoftwareSolutions/dataserver/API/*/Contracts/` | C# `[DataContract]` classes per service module |
| **Queue Messages** (DataServer) | `CamtekSoftwareSolutions/dataserver/Camtek.QueueMessages/` | protobuf-net serialized: `CMMBaseRequest`, `CMMExportRequest`, `CmmTicketCreationRequestMessage`, `CmmTicketState`, `ExportMapMessage`, `ScanReadyMessage`, `ScanResultChangedMessage`, `SaveWaferVerificationProcessChangesMessage`, `UpdateDiceClassChangesMessage`, `UpdateInspectionResultsMessage` |
| **COM Type Libraries** (BIS) | `BIS/bin/Win32.tlb` and various `*PS_d.dll` | COM IDL/TLB for `AlgManager`, `Alignment`, `Job`, `PreProc`, `AlgObjects`, `utils` |
| **Shared Globals** | `CamtekSoftwareSolutions/dataserver/Camtek.Shared.Global/` | Cross-cutting shared types |
| **External Verification Data Model** | `CamtekSoftwareSolutions/dataserver/Camtek.ExternalVerificationDataModel/` | Verification data exchange format |

### 4.3 Shared Libraries for Contracts

| Library | Used By | Purpose |
|---|---|---|
| `Camtek.Auth.Proxy` | DataServer, MDC | WCF auth service proxy (`PermissionServiceProxy`, `UserAuthServiceProxy`, `UserServiceProxy`) |
| `Camtek.Common.WCF.ServiceModel` | DataServer | Custom WCF bindings, duplex, utilities |
| `Camtek.QueueSharedModels` | DataServer internal | File-system queue: `FileSystemMessageProducer`, `DiskMessageConsumer` |
| `Camtek.Common.Logging` | DataServer | log4net-based logging |
| `Camtek.Common.Tools` | DataServer | HTTP helpers (`WebApiHelper`) |
| `CamtekSoftwareSolutions/Common/` | Multiple | Shared: `AssemblyInfo/`, `Coordinatesystems/`, `Extensions/`, `References/` |
| `LightInfrastructure` | CMM, CmmLightConverters | Shared lightweight infrastructure |
| `BIS/Sources/system/System.Common/` | BIS-wide | Common system types |

---

## 5. Infrastructure & Dependencies

### 5.1 External Third-Party APIs / SDKs

| Dependency | Used By | Purpose |
|---|---|---|
| **Matrox MIL** (Matrox Imaging Library) | BIS (`MilExt`, `MilWrapper`, `ManagedMil`, `RadientConnector/Controller`) | Image acquisition and processing — core imaging SDK |
| **ONNX Runtime** | BIS (`OnnxWrapper` in `Sources/dds/`) | ML model inference for defect detection |
| **Cimetrix** | BIS (`SecsGemClient`, `SecsGemDriver`) | SECS/GEM semiconductor equipment communication |
| **Telerik UI for WPF** | MDC, SystemCalibration | `RadGridView`, `RadWindow`, UI controls |
| **LiveCharts.Wpf** | ToolAnalytics | Charting |
| **Plotly.js** | Install/iTOOLS | Browser-based visualization |
| **ETEL** | BIS (`EtelDriver`) | Motion controller SDK |
| **EtherCAT** | BIS (`EtherCATDriver`) | Real-time motion bus |
| **STIL** | BIS (`StilScanner`), BSIHR (`BSIHR.HW`) | Confocal chromatic sensor |
| **Cognex** | BIS (`Scripts/CognexOCR1700`) | OCR vision system |
| **OpenCL** | BIS (~15 modules) | GPU-accelerated algorithms |
| **FiltAir** | ExternalTools | Cleanroom air filtration |

### 5.2 Auth / Identity Provider

| System | Auth Mechanism |
|---|---|
| **DataServer** | Custom WCF auth — `Camtek.Auth.Proxy` (`PermissionServiceProxy`, `UserAuthServiceProxy`, `UserServiceProxy`), WCF port 8012 |
| **RMS** | Custom JWT — `JwtMiddleware` on server, `Bearer` token via gRPC metadata; ASP.NET Identity with SQLite backend; OpenSSL X.509 certificates (CA → server/client PFX) |
| **MDC** | Proxied through DataServer auth (login dialog → `UserAuthServiceProxy`) |
| **BSIHR** | gRPC metadata-based auth [UNCLEAR — specific mechanism not determined] |

### 5.3 Observability Stack

| Component | Technology | Details |
|---|---|---|
| **Logging (BIS)** | log4net + custom | `CamtekLogger.NET`, `Log4cpp` (native), `LogManager`, `SystemLogger`, `CamtekLogAppenders` |
| **Logging (DataServer)** | log4net | `Camtek.Common.Logging` (log4net wrapper) |
| **Logging (RMS)** | Serilog | Console + File sinks; server: `c:/bis/ErrorLog/RMS/Camtek.RMS.Server_.log`, tool: `...Serice4Tool_.log`, client: `...Camtek.RMS_.log` |
| **Logging (ToolAnalytics)** | log4net 3.0.4 | Console + File (`C:\Temp\ToolAnalytics\ToolAnalytics.log`, rolling 10MB×5) + `CamtekIndexedFileAppender` (`c:\bis\errorlog`, 21 days, 1GB max) |
| **Logging (MDC)** | log4net | Via infrastructure |
| **Audit Logging** | Serilog (RMS) | Separate audit trail: `C:/Bis/SystemAudit/RMS/AuditLogServer_.log` |
| **Log Viewer** | LogLens | Real-time log viewer/analyzer with TCP sniffer agents, structured parsing, query language |
| **Performance Timing** | Custom `TimeLogger` (BIS/dds) | C++ timing instrumentation for DDS pipeline |
| **System Logger UI** | BIS (`SystemLoggerUI`) | Built-in log viewer for BIS |
| **Metrics** | [UNCLEAR] | No Prometheus, Grafana, or OpenTelemetry found |
| **Tracing** | [UNCLEAR] | No distributed tracing (Jaeger, Zipkin) found |

### 5.4 CI/CD Pipeline

| Pipeline | File | Template (from `PipelineRepo`) | Trigger | Purpose |
|---|---|---|---|---|
| CI | `xbuild/pipeline_ci.yml` | `ci_pipeline.yml` | `main` | Continuous integration build |
| PR | `xbuild/pipeline_pr.yml` | `base_pipeline.yml` | `main` | Pull request validation |
| Release | `xbuild/pipeline_rel.yml` | `rel_pipeline.yml` | `main` | Release build |
| Test | `xbuild/pipeline_test.yml` | `test_pipeline.yml` | `main` | Configurable compile testing (params: singleThreaded, compileLoops, per-solution toggles for FS_COMMON, FS_EBI_ONLY, Falcon_2022) |
| SWS | `xbuild/sws.yml` | `sws_pipeline.yml` | `main` | Software Solutions (DataServer+MDC+RMS) build |
| SWS Private | `xbuild/sws_private.yml` | `sws_pipeline_private.yml` | `main` | Private SWS build (params: MDC, DATASERVER toggles) |
| SWS Private Dev | `xbuild/sws_private_dev.yml` | [UNCLEAR] | `main` | Dev private build |

All pipelines use **Azure DevOps Pipelines** with templates from an external `Git/PipelineRepo` repository.

**Local build orchestration:** `DeployUI2.ps1` (PowerShell + WPF GUI) — builds solutions via MSBuild locally, handles COM registration, binary deployment.

**Distributed compile farm:** `BIS/comp1.cmd` through `comp5.cmd` — distribute source to 5 compilation machines (`\\comp_1` – `\\comp_5`) for parallel builds.

---

## 6. Known Patterns & Conventions

### 6.1 Naming Conventions

| Element | Convention | Examples |
|---|---|---|
| **C# projects** | `Camtek.{Area}.{Module}` or `{Area}.{Module}` | `Camtek.API.ScanResults`, `System.Hardware.Cameras.Camera2D`, `BSIHR.ImageProc` |
| **C++ projects** | Short names, sometimes with `_d` debug suffix | `AlgManager_d.dll`, `MilExt`, `DdsProcessor` |
| **COM DLLs** | `{Name}_d.dll` + `{Name}PS_d.dll` (proxy/stub) | `AlgManager_d.dll` / `AlgManagerPS_d.dll` |
| **Namespaces** | Match project name | `Camtek.API.ScanResults`, `BSIHR.Common` |
| **Solution files** | Descriptive, underscored | `Falcon_2022.sln`, `FS_COMMON.sln`, `FS_EBI_ONLY.sln` |
| **Build props** | `Camtek.{Lang}.Common.Properties.props` | `Camtek.CSharp.Common.Properties.props`, `Camtek.Cpp.Common.Properties.props` |
| **Env vars** | [UNCLEAR] | No `.env` files found; configuration via `App.config`, `appsettings.json`, INI |
| **Folders** | PascalCase | `ScanResults`, `WaferLayout`, `CameraManager` |
| **File paths (machine)** | `c:\bis\bin\`, `c:\falcon\data\`, `c:\bis\errorlog\`, `c:\Job\` | Standard deployment paths |

### 6.2 Error Handling Strategy

| Area | Strategy |
|---|---|
| **WCF (DataServer)** | `FaultException<T>` with custom fault contracts (`API/Common/Faults/`) |
| **gRPC (RMS)** | gRPC status codes; Polly retry policies for resilience |
| **gRPC (BSIHR)** | Standard gRPC error handling via Grpc.Core |
| **File-system queue** | Polly retry policies in `DiskMessageConsumer` |
| **BIS (native)** | COM `HRESULT` error codes, VB6 `On Error` handlers |
| **MDC** | Auto-reconnect with 3-second polling cycle (`ConnectionSwitchManager`) for lost service connections |
| **General** | log4net / Serilog logging at all levels |

### 6.3 Testing Approach

| Area | Framework | Type | Notes |
|---|---|---|---|
| **BIS** | NUnit, MSTest | Unit + Integration | ~100 test projects in `Sources/tests/`; `TestAutomationAPI` for E2E with FlaUI (UI automation) |
| **BSIHR** | [UNCLEAR] | Integration | `FrameToSectorIntersectionTest` in `Tests/` |
| **CMM** | NUnit | Unit | `CMM.NET.UnitTests` (`[TestFixture]`, `[Test]`) |
| **CmmLightConverters** | NUnit | Unit | 300+ converter tests, test data from FTP `10.5.0.119` |
| **DataServer** | [UNCLEAR] | [UNCLEAR] | Test projects in `CamtekSoftwareSolutionsOld` but not in current |
| **RMS** | [UNCLEAR] | [UNCLEAR] | No test project found in current RMS.sln |
| **MDC** | [UNCLEAR] | [UNCLEAR] | `Camtek.UnitTests` exists in Old version only |
| **SystemCalibration** | `IntegrationTests` | Integration | Loaded dynamically via Prism module catalog |
| **ToolAnalytics** | xUnit/NUnit | Unit | `ToolAnalytics.Tests` (scaffold) |
| **LogLens** | [UNCLEAR] | Unit | `LogLens.Tests` project |
| **Test Automation SDK** | Custom + FlaUI | E2E | `TestAutomationAPI/` with `AOI_Main`, `Engine.FlaUI`, `RunnerGui`, `ResultsComparison`, `ReportGenerator` |
| **Test Data** | Shared | Fixture | `UnitTestsData/` at repo root; NUnit test categories for test organization |

Coverage targets: [UNCLEAR] — no coverage configuration files found.

### 6.4 Branching Strategy

| Aspect | Details |
|---|---|
| **Main branch** | `main` (all pipeline triggers) |
| **PR workflow** | Azure DevOps PRs via `CreatePR.exe` tool (`xgitscripts/CreatePR/`) |
| **Pipeline-based validation** | PR pipeline (`pipeline_pr.yml`) runs on `main` pushes [UNCLEAR — may be branch-filtered in PipelineRepo template] |
| **Strategy** | Likely **trunk-based** or **gitflow-lite** — all pipelines trigger on `main`; PRs via Azure DevOps; AI-assisted workflow (`req-verify` → `coding` → `code-review`) enforces structured handoffs |

### 6.5 AI-Assisted Development Workflow (Camtek Pilot 2026)

| Command | Purpose | Tool |
|---|---|---|
| `/req-build` | Requirements building from ADO work items, text, or files | `req-build.md` |
| `/req-verify` | Requirements verification + codebase impact analysis via Sourcegraph MCP | `.windsurf/workflows/req-verify.md` |
| `/coding` | Suggest-only coding assistance (never writes to production files directly) | `.windsurf/workflows/coding.md` |
| `/code-review` | Pre-commit structured code review anchored to PR Plan | `.windsurf/workflows/code-review.md` |

Integration tools: **Sourcegraph MCP** (http://10.5.1.149) for cross-repo search, **Azure DevOps MCP** for work item management.

---

## 7. Solution Files Summary

### BIS Master Solutions (`BIS/build/`)

| Solution | Scope |
|---|---|
| `Falcon_2022.sln` | **Main Falcon system** — full build |
| `FS_COMMON.sln` | Falcon-System common modules |
| `FS_EBI_ONLY.sln` | EBI-only subset |
| `FalseAlarmReduction.sln` | FAR subsystem |
| `TestAutomationAPI.sln` | Test automation framework |
| `CMM_2023.sln` | CMM integration |
| `DieEdit.sln` | Die editing app |
| `DieReconstructWpf.sln` | Die reconstruction |
| `Calib.sln` | Calibration |
| `Camtek.Display.sln` | Display subsystem |
| `FrameAlignment.sln` | Frame alignment |
| + 42 more specialized solutions | Various subsystems |

### Other Solutions

| Solution | Location |
|---|---|
| `ScanResultsServerAPI.sln` | `CamtekSoftwareSolutions/dataserver/` |
| `MDC.sln` | `CamtekSoftwareSolutions/mdc/` |
| `RMS.sln` | `CamtekSoftwareSolutions/rms/` |
| `Server.sln` / `Client.sln` | `BSIHR/build/` |
| `CmmLightConverters.sln` | `CmmLightConverters/Sources/` |
| `ToolAnalytics.sln` | `ToolAnalytics/` |
| `LogLens.sln` | `DevelopmentTools/LogLens/` |

---

## 8. Quick Reference: Ports & Endpoints

| Service | Port | Protocol | URI |
|---|---|---|---|
| DataServer MainServer | 8002 | `net.tcp` | `net.tcp://localhost:8002/DataServer` |
| DataServer UserAuth | 8012 | `net.tcp` | `net.tcp://localhost:8012/...` |
| DataServer Identification | 8022 | `net.tcp` | `net.tcp://localhost:8022/...` |
| DataServer CMM | 8032 | `net.tcp` | `net.tcp://localhost:8032/...` |
| DataServer ScanResults | 8202 | `net.tcp` | `net.tcp://localhost:8202/...` |
| DataServer Classifiers | 8212 | `net.tcp` | `net.tcp://localhost:8212/...` |
| DataServer WaferLayout | 8222 | `net.tcp` | `net.tcp://localhost:8222/...` |
| DataServer DiceAttributes | 8232 | `net.tcp` | `net.tcp://localhost:8232/...` |
| DataServer Images | 8242 | `net.tcp` | `net.tcp://localhost:8242/...` |
| DataServer VerificationImages | 8252 | `net.tcp` | `net.tcp://localhost:8252/...` |
| DataServer Verification | 8262 | `net.tcp` | `net.tcp://localhost:8262/...` |
| DataServer InspectionResult | 8272 | `net.tcp` | `net.tcp://localhost:8272/...` |
| RMS Server | 5001 | HTTP (gRPC-Web + SignalR) | `http://localhost:5001` |
| RMS Tool Agent | 5020 | HTTP (gRPC-Web) | `http://localhost:5020` |
| RMS SignalR Hub | 5001 | WebSocket | `http://localhost:5001/notify` |
| RabbitMQ AMQP | 5672 | AMQP | `amqp://localhost:5672` |
| RabbitMQ Management | 15672 | HTTP | `http://localhost:15672` |

---

## 9. Technology Version Matrix

| Technology | Version | Used By |
|---|---|---|
| .NET Framework | 4.6.1 | SystemCalibration |
| .NET Framework | 4.8 | BIS, DataServer, MDC, CMM, CmmLightConverters |
| .NET 6.0 | 6.0 | BSIHR, RMS |
| .NET 7.0 | 7.0 | ToolAnalytics, LogLens |
| .NET Standard | 2.1 | LogLens.Core |
| .NET Core | 3.1 | RMS Worker (scaffold) |
| C++ | MSVC (VS2019/2022) | BIS native (DDS, algorithms, grabbing, machine) |
| VB6 | 6.0 | BIS legacy UI/controls (96 projects) |
| EF Core | 6.0.11 | BSIHR, RMS |
| LinqToDB | **2.6.4** | DataServer [NEW] |
| WCF | .NET 4.8 | DataServer (server+client), MDC (client) |
| gRPC | Grpc.Core + Grpc.AspNetCore | BSIHR |
| gRPC (code-first) | protobuf-net.Grpc | RMS |
| SignalR | ASP.NET Core | RMS |
| Prism | 5 (MEF) | SystemCalibration |
| Prism | 6 (Unity) | MDC |
| Serilog | Latest | RMS |
| log4net | 3.0.4 / earlier | BIS, DataServer, MDC, ToolAnalytics |
| NUnit | 3.x | CMM, CmmLightConverters, BIS |
| SQLite | via EF Core / LinqToDB | BSIHR, RMS, DataServer |
| Matrox MIL | **10.0** (header rev 10.50.0734, ©1992–2021) | BIS (core imaging) — SDK at `BIS/Externals/Mil/10.0/X64/` [NEW] |
| Telerik WPF | **2022.1.222.45** (MDC), **2016.2.613.45** (SystemCalibration), **R2 2021** (RMS) | MDC, SystemCalibration, RMS — ⚠️ SystemCalibration is 6 years behind MDC [NEW] |
| CommunityToolkit.Mvvm | 8.4.0 | ToolAnalytics |
| LiveCharts.Wpf | 0.9.7 | ToolAnalytics |
| Polly | **6.0.1** (DataServer infrastructure), **7.2.2** (DataServer queue) — ⚠️ version mismatch | DataServer (retry/circuit breaker), RMS [NEW] |
| Newtonsoft.Json | [UNCLEAR] | Multiple |
| AutoMapper | [UNCLEAR] | MDC |

---

## 10. [NEW] Risk Register — Deep Dive (2026-04-04)

### CRITICAL

**Risk: Predictable JWT signing key in RMS**
- **Location:** `CamtekSoftwareSolutions/rms/Camtek.RMS.Service/Infrastructure/Helpers/JwtMiddleware.cs`
- **Detail:** JWT signing key is derived from `Encoding.ASCII.GetBytes($"{ServerName} {ServerUri}")` — for defaults this is `"Server http://localhost:5001"`. A predictable, weak symmetric key. Issuer/audience validation is disabled. Failed JWT validation is silently swallowed (request proceeds unauthenticated).
- **Impact:** Any user who knows the server name and URI can forge valid JWT tokens with arbitrary claims, gaining admin access to all RMS operations.
- **Suggested fix:** Use a cryptographically random secret (256+ bits) stored in a protected config file. Enable issuer and audience validation. Return 401 on JWT validation failure instead of silently continuing.

**Risk: No TLS on any internal service communication**
- **Location:** DataServer WCF bindings named `"NotSecured"`, BSIHR uses `ChannelCredentials.Insecure`, RMS uses `http://localhost:5001` (no HTTPS)
- **Detail:** All 12 DataServer WCF endpoints use plain `net.tcp` with no `NetTcpSecurity`. Certificate validation is explicitly disabled (`certificateValidationMode="None"`). BSIHR gRPC channels use `ChannelCredentials.Insecure`. RMS explicitly enables `Http2UnencryptedSupport`.
- **Impact:** All service-to-service traffic (scan results, verification data, user credentials, recipes) traverses the network in plaintext. Susceptible to MITM, sniffing, and replay attacks. On a shared factory network, this exposes proprietary inspection data and credentials.
- **Suggested fix:** Enable TLS on all WCF endpoints (`NetTcpSecurity.Mode = Transport`). Use TLS for gRPC channels. Enable HTTPS on RMS.

**Risk: Hardcoded default credentials across the system**
- **Location:** `ServiceSettings.cs` (DataServer): `DefaultToolUserName = "me_admin"`, `DefaultToolPassword = "1122"`. Seeded in `AuthDbContext.cs` with `admin` role. Used for network file copy in `ParallelManager.cs`.
- **Detail:** The 4-digit password `1122` is the default for admin access, compiled into binaries, and used for network file operations (SMB credential delegation). `WebApiHelper` defaults to `guest/guest`.
- **Impact:** Any developer or decompiled binary reveals admin credentials. These credentials are used for cross-machine file copy operations, meaning compromise grants access to all DataServer instances.
- **Suggested fix:** Remove hardcoded credentials. Require secure credential injection via encrypted config or secret store. Enforce minimum password complexity. Rotate seeded admin password on first login.

### HIGH

**Risk: Silent COM registration failures**
- **Location:** `BIS/reg.cmd`, `DeployUI/helpers/reg.unreg.ps1`
- **Detail:** `regsvr32 /s` suppresses all error dialogs. No `%ERRORLEVEL%` checking. Registration order is non-deterministic (NTFS directory order). Critical inspection-path VB6 COM objects (`Connector.vbp`, `Display.vbp`) depend on correct registration.
- **Impact:** A failed COM registration goes undetected until runtime `COMException` or `ClassNotRegisteredException` crashes the inspection workflow. Debugging requires manual registration forensics.
- **Suggested fix:** Add error checking to registration scripts. Log results. Validate COM CLSID/ProgID entries in registry after registration. Adopt deterministic registration order for dependent components.

**Risk: Unbounded file-system message queue**
- **Location:** `DiskMessageConsumer.cs` in `CamtekSoftwareSolutions/dataserver/Common/Queue/Camtek.QueueSharedModels/`
- **Detail:** No max queue depth, no disk space check, no backpressure. `Directory.GetFiles()` loads all filenames into memory at once. `Failed/` subfolder also has no purge/rotation. `WaitAndRetryForever` policy means transient errors cause infinite retry with 6-second delay.
- **Impact:** Under sustained load or consumer downtime, input directory grows unbounded → `OutOfMemoryException` on `GetFiles()` or disk exhaustion. Failed messages accumulate forever.
- **Suggested fix:** Add max queue depth limit. Implement file count pagination in consumer. Add disk space monitoring. Set Failed folder TTL with automatic purge. Replace `WaitAndRetryForever` with bounded retry + circuit breaker.

**Risk: WCF message size limits set to Int32.MaxValue (2GB)**
- **Location:** DataServer Host `App.config` — all reader quotas and transport sizes at `2147483647`
- **Detail:** Both custom bindings (`NotSecured`, `NotSecuredInspection`) have all size limits maxed: `maxArrayLength`, `maxBytesPerRead`, `maxStringContentLength`, `maxBufferSize`, `maxReceivedMessageSize` all at 2GB.
- **Impact:** No protection against oversized or malicious messages. A single large message can exhaust process memory (single 2GB allocation). No DoS protection.
- **Suggested fix:** Set realistic per-operation limits based on actual data sizes. The largest expected payload (inspection result images) should cap limits. Add per-client throttling.

**Risk: RMS has zero test coverage**
- **Location:** `CamtekSoftwareSolutions/rms/` — no `*.Tests.csproj`, no NUnit/xUnit/MSTest references, no test methods
- **Detail:** 18 projects, 9 gRPC services, JWT auth, SignalR, SQLite storage — none have any automated tests.
- **Impact:** Regressions in recipe deployment, auth, or job lifecycle have no safety net. The JWT security vulnerability (see Critical section) would have been caught by basic testing.
- **Suggested fix:** Add unit tests for critical paths: JWT validation, gRPC service operations, EF Core migrations, SignalR notification flow.

**Risk: Extremely weak password policy in RMS**
- **Location:** `Camtek.RMS.Service/Startup.cs` — ASP.NET Identity configured with 1-character minimum, no complexity requirements
- **Detail:** `RequiredLength = 1`, `RequireDigit = false`, `RequireLowercase = false`, `RequireUppercase = false`, `RequireNonAlphanumeric = false`.
- **Impact:** Users can set single-character passwords. Combined with the JWT signing key vulnerability, this eliminates both authentication barriers.
- **Suggested fix:** Enforce minimum 8+ character passwords with digit + letter requirements. Add account lockout on failed attempts.

### MEDIUM

**Risk: Shared binary coupling — SystemCalibration ↔ BIS**
- **Location:** `SystemCalibration/Sources/SystemCalibrationDllUpdater/Program.cs`
- **Detail:** `SystemCalibrationDllUpdater` unconditionally copies DLLs from `c:\bis\bin\` to SystemCalibration's `lib/` folder. No version compatibility check, no hash verification. Excluded DLLs (`log4net`, `System.Buffers`, `Newtonsoft.Json`) could diverge. Missing DLLs in `c:\bis\bin` are silently skipped.
- **Impact:** SystemCalibration can run with mismatched DLL versions, causing subtle runtime failures in camera calibration routines.
- **Suggested fix:** Add assembly version compatibility checks. Compare file hashes before/after copy. Generate a DLL manifest with expected versions and validate at SystemCalibration startup.

**Risk: Mixed .NET runtimes — `netcoreapp3.1` in RMS Worker**
- **Location:** `CamtekSoftwareSolutions/rms/Camtek.Rms.Worker/Camtek.Rms.Worker.csproj` targets `netcoreapp3.1`
- **Detail:** .NET Core 3.1 reached end-of-life December 2022. No security patches since then. The RMS Worker runs alongside .NET 6.0 services.
- **Impact:** Security vulnerabilities in the .NET Core 3.1 runtime are unpatched. Potential assembly binding conflicts with .NET 6 shared contracts.
- **Suggested fix:** Upgrade the RMS Worker to `net6.0` (or `net8.0`).

**Risk: Telerik WPF version skew — SystemCalibration 6 years behind**
- **Location:** SystemCalibration uses Telerik **2016.2.613.45**; MDC uses **2022.1.222.45**; RMS uses **R2 2021**
- **Detail:** Three different Telerik versions across three products. SystemCalibration's 2016 version lacks security patches and modern control features. DLLs are resolved from `c:\bis\bin\` which may have a different version.
- **Impact:** Potential DLL hell if SystemCalibration and BIS share the same `c:\bis\bin\` at different Telerik versions. Missing security fixes in the 2016 version.
- **Suggested fix:** Unify Telerik versions across all products. Minimum: upgrade SystemCalibration to match MDC's 2022 version.

**Risk: VB6 COM components on critical inspection path**
- **Location:** `Connector.vbp`, `Display.vbp`, `FalCal.vbp` in `BIS/Sources/`
- **Detail:** 96 VB6 projects still in BIS. Critical components (Connector, Display, Calibration) are VB6 COM objects accessed via 18 interop wrapper projects. VB6 IDE hasn't been updated since 2008.
- **Impact:** No modern tooling, no unit test support, no async support, COM registration fragility. VB6 runtime end-of-support creates compliance risk.
- **Suggested fix:** Prioritize migration of critical-path VB6 components (Connector, Display) to C#/.NET. Use COM Callable Wrappers during transition.

**Risk: No distributed tracing or metrics**
- **Location:** Entire codebase — no OpenTelemetry, Prometheus, Grafana, Jaeger, or Zipkin found
- **Detail:** 12 WCF endpoints + 9 gRPC services + COM IPC + file-system queues — all diagnosed purely via log files (log4net/Serilog).
- **Impact:** Cross-service request failures require manual log correlation across multiple files and machines. Mean-time-to-diagnose is high.
- **Suggested fix:** Adopt OpenTelemetry for distributed tracing. Add structured correlation IDs to all service calls. Start with the DataServer ↔ MDC ↔ CMM flow.

### LOW

**Risk: Polly version mismatch in DataServer**
- **Location:** `Common.Infrastructure.Policies` (Polly 6.0.1) vs `Camtek.QueueSharedModels` (Polly 7.2.2)
- **Impact:** Different Polly APIs/behaviors in the same process. Assembly binding redirects may mask version conflicts.
- **Suggested fix:** Unify to Polly 8.x (current).

**Risk: `pipeline_pr.yml` misleading name**
- **Location:** `xbuild/pipeline_pr.yml` — contains only `trigger: main` (CI trigger), no `pr:` section
- **Detail:** Despite the filename, this is a CI pipeline, not a PR pipeline. PR triggering relies on external `base_pipeline.yml@PipelineRepo` template or Azure DevOps branch policies [UNCLEAR — cannot inspect PipelineRepo].
- **Impact:** Developer confusion about which pipeline validates PRs.
- **Suggested fix:** Document the actual PR trigger mechanism. Add explicit `pr:` section if PR-triggered behavior is intended.

**Risk: RabbitMQ references in DataServer are legacy/dead**
- **Location:** `WebApiHelper.cs` (zero callers), `FileDB.csproj` (unused `RabbitMQ.Client 6.2.1` reference), installer `CustomAction.cs` (RabbitMQ setup commented out)
- **Detail:** RabbitMQ is only actively used in BIS PubSub (via `RabbitMQPublisher`/`RabbitMQSubscriber`). DataServer's references are vestigial.
- **Impact:** Unused dependencies increase attack surface and confusion. The installer still packages RabbitMQ MSI unnecessarily.
- **Suggested fix:** Remove dead `RabbitMQ.Client` reference from `FileDB.csproj`. Remove `WebApiHelper.cs`. Clean installer.

---

## 11. [NEW] DataServer Deep Dive — Full WCF Interface Reference (2026-04-04)

### 11.1 Service Contracts Summary (121 operations across 21 interfaces)

| Interface | Port | # Ops | Duplex |
|---|---|---|---|
| `IMainService` | 8002 | 11 | No |
| `IScanResultsService` | 8202 | 15 | No |
| `IScanResultsServiceNotifier` | 8202 | 1 | **Yes** → `IScanResultsServiceCallbacks` (5 callbacks) |
| `IScanProcessesToolServiceNotifier` | 8202 | 1 | **Yes** → `IScanProcessesToolServiceCallbacks` (6 callbacks) |
| `IInspectionResultsService` | 8272 | 17 | No |
| `IVerificationService` | 8262 | 3 | No |
| `IVerificationServiceNotifier` | 8262 | 1 | **Yes** → `IVerificationServiceCallbacks` (1 callback) |
| `IVerificationImageService` | 8252 | 3 | No |
| `IImagesService` | 8242 | 5 | No |
| `IWaferLayoutService` | 8222 | 3 | No |
| `IClassifierService` | 8212 | 7 | No |
| `IDiceAttributesService` | 8232 | 4 | No |
| `IDiceAttributesClassesService` | 8232 | 2 | No |
| `ICmmService` | 8032 | 10 | No |
| `ICmmServiceNotifier` | 8032 | 1 | **Yes** → `ICmmServiceCallbacks` (4 callbacks) |
| `IAuthService` | 8012 | 6 | No |
| `IUsersService` | 8012 | 12 | No |
| `IPermissionService` | 8012 | 6 | No |
| `IIdentificationService` | 8022 | 5 | No |
| `IVirtualDataService` | — | 1 | No |

### 11.2 Key Operation Signatures

**IMainService** (`net.tcp://localhost:8002`):
- `bool UpdateDataServerSettings()`
- `ReloadStatus ValidateRepository(RepositorySource repository)`
- `Task<ReloadStatus> ReloadScanResultsFromRepositoryAsync(string repositoryId)`
- `Task<ReloadStatus> ReloadScanResultsFromRepositorySync(string repositoryId, SearchFilter searchFilter)`
- `Task<ReloadResponse> ReloadScanResultsFromEnabledRepositoriesAsync()`
- `List<RepositorySource> GetRepositories()` / `AddRepository()` / `EditRepository()` / `DeleteRepository()`
- `void CancelRepositoryProcessing(string repositoryId)` / `CancelAllRepositoriesProcessing()`

**IScanResultsService** (`net.tcp://localhost:8202`):
- `IList<WaferScanResult> GetWaferScanResult(IList<string> waferScanResultPaths)`
- `WaferScanResult GetWaferScanResultIncludeRecipes(string path)`
- `IList<string> GetDevicesNames/GetSetupsNames/GetLotsNames(FilterForScanResults filter)`
- `WaferScanResultResponse GetWaferScanResultsByFilter(FilterForScanResults)`
- `void UpdateYield(string path, int changeInBadDice)`
- `void UpdateDefectsCount(string path, int changeInDefects)`
- `void LockScanResults/UnLockScanResults(IList<string> paths, string userName, ...)`

**ICmmService** (`net.tcp://localhost:8032`):
- `void ExportMaps(MapExportRequest requestData)`
- `void ExportReports(IList<CmmReportAction> reports)`
- `AvailableExportMapModes GetAvailableModes()`
- `IDictionary<string, ExportStatus> GetMapExportStatuses(IEnumerable<string> scanResultsPaths)`
- `List<ServerModel> GetCMMCollection()` / `AddCMMSource()` / `EditCMMSource()` / `DeleteCMMSource()`

**IInspectionResultsService** (`net.tcp://localhost:8272`):
- `IList<InspectionResultData> ExecuteQuery(string query)` — XSql query engine
- `IList<InspectionResultData> ExecutePagingQuery(string query, int startRow, int rowsCount)`
- `void ChangeClassId(string wsrPath, IList<int> inspectionResultIds, int newClassId)`
- `HyperCreationResult GenerateScanResultsData(IList<string> paths, string userName, string twbxPath, ...)`
- `ExportAdcResult ExportADC(IList<string> paths, ExportAdcRequest)`
- `BaselineResponse CreateBaseline(BaselineRequest)` / `ImportBaselineFromCsv(BaselineImportRequest)`

**IVerificationService** (`net.tcp://localhost:8262`):
- `bool StartWaferVerificationProcess(string waferScanResultPath, string userName)`
- `void CancelWaferVerificationProcess(string waferScanResultPath, string userName)`
- `void CompleteVerificationProcess(string path, string userName, CompleteVerificationExtraData)`

**IAuthService** (`net.tcp://localhost:8012`):
- `User Login(string userName, string password)`
- `void Logout(string userName)`
- `bool Authenticate(string userName, string password)`
- `bool IsInRole(string userName, string role)`

### 11.3 Duplex Callbacks

**IScanResultsServiceCallbacks** (pushed to subscribers):
- `OnScanResultReady(WaferScanResult)` — new scan result available
- `OnLockStateChanged(IList<string> paths, string userName, bool state, string reason)`
- `OnYieldChanged(string path, double totalYield)`
- `OnNumberOfDefectsChanged(string path, int change)`
- `ScanResultsDeleted(IList<string> paths)`

**IScanProcessesToolServiceCallbacks** (tool scan lifecycle):
- `OnScanStarted/OnScanCompleted/OnScanFailed/OnScanResultsReady(ScanProcess)`
- `OnCarriersStarted/OnCarriersCompleted(IList<ToolCarrier>)`

**IVerificationServiceCallbacks**:
- `OnWaferScanResultVerificationChanged(WaferScanResult)`

**ICmmServiceCallbacks** (export status):
- `RaiseExportDataFailed(IEnumerable<string> paths, DataExportType, string extraKey, string user, string reason)`
- `RaiseExportDataStatusChanged(IEnumerable<string> paths, DataExportType, string extraKey, ExportStatus, string user)`

### 11.4 Fault Codes

18 fault codes defined in `FaultCodes.cs`: `Authentication`, `Authorization`, `NotImplemented`, `NotSupported`, `Internal`, `InvalidOperation`, `Communication`, `Arguments`, `Storage`, `FileFormatNotSupported`, `UnknownScanResult`, `StorageIsBusy`, `MessageInFailQueue`, `FailedToSaveInFS`, `DataAlreadyLocked`, `DataIsNotValid`, `NetworkIssue`, `Faulted`

### 11.5 WCF Binding Configuration

- **Binding type:** `customBinding` with `binaryMessageEncoding` + `reliableSession` + `tcpTransport`
- **Security:** **None** — bindings explicitly named `"NotSecured"`. Certificate validation disabled.
- **Message size limit:** All quotas at `Int32.MaxValue` (2,147,483,647 bytes = 2GB)
- **Timeouts:** Open/Close = 10s, Send = 3min (default) or 1hr (InspectionResults), Receive = ~25 days
- **Serialization:** Standard WCF binary for most; `InspectionResultsService` uses **protobuf-net** endpoint behavior

---

## 12. [NEW] DataServer Database Schema (2026-04-04)

### 12.1 SQLite Database (`DataServerDB.sqlite3`)

**Table: `ScanResults`** — maps to entity `WaferScanResultWrapper`

| Column | Type | PK | Nullable | Notes |
|---|---|---|---|---|
| `StartScanTimestamp` | DateTime | ✓ | No | Composite PK order 0 |
| `MachineName` | string | No | No | Order 1 |
| `ScanLogHash` | string | ✓ | No | Composite PK order 2 |
| `Path` | string(255) | ✓ | No | Composite PK order 3; unique index `Path_IX` |
| `JobName` | string(150) | No | No | |
| `SetupName` | string(150) | No | No | |
| `LotId` | string(150) | No | No | |
| `WaferId` | string(150) | No | No | |
| `InsertTimestamp` | DateTime | No | No | |
| `NumberOfDefectsAfterScan` | int | No | No | |
| `NumberOfDefects` | int | No | No | |
| `TotalScanDice` | int | No | No | |
| `GoodDice` | int | No | No | |
| `BadDice` | int | No | No | |
| `GoodDiceAfterScan` | int | No | No | |
| `BadDiceAfterScan` | int | No | No | |
| `LockedBy` | string(50) | No | ✓ | |
| `SourceId` | string | No | ✓ | |
| `VerificationState` | int | No | No | Default 0; added via ALTER TABLE |

**Table: `ExportData`**

| Column | Type | PK | Nullable | Notes |
|---|---|---|---|---|
| `ScanResultPath` | TEXT | ✓ | No | FK → `ScanResults(Path)` ON DELETE CASCADE |
| `DataExportType` | INTEGER | ✓ | No | Composite PK |
| `ExtraKey` | TEXT | ✓ | No | Composite PK |
| `RequestTime` | DATETIME | No | No | |
| `Status` | INTEGER | No | No | |
| `TicketName` | TEXT | No | ✓ | Index `IX_ticket_name` |
| `UserLogin` | TEXT | No | No | |

### 12.2 Auth Database (`Auth.db3`)

Managed via custom ORM in `AuthDbContext` — contains user/role/permission tables. Seeded with `me_admin` user (admin role, argon2 password hash).

### 12.3 File-based Inspection DB (`FileDB.INFS`)

Custom binary table format at `Tier1/Modules/InspectionResults/FileDB/`:
- `FlatDefect` — defect record structure
- `Table` — binary table container
- `ProtoViewSerializer` — protobuf-net serialization for views
- No SQL schema — direct binary read/write to files in scan result directories

---

## 13. [NEW] DataServer Configuration Reference (2026-04-04)

### 13.1 Service Settings

| Module | Key | Default | ⚠️ Hard-coded |
|---|---|---|---|
| DataServer | `BaseHost` | `net.tcp://localhost:8000/DataServer` | |
| DataServer | `DBFilePath` | `C:\bis\data\SWS\dataserver\DataServerDB.sqlite3` | ⚠️ |
| DataServer | `ClientDataPollingIntervalInSeconds` | `10` | |
| DataServer | `TasksCount` | `4` | |
| DataServer | `UseNetworkConnection` | `true` | |
| UsersAuth | `AuthDatabaseFile` | `C:\bis\data\SWS\dataserver\Auth.db3` | ⚠️ |
| CMM | `MappingsFolderRoot` | `C:\bis\data\SWS\dataserver\Mappings` | ⚠️ |
| CMM | `LocalQueueFolderPath` | `C:\bis\ScanResultServer\DataServer\CmmQueue` | ⚠️ |
| CMM | `IncomingTicketsFolderPath` | `C:\ParallelCMM\Tickets\Incoming` | ⚠️ |
| CMM | `FailedTicketsFolderPath` | `C:\ParallelCMM\Tickets\Failed` | ⚠️ |
| CMM | `UseGrpc` | `true` | |
| CMM | `TimeSpanGrpcServiceTimeout` | `5` (seconds) | |
| CMM | `TimeSpanGrpcRetry` | `10` (seconds) | |
| Classifiers | `ToolClassifiersPath` | `C:\bis\data\dds` | ⚠️ |
| InspectionResults | `PythonPath` | `C:\Dev\Python\SWS\python.exe` (fallback) | ⚠️ |
| InspectionResults | `PortNumber` (for Python workers) | `9000` | |
| InspectionResults | `NumberOfProcessToUse` | `4` | |
| WaferLayout | `LayoutCacheSize` | `60` | |
| VerificationImage | `QueryPageSize` | `50000` | |
| Base | `DefaultToolUserName` | `me_admin` | ⚠️ |
| Base | `DefaultToolPassword` | `1122` | ⚠️ |

### 13.2 DataServer Outbound Calls

| Target | Protocol | Trigger | Data |
|---|---|---|---|
| CMM Parallel Runner | gRPC (`ChannelCredentials.Insecure`) | Map/report export when `UseGrpc=true` | `CmmTicketCreationRequestMessage`, `ReportTicketCreationRequestMessage` |
| Python HyperCreator workers | gRPC (localhost:9001-900N) | `GenerateScanResultsData()` call | `ProcessChunk` with inspection data |
| Network file shares | SMB (P/Invoke `mpr.dll`) | Ticket polling, file copy | Scan result directories |
| File-system queue | File I/O (JSON) | Scan ready, export, verification | Various message types |

### 13.3 File-System Queue Retry Configuration

**Wrap pattern:** Inner=`WaitAndRetryForever`, Outer=`WaitAndRetry(2)`

| Policy | Trigger Exceptions | Count | Backoff |
|---|---|---|---|
| **WaitAndRetryForever** | `FaultException(UnknownScanResult, Communication)`, `CommunicationException`, `TimeoutException`, `ObjectDisposedException`, `SqlException(-2,-1,2,53)`, `SQLiteException(Busy,Locked,Full)` | ∞ | 2s→4s→6s forever |
| **WaitAndRetry** | Other `FaultException`s, `IOException`, `SqlException(1205)`, `SQLiteException(Error,NoMem,IoErr)`, `RobocopyException` | 2 | 5s fixed |

Dead letter: Messages move to `{inputFolder}/Failed/` subfolder. No TTL, no purge, no monitoring.

---

## 14. [NEW] Communication Flow Trace — Wafer Scan Completes (B1) (2026-04-04)

```
[1] BIS DDS ProcessingSystem
      EndScan → all processing workers finish
      → signals DDS scan completion
    → [2] BsiScanResCreator

[2] BIS BsiScanResCreator
      CreateScanResDir() writes scan result folder:
        C:\Falcon\ScanResults\{Job}\{Setup}\{Lot}\{WaferId}\
        → ScanLog.ini (all scan metadata)
        → ProductInfo.ini (equipment IDs)
        → WaferMap (die states)
        → bsiScanResult.result (binary defect data)
        → recipe files
    → [3] BIS E30Client

[3] BIS E30Client (SECS/GEM)
      WaferScanResultsAreReady() → triggers DataCollectionTH (async)
      → reads ScanLog.ini + ProductionInfo.ini
      → SECS/GEM data collection to factory host
      → DataCollectionCompleted() signals automation cycle
    → [4] Ticket creation

[4] BIS Automation
      Creates .tck ticket file on \\tool\Tickets\ network share
      → { TicketPath, ScanResultPath, MachineName, timestamp }
    → [5] DataServer PollingDirectoryService

[5] DataServer PollingDirectoryService (timer: every 10s)
      Enumerates *.tck files from configured ClientDataSources
      → ProcessTicket(): validates ticket, builds source path, hash-dedup check
      → Publishes ScanReadyMessage to in-process queue
        { Path, SourceType, RepositoryId }
    → [6] ProcessScanResultService

[6] DataServer ProcessScanResultService
      Consumes ScanReadyMessage
      → Verifies repository exists
      → Delegates to PreProcessingService.HandleScanLoading(msg)
    → [7] ScanResultsInternalService

[7] DataServer ScanResultsInternalService
      CreateScanResult():
      → WaferScanResultFSContext.BuildScanLogData() reads ScanLog.ini
      → Parses path into Job/Setup/Lot/WaferId
      → SQLite: InsertOrReplace into ScanResults table
        { Path, JobName, SetupName, LotId, WaferId, StartScanTimestamp,
          NumberOfDefects, TotalScanDice, GoodDice, BadDice, ... }
      CompleteLoading():
      → _externalSubscription.InvokeAsync()
    → [8] WCF Duplex Callbacks (async, to all subscribers)

[8] DataServer → MDC (WCF duplex net.tcp port 8202)
      OnScanResultReady(WaferScanResult waferScanResult)
      → Pushed via duplex channel to all subscribed clients
        { PathToFiles, JobName, SetupName, LotId, WaferId,
          NumberOfDefects, GoodDice, BadDice, StartScanTimestamp }
    → [9] MDC ScanResultsNotifierProxy

[9] MDC ScanResultsNotifierProxy
      Receives OnScanResultReady callback
      → Fires ScanResultReady C# event
    → [10] MDC ScanResultService

[10] MDC ScanResultService
       ScanResultsClientCallback_ScanResultReady(waferScanResult)
       → _wafersToAddOrUpdate.Enqueue(waferScanResult) [ConcurrentQueue]
     → [11] MDC DispatcherTimer

[11] MDC DispatcherTimer (UI thread)
       Drains queue: dequeues up to MaxWafersToAdd per tick
       → IsScanResultFitDateFilter() — checks date filter
       → UpsertWaferInWaferList() — creates/updates Wafer view model
       → InvokeInUiDispatcher(() => Wafers.AddRange(wafersToAdd))
       → UI grid updates with new wafer row ✓
```

**Service boundaries:**
| # | From → To | Protocol | Port/Path |
|---|---|---|---|
| 2→4 | BIS → Network share | SMB/CIFS | `\\tool\Tickets\` |
| 5 | DataServer polling | File I/O | `*.tck` files |
| 5→6 | In-process | `IMessageProducer<ScanReadyMessage>` | — |
| 7 | DataServer → SQLite | LinqToDB 2.6.4 | `DataServerDB.sqlite3` |
| 8 | DataServer → MDC | WCF duplex `net.tcp` | Port 8202, `IScanResultsServiceCallbacks` |
| 3 | BIS → Factory Host | SECS/GEM (HSMS) | Equipment integration (async branch) |

---

## 15. [NEW] Hard-Coded Deployment Paths Registry (2026-04-04)

| Path | Component | Configurable? | Used For |
|---|---|---|---|
| `C:\bis\bin\` | BIS, SystemCalibration | No | Binary deployment root |
| `C:\bis\bin\x64\` | BIS | No | 64-bit binaries |
| `C:\bis\data\SWS\dataserver\` | DataServer | Via Settings.cs | SQLite DBs, mappings, configs |
| `C:\bis\data\dds` | DataServer Classifiers | Via Settings.cs | Tool classifier data |
| `C:\bis\data\config\env\system.ini` | DataServer Tool | No | System definitions |
| `C:\bis\data\config\WaferTypes` | DataServer Tool | No | Wafer shape types |
| `C:\bis\errorlog\` | BIS, ToolAnalytics | No | Error log root |
| `C:\bis\ScanResultServer\DataServer\CmmQueue` | DataServer CMM | Via Settings.cs | CMM queue folder |
| `C:\BIS\RMS\Server\` | RMS | Via appsettings.json + fallback | RMS root |
| `C:\BIS\RMS\Server\RMSStorages` | RMS | Via config + hard-coded fallback | Recipe storage |
| `C:\BIS\RMS\Client\CodeCompare\CodeCompare.exe` | RMS Client | **No** | File comparison tool |
| `C:\falcon\data\` | ToolAnalytics, BIS | No | Machine config INI files |
| `C:\Falcon\ScanResults\` | BIS | No | Scan result output |
| `C:\Falcon\Data\ScanResultsServer\Tickets\` | DataServer Tool | No | Ticket processing |
| `C:\Job\` | RMS Tool Agent | Via config | Recipe deployment |
| `C:\ParallelCMM\Tickets\Incoming` | DataServer CMM | Via Settings.cs | Parallel CMM incoming |
| `C:\ParallelCMM\Tickets\Failed` | DataServer CMM | Via Settings.cs | Parallel CMM failed |
| `C:\ScanResultServer\Global\` | DataServer | No | Global config |
| `C:\Dev\Python\SWS\python.exe` | DataServer | Via Settings.cs (fallback) | Python runtime |
| `C:\ScanResultsServerTool\Logging.xml` | DataServer Tool | No | Logging config |

---

## 16. [NEW] AOI_Main Deep Dive — Test Automation State Analysis (2026-04-04)

### Section 1 — AOI_Main Structure

#### 1.1 Entry Point

`AOI_Main` is a **.NET Framework 4.8 class library** (`OutputType=Library`), NOT an executable. It compiles to `AOI_Main.dll` and is output to `C:\bis\bin\TestAutomation\`.

- **Project:** `BIS/Sources/TestAutomationAPI/AOI_Main/AOI_Main.csproj`
- **Target:** `net48`, `OutputType=Library`, `OutputPath=C:\bis\bin\TestAutomation\`
- **Assembly:** `AOI_Main.dll` (GUID `9c4bef4f-251a-45e9-a998-21d47b68c6d0`)

The **confusingly named** `AOI_Main.exe` referenced in `AoiMainUtils.GetAoiMainExceutablePath()` is the **Falcon.Net main application** (`c:\bis\bin\x64\AOI_Main.exe`), NOT this library. This library automates that executable via UI automation (FlaUI).

#### 1.2 How AOI_Main Is Launched

**Indirectly via NUnit test runner.** The execution chain is:

```
RunnerGui (testcentric.exe) [STAThread WinForms]
  → NUnit Engine loads test assemblies
    → Test projects reference TestAutomationSDK.dll
      → TestAutomationSDK references AOI_Main.dll
        → Test [Test] methods call Tool.LaunchAOI() / Tool.StartScan() etc.
          → AOI_Main page objects drive Falcon.Net UI via FlaUI
```

- `RunnerGui/TestCentric/testcentric.exe/Class1.cs` — `[STAThread] Main()` → `AppEntry.Main(args)`
- `AppEntry.cs` registers `AssemblyResolve` handler probing `C:\bis\bin\x64` and `C:\bis\bin\TestAutomation`
- NUnit engine discovers `[Test]`/`[TestFixture]` methods in test assemblies
- Test methods use `TestRunner.RunDeterministicScan(action)` where `action` delegates call AOI_Main page objects

#### 1.3 Top-Level Orchestrating Class

The orchestrator is **`TestAutomationSDK.FSI.Tool`** (not in AOI_Main itself, but in TestAutomationSDK):

**File:** `BIS/Sources/TestAutomationAPI/TestAutomationSDK/FSI/Tool.cs`

**Public members:**

| Member | Signature |
|---|---|
| Property | `bool FailedAsExpected { get; }` |
| Method | `void LaunchAOI()` |
| Method | `void KillAOI(bool aOIOnly = true, bool checkConfig = true)` |
| Method | `void LoadJob(string recipePath = null)` |
| Method | `void StartScan(ScanOperationInfo scanOperationInfo)` |
| Method | `void StartReferenceCreation(ReferenceCreationParams)` |
| Method | `void StartReferenceCreationWithCoordinateInput(ReferenceCreationParams)` |
| Method | `AutoCycleSetup StartAutoCycleSetup()` |
| Method | `ProductionLocal StartProduction()` |
| Method | `void AutoCycleScanSeq(ScanOperationInfo)` |
| Method | `void ProductionScanSeq(DataProviderBase)` |
| Method | `void SelectTab(MainUI.Tab tab)` |
| Method | `void SetWaferEditScanArea(int dx, int dy)` |
| Method | `IWaferSlot LoadFirstAvailableWafer()` |
| Method | `bool IsWaferOnChuck()` |
| Method | `void ClearWaferSeq()` |
| Method | `void ClearAllSlotsTextSeq()` |

**Private fields (page objects):**

| Field | Type |
|---|---|
| `_mainUIPage` | `MainUI` |
| `_scanTabPage` | `ScanTab` |
| `_jobSelectTabPage` | `JobSelectTab` |
| `_setupTabPage` | `SetupTab` |
| `_verticalNavigationToolbar` | `VerticalNavigationToolbar` |
| `_stageControl` | `StageControl` |
| `_guiHandler` | `GUIHandler` |
| `_machineState` | `MachineState` |

#### 1.4 Dependencies

**Project References:**

| Reference | Source |
|---|---|
| `Engine.Common` | `BIS/Sources/TestAutomationAPI/Engine.Common/` — base types, config, reporting |
| `Engine.FlaUI` | `BIS/Sources/TestAutomationAPI/Engine.FlaUI/` — UI automation driver layer |

**Binary References from `c:\bis\bin\` (COM interop):**

| DLL | EmbedInterop | Purpose |
|---|---|---|
| `FalconWrapperPS.Interop.dll` | **Yes** (embedded) | COM Primary Interop Assembly for FalconWrapper |
| `FalconWrapper.NET.dll` | No | .NET wrapper for COM `CFalconExternalControl` |
| `CamtekSystem.dll` | No | PubSub, INI helpers, AppConfig |
| `ComSingletonUtils.dll` | No | COM singleton utilities |

**NuGet Packages:**

| Package | Version |
|---|---|
| FlaUI.Core | 4.0.0 |
| FlaUI.UIA3 | 4.0.0 |
| ini-parser | 2.5.2 |
| Interop.UIAutomationClient | 10.19041.0 |
| Newtonsoft.Json | 13.0.3 |
| System.Drawing.Common | 5.0.2 |
| System.Management | 5.0.0 |
| Microsoft.Win32.Registry | 5.0.0 |

**Framework References:** `System.Windows.Forms`, `WindowsBase`, `UIAutomationClient`, `UIAutomationTypes`, `System.Drawing`, `System.Configuration`, `System.ServiceProcess`

#### 1.5 Existing State Model

AOI_Main has **no formal state model** (no state machine class, no central state enum, no state dictionary). State is implicit in:

| State Indicator | Type | Location |
|---|---|---|
| `MainUI.Tab` | enum | `MainUI.cs` — `{ JobSelect, Setup, Scan, Verify, SPC }` |
| `MainUI.IsBusy` | bool property | Checks title bar for "Busy." string |
| `MainUI.IsLoaded` | bool property | Checks if `JobSelectTabBtn` exists |
| `Direction` | enum | `ReferenceCreation.cs` — `{ Up, Down, Left, Right, UpLeft, UpRight, DownLeft, DownRight }` |
| `CoordSystemType` | enum | `StageControl.cs` — `{ Wafer, Chuck, Stage }` |
| `eManagerState` | COM enum (external) | FalconWrapper — `{ Undefined, Initializing, Idle, Executing, Pausing, Paused, Stopping, Aborting }` |
| `eFalconGuiLifeCycle` | COM enum (external) | FalconWrapper — `{ eFalconDown, eFalconInitializing, eFalconWorking, eFalconTerminating }` |
| `VcamRunState` | singleton | TestAutomationSDK — `{ LastVcam, CurrentVcam, IsLastTestFailed, IsDeployNeeded, IsVcamChanged }` |
| `MachineState.IsPureSimulator` | bool | Reads from `config.ini` `[VcamSimulator]IsPureSimulator` |

---

### Section 2 — The 8 State Domains: Current Implementation

#### 2.1 Scan / Grab / Color Grabbing

- **Current mechanism:** **UI automation polling** (FlaUI). AOI_Main clicks the "Scan" button in the Falcon GUI and polls for scan completion by checking whether the JobSelect tab button becomes re-enabled. Also parses `C:\bis\errorlog\FalconLog.txt` for the trace string `"frmScanTab::Scan -- Exit form Scan"`.
- **Owner class/interface:** `AOI_Main.Pages.ScanTab.ScanTab` (UI page object)
- **Data model:**
  - `ScanOperationInfo` { `bool UseAutoLoader`, `bool UseProductionMode`, `double TimeOutMS` (default 600000), `bool SetLotAndWaferIdToZero`, `bool IsFailureExpected` }
  - `ScanTab.LotTextBox` / `WaferIdTextBox` — text fields on UI
  - Scan end detected via: (1) `JobSelectTabBtn.IsEnabled` goes true, (2) `AutoLoader.IsLoaded()` goes false, (3) log trace match
- **Async/sync:** **Async** — scan is triggered by UI button click, then two parallel `Task.Run` tasks: (a) popup monitor, (b) scan-end monitor via `Task.WaitAny`. CancellationToken coordinates cancellation.
- **Existing events:** **None** in AOI_Main. No COM event subscription to `IScanManagerCB`. No PubSub subscription for scan events. Detection is pure **UI polling + log parsing**.
- **Threading notes:** Two background tasks + main thread. Popup handling task polls every 5 seconds for error dialog. Scan-end task polls every 1 second. `FalconLogParser` reads log file with `FileShare.ReadWrite`.
- **Gaps / unknowns:**
  - AOI_Main does NOT subscribe to `IScanManagerCB.OperationStarted/OperationCompleted` COM callbacks
  - AOI_Main does NOT use the PubSub `EventKey{Context=Scan}` channel
  - No scan progress % available — only binary "scanning" / "done"
  - No camera mode (color vs mono) or scan type (2D/3D/overlay) data exposed
  - `GrabIPC` / `AcqIPC` / `DdsIPC` are BIS-internal IPC channels — AOI_Main does NOT interact with them

**COM interfaces that EXIST but are NOT USED by AOI_Main:**

| COM Interface | Method | Fires when |
|---|---|---|
| `IScanManagerCB.OperationStarted(eScanManagerOperation, IWaferData*)` | Operation begins | Alignment, 2D scan, 3D scan, ink marking, etc. |
| `IScanManagerCB.OperationCompleted(eScanManagerOperation, IWaferData*, eCycleCompletionCode, VARIANT, VARIANT_BOOL*)` | Operation ends | With completion code |
| `IFalconGuiCB.ManualScanDone()` | Manual scan complete | Falcon fires this |

**COM `eScanManagerOperation` enum (available scan types):**
`WaferMapImport`, `WaferMapExport`, `Alignment`, `InkDotScan`, `2DScan`, `3DScan`, `InkMarking`, `ImageGrabbing`, `WaferVerification`, `TNE_RegistrationScan`, `WLGM_RegistrationScan`, `DYNAMIC_EBR_Scan`, `Sampling_Metrology_Scan`, `Layer3D_Scan`, `LotMapExport`, `AutoFocus`, `Overlay_Scan`

---

#### 2.2 Robot Setup / AutoLoader

- **Current mechanism:** **UI automation** (FlaUI). AOI_Main interacts with the AutoLoader window via page objects — checking/unchecking "Use AutoLoader" and "Production Mode" checkboxes, clicking Map/Dock/Undock buttons, reading wafer slot states.
- **Owner class/interface:**
  - `AOI_Main.Pages.ScanTab.AutoLoaderSection` — checkbox control on scan tab
  - `AOI_Main.Pages.AutoLoader.AutoLoader` — full AutoLoader window
  - `AOI_Main.Pages.AutoLoader.LoadPort` / `ILoadPort` — per-port UI
  - `AOI_Main.Pages.AutoLoader.WaferSlot` / `IWaferSlot` — per-slot UI
  - `AOI_Main.Pages.AutoLoader.ProductionLocalPage` / `ProductionLoadport` — production mode UI
- **Data model:**
  - `AutoLoaderSection.UseAutoLoader` — bool (get/set via checkbox)
  - `AutoLoaderSection.UseProductionMode` — bool (get/set via checkbox)
  - `LoadPort` { `PortName`, `PortId`, `MapBtn`, `DockUnDockBtn` }
  - `WaferSlot` { `Id` (int), `HasWafer` (bool), `IsUsedForScan()`, `IsOnFrontSideInsp()`, slot text }
  - `ProductionLoadport` { `PortId`, `IsExecuting()` (checks "Executing" text), `IsReadyForStart()` (checks Start button) }
- **Async/sync:** **Async** — `AutoLoader.LoadWafer()` and `ProductionLoadport.WaitForExecitionEnd()` use `Task.Run` + `Task.WaitAny` + `CancellationToken`. Popup monitoring runs in parallel.
- **Existing events:** **None.** No COM event subscription. Robot state is read via UI element state polling (`LegacyIAccessibleDataType.State`).
- **Threading notes:** Background tasks for popup monitoring during wafer load. `Thread.Sleep(3000)` retry loops for loadport availability.
- **Gaps / unknowns:**
  - No robot state enum (idle/loading/unloading/error/homing) — inferred from button enabled/disabled state
  - No direct interaction with `PizzaServer.exe` or `E84Driver`
  - No subscription to `eAutoCycleManagerEvent` COM events
  - `ProcessGetProcessesByName("MachineSrv")` used as health check during production

---

#### 2.3 Camera & Lights / Illumination Change

- **Current mechanism:** **UI automation** only. AOI_Main interacts with camera/illumination exclusively through UI buttons.
- **Owner class/interface:**
  - `MainUI.TwoDBtn` — "2D" button for optic mode selection
  - `VerticalNavigationToolbar` — contains mode buttons
  - `PopUpIlluminationError` — detects illumination error popup (two versions: `PopUpIlluminationErrorVer1` for VB6 `ThunderRT6FormDC` window, `PopUpIlluminationErrorVer2` for WPF)
  - `DebugWindow.SetScanPartialOperations(bool, string)` — sets algorithm activation dropdown
- **Data model:**
  - No camera state object. Only UI button states.
  - `PopUpIlluminationError` — detects error popups but exposes no illumination data.
  - `DebugWindow.ActivateAlgComboBox` — algorithm selection (string value from combobox)
- **Async/sync:** Synchronous UI actions.
- **Existing events:** **None.** `IFalconGuiCB.Set2dOpticsDone()` exists in COM but is not subscribed.
- **Threading notes:** N/A for current implementation.
- **Gaps / unknowns:**
  - No channel/intensity/wavelength/objective data exposed
  - No camera type detection (of the 17 BIS camera types, none are programmatically identified in AOI_Main)
  - `IFalconGui.Set2DOptics(VARIANT_BOOL LiveVideo)` exists at COM level but AOI_Main uses UI button only
  - BIS camera drivers (`Sources/system/` — Camera2D, CameraClip, CameraColor, CTS, CSP, IRScan, TDI, CCS) are not referenced
  - `IFalconGuiCB.LCCPeriodicCalibAlert(VARIANT_BOOL)` callback exists but is not subscribed

---

#### 2.4 Job Created / Deleted

- **Current mechanism:** **Hybrid — COM interop + UI automation.**
  - `JobSelectTab.LoadJob(jobName, setupName, recipeName)` calls COM: `IFalconExternalControl → IFalconGui.GuiLoadRecipe(jobName, setupName, recipeName)` with `Marshal.ReleaseComObject`
  - `Tool.LoadJob()` in TestAutomationSDK also uses COM `IFalconGui.GuiLoadRecipe()`
  - `JobSelectTab.OpenNewJobWindow()` uses UI automation to click "New" button
  - `NewJob` page object sets job parameters via UI (robot setup, wafer type, scan diameter, notch position, job name)
- **Owner class/interface:**
  - `AOI_Main.Pages.JobSelectTab.JobSelectTab` — main job tab
  - `AOI_Main.Pages.JobSelectTab.NewJob` — new job creation dialog
  - `AOI_Main.Pages.JobSelectTab.JobSelect` — job selection/browsing dialog
  - COM: `FalconWrapper.IFalconGui.GuiLoadRecipe(BSTR job, BSTR setup, BSTR recipe)`
- **Data model:**
  - Job identified by 3 strings: `(jobName, setupName, recipeName)`
  - `RecipePathInfo` (TestAutomationSDK) parses recipe path → `{JobName, SetupName, RecipeName}`
  - `JobSelectTab.JobComboBox` — currently loaded job (UI combobox)
  - `NewJob` fields: `JobNameTextBox`, `RobotSetupComboBox`, `RobotSetupDiameterComboBox`, `WaferTypeComboBox`, `ScanDiametersComboBox`, `NotchPositionsComboBox`
- **Async/sync:** `LoadJob()` is **async** — uses `Task.Run` for 3 parallel tasks: (1) load job via COM, (2) handle WaferType update window, (3) handle illumination error window. `System.Timers.Timer` as watchdog with cancellation.
- **Existing events:** `IFalconGuiCB.JobLoaded(BSTR JobName, BSTR SetupName, BSTR RecipeName, long CompletionCode)` — **exists in COM but NOT subscribed by AOI_Main**. Job load completion is detected via UI polling (waiting for vertical navigation toolbar to become enabled).
- **Threading notes:** Three parallel tasks in `LoadJob()`, coordinated via `CancellationTokenSource`. COM calls happen on background thread (COM marshalling to STA is automatic via COM proxy).
- **Gaps / unknowns:**
  - No job-changed event subscription — neither COM `IFalconGuiCB.JobLoaded` nor PubSub
  - No job deletion tracking
  - Does NOT call RMS (`gRPC port 5001`) — job loading is purely local via COM + INI files
  - `IFalconGui.DeleteAllJobsExceptCurrent(jobName)` exists but `AOI_Main` doesn't use it directly (TestAutomationSDK `JobReference` does)

---

#### 2.5 Alignment Modification

- **Current mechanism:** **UI automation** (FlaUI) for triggering + **log parsing** for result verification.
  - `AlignmentSection` exposes checkboxes: `AutoFocusBeforeAlignmentChBx`, `QuickCB`, `ManualChBx`
  - `VerticalNavigationToolbar.AlignmentSeq()` clicks alignment button and monitors
  - `FalconLogParser.VerifyAlignmentPassed()` / `HasAlignmentStarted()` parse `FalconLog.txt`
- **Owner class/interface:**
  - `AOI_Main.Pages.ScanTab.AlignmentSection` — alignment UI controls
  - `AOI_Main.Pages.MainUI.VerticalNavigationToolbar` — alignment button
  - `AOI_Main.Components.FalconLog.FalconLogParser` — log-based result verification
- **Data model:**
  - 3 boolean checkboxes: `AutoFocusBeforeAlignment`, `Quick`, `Manual`
  - Alignment pass/fail: parsed from `FalconLog.txt` log lines with timestamp correlation
  - No offset X/Y, angle, reference point data exposed
- **Async/sync:** **Async** — `AlignmentSeq()` uses `Task.Run` + `CancellationToken` for parallel popup monitoring + wait-for-completion.
- **Existing events:** **None.** `IScanManagerCB.OperationCompleted(eSMO_Alignment, ...)` exists at COM level but is NOT subscribed.
- **Threading notes:** Parallel task for popup monitoring during alignment.
- **Gaps / unknowns:**
  - No alignment result data (offsets, angle, pass/fail) available programmatically — only via log parsing
  - No event when alignment parameters change
  - `eScanManagerOperation.eSMO_Alignment` COM callback is available but unused

---

#### 2.6 Clean Reference

- **Current mechanism:** **UI automation** + **FileSystemWatcher** for die mapping file creation.
  - `ReferenceCreation` page object manages the full reference creation sequence: Create → DieMapping → CleanReference
  - `ReferenceCreation.CleanReferenceSeq()` expands clean reference section, sets dice count checkbox, clicks Start, waits for `ReferenceGeneration` OK button
  - For die mapping: `FileSystemWatcher` monitors a folder for die mapping file creation
- **Owner class/interface:**
  - `AOI_Main.Pages.SetupTab.ReferenceCreation` — main reference creation page
  - `AOI_Main.Pages.SetupTab.ReferenceGeneration` — reference generation progress/result page
  - `AOI_Main.Pages.SetupTab.SetupTab` — parent tab
  - `AOI_Main.Pages.WaferEdit` — scan area and clean reference dice selection
- **Data model:**
  - `ReferenceCreationParams` { `bool Create`, `bool DieMapping`, `bool UseCalculatedDieMapping`, `bool CreateCleanReference`, `double TimeOutMS` (default 300000), coordinate inputs (`X_UpperRight`, `Y_UpperRight`, etc.), `List<MovementStep> Steps`, `int CleanDiceNumber`, `CleanReferenceDieChoosingParams` }
  - `SetupSequenceParams` — tracks group IDs for step sequencing
  - `CleanReferenceDieChoosingParams.DiePosition` — specifies which die to use
  - Checkboxes: `CreateChBx`, `DieMappingChBx`, `CalculatedChBx`, `CleanReferencedChBx`
- **Async/sync:** **Async** — `Task.Run` + `Task.WaitAny` + `CancellationTokenSource`. `FileSystemWatcher.Created` event used for die mapping file detection. `TaskCompletionSource<bool>` in PubSub awaiter.
- **Existing events:** `FileSystemWatcher.Created` (file-system event for die mapping file). PubSub is available (`AOI_Main.PubSub.PreparePubSubAwaiter`) but it is NOT used in reference creation sequences from the source code.
- **Threading notes:** Multiple parallel tasks for popup monitoring. `FileSystemWatcher` fires on threadpool thread.
- **Gaps / unknowns:**
  - No golden image / reference frame metadata exposed (valid/invalid, timestamp, camera, path)
  - No event for reference state changes
  - PubSub infrastructure exists but is not wired to reference creation events

---

#### 2.7 CMM Integration

- **Current mechanism:** **UI automation only.** `CmmSection` is a collapsible UI group on the scan tab. AOI_Main only expands/collapses it — no CMM operations are triggered programmatically.
- **Owner class/interface:**
  - `AOI_Main.Pages.ScanTab.CmmSection` — UI group with expand/collapse
- **Data model:**
  - Only the collapsed/expanded state of the CMM UI section. No CMM data is read or written by AOI_Main.
- **Async/sync:** Synchronous (UI click only).
- **Existing events:** **None.** DataServer `ICmmServiceNotifier` / `ICmmServiceCallbacks` duplex WCF callbacks exist but AOI_Main does NOT connect to DataServer WCF.
- **Threading notes:** N/A.
- **Gaps / unknowns:**
  - AOI_Main has zero CMM integration — no WCF connection, no ticket monitoring, no export status
  - `IFalconFireEvents.CmmImport()` / `CmmImportCompleted()` / `CmmUpdateCompleted()` exist at COM level but are not used
  - `IFalconGui.ExportMap()` exists but is not called
  - No `ScanReadyMessage` queue interaction
  - The `ExternalControlCbUiWrapper` class (in `Falcon.Net`) does have CMM COM callback stubs but AOI_Main does NOT use `ExternalControlCbUiWrapper`

---

#### 2.8 Die Edit Modification

- **Current mechanism:** **UI automation** (FlaUI). AOI_Main opens the DieEdit window via `VerticalNavigationToolbar.DieEditOpen()` and interacts with it as a page object.
- **Owner class/interface:**
  - `AOI_Main.Pages.DieEdit.DieEditMain` — main die edit window
  - `AOI_Main.Pages.DieEdit.ImportJobWindow` — import job dialog
  - `AOI_Main.Pages.DieEdit.LayersSection` + `Layer` — layer tree and individual layers
- **Data model:**
  - `DieEditMain` — `ImportJobWindow`, `LayersSection`, `ClickSave()`, `DieEditExit()`
  - `LayersSection` — `LayersTreeView`, `GetLayer(uint index)` → returns `Layer`
  - `Layer` — `ImageMaskTreeItem`, `CBtn`, `RDLBtn`, `Click()`
  - No die coordinate, classification, or reclassification data exposed
- **Async/sync:** Synchronous UI automation.
- **Existing events:** **None.** No die-edit-changed event in AOI_Main or in the COM layer.
- **Threading notes:** N/A.
- **Gaps / unknowns:**
  - No die edit state data (wafer ID, die coordinates, old/new values, timestamp)
  - No event or notification when a die edit occurs
  - `DieEdit.sln` is a separate BIS solution — AOI_Main only drives its UI

---

### Section 3 — Threading & Concurrency Model

#### 3.1 COM Apartment

- `RunnerGui` entry point is `[STAThread]` → WinForms `Application.Run(view)`
- NUnit test engine runs test methods — **NUnit 3.x uses `[Apartment(ApartmentState.STA)]` attribute or defaults to MTA** for test threads
- No `[STAThread]` or `[MTAThread]` attributes found anywhere in AOI_Main or TestAutomationSDK source
- COM calls (`CFalconExternalControl`, `IFalconGui`) are made from `Task.Run` lambdas → these run on **MTA threadpool threads**
- COM marshalling happens automatically since `CFalconExternalControl` is declared `threading(both)` in C++ ATL — supports both STA and MTA

#### 3.2 Threading Patterns

| Pattern | Where | Details |
|---|---|---|
| `Task.Run` + `Task.WaitAny` | `ScanTab.ClickScanAndWait`, `Tool.LaunchAOI`, `Tool.LoadJob`, `VerticalNavigationToolbar.AlignmentSeq`, `AutoLoader.LoadWafer`, `ProductionLoadport.WaitForExecitionEnd` | Fork multiple monitoring tasks, cancel on first completion |
| `CancellationTokenSource` / `CancellationToken` | Same locations as above | Cooperative cancellation between forked tasks |
| `TaskCompletionSource<bool>` | `AOI_Main.PubSub.PreparePubSubAwaiter` | Wraps PubSub subscription as awaitable Task |
| `Thread.Sleep` | Throughout (200ms–5000ms) | Hard wait for UI settling, keyboard input timing |
| `Retry.WhileFalse/WhileTrue` | All page objects via `Waiter` | FlaUI polling retry (configurable delay, default 100ms via `TestAutomationConfig.WaiterDelayMillisec`) |
| `FileSystemWatcher.Created` | `ReferenceCreation.cs` | Async file system notification for die mapping files |
| `System.Timers.Timer` | `Tool.LoadJob()` | Watchdog timer with cancellation |
| `lock(_locker)` | `Report`, `GUIHandler`, `Recorder`, `TestAutomationConfig`, `InProcEventsBroker` | Thread-safe singletons |
| `Recorder` background task | `Engine.Common.Services.Recorder.Recorder` | Long-running screen capture task (ffmpeg video assembly) |

#### 3.3 IPC Callback Threading

- **COM callbacks from FalconWrapper:** `CFalconExternalControl` / `CFalconEvents` are ATL `threading(both)` COM objects. Callbacks (`IFalconExternalControlCB`, `IScanManagerCB`, `IFalconGuiCB`) fire on the **COM's apartment thread** — for MTA clients, this is a COM threadpool thread. **AOI_Main does NOT subscribe to any of these callbacks.**
- **PubSub callbacks:** `InProcEventsBroker.GetCallbacks()` returns delegates under `lock`. Callbacks execute on the publisher's thread (typically a BIS process thread). For RabbitMQ transport, callbacks fire on the RabbitMQ consumer thread.
- **FlaUI:** `GUIHandler.GetRootWindow` uses `lock(_locker)`. All UI automation calls go through UIA3 COM proxy, which marshals to the target app's UI thread.

#### 3.4 Synchronization Primitives

| Primitive | Location | Purpose |
|---|---|---|
| `lock(_staticLock)` | `Report` | Thread-safe logging |
| `lock(_locker)` | `GUIHandler.GetRootWindow` | Prevent concurrent root window search |
| `lock(_staticLocker)` | `Recorder` | Thread-safe recording state |
| `lock(_createLock)` | `TestAutomationConfig` | Singleton initialization |
| `lock(_locker)` | `InProcEventsBroker` | Thread-safe callback dictionary |
| `ConcurrentQueue<T>` | **None found in AOI_Main** — only in MDC's `ScanResultService` |

#### 3.5 UI Thread Interaction

- AOI_Main does **NOT** have its own WPF Dispatcher or WinForms message loop
- It drives the **external** Falcon.Net process's UI via FlaUI UIA3 automation
- `FlaUI.Core.Input.Mouse`, `FlaUI.Core.Input.Keyboard` — inject input events into target window
- No `Dispatcher.Invoke` or `Control.Invoke` calls within AOI_Main

---

### Section 4 — Existing Event Infrastructure

#### 4.1 PubSub (CamtekSystem.PubSub)

AOI_Main has a `PubSub` wrapper class at `AOI_Main/PubSub/PubSub.cs` with:
- `static Task<bool> PreparePubSubAwaiter(EventKey eventKey)` — wraps subscription as `TaskCompletionSource<bool>`
- `static bool Subscribe(EventKey eventKey, Action<IEventMessage> action)` — direct subscription

**Transport:** Configured via `system.ini` `[PubSubEvents]` section:
- `Enabled=true/false`
- `SubscriberType=RabbitMQ|InProc|MSMQ`
- `ConnectionString=localhost`

When `PubSubEnabled=false` (default for non-production?), `SubscriberFactory.Create()` returns `NullableSubscriber` (no-op).

**EventKey structure:**
```
{
  Context: EventContext { None, Startup, Alert, Scan, Lcc, All }
  SubContext: EventSubContext { None, ProgressBar, Init, Update, IllumChannelCalib, CalibJournal, StageSurfaceCalib, StageAxesCalib, XYStageCalib, LampInfoUpdate, Execution, All }
  Source: string (process name, e.g. "AOI_Main")
  Action: EventAction { None, Occured, Start, Finished, Opened, Closed, On, Off, All }
}
```

**Current AOI_Main PubSub usage: UNKNOWN / MINIMAL** — the class exists but no call sites to `PubSub.PreparePubSubAwaiter()` or `PubSub.Subscribe()` were found in the AOI_Main page objects.

#### 4.2 WCF Duplex Callbacks

**AOI_Main does NOT use any WCF duplex callbacks.** It does not reference `System.ServiceModel` for WCF client operations. No `ScanResultsNotifierProxy`, `VerificationNotifierProxy`, or `CmmServiceNotifierProxy` usage.

#### 4.3 COM Event Infrastructure (FalconWrapper)

Three callback interface families exist in FalconWrapper but **NONE are subscribed by AOI_Main**:

| Callback Interface | Registration Method | Key Callbacks |
|---|---|---|
| `IAutoCycleManagerCB` | `IFalconEvents.RegisterAutoCycleEvent()` | `WaferScanResultsAreReady`, `WaferInspectionStarted`, `CmmImport/Complete`, `PeriodicCalibrationCompleted` |
| `IScanManagerCB` | `IFalconEvents.RegisterScanEvent()` | `OperationStarted(eScanManagerOperation, IWaferData*)`, `OperationCompleted(eScanManagerOperation, IWaferData*, eCycleCompletionCode, ...)` |
| `IFalconGuiCB` | `IFalconEvents.RegisterFalconGuiEvent()` | `JobLoaded`, `ManualScanDone`, `Set2dOpticsDone`, `UserLoggedIn/Out`, `FalconGuiLifeCycleChanged`, `ExportMapAfterReviewAtOffline`, `LCCPeriodicCalibAlert` |

Registration example (from `ExternalControlCbUiWrapper` — used by `Falcon.Net` NOT by AOI_Main):
```csharp
mExternalControl = new CFalconExternalControlClass();
mExternalControl.Init();
mExternalControl.RegisterEvent(eFalconExternalEventsId.eFEE_AllFalconEvents, this);
```

#### 4.4 C# Events/Delegates in TestAutomationSDK

| Type | Location | Details |
|---|---|---|
| `delegate void OnCloseEvent()` | `TestAutomationSDK/FSI/AutoCycle/AutoCycleSetup.cs` | File-level delegate |
| `event OnCloseEvent OnClose` | `AutoCycleSetup` class | Fired when auto-cycle setup closes |
| `event Action OnGuiStartManualScan` | `ExternalControlCbUiWrapper` (Falcon.Net) | NOT in AOI_Main scope |
| `event Action OnGuiExportMap` | `ExternalControlCbUiWrapper` (Falcon.Net) | NOT in AOI_Main scope |
| `event PropertyChangedEventHandler PropertyChanged` | `FailureClassification`, `TestCaseResultData` | INotifyPropertyChanged for results UI |

#### 4.5 Logging

- **Framework:** Serilog (via `Engine.Common.Services.Reporter.SerilogWrapper`)
- **Facade:** `Report` static class — thread-safe composite pattern (`Debug`, `Info`, `Warning`, `Error`, `TakeScreenShot`)
- **Output:** Console + File + HTML report + StepRecorder + ScreenshotWrapper
- **Log files:** Written to `C:\TestAutomation\Reports\{TestName}\` directory tree
- **Machine logs:** Read from `C:\bis\errorlog\` (FalconLog.txt, .net log files) via `LogParser` and `FalconLogParser`
- **No log4net in AOI_Main** — log4net is used by BIS/DataServer but AOI_Main uses Serilog via `Report`

#### 4.6 Rx.NET / IObservable

**None.** No `System.Reactive` or `IObservable<T>` usage found anywhere in AOI_Main, Engine.Common, Engine.FlaUI, or TestAutomationSDK.

---

### Section 5 — Constraints & Non-Negotiables

#### 5.1 Constraints Summary Table

| Constraint | Details | Impact on state design |
|---|---|---|
| **COM apartment — `threading(both)`** | `CFalconExternalControl` and `CFalconEvents` are ATL COM objects with `threading(both)`. Callbacks fire on the caller's apartment thread. NUnit test threads are typically MTA. | Any COM event sink must handle MTA callback delivery. State updates from COM callbacks need explicit marshalling to a state-owner thread. |
| **No UI thread in AOI_Main** | AOI_Main is a library — no Dispatcher, no message loop. It drives external process UI via FlaUI IPC. | State model cannot rely on `Dispatcher.Invoke`. Must use thread-safe patterns (`lock`, `ConcurrentDictionary`, etc.) |
| **FlaUI UIA3 is cross-process COM** | All UI automation goes through UIA3 COM pipes to the Falcon process. UI reads have ~10-50ms latency per element. Complex queries (XPath hierarchies) can take 100-500ms. | Polling-based state detection adds inherent latency. Batch UI reads where possible. |
| **PubSub may be disabled** | `SubscriberFactory.Create()` returns `NullableSubscriber` when `[PubSubEvents]Enabled=false` in `system.ini`. The InProc transport is process-local (cannot receive from Falcon process). | PubSub is unreliable for cross-process state notification. RabbitMQ transport is needed for production, but adds infrastructure dependency. |
| **COM singleton pattern** | `CFalconExternalControl` uses `DECLARE_CLASSFACTORY_SINGLETON` — all callers get the same instance. Thread-safe by ATL design. | Multiple COM interop calls from different test threads get same object. Event registration is shared. |
| **No WCF in AOI_Main** | AOI_Main has no `System.ServiceModel` reference. No WCF client proxies. | Cannot subscribe to DataServer duplex callbacks directly. Would need to add WCF client dependency. |
| **Log file parsing is fragile** | `LogParser` and `FalconLogParser` read `C:\bis\errorlog\FalconLog.txt` with `FileShare.ReadWrite`. They search for exact string patterns with timestamp correlation. | Log format changes break state detection. No structured log contract. Race conditions with log rotation. |
| **UI automation IDs are stable** | Page objects use `AutomationId` constants (e.g., `"frmScantab"`, `"cmdScan"`, `"hd_alignment"`) matching Falcon source code. | UI automation IDs are the integration contract. Changes to Falcon UI AutomationIds break AOI_Main. |
| **NUnit execution context** | Tests run via NUnit 3.x engine (from RunnerGui or CLI). Test order, parallelism, and apartment state are NUnit-controlled. | State model must survive test isolation. Singletons persist across tests in same AppDomain. |
| **Hard-coded paths** | `C:\bis\bin\TestAutomation\` (output), `C:\bis\bin\x64\` (Falcon binaries), `C:\bis\errorlog\` (logs), `C:\TestAutomation\` (config/reports), `C:\bis\data\Config\env\` (INI files) | Deployment paths are frozen. State model files must go into these standard locations. |
| **Falcon process is external** | AOI_Main launches `AOI_Main.exe` (Falcon) as a separate process via `Process.Start`. It has no in-process access to Falcon internals. | All state observation must be via: (1) UI automation, (2) COM interop, (3) PubSub, (4) log files, or (5) file system. No in-process events. |

#### 5.2 Integration Points That Cannot Be Changed

| Integration Point | Type | Status |
|---|---|---|
| `IFalconExternalControl` (COM) | `{6C7C115C-BAF7-4af8-8002-7F261406F9AC}` | Frozen — used by SECS/GEM, ProductionGui, Falcon.Net |
| `IFalconGui` (COM) | `{E849C759-CEC4-4c7e-B13A-83F1E3F481E1}` | Frozen — core GUI control interface |
| `IFalconExternalControlCB` (COM) | `{2BA1BA80-1C87-42DA-A8B2-9463FC896EE0}` | Frozen — callback interface |
| `IFalconGuiCB` (COM) | `{BD86796B-D767-44e9-A1B4-428CBD28DE38}` | Frozen — GUI callback interface |
| `IScanManagerCB` (COM) | `{7ADB9160-CCD3-4e97-A083-30924C444740}` | Frozen — scan lifecycle callback |
| `IAutoCycleManagerCB` (COM) | `{8DC69B05-313B-4321-A3D2-AB7DA95DA355}` | Frozen — auto-cycle callback |
| `IFalconEvents` (COM) | `{407BC9F7-301A-4096-BA88-522531C8BE1D}` | Frozen — event registration hub |
| `IFalconFireEvents` (COM) | `{B97FA438-4B61-4579-A6CC-2CBE6DF3DAC9}` | Frozen — event firing (Falcon → listeners) |
| `IWaferData` (COM) | `{41463278-4D40-4CB4-8EA2-FFC6794D4EE3}` | Frozen — wafer data contract |
| `CamtekSystem.PubSub.EventKey` | C# struct | Frozen — PubSub message key |
| `CamtekSystem.PubSub.IEventMessage` | COM-visible interface | Frozen — PubSub message envelope |
| FlaUI AutomationId strings | Convention | Semi-frozen — tied to Falcon source controls (`frmScantab`, `cmdScan`, `hd_alignment`, etc.) |
| `C:\bis\errorlog\FalconLog.txt` | File convention | Semi-frozen — log file location and format |

#### 5.3 Latency Requirements

| Domain | Required Latency | Current Latency | Notes |
|---|---|---|---|
| Scan start/complete | <1s detection | 1-2s (UI polling @ 1s interval) | Could be <10ms via COM callback |
| Alignment complete | <1s detection | 1-5s (log parsing + UI polling) | Could be <10ms via COM callback |
| Robot state change | <1s detection | 1-3s (UI element state polling) | Could be <10ms via COM callback |
| Job loaded | <500ms detection | 1-10s (UI polling for toolbar enable) | Could be <10ms via COM `JobLoaded` callback |
| Camera/illumination change | 100ms+ tolerable | N/A — not currently detected | PubSub `EventKey{Context=Lcc}` available |
| CMM export status | 100ms+ tolerable | N/A — not currently detected | WCF duplex callback available |
| Die edit | 100ms+ tolerable | N/A — not currently detected | No existing mechanism |
| Clean reference complete | <2s detection | 2-10s (UI polling) | Could use PubSub or COM |

#### 5.4 Existing Patterns to Preserve

| Pattern | Description | Must Preserve |
|---|---|---|
| **Page Object pattern** | All UI interaction via `BasePage` → `IPage` hierarchy | ✓ Yes — 47 page objects depend on this |
| **`Report` static facade** | Thread-safe logging via `Report.Debug/Info/Error/TakeScreenShot` | ✓ Yes — used everywhere |
| **`Waiter` polling** | `Waiter.WhileFalse/WhileTrue` with configurable delay | ✓ Yes — core synchronization pattern |
| **`TestAutomationConfig` singleton** | JSON-persisted configuration | ✓ Yes — controls all test behavior |
| **`Tool` as orchestrator** | `TestAutomationSDK.FSI.Tool` coordinates page objects | ✓ Yes — all test methods use it |
| **`TestRunner` scope** | `TestRunnerScope : IDisposable` for error detection | ✓ Yes — deterministic test framework |
| **NUnit data-driven tests** | `TestCaseSourceHelper` + JSON test case files | ✓ Yes — test discovery mechanism |
| **COM `CFalconExternalControl`** | Singleton COM object for Falcon control | ✓ Yes — only programmatic API to Falcon |

---

## 17. AOI_Main State System — Architecture Alternatives: Scored Comparison (2026-04-04)

### 0. Discovery-vs-Proposal Corrections

Before scoring, several **critical mismatches** between the proposal's assumptions and actual discovery findings must be stated. These are not minor: they change the feasibility and scoring of all three alternatives.

| Proposal assumption | Reality (from Section 16 discovery) | Impact |
|---|---|---|
| "COM event from `DdsIPC`/`GrabIPC`" feeds Scan domain | AOI_Main has **zero** access to `DdsIPC`/`GrabIPC`/`AcqIPC`. These are BIS-internal, in-process IPC channels between Falcon.Net native modules. AOI_Main runs **out-of-process** (separate DLL loaded by NUnit). The only existing IPC path is via COM `CFalconExternalControl` singleton. | Alt 1/2/3 bridge diagrams showing "COM event from DdsIPC" are invalid. The actual bridge must go through `IScanManagerCB` COM callback (currently NOT subscribed) or PubSub. |
| "WCF duplex callback from Job.NET" feeds Job domain | AOI_Main has **no WCF reference** (`System.ServiceModel` is absent from project). No WCF client proxies exist. WCF is used by DataServer ↔ CMM, not by AOI_Main. | Job bridge cannot use WCF. Must use COM `IFalconGuiCB.JobLoaded` callback or PubSub. |
| "WCF duplex `CmmServiceNotifierProxy`" feeds CMM domain | Same — no WCF in AOI_Main. `CmmServiceNotifierProxy` is a DataServer component. | CMM bridge needs COM `IAutoCycleManagerCB.CmmImportCompleted` or PubSub, not WCF. |
| "WinSock TCP from `PizzaServer.exe`" feeds Robot domain | AOI_Main does not connect to PizzaServer TCP. It reads robot state via **FlaUI UI automation** of the AutoLoader window. | Robot bridge must subscribe to COM `IAutoCycleManagerCB` callbacks or replicate UI automation observations. |
| "COM event from camera driver" feeds Camera domain | AOI_Main has no reference to any BIS camera driver DLL. Camera state is not observed — only UI buttons clicked. | Camera bridge must use PubSub `EventKey{Context=Lcc}` or add COM camera driver reference. |
| "COM event from Alignment module" | AOI_Main reads alignment results from `FalconLog.txt` via `FalconLogParser.VerifyAlignmentPassed()`. No COM event subscription. | Alignment bridge must subscribe to `IScanManagerCB.OperationCompleted(eSMO_Alignment)`. |
| "Direct call after clean operation" | AOI_Main drives clean reference via UI automation (`ReferenceCreation.CleanReferenceSeq()`). No callback. Result is detected by UI polling (OK button on `ReferenceGeneration` window). | Clean ref bridge needs either a COM callback or continuation of UI polling with event emission. |
| "COM event or file-watch on ticket directory" for Die Edit | No COM event for die edit exists. AOI_Main drives die edit via UI only (`DieEditMain`). No file-watch. | Die edit remains the weakest domain — no existing event source at all. |
| "This mirrors the Prism EventAggregator pattern already used in MDC" (Alt 3) | **Confirmed** — MDC uses `Prism.Core` (versionless NuGet), RMS uses Prism 7.2/8.1, SystemCalibration uses Prism 5.0.  **But** AOI_Main / TestAutomationSDK / Engine.Common / Engine.FlaUI do NOT reference Prism today. Adding it is possible but is a new dependency for this project set. | Alt 3 "zero new deps" claim is **partially false** for AOI_Main — Prism DLLs exist in `c:\bis\bin\` but AOI_Main.csproj must be modified to reference them. However, a custom lightweight event aggregator (~100 LOC) could replace Prism, keeping "zero new deps" true. |
| `record` types for Alt 1 immutable state | .NET Framework 4.8 / C# 7.3 — no `record` or `with`-expressions. | Must use manual immutable classes with copy constructors. Adds boilerplate but is feasible. |
| `System.Reactive` for Alt 2 | **Not used anywhere** in the entire monorepo (BIS, MDC, RMS, SystemCalibration, ToolAnalytics). Would be the first introduction. | Rx.NET is a genuine new-dependency risk — no existing team expertise or CI/CD packaging for it. |

### 1. Alternative Summaries

**Alternative 1 — Centralized Immutable State Store (Redux-style)**
A single `AoiStateStore` manages the complete system state as an immutable snapshot object. Every state change is represented as a `StateAction` dispatched to a `ConcurrentQueue<IStateAction>`, drained by a dedicated background thread that produces a new `AoiState` snapshot and fires `event StateChanged`. COM and PubSub callbacks never block — they only enqueue. This gives a single source of truth with time-travel debugging capability, but requires manual immutable-class boilerplate on .NET 4.8 (no records), couples all 8 domains in one event, and doubles the event wiring since every existing COM/PubSub callback must be bridged into an action. The GC pressure from allocating a new 8-field aggregate object on every scan tick is a concern for high-frequency grab loops — though in practice AOI_Main's observation rate (~1 Hz UI polling today) would not stress this.

**Alternative 2 — Per-Domain Reactive Subjects (Rx.NET / IObservable)**
Each of the 8 domains is an independent `BehaviorSubject<T>` observable stream. Consumers subscribe to individual domains or compose them with LINQ operators (`CombineLatest`, `Merge`, `Throttle`). Per-domain isolation means a scan tick never fires a CMM subscriber. `BehaviorSubject` replays the latest value on subscribe, eliminating "missed event at startup" bugs. However, `System.Reactive` is completely absent from this monorepo — it would be the first introduction, adding an unfamiliar dependency with a steep learning curve. `Observable.FromEvent` over COM callbacks requires careful scheduler selection or risks STA deadlocks. Rx exception handling (silent `OnError` stream termination) is a subtle bug source, and debugging Rx pipelines is significantly harder than plain C# events for the team.

**Alternative 3 — Event Aggregator with Typed Domain Events (Prism-style)**
A lightweight in-process event bus with strongly-typed events per domain (`ScanStateChangedEvent`, `RobotStateChangedEvent`, etc.). Publishers call `Publish(payload)`, subscribers call `Subscribe(handler, ThreadOption)`. This mirrors the Prism `EventAggregator` pattern already proven in MDC and SystemCalibration. The critical advantage: no new conceptual dependency — Prism DLLs already exist in `c:\bis\bin\`, and a custom 100-line event aggregator can replicate the pattern without even adding the Prism NuGet reference. `ThreadOption.BackgroundThread` keeps COM STA unblocked. Weak-reference subscriptions prevent leaks. The main limitation is no built-in "current value on subscribe" (mitigated by an `AoiStateCache` companion) and no cross-domain composition without manual wiring.

### 2. Evaluation Matrix (Scored with Justification)

| Criterion | Weight | Alt 1: Redux Store | Alt 2: Rx.NET | Alt 3: Event Aggregator |
|---|---|---|---|---|
| **Non-blocking (COM/UI thread safety)** | 30% | **5** — ConcurrentQueue enqueue is lock-free. COM STA never waits. Dedicated drain thread. | **4** — `ObserveOn(TaskPoolScheduler)` achieves it, but incorrect scheduler choice causes STA deadlock. One misconfigured `.ObserveOn()` is a production hang. | **5** — `ThreadOption.BackgroundThread` dispatches to ThreadPool by default. `Publish()` returns immediately. No STA affinity. |
| **Fits existing .NET 4.8 + COM constraints** | 25% | **3** — No `record` types (C# 7.3). Must hand-write immutable classes + clone methods for 8 domain objects. `ConcurrentQueue<T>` is fine. COM callback → enqueue bridging is straightforward. Feasible but tedious boilerplate. | **3** — `System.Reactive` 5.x supports net48 ✅. But `Observable.FromEvent` over COM callbacks requires `SynchronizationContext`-aware marshalling. COM `threading(both)` helps but `.ObserveOn()` selection is error-prone. Never been done in this codebase. | **5** — Prism 5-8 all support net48. DLLs already in `c:\bis\bin\`. Pattern proven in MDC + SystemCalibration. OR a custom EventAggregator is trivially net48-compatible. COM callback → `Publish()` is a 1-line bridge. |
| **Team familiarity / learning curve** | 15% | **2** — Redux/Flux pattern is not used anywhere in the monorepo. Immutable state + action dispatch is a paradigm shift from the existing procedural/page-object style. Requires team training. | **1** — Rx.NET is absent from the entire monorepo. No team member has shipped Rx code in this codebase. Scheduler model, hot vs cold observables, error handling semantics — all require dedicated training. Silent `OnError` stream termination will produce subtle production bugs during the learning phase. | **5** — `EventAggregator.GetEvent<T>().Subscribe()` is already understood. MDC ViewModels use this exact pattern. SystemCalibration modules use it. Team can read existing code as examples. |
| **Testability** | 15% | **5** — Inject actions, assert resulting `AoiState` snapshot. Deterministic: same actions always produce same state. Serializable for replay. | **4** — `TestScheduler` virtual-time testing is powerful BUT requires Rx expertise to write tests correctly. `Subscribe()` + manual `OnNext()` injection is easy for simple cases; complex timing tests are harder. | **4** — Mock `IEventAggregator`, assert `Publish()` calls and `Subscribe()` handler invocations. Straightforward. No time-travel but sufficient for domain validation. The companion `AoiStateCache` is separately testable. |
| **Composability across domains** | 10% | **3** — `StateChanged` fires on every change with full snapshot — consumer can derive cross-domain predicates from the snapshot. But there's no selective subscription: CMM subscriber receives scan ticks too. Must filter client-side. | **5** — `CombineLatest`, `Merge`, `WithLatestFrom`, `Zip` — first-class cross-domain composition. This is Rx's strongest feature. | **2** — No built-in composition. Cross-domain logic requires subscribing to N events and manually coordinating. An `AoiStateCache` helps but adds custom code per cross-domain scenario. |
| **Zero new external dependencies** | 5% | **4** — No NuGet dependency needed. `ConcurrentQueue`, `Interlocked`, `EventHandler<T>` are all BCL. But requires ~300 lines of immutable-class boilerplate. | **1** — `System.Reactive` 5.x is a completely new NuGet dependency. Never used in this monorepo. Adds `System.Reactive.Core`, `System.Reactive.Interfaces`, `System.Reactive.Linq`, `System.Reactive.PlatformServices`, `System.Reactive.Windows.Threading` — 5 assemblies. | **5** — Custom event aggregator: 0 new deps (~100 LOC). Or reference existing `Prism.Core` from `c:\bis\bin\` — already deployed. Either way, no new NuGet package approval needed. |
| **Weighted total** | 100% | **3.60** | **2.95** | **4.55** |

**Weighted calculation detail:**

| | Alt 1 | Alt 2 | Alt 3 |
|---|---|---|---|
| Non-blocking × 0.30 | 1.50 | 1.20 | 1.50 |
| Fits constraints × 0.25 | 0.75 | 0.75 | 1.25 |
| Team familiarity × 0.15 | 0.30 | 0.15 | 0.75 |
| Testability × 0.15 | 0.75 | 0.60 | 0.60 |
| Composability × 0.10 | 0.30 | 0.50 | 0.20 |
| Zero new deps × 0.05 | 0.20 | 0.05 | 0.25 |
| **Total** | **3.80** | **3.25** | **4.55** |

*(Note: My weighted totals differ from the proposal's because I scored Alt 2 lower on team familiarity (1 vs 2) and constraints (3 vs 4) based on the discovery finding that Rx.NET is completely absent from the entire monorepo, and Alt 3 higher on constraints (5 vs 5 — matches) because Prism DLLs are already deployed.)*

### 3. Hybrid Option Assessment

The Hybrid (Alt 3 + selective Alt 2 wrapping) is **worth pursuing** and should be the default recommendation. The Event Aggregator provides the non-blocking, zero-new-deps, team-familiar backbone, while the `AoiStateCache` companion solves the "current value on subscribe" gap. For the rare consumer that genuinely needs cross-domain composition (e.g., "alert when scan completes AND CMM is idle"), a thin `IObservable<T>` wrapper around the cache could be added later — but only on the **consumer** side, keeping Rx out of the core infrastructure. This approach defers the Rx dependency decision without closing the door, and avoids the all-or-nothing commitment that pure Alt 2 demands.

### 4. Recommendation for Prompt 3

**Take Alternative 3 (Event Aggregator) and the Hybrid variant (Alt 3 + AoiStateCache) to Prompt 3 for detailed design.**

Alternative 2 (Rx.NET) is eliminated:
- It scores lowest overall (3.25 weighted)
- It introduces the only genuinely new external dependency (`System.Reactive`) that has zero precedent in the monorepo
- Its strongest feature (cross-domain composability) is a "nice to have" for 8 independent test automation domains that are almost never composed today
- The STA deadlock risk from misconfigured `.ObserveOn()` over COM callbacks is a production-down scenario that the team has no experience debugging

Alternative 1 (Redux Store) is carried **as the second option** to Prompt 3:
- It scores 3.80 — meaningfully above Alt 2
- Its time-travel / action-replay capability is genuinely valuable for test automation debugging
- The .NET 4.8 boilerplate concern (no records) is a one-time cost, not a recurring risk
- It provides the strongest testability story (inject actions → assert snapshot)
- If Prompt 3 design reveals that cross-domain snapshot queries are frequently needed, Alt 1's "single source of truth" may outweigh Alt 3's per-domain isolation

**Final ranking:**
1. **Alt 3 — Event Aggregator** (4.55) → **Primary candidate** for Prompt 3
2. **Alt 1 — Redux Store** (3.80) → **Secondary candidate** for Prompt 3
3. **Alt 2 — Rx.NET** (3.25) → **Eliminated** (salvageable as thin consumer-side wrapper in Hybrid)

---

## 18. AOI_Main State System — Full Design Document (2026-04-04)

### Step 1 — Architecture Decision Record

```
## ADR-001: AOI_Main State Architecture

Status:    Accepted
Date:      2026-04-04
Deciders:  Architecture Review Board, Test Automation Team Lead, AOI_Main maintainers
```

#### Context

AOI_Main is a .NET Framework 4.8 UI-automation library (not an executable) that drives the Falcon.Net inspection application via FlaUI. It currently has **no formal state model**: all 8 state domains (Scan, Robot, Camera/Lights, Job, Alignment, Clean Reference, CMM, Die Edit) are observed via UI element polling and log-file parsing, with 1–10 second detection latency. The existing COM callback interfaces (`IScanManagerCB`, `IFalconGuiCB`, `IAutoCycleManagerCB`) and PubSub infrastructure (`CamtekSystem.PubSub` with RabbitMQ/InProc/MSMQ transports) are available but **none are subscribed** by AOI_Main today. The state system must be non-blocking (COM STA safety), event-driven, composable per domain, testable without hardware, and compatible with .NET Framework 4.8 (C# 7.3 — no records, no pattern matching on types).

#### Decision

Adopt **Alternative 3 — Event Aggregator with Typed Domain Events** in the **Hybrid variant** (Event Aggregator + `AoiStateCache` companion). Implement a custom lightweight event aggregator (~150 LOC, zero external dependencies) modelled on the Prism `PubSubEvent<T>` pattern already proven in MDC and SystemCalibration. Add an `AoiStateCache` that subscribes to all 8 domain events and maintains last-known state per domain, solving the "no current value on subscribe" gap. Defer Rx.NET to an optional consumer-side wrapper if cross-domain composition is needed later.

#### Consequences

**Positive:**
- Weighted score 4.55 — highest of all 3 alternatives (vs 3.80 Redux, 3.25 Rx.NET)
- Zero new external dependencies: custom event aggregator uses only BCL types (`ConcurrentDictionary`, `ThreadPool.QueueUserWorkItem`, `SynchronizationContext.Post`)
- Team familiarity: Prism `EventAggregator.GetEvent<T>().Subscribe(handler, ThreadOption)` pattern is identical to existing MDC/SystemCalibration code — zero learning curve
- Non-blocking by design: `Publish()` dispatches to ThreadPool for `BackgroundThread` subscribers, posts via `SynchronizationContext` for `UIThread` subscribers — never blocks the publishing thread
- Fully testable: `IAoiEventAggregator` is an interface — inject a mock/stub in unit tests; no COM server or hardware needed
- `AoiStateCache.GetCurrentState()` provides lock-free snapshot reads for consumers that need current state without subscribing

**Negative / trade-offs accepted:**
- No built-in cross-domain composition (unlike Rx `CombineLatest`) — accepted because the 8 domains are almost never composed today; the `AoiStateCache` snapshot suffices for the rare cross-domain predicate
- No time-travel / action-replay debugging (unlike Redux) — accepted because the Serilog `Report` facade already logs all state transitions; action replay can be approximated by replaying log entries
- Global event bus can become "who published this?" opaque — mitigated by requiring all `Publish()` calls to originate only from `IAoiStateBridge` implementations (enforced by code review, logged by bridge name)
- Manual immutable-class boilerplate for 8 payload types (no C# 9 records) — accepted as one-time cost; each payload is ~15 lines

**Risks:**
- Bridge complexity: each bridge must correctly subscribe to COM `CFalconEvents` callbacks (new code). Mitigated by following the proven `ExternalControlCbUiWrapper` registration pattern from `Falcon.Net`
- PubSub transport may be disabled (`NullableSubscriber`): bridges using PubSub must fall back gracefully. Mitigated by bridge `Start()` logging the transport status and setting domain state to `Unknown` on failure
- COM callback thread safety: callbacks fire on COM apartment threads (MTA for `threading(both)` objects). Mitigated by bridge handlers doing only mapping + `Publish()` — no locks, no I/O, no blocking

---

### Step 2 — Complete Class Design

#### 2.1 Enums

```
ScanStatus
├── Unknown         = 0
├── Idle            = 1
├── Starting        = 2
├── Grabbing        = 3
├── ColorGrab       = 4
├── Aborting        = 5
├── Complete        = 6
└── Error           = 7

ScanOperationType               (mirrors COM eScanManagerOperation)
├── Unknown             = 0
├── WaferMapImport      = 1
├── WaferMapExport      = 2
├── Alignment           = 3
├── InkDotScan          = 4
├── Scan2D              = 5
├── Scan3D              = 6
├── InkMarking          = 7
├── ImageGrabbing       = 8
├── WaferVerification   = 9
├── OverlayScan         = 10
├── Layer3DScan         = 11
├── AutoFocus           = 12
└── Other               = 99

RobotStatus
├── Unknown     = 0
├── Idle        = 1
├── Loading     = 2
├── Unloading   = 3
├── Mapping     = 4
├── Docking     = 5
├── Undocking   = 6
├── Homing      = 7
└── Error       = 8

JobStatus
├── None        = 0
├── Loading     = 1
├── Loaded      = 2
├── Running     = 3
├── Deleted     = 4
└── Error       = 5

AlignmentResult
├── Unknown     = 0
├── InProgress  = 1
├── Passed      = 2
├── Failed      = 3
└── Skipped     = 4

CmmPhase
├── Idle        = 0
├── Importing   = 1
├── Exporting   = 2
├── Done        = 3
└── Error       = 4

DieEditType
├── Unknown       = 0
├── Reclassify    = 1
├── Exclude       = 2
├── Restore       = 3
└── LayerEdit     = 4

ManagerState                    (mirrors COM eManagerState)
├── Undefined     = 0
├── Initializing  = 1
├── Idle          = 2
├── Executing     = 3
├── Pausing       = 4
├── Paused        = 5
├── Stopping      = 6
└── Aborting      = 7

AoiThreadOption
├── PublisherThread    = 0     handler runs on calling thread
├── BackgroundThread   = 1     handler dispatched to ThreadPool
└── UIThread           = 2     handler dispatched via SynchronizationContext
```

#### 2.2 State Payload Data Types

All payloads are immutable classes with readonly fields, set via constructor. All override `ToString()` for diagnostic logging. All are `[Serializable]` for Serilog structured logging and JSON snapshot export.

```
ScanStatePayload
├── Status              : ScanStatus
├── OperationType       : ScanOperationType
├── WaferId             : string                  (from IWaferData or UI, null if unknown)
├── LotId               : string                  (from ScanTab.LotTextBox, null if unknown)
├── CompletionCode      : string                  (from eCycleCompletionCode: "Success", "Stopped", "Aborted", etc.)
├── StartTimeUtc        : DateTime
├── ElapsedMs           : long
└── ErrorMessage        : string                  (null if no error)

    Note: ProgressPercent is NOT included — discovery found no programmatic
    scan progress source. BIS does not expose scan % via COM or PubSub.
    Can be added later if IScanManagerCB is extended.
```

```
RobotStatePayload
├── Status              : RobotStatus
├── PortId              : int                     (loadport number, -1 if unknown)
├── SlotId              : int                     (wafer slot number, -1 if unknown)
├── HasWaferOnChuck     : bool
├── AutoCycleState      : ManagerState            (from eManagerState via IAutoCycleManagerCB)
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)
```

```
CameraLightPayload
├── OpticMode           : string                  (e.g. "2D", "3D" — from UI button state or Set2dOpticsDone callback)
├── IsIlluminationError : bool                    (true if PopUpIlluminationError detected)
├── LccCalibAlert       : bool                    (from IFalconGuiCB.LCCPeriodicCalibAlert)
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)

    Note: CameraId, Channel, Intensity, Objective are NOT included — discovery
    found AOI_Main has zero reference to BIS camera driver DLLs and no
    programmatic access to illumination channel data. These fields can be
    added when camera driver COM interop is introduced.
```

```
JobStatePayload
├── Status              : JobStatus
├── JobName             : string                  (from IFalconGuiCB.JobLoaded or UI combobox)
├── SetupName           : string
├── RecipeName          : string
├── CompletionCode      : long                    (from IFalconGuiCB.JobLoaded completionCode param)
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)
```

```
AlignmentPayload
├── Result              : AlignmentResult
├── WaferId             : string                  (from IWaferData if available, else null)
├── OperationType       : ScanOperationType       (= ScanOperationType.Alignment)
├── CompletionCode      : string                  (from eCycleCompletionCode)
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)

    Note: OffsetX/OffsetY/Angle are NOT included — discovery found these are
    not exposed via COM IScanManagerCB callbacks (only operation + completion
    code). Log parsing for offsets is fragile. These can be added if a
    structured alignment result COM interface is introduced.
```

```
CleanRefPayload
├── IsValid             : bool
├── Phase               : string                  ("Creating" | "DieMapping" | "CleanReference" | "Complete" | "Error")
├── DiceCount           : int                     (number of clean reference dice)
├── FilesystemEvent     : string                  (FileSystemWatcher path if die mapping detected, null otherwise)
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)

    Note: CameraId and FilePath for golden image are NOT included — discovery
    found no programmatic access to reference frame metadata. These are
    internal to BIS ReferenceCreation module.
```

```
CmmStatePayload
├── Phase               : CmmPhase
├── OperationType       : string                  ("CmmImport" | "CmmUpdate" | "CmmExport" | null)
├── CompletionCode      : string                  (from eCycleCompletionCode if available)
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)

    Note: TicketId and ExportPath are NOT included — discovery found AOI_Main
    has no WCF connection to DataServer and no access to CMM ticket data.
    COM callbacks IAutoCycleManagerCB.CmmImportCompleted / CmmUpdateCompleted
    fire with no ticket ID parameter.
```

```
DieEditPayload
├── EditType            : DieEditType
├── LayerIndex          : int                     (from LayersSection.GetLayer(index), -1 if unknown)
├── LayerName           : string                  (layer label text from UI, null if unknown)
├── IsSaved             : bool                    (true after DieEditMain.ClickSave())
├── Timestamp           : DateTime
└── ErrorMessage        : string                  (null if no error)

    Note: WaferId, DieRow/Col, Before/After classification values, and
    OperatorId are NOT included — discovery found AOI_Main's DieEdit page
    objects expose only layer tree navigation and save/exit buttons.
    No die coordinate or classification data is accessible via UI automation.
```

#### 2.3 Event Classes

```
AoiStateEventBase<TPayload>                   (abstract generic base)
├── Payload         : TPayload                (the domain-specific DTO)
├── TimestampUtc    : DateTime                (UTC wall-clock time of event creation)
├── SequenceNo      : long                    (monotonically increasing, from AoiEventAggregator._sequenceCounter)
├── BridgeName      : string                  (name of the bridge that published, for diagnostics)
└── ToString()      : string                  (returns "[{SequenceNo}] {BridgeName}: {Payload}")

ScanStateChangedEvent       : AoiStateEventBase<ScanStatePayload>
RobotStateChangedEvent      : AoiStateEventBase<RobotStatePayload>
CameraLightChangedEvent     : AoiStateEventBase<CameraLightPayload>
JobStateChangedEvent        : AoiStateEventBase<JobStatePayload>
AlignmentChangedEvent       : AoiStateEventBase<AlignmentPayload>
CleanRefChangedEvent        : AoiStateEventBase<CleanRefPayload>
CmmStateChangedEvent        : AoiStateEventBase<CmmStatePayload>
DieEditChangedEvent         : AoiStateEventBase<DieEditPayload>
```

#### 2.4 Core Infrastructure

```
IAoiEventAggregator                                              (interface — inject/mock in tests)
├── Publish<TEvent>(TEvent evt) : void                           thread-safe, non-blocking
├── Subscribe<TEvent>(Action<TEvent> handler,
│                      AoiThreadOption threadOpt) : IDisposable  returns token for unsubscribe
└── GetCurrentState() : AoiStateSnapshot                         lock-free read of last known state

AoiEventAggregator : IAoiEventAggregator                         (concrete, singleton per test session)
├── [private] ConcurrentDictionary<Type, SubscriptionList> _subscriptions
├── [private] AoiStateCache _cache                               companion — updated on every Publish
├── [private] long _sequenceCounter                              Interlocked.Increment on each Publish
│
├── Publish<TEvent>(TEvent evt) : void
│       1. Interlocked.Increment → evt.SequenceNo
│       2. _cache.Update(evt)                                    volatile write of domain slot
│       3. foreach subscriber in _subscriptions[typeof(TEvent)]:
│            if PublisherThread  → invoke directly
│            if BackgroundThread → ThreadPool.QueueUserWorkItem(handler, evt)
│            if UIThread         → SynchronizationContext.Post(handler, evt)
│       4. return immediately
│
├── Subscribe<TEvent>(handler, threadOpt) : IDisposable
│       1. wrap handler + threadOpt in Subscription<TEvent>
│       2. _subscriptions.GetOrAdd(typeof(TEvent)).Add(subscription)
│       3. return SubscriptionToken { Dispose() → remove from list }
│
└── GetCurrentState() : AoiStateSnapshot
        return _cache.Snapshot                                   Volatile.Read per domain slot

AoiStateCache                                                    (internal companion)
├── [private volatile] ScanStatePayload    _scan
├── [private volatile] RobotStatePayload   _robot
├── [private volatile] CameraLightPayload  _cameraLight
├── [private volatile] JobStatePayload     _job
├── [private volatile] AlignmentPayload    _alignment
├── [private volatile] CleanRefPayload     _cleanRef
├── [private volatile] CmmStatePayload     _cmm
├── [private volatile] DieEditPayload      _dieEdit
│
├── Update(AoiStateEventBase<T> evt)       switch on typeof(T) → volatile write to slot
└── Snapshot : AoiStateSnapshot            { get → new AoiStateSnapshot(_scan, _robot, ...) }

AoiStateSnapshot                                                 (immutable, created on demand)
├── Scan        : ScanStatePayload         (null if domain never published)
├── Robot       : RobotStatePayload
├── CameraLight : CameraLightPayload
├── Job         : JobStatePayload
├── Alignment   : AlignmentPayload
├── CleanRef    : CleanRefPayload
├── Cmm         : CmmStatePayload
├── DieEdit     : DieEditPayload
└── ToString()  : string                   summary of all non-null domains

SubscriptionList                                                 (internal, per event type)
├── [private] List<ISubscription> _items   guarded by lock
├── Add(ISubscription sub)                 lock → add
├── Remove(ISubscription sub)              lock → remove
└── GetSnapshot() : ISubscription[]        lock → ToArray() (snapshot for iteration)

ISubscription                                                    (internal)
├── ThreadOption   : AoiThreadOption
├── HandlerRef     : WeakReference<Delegate>    prevents memory leaks
├── IsAlive        : bool
└── Invoke(object evt)

SubscriptionToken : IDisposable                                  (returned to consumer)
├── [private] SubscriptionList _owner
├── [private] ISubscription _sub
└── Dispose()       → _owner.Remove(_sub)
```

#### 2.5 Bridge Adapters

```
IAoiStateBridge                                                  (interface — stub in tests)
├── Start() : void            subscribe to source event / register COM callback
├── Stop()  : void            unsubscribe, release COM references
└── BridgeName : string       diagnostic identifier (e.g. "ScanStateBridge")

AoiStateBridgeOrchestrator                                       (lifecycle manager)
├── [private] List<IAoiStateBridge> _bridges                     injected via constructor
├── [private] IAoiEventAggregator _eventAggregator
├── Start()   → foreach bridge: try { bridge.Start() } catch { log + set domain Unknown }
├── Stop()    → foreach bridge: try { bridge.Stop()  } catch { log }
└── Dispose() → Stop()


ScanStateBridge : IAoiStateBridge
    Source:  COM IScanManagerCB via IFalconEvents.RegisterScanEvent()
    Wires:   IScanManagerCB.OperationStarted  → Publish ScanStateChangedEvent(Starting/Grabbing)
             IScanManagerCB.OperationCompleted → Publish ScanStateChangedEvent(Complete/Error)
             IFalconGuiCB.ManualScanDone      → Publish ScanStateChangedEvent(Complete)

RobotStateBridge : IAoiStateBridge
    Source:  COM IAutoCycleManagerCB via IFalconEvents.RegisterAutoCycleEvent()
    Wires:   IAutoCycleManagerCB.WaferInspectionStarted   → Publish RobotStateChangedEvent(Loading)
             IAutoCycleManagerCB.WaferScanResultsAreReady → Publish RobotStateChangedEvent(Idle)
             IAutoCycleManagerCB.StateChanged(eManagerState) → Publish with mapped ManagerState

CameraLightBridge : IAoiStateBridge
    Source:  COM IFalconGuiCB via IFalconEvents.RegisterFalconGuiEvent()
    Wires:   IFalconGuiCB.Set2dOpticsDone()          → Publish CameraLightChangedEvent(OpticMode="2D")
             IFalconGuiCB.LCCPeriodicCalibAlert(b)   → Publish CameraLightChangedEvent(LccCalibAlert=b)
    Fallback: PubSub EventKey{Context=Lcc, SubContext=IllumChannelCalib} if COM callback insufficient

JobStateBridge : IAoiStateBridge
    Source:  COM IFalconGuiCB via IFalconEvents.RegisterFalconGuiEvent()
    Wires:   IFalconGuiCB.JobLoaded(jobName, setupName, recipeName, completionCode)
                → Publish JobStateChangedEvent(Loaded or Error based on completionCode)
             IFalconGuiCB.FalconGuiLifeCycleChanged(eFalconTerminating)
                → Publish JobStateChangedEvent(None) — Falcon shutting down

AlignmentBridge : IAoiStateBridge
    Source:  COM IScanManagerCB via IFalconEvents.RegisterScanEvent()
    Wires:   IScanManagerCB.OperationStarted(eSMO_Alignment, ...)
                → Publish AlignmentChangedEvent(InProgress)
             IScanManagerCB.OperationCompleted(eSMO_Alignment, waferData, completionCode, ...)
                → Publish AlignmentChangedEvent(Passed or Failed based on completionCode)

CleanRefBridge : IAoiStateBridge
    Source:  Explicit API call from ReferenceCreation page object + FileSystemWatcher
    Wires:   CleanRefBridge.NotifyPhaseChange(phase, diceCount)
                → Publish CleanRefChangedEvent(phase)
             FileSystemWatcher.Created
                → Publish CleanRefChangedEvent(Phase="DieMapping", FilesystemEvent=path)
    Note:    This bridge has no COM event source — clean reference lifecycle is driven
             by AOI_Main UI automation. The bridge is called directly by ReferenceCreation
             page object methods at each phase transition.

CmmBridge : IAoiStateBridge
    Source:  COM IAutoCycleManagerCB via IFalconEvents.RegisterAutoCycleEvent()
    Wires:   IAutoCycleManagerCB.CmmImportCompleted()    → Publish CmmStateChangedEvent(Done, "CmmImport")
             IAutoCycleManagerCB.CmmUpdateCompleted()    → Publish CmmStateChangedEvent(Done, "CmmUpdate")
             IFalconFireEvents.CmmImport() [if observable] → Publish CmmStateChangedEvent(Importing)
    Note:    AOI_Main currently has zero CMM integration. This bridge activates a
             previously dormant COM callback path. Requires IFalconEvents registration.

DieEditBridge : IAoiStateBridge
    Source:  Explicit API call from DieEditMain page object
    Wires:   DieEditBridge.NotifyEditApplied(editType, layerIndex, layerName)
                → Publish DieEditChangedEvent
             DieEditBridge.NotifySaved()
                → Publish DieEditChangedEvent(IsSaved=true)
    Note:    No COM or PubSub event exists for die edits. This bridge is called
             directly by DieEditMain page object methods. It converts imperative
             UI automation steps into state events.
```

#### 2.6 Consumer API Examples

```csharp
// === Subscription — returns IDisposable for clean unsubscribe ===
IDisposable scanSub = _eventAgg.Subscribe<ScanStateChangedEvent>(
    evt => HandleScan(evt.Payload),
    AoiThreadOption.BackgroundThread);

// === Query current state without waiting for next event ===
AoiStateSnapshot snap = _eventAgg.GetCurrentState();
ScanStatePayload current = snap.Scan;   // null if not yet received

// === Multi-domain check (synchronous, via cache) ===
var state = _eventAgg.GetCurrentState();
bool canStartCmm = state.Scan?.Status == ScanStatus.Complete
                 && state.Cmm?.Phase == CmmPhase.Idle;

// === Unsubscribe ===
scanSub.Dispose();

// === In test code — no COM needed ===
var mockAgg = new MockAoiEventAggregator();
mockAgg.SimulatePublish(new ScanStateChangedEvent(
    new ScanStatePayload(ScanStatus.Complete, ScanOperationType.Scan2D,
        "W001", "LOT1", "Success", DateTime.UtcNow, 45000, null),
    "ScanStateBridge"));
Assert.AreEqual(ScanStatus.Complete, mockAgg.GetCurrentState().Scan.Status);
```

---

### Step 3 — Threading Model (Formal Specification)

#### 3.1 COM Callback Path (Scan, Robot, Camera, Job, Alignment, CMM)

```
[COM Apartment Thread — CFalconEvents callback delivery]
    │  Threading model: "both" (ATL) — callback arrives on caller's apartment.
    │  For MTA callers (AOI_Main Task.Run threads): arrives on COM threadpool thread.
    │  For STA callers (RunnerGui main thread): arrives on STA thread.
    ↓
Bridge.OnComCallback(comArgs)           ← MUST return in <1ms, never block, no locks
    │  1. Map comArgs → typed payload (pure computation, no I/O)
    │  2. Create event: new TEvent(payload, bridgeName)
    ↓
AoiEventAggregator.Publish<TEvent>(evt)
    │  3. Interlocked.Increment(_sequenceCounter) → evt.SequenceNo           [~10ns]
    │  4. _cache.Update(evt)  → Volatile.Write to single domain slot         [~10ns]
    │  5. snapshot = _subscriptions[typeof(TEvent)].GetSnapshot()             [lock + ToArray, <1µs]
    │  6. foreach sub in snapshot:
    │       PublisherThread  → sub.Invoke(evt) directly                       [runs on COM thread!]
    │       BackgroundThread → ThreadPool.QueueUserWorkItem(sub.Invoke, evt)  [<1µs enqueue]
    │       UIThread         → SynchronizationContext.Post(sub.Invoke, evt)   [<1µs post]
    ↓
Return to COM apartment immediately ✓
    Total Publish() cost on COM thread: <50µs

[ThreadPool thread — BackgroundThread subscriber]
    │  try { handler(evt); } catch (Exception ex) { Report.Error(ex); }
    ↓
    Subscriber does its work (logging, state assertion, test verdict)

[UI SynchronizationContext thread — UIThread subscriber]
    │  try { handler(evt); } catch (Exception ex) { Report.Error(ex); }
    ↓
    Subscriber updates WPF/WinForms UI (if applicable)
```

#### 3.2 PubSub Path (Camera/Lights fallback)

```
[RabbitMQ Consumer Thread — or InProc publisher's thread]
    ↓
CameraLightBridge.OnPubSubEvent(IEventMessage msg)
    │  1. Check msg.EventKey.Relevant(expectedKey)
    │  2. Map msg → CameraLightPayload
    ↓
AoiEventAggregator.Publish<CameraLightChangedEvent>(evt)
    │  (same non-blocking dispatch as 3.1 above)
    ↓
Return to PubSub thread immediately ✓
```

#### 3.3 Direct Call Path (CleanRef, DieEdit)

```
[Any thread — typically NUnit test thread via Task.Run]
    ↓
CleanRefBridge.NotifyPhaseChange("CleanReference", diceCount: 4)
    │  1. Create CleanRefPayload
    │  2. Create CleanRefChangedEvent
    ↓
AoiEventAggregator.Publish<CleanRefChangedEvent>(evt)
    │  (same non-blocking dispatch)
    ↓
Return to caller immediately ✓
```

#### 3.4 Threading Invariants

These invariants MUST be enforced **by design** (type system + implementation), not by convention or code review alone:

| # | Invariant | Enforcement Mechanism |
|---|---|---|
| T1 | `Publish()` completes in O(1) — constant time regardless of subscriber count | `GetSnapshot()` returns a frozen array; iteration + `QueueUserWorkItem` are O(n) but each dispatch is O(1). No subscriber handler executes synchronously for `BackgroundThread`/`UIThread`. |
| T2 | No subscriber can block `Publish()` | `BackgroundThread` → `ThreadPool.QueueUserWorkItem` (fire-and-forget). `UIThread` → `SynchronizationContext.Post` (async post, never `Send`). Only `PublisherThread` runs inline — documented as "use with extreme care on STA threads". |
| T3 | `GetCurrentState()` is lock-free for reads | Each domain slot in `AoiStateCache` is a `volatile` reference field. `Snapshot` property reads 8 volatile fields and creates a new `AoiStateSnapshot`. No lock acquired. |
| T4 | Subscriber exceptions never crash the bridge or aggregator | Every subscriber invocation is wrapped in `try/catch(Exception)`. Caught exceptions are logged via `Report.Error()` with subscriber type name. Dispatch continues to remaining subscribers. |
| T5 | Weak references prevent memory leaks | `ISubscription.HandlerRef` stores `WeakReference<Delegate>`. On `Publish()`, dead references are skipped and lazily pruned. Explicit `Dispose()` of `SubscriptionToken` removes immediately. |
| T6 | Sequence numbers are globally monotonic | `Interlocked.Increment(ref _sequenceCounter)` on every `Publish()` call regardless of event type. Consumers can detect gaps (missed events) by checking `SequenceNo` continuity per domain. |
| T7 | `AoiStateCache` writes are atomic per domain | Each domain slot is a single reference assignment (`volatile` write). No torn reads. Cross-domain consistency is NOT guaranteed — `AoiStateSnapshot` is a best-effort "recent" view. |
| T8 | COM STA pump is never starved | Bridge handlers on COM thread do only: map args (pure computation) + `Publish()` (<50µs). No `Thread.Sleep`, no `Task.Wait`, no `lock`, no I/O. Return immediately to COM pump. |

---

### Step 4 — Integration Map

Every `[FILL]` cell from the proposal is now populated with **exact** integration points from the Section 16 discovery findings. Cells that the original proposal assumed incorrectly are marked with **[CORRECTED]**.

| Domain | BIS Source Component | Integration Mechanism | Bridge Method | Payload Fields Mapped |
|---|---|---|---|---|
| **Scan/Grab** | `CFalconEvents` singleton (FalconWrapper ATL COM) | COM callback: `IScanManagerCB.OperationStarted(eScanManagerOperation, IWaferData*)` and `IScanManagerCB.OperationCompleted(eScanManagerOperation, IWaferData*, eCycleCompletionCode, VARIANT, VARIANT_BOOL*)`. Registered via `IFalconEvents.RegisterScanEvent(IScanManagerCB)`. **[CORRECTED]** — NOT `DdsIPC`/`GrabIPC` (BIS-internal, inaccessible to AOI_Main). | `ScanStateBridge.OnOperationStarted(op, waferData)` → maps `eScanManagerOperation` to `ScanOperationType`, sets `Status=Starting` or `Grabbing`. `ScanStateBridge.OnOperationCompleted(op, waferData, code)` → maps `eCycleCompletionCode` to `CompletionCode` string, sets `Status=Complete` or `Error`. | `Status`, `OperationType`, `WaferId` (from `IWaferData` if non-null), `CompletionCode`, `StartTimeUtc`, `ElapsedMs` |
| **Color Grab** | Same `IScanManagerCB` | COM callback: `IScanManagerCB.OperationStarted(eSMO_ImageGrabbing, ...)`. **[CORRECTED]** — no separate color grabber COM event; `ImageGrabbing` is one of the 17 `eScanManagerOperation` values. | `ScanStateBridge.OnOperationStarted(eSMO_ImageGrabbing, ...)` → `Status=ColorGrab`, `OperationType=ImageGrabbing` | `Status=ColorGrab`, `OperationType=ImageGrabbing` |
| **Robot** | `CFalconEvents` singleton | COM callback: `IAutoCycleManagerCB.WaferInspectionStarted()`, `IAutoCycleManagerCB.WaferScanResultsAreReady()`, `IAutoCycleManagerCB.StateChanged(eManagerState)`. Registered via `IFalconEvents.RegisterAutoCycleEvent(IAutoCycleManagerCB)`. **[CORRECTED]** — NOT WinSock TCP from `PizzaServer.exe` (AOI_Main has no TCP connection). | `RobotStateBridge.OnWaferInspectionStarted()` → `Status=Loading`. `RobotStateBridge.OnWaferScanResultsAreReady()` → `Status=Idle`. `RobotStateBridge.OnAutoCycleStateChanged(state)` → maps `eManagerState` to `ManagerState` enum. | `Status`, `AutoCycleState`, `HasWaferOnChuck` (inferred from lifecycle), `PortId`/`SlotId` (not available from COM — set to -1) |
| **Camera/Lights** | `CFalconEvents` singleton + PubSub | COM callback: `IFalconGuiCB.Set2dOpticsDone()` and `IFalconGuiCB.LCCPeriodicCalibAlert(VARIANT_BOOL)`. Registered via `IFalconEvents.RegisterFalconGuiEvent(IFalconGuiCB)`. PubSub fallback: `EventKey{Context=Lcc, SubContext=IllumChannelCalib, Action=Finished}` via `CamtekSystem.PubSub.SubscriberFactory`. **[CORRECTED]** — NOT direct camera driver COM event (AOI_Main references no camera driver DLLs). | `CameraLightBridge.OnSet2dOpticsDone()` → `OpticMode="2D"`. `CameraLightBridge.OnLCCCalibAlert(isActive)` → `LccCalibAlert=isActive`. `CameraLightBridge.OnPubSubIllumCalib(msg)` → fallback illumination state. | `OpticMode`, `IsIlluminationError`, `LccCalibAlert` |
| **Job** | `CFalconEvents` singleton | COM callback: `IFalconGuiCB.JobLoaded(BSTR jobName, BSTR setupName, BSTR recipeName, long completionCode)` and `IFalconGuiCB.FalconGuiLifeCycleChanged(eFalconGuiLifeCycle)`. Registered via `IFalconEvents.RegisterFalconGuiEvent(IFalconGuiCB)`. **[CORRECTED]** — NOT WCF duplex callback (AOI_Main has no `System.ServiceModel` reference). | `JobStateBridge.OnJobLoaded(job, setup, recipe, code)` → `Status=Loaded` (if code=0) or `Error`. `JobStateBridge.OnLifeCycleChanged(eFalconTerminating)` → `Status=None`. | `JobName`, `SetupName`, `RecipeName`, `CompletionCode`, `Status` |
| **Alignment** | `CFalconEvents` singleton (same `IScanManagerCB` as Scan) | COM callback: `IScanManagerCB.OperationStarted(eSMO_Alignment, IWaferData*)` and `IScanManagerCB.OperationCompleted(eSMO_Alignment, IWaferData*, eCycleCompletionCode, ...)`. **[CORRECTED]** — NOT "Alignment module COM event" (no separate alignment COM interface exists). | `AlignmentBridge.OnOperationStarted(eSMO_Alignment, wd)` → `Result=InProgress`. `AlignmentBridge.OnOperationCompleted(eSMO_Alignment, wd, code)` → `Result=Passed` or `Failed` based on `eCycleCompletionCode`. | `Result`, `WaferId`, `CompletionCode`, `OperationType=Alignment` |
| **Clean Ref** | Direct API call from `ReferenceCreation` page object + `FileSystemWatcher` | Explicit method call: `CleanRefBridge.NotifyPhaseChange(phase, diceCount)` called by `ReferenceCreation.CreateReferenceSeq()` / `CleanReferenceSeq()` at each phase transition. `FileSystemWatcher.Created` event wired in `ReferenceCreation.cs`. **[CORRECTED]** — confirmed: no COM or PubSub event for reference creation lifecycle. | `CleanRefBridge.NotifyPhaseChange(phase, diceCount)` → `Phase=("Creating"\|"DieMapping"\|"CleanReference"\|"Complete"\|"Error")`. `CleanRefBridge.OnFileCreated(path)` → `Phase="DieMapping", FilesystemEvent=path`. | `IsValid`, `Phase`, `DiceCount`, `FilesystemEvent` |
| **CMM** | `CFalconEvents` singleton | COM callback: `IAutoCycleManagerCB.CmmImportCompleted()` and `IAutoCycleManagerCB.CmmUpdateCompleted()`. Registered via `IFalconEvents.RegisterAutoCycleEvent(IAutoCycleManagerCB)`. **[CORRECTED]** — NOT WCF duplex `CmmServiceNotifierProxy` (AOI_Main has no WCF reference). | `CmmBridge.OnCmmImportCompleted()` → `Phase=Done, OperationType="CmmImport"`. `CmmBridge.OnCmmUpdateCompleted()` → `Phase=Done, OperationType="CmmUpdate"`. | `Phase`, `OperationType`, `CompletionCode` |
| **Die Edit** | Direct API call from `DieEditMain` page object | Explicit method call: `DieEditBridge.NotifyEditApplied(editType, layerIndex, layerName)` and `DieEditBridge.NotifySaved()` — called by `DieEditMain` page object methods. **[CORRECTED]** — NO COM event and NO file-watch exist for die edits. | `DieEditBridge.NotifyEditApplied(type, idx, name)` → `EditType`, `LayerIndex`, `LayerName`. `DieEditBridge.NotifySaved()` → `IsSaved=true`. | `EditType`, `LayerIndex`, `LayerName`, `IsSaved` |

**COM Registration Summary — New Registrations Required:**

All COM-sourced bridges (Scan, Robot, Camera, Job, Alignment, CMM) share a single COM registration pattern. The bridge orchestrator creates ONE `CFalconExternalControlClass` instance and registers a composite callback sink:

```
AoiStateBridgeOrchestrator.Start():
    1. _externalControl = new CFalconExternalControlClass();
    2. _externalControl.Init();
    3. _falconEvents = (IFalconEvents)_externalControl;
    4. _falconEvents.RegisterScanEvent(_scanCallbackSink);           // IScanManagerCB
    5. _falconEvents.RegisterAutoCycleEvent(_autoCycleCallbackSink); // IAutoCycleManagerCB
    6. _falconEvents.RegisterFalconGuiEvent(_guiCallbackSink);       // IFalconGuiCB

    Each callback sink implements the COM interface and delegates to
    the corresponding bridge's OnXxx() methods.
```

This follows the **exact pattern** used by `ExternalControlCbUiWrapper` in `Falcon.Net` (discovery Section 4.3), which registers via:
```csharp
mExternalControl.RegisterEvent(eFalconExternalEventsId.eFEE_AllFalconEvents, this);
```

---

### Step 5 — Testability Contract

#### 5.1 Test Seams

```
IAoiEventAggregator             ← inject mock in unit tests (MockAoiEventAggregator)
IAoiStateBridge                 ← inject stub bridges; trigger events via Publish() directly
AoiStateBridgeOrchestrator      ← inject bridge list; call Start()/Stop() in test setup/teardown
AoiStateCache                   ← test independently: publish events, assert GetCurrentState()
```

**No hardware, no COM server, no RabbitMQ, no Falcon.Net process required for any test.**

#### 5.2 Unit Test Patterns

**Pattern 1 — Bridge Test (given simulated COM event → assert correct payload published)**

```
// Arrange
var mockAgg = new MockAoiEventAggregator();
var bridge = new ScanStateBridge(mockAgg);

// Act — simulate COM callback (no actual COM server)
bridge.OnOperationCompleted(
    ScanOperationType.Scan2D,
    waferData: null,
    completionCode: "Success");

// Assert
var published = mockAgg.GetLastPublished<ScanStateChangedEvent>();
Assert.AreEqual(ScanStatus.Complete, published.Payload.Status);
Assert.AreEqual("Success", published.Payload.CompletionCode);
Assert.AreEqual("ScanStateBridge", published.BridgeName);
```

**Pattern 2 — Consumer Test (subscribe → publish → assert handler invoked)**

```
// Arrange
var agg = new AoiEventAggregator();
ScanStatePayload received = null;
agg.Subscribe<ScanStateChangedEvent>(
    evt => received = evt.Payload,
    AoiThreadOption.PublisherThread);  // synchronous for test determinism

// Act
agg.Publish(new ScanStateChangedEvent(
    new ScanStatePayload(ScanStatus.Grabbing, ScanOperationType.Scan2D,
        "W001", "LOT1", null, DateTime.UtcNow, 0, null),
    "TestBridge"));

// Assert
Assert.IsNotNull(received);
Assert.AreEqual(ScanStatus.Grabbing, received.Status);
```

**Pattern 3 — Threading Test (publish on thread A → assert BackgroundThread handler runs on ThreadPool)**

```
// Arrange
var agg = new AoiEventAggregator();
int handlerThreadId = -1;
var handlerInvoked = new ManualResetEventSlim(false);
agg.Subscribe<ScanStateChangedEvent>(
    evt => { handlerThreadId = Thread.CurrentThread.ManagedThreadId; handlerInvoked.Set(); },
    AoiThreadOption.BackgroundThread);

// Act
int publisherThreadId = Thread.CurrentThread.ManagedThreadId;
agg.Publish(new ScanStateChangedEvent(...));
handlerInvoked.Wait(TimeSpan.FromSeconds(5));

// Assert — handler ran on a DIFFERENT thread (ThreadPool)
Assert.AreNotEqual(publisherThreadId, handlerThreadId);
```

**Pattern 4 — Current State Test (publish 3 sequential events → assert GetCurrentState returns last)**

```
// Arrange
var agg = new AoiEventAggregator();

// Act
agg.Publish(new ScanStateChangedEvent(Payload(ScanStatus.Starting), "bridge"));
agg.Publish(new ScanStateChangedEvent(Payload(ScanStatus.Grabbing), "bridge"));
agg.Publish(new ScanStateChangedEvent(Payload(ScanStatus.Complete), "bridge"));

// Assert
var snap = agg.GetCurrentState();
Assert.AreEqual(ScanStatus.Complete, snap.Scan.Status);
```

**Pattern 5 — Sequence Gap Detection Test**

```
// Arrange
var agg = new AoiEventAggregator();
long lastSeq = -1;
agg.Subscribe<ScanStateChangedEvent>(
    evt => { Assert.AreEqual(lastSeq + 1, evt.SequenceNo); lastSeq = evt.SequenceNo; },
    AoiThreadOption.PublisherThread);

// Act — publish in order
agg.Publish(new ScanStateChangedEvent(...));  // seq 1
agg.Publish(new ScanStateChangedEvent(...));  // seq 2
agg.Publish(new JobStateChangedEvent(...));   // seq 3 — different domain, same counter
agg.Publish(new ScanStateChangedEvent(...));  // seq 4

// Assert — no gaps in global sequence
// (scan subscriber sees 1, 2, 4 — gap at 3 is expected, it was a Job event)
```

---

### Step 6 — Error Handling & Diagnostics

| # | Failure Scenario | Handling | Severity |
|---|---|---|---|
| E1 | Bridge fails to connect to COM server at `Start()` (e.g., Falcon.Net not running) | `Report.Warning("ScanStateBridge: COM registration failed: {ex.Message}")`. Set domain state to payload with `Status=Unknown`, `ErrorMessage=ex.Message` via `Publish()`. Bridge enters dormant mode — `Stop()` is safe to call. Orchestrator continues starting remaining bridges. | Warning |
| E2 | Bridge receives malformed COM callback data (null `IWaferData*`, unexpected `eScanManagerOperation` value) | `Report.Error("ScanStateBridge: malformed callback: {rawDump}")`. Publish payload with available fields + `ErrorMessage` describing what was malformed. Never throw from COM callback — exception would propagate back to Falcon COM server. | Error |
| E3 | `BackgroundThread` subscriber throws exception in handler | Caught by dispatcher: `try { handler(evt); } catch (Exception ex) { Report.Error("Subscriber {handlerType} threw: {ex}"); }`. Remaining subscribers still receive the event. Failed subscriber's subscription remains active for future events. | Error |
| E4 | `UIThread` subscriber's `SynchronizationContext.Current` is null (headless NUnit test, no WinForms/WPF message loop) | Fall back to `BackgroundThread` dispatch: `if (SynchronizationContext.Current == null) ThreadPool.QueueUserWorkItem(handler, evt)`. Log once per aggregator lifetime: `Report.Info("No SynchronizationContext — UIThread subscribers fallback to ThreadPool")`. | Info |
| E5 | Sequence number gap detected by consumer | Consumer responsibility. Recommended pattern: consumer calls `GetCurrentState()` to get fresh snapshot if gap > threshold. Aggregator does NOT auto-replay missed events (no event log). | N/A (consumer) |
| E6 | `WeakReference<Delegate>` handler is GC'd before explicit `Dispose()` | On next `Publish()`, `IsAlive` returns false → subscription skipped and lazily removed from list. `Report.Debug("Pruned dead subscription for {eventType}")`. No error. | Debug |
| E7 | PubSub transport disabled (`NullableSubscriber` returned) | `CameraLightBridge.Start()` checks subscriber type. If `NullableSubscriber`, log: `Report.Warning("PubSub disabled — CameraLightBridge operating without illumination events")`. Bridge still registers COM `IFalconGuiCB` callbacks as primary source. | Warning |
| E8 | COM `CFalconExternalControl` singleton already initialized by another component in same process | Not a problem — `DECLARE_CLASSFACTORY_SINGLETON` returns same instance. `Init()` is idempotent. `RegisterEvent()` adds additional callback sink. Multiple bridges can coexist with `ExternalControlCbUiWrapper` (if both present). | None |
| E9 | Multiple rapid `Publish()` calls from overlapping COM callbacks | Thread-safe by design. `Interlocked.Increment` for sequence counter, `volatile` write for cache slots, `GetSnapshot()` under lock for subscriber list. No data corruption. Subscribers may receive events out of original COM callback order if two callbacks arrive on different threadpool threads — mitigated by `TimestampUtc` on each payload. | None |

---

### Step 7 — Architecture Summary Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        BIS / Falcon.Net Process                              │
│                     (AOI_Main.exe — external process)                        │
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐              │
│  │ ScanManager  │  │ AutoCycle   │  │   FalconGui             │              │
│  │ (IScanMgr)   │  │ Manager     │  │   (IFalconGui)          │              │
│  └──────┬───────┘  └──────┬──────┘  └───────────┬─────────────┘              │
│         │                 │                     │                            │
│  ┌──────┴─────────────────┴─────────────────────┴──────────┐                 │
│  │              CFalconEvents  (COM singleton)              │                 │
│  │  IFalconFireEvents: fires OperationStarted/Completed,   │                 │
│  │  JobLoaded, WaferScanResultsAreReady, CmmImportDone...  │                 │
│  └──────────────────────────┬───────────────────────────────┘                 │
│                             │  COM IPC (out-of-process)                      │
└─────────────────────────────┼────────────────────────────────────────────────┘
                              │
══════════════════════════════╪══════════════ PROCESS BOUNDARY ═════════════════
                              │
┌─────────────────────────────┼────────────────────────────────────────────────┐
│  AOI_Main.dll + TestAutomationSDK.dll  (loaded by NUnit in RunnerGui.exe)    │
│                             │                                                │
│                             ▼                                                │
│  ┌────────────────────────────────────────────────────┐                      │
│  │        AoiStateBridgeOrchestrator                  │                      │
│  │  .Start() → registers all COM callback sinks       │                      │
│  │  .Stop()  → unregisters, releases COM refs         │                      │
│  └──┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬┘                      │
│     │      │      │      │      │      │      │      │                       │
│     ▼      ▼      ▼      ▼      ▼      ▼      ▼      ▼                      │
│  ┌──────┐┌─────┐┌──────┐┌────┐┌─────┐┌──────┐┌────┐┌──────┐                │
│  │ Scan ││Robot││Camera││Job ││Align││ClnRef││CMM ││DieEd │                │
│  │Bridge││Brdg ││Light ││Brdg││Brdg ││Brdg  ││Brdg││Brdg  │                │
│  │      ││     ││Brdg  ││    ││     ││      ││    ││      │                │
│  └──┬───┘└──┬──┘└──┬───┘└──┬─┘└──┬──┘└──┬───┘└──┬─┘└──┬───┘                │
│     │       │      │       │     │      │       │      │                    │
│     │  COM CB │  COM+PS │  COM  │ COM  │ Direct │ COM  │ Direct             │
│     │       │      │       │     │      │       │      │                    │
│     └───────┴──────┴───────┴─────┴──────┴───────┴──────┘                    │
│                             │                                                │
│                             ▼  Publish<TEvent>(evt)                          │
│  ┌────────────────────────────────────────────────────┐                      │
│  │          AoiEventAggregator : IAoiEventAggregator  │                      │
│  │                                                    │                      │
│  │  ┌──────────────────────────────────────────────┐  │                      │
│  │  │  ConcurrentDictionary<Type, SubscriptionList>│  │                      │
│  │  │  (per-event-type subscriber lists)           │  │                      │
│  │  └──────────────────────────────────────────────┘  │                      │
│  │  ┌──────────────────────────────────────────────┐  │                      │
│  │  │  AoiStateCache (volatile domain slots)       │  │                      │
│  │  │  Scan | Robot | Camera | Job | Align |       │  │                      │
│  │  │  ClnRef | CMM | DieEdit                      │  │                      │
│  │  └──────────────────────────────────────────────┘  │                      │
│  │  long _sequenceCounter (Interlocked)               │                      │
│  └──────────┬──────────────┬──────────────┬───────────┘                      │
│             │              │              │                                   │
│    ┌────────▼────┐  ┌──────▼──────┐  ┌───▼──────────┐                       │
│    │  ThreadPool │  │  SyncCtx    │  │  Direct      │                       │
│    │  .QUWI()   │  │  .Post()    │  │  (same thd)  │                       │
│    │  [BGThread] │  │  [UIThread] │  │  [PubThread] │                       │
│    └────────┬────┘  └──────┬──────┘  └───┬──────────┘                       │
│             │              │             │                                    │
│             ▼              ▼             ▼                                    │
│  ┌────────────────────────────────────────────────────┐                      │
│  │                  CONSUMERS                         │                      │
│  │                                                    │                      │
│  │  ┌──────────────┐  ┌───────────┐  ┌────────────┐  │                      │
│  │  │ TestRunner   │  │ Report /  │  │ Future:    │  │                      │
│  │  │ (assert on   │  │ Serilog   │  │ Dashboard  │  │                      │
│  │  │  state DTO)  │  │ (log all  │  │ ViewModel  │  │                      │
│  │  │  [BGThread]  │  │  events)  │  │ [UIThread] │  │                      │
│  │  └──────────────┘  │  [BGThrd] │  └────────────┘  │                      │
│  │                    └───────────┘                   │                      │
│  │  ┌──────────────────────────────────────────────┐  │                      │
│  │  │ eventAgg.GetCurrentState() → AoiStateSnapshot│  │                      │
│  │  │ (lock-free read, any thread, any time)       │  │                      │
│  │  └──────────────────────────────────────────────┘  │                      │
│  └────────────────────────────────────────────────────┘                      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

Thread boundary legend:
  ═══  Process boundary (Falcon.Net ↔ AOI_Main via COM IPC)
  ───  Thread boundary (COM callback thread → ThreadPool / SyncContext)
  COM CB  = IScanManagerCB / IAutoCycleManagerCB / IFalconGuiCB  (6 bridges)
  COM+PS  = IFalconGuiCB + CamtekSystem.PubSub fallback          (1 bridge)
  Direct  = Explicit API call from page object                    (2 bridges)
```

---

### Design Document — Summary of Key Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Custom event aggregator, not Prism NuGet | AOI_Main.csproj does not reference Prism today. A 150-LOC custom implementation avoids new dependency while matching the exact same API pattern. Can swap to Prism.Core later if desired. |
| D2 | Payload fields limited to what COM/PubSub actually provides | Discovery found that many "ideal" fields (ProgressPercent, OffsetX/Y, CameraId, TicketId, DieCoord) are NOT exposed by any available interface. Payloads include only fields that can be reliably populated. Fields marked for future addition when data sources become available. |
| D3 | Single `CFalconExternalControlClass` instance shared by orchestrator | COM `DECLARE_CLASSFACTORY_SINGLETON` guarantees same instance. One `Init()` call, three `Register*Event()` calls for the three callback interface families. Follows `ExternalControlCbUiWrapper` pattern. |
| D4 | CleanRef and DieEdit bridges use direct API calls, not COM events | Discovery confirmed NO COM event exists for these domains. Bridges are called from page object methods at state transition points. This is an explicit trade-off: these two domains are "push from test code" rather than "push from Falcon." |
| D5 | `volatile` fields in `AoiStateCache` instead of `Interlocked.Exchange` | Reference writes on x64 .NET are atomic. `volatile` ensures no stale reads from CPU cache. Simpler than `Interlocked.Exchange<T>` which requires boxing for reference types on .NET 4.8. |
| D6 | `WeakReference<Delegate>` for subscriber lifetime | Matches Prism pattern. NUnit creates/tears down test fixtures — if a fixture subscribes but doesn't dispose, the weak reference prevents the aggregator (singleton across test session) from leaking fixture instances. |
| D7 | Global sequence counter across all event types | Enables consumers to detect not just missed events within a domain, but also to reconstruct global ordering across domains for diagnostic logs. |
| D8 | `PublisherThread` option documented as "use with extreme care" | On COM callback thread, a synchronous subscriber that takes >1ms could stall the COM pump. Provided for test convenience (deterministic assertion) but discouraged in production bridges. |
