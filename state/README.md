# Falcon.Net State Shell — Prompt Series

> **Purpose:** Design and implement a non-blocking, event-driven state shell **owned by `Falcon.Net`**,  
> with `AOI_Main` as a consumer/adapter,  
> covering 8 operational domains in the Camtek Falcon BIS system.  
> **Runtime target:** .NET Framework 4.8 / C# 7.3  
> **Run prompts in order — each one depends on the output of the previous.**

---

## The 8 State Domains

| # | Domain | Source in BIS |
|---|---|---|
| 1 | Scan / Grab / Color Grabbing | `DdsSrv_d.exe`, `Sources/Grabbing/`, `DdsIPC`/`GrabIPC` |
| 2 | Robot Setup | `PizzaServer.exe`, `Sources/machine/`, E84 driver |
| 3 | Camera & Lights / Illumination | BIS camera drivers (17 types), `Sources/system/` |
| 4 | Job Created / Deleted | `Job.NET` in `Sources/objects/`, RMS gRPC |
| 5 | Alignment Modification | `Sources/objects/Alignment`, alignment COM event |
| 6 | Clean Reference | `Sources/dds/`, `Sources/calibration/` |
| 7 | CMM | `CmmServiceNotifierProxy`, WCF port 8032 |
| 8 | Die Edit Modification | `DieEdit.sln`, `Sources/objects/` |

---

## Prompt Sequence

| File | Phase | Goal | Input needed |
|---|---|---|---|
| [`01_aoi_state_discovery.md`](01_aoi_state_discovery.md) | Discovery | Map integration points in both `AOI_Main` and `Falcon.Net`, plus current callback ownership | Access to `AOI_Main` + `Falcon.Net` source |
| [`02_aoi_state_alternatives.md`](02_aoi_state_alternatives.md) | Architecture | 3 alternatives evaluated for a **Falcon.Net-owned** state shell | Prompt 1 findings |
| [`03_aoi_state_design.md`](03_aoi_state_design.md) | Design | Winning architecture + full move map + COM callback ownership transfer plan | Prompt 2 evaluation |
| [`04_aoi_state_implementation.md`](04_aoi_state_implementation.md) | Implementation | Generate code phase-by-phase in Falcon.Net + AOI_Main adapter/wiring | Prompt 3 design doc |

---

## Key Design Constraints

- **Non-blocking:** COM STA pump, grabbing pipeline, and UI thread must never be stalled
- **Event-driven:** subscribers declare what they care about; no polling
- **No new external dependencies:** stays within .NET 4.8 BCL + existing BIS libraries
- **Testable without hardware:** stub bridges allow full CI testing
- **Familiar pattern:** mirrors Prism EventAggregator already used in MDC and SystemCalibration
- **Ownership boundary:** COM callback registration and state shell lifecycle are owned by `Falcon.Net`, not `AOI_Main`

---

## Expected Output Artefacts

After completing all 4 prompts:

```
Falcon.Net.StateShell/
├── AoiThreadOption.cs
├── AoiStatePayloadBase.cs
├── Payloads/
│   ├── ScanStatePayload.cs
│   ├── RobotStatePayload.cs
│   ├── CameraLightPayload.cs
│   ├── JobStatePayload.cs
│   ├── AlignmentPayload.cs
│   ├── CleanRefPayload.cs
│   ├── CmmStatePayload.cs
│   └── DieEditPayload.cs
├── Events/
│   ├── AoiStateEventBase.cs
│   └── [8 domain event classes]
├── AoiStateSnapshot.cs
├── IAoiEventAggregator.cs
├── AoiEventAggregator.cs
├── IAoiStateBridge.cs
├── AoiStateBridgeOrchestrator.cs
└── Bridges/
    ├── ScanStateBridge.cs
    ├── RobotStateBridge.cs
    ├── CameraLightBridge.cs
    ├── JobStateBridge.cs
    ├── AlignmentBridge.cs
    ├── CleanRefBridge.cs
    ├── CmmBridge.cs
    └── DieEditBridge.cs

Falcon.Net.StateShell.Tests/
├── AoiEventAggregatorTests.cs
├── BridgeOrchestratorTests.cs
└── AoiStateEngineIntegrationTest.cs

AOI_Main.StateShellAdapter/
└── Thin consumer adapter (subscribe/query API only; no COM callback registration)
```
