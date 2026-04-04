# AOI Main State Engine — Prompt Series

> **Purpose:** Design and implement a non-blocking, event-driven state model for `AOI_Main`  
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
| [`01_aoi_state_discovery.md`](01_aoi_state_discovery.md) | Discovery | Map every integration point, threading model, existing event infrastructure | Access to `AOI_Main` source + BIS source |
| [`02_aoi_state_alternatives.md`](02_aoi_state_alternatives.md) | Architecture | 3 alternatives evaluated: Redux store / Rx.NET / Event Aggregator | Prompt 1 findings |
| [`03_aoi_state_design.md`](03_aoi_state_design.md) | Design | Win architecture selected, full class design, threading spec, integration map | Prompt 2 evaluation |
| [`04_aoi_state_implementation.md`](04_aoi_state_implementation.md) | Implementation | Code generation phase-by-phase, unit tests, integration wiring | Prompt 3 design doc |

---

## Key Design Constraints

- **Non-blocking:** COM STA pump, grabbing pipeline, and UI thread must never be stalled
- **Event-driven:** subscribers declare what they care about; no polling
- **No new external dependencies:** stays within .NET 4.8 BCL + existing BIS libraries
- **Testable without hardware:** stub bridges allow full CI testing
- **Familiar pattern:** mirrors Prism EventAggregator already used in MDC and SystemCalibration

---

## Expected Output Artefacts

After completing all 4 prompts:

```
AOI_Main.StateEngine/
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

AOI_Main.StateEngine.Tests/
├── AoiEventAggregatorTests.cs
├── BridgeOrchestratorTests.cs
└── AoiStateEngineIntegrationTest.cs
```
