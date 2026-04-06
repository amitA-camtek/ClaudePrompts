# Q&A

---

## Question
Based on the `state_shell_design`, except for the `Falcon.Net` changes, what other projects will be changed?

## Answer
All implementation changes are internal to `Falcon.Net`.

Every file in the Module Change Plan (`M1`–`M58`) and every new file (`N1`–`N39`) lives under `Falcon.Net`.

| File Category | Project | Examples |
|---|---|---|
| New `StateShell/` folder (39 files) | `Falcon.Net` | Enums, Payloads, Events, Bridges, core infrastructure |
| COM wrapper modifications (Keep/Wrap) | `Falcon.Net` | `ScanManagerWrapper.cs`, `RobotUIEventHandlerWrapper.cs`, `AutoLoaderUIWrapper.cs`, `ExternalControlCbUiWrapper.cs` |
| Form modifications | `Falcon.Net` | `frmMain.cs`, `frmProduction.cs` |
| Module modifications | `Falcon.Net` | `OpticModule.cs`, `modWaferAlignment.cs`, `ExternalCoordSystemsAlign.cs`, `modCleanReferenceOptions.cs` |
| MainContext modifications | `Falcon.Net` | `MainContextModule.cs`, `clsInitAOI.cs`, `clsFalconPresentation.cs` |
| CMM modifications | `Falcon.Net` | `CmmReceiverApiRequetsHandler.cs`, `clsCMM.cs` |
| UIEvents modifications | `Falcon.Net` | `UIEvents.cs` |

## Why no external project changes are needed

### 1. COM interfaces are frozen
`IScanManagerInkingCB`, `IRobotUIConnectorCB`, `IFalconFireEvents`, and `IAutoLoaderEvents` remain unchanged. The COM servers (`CScanManager`, `EfemSrv`, `CFalconEvents` ATL) are not modified.

### 2. Bridges wrap, not replace
Each bridge subscribes to existing .NET delegate events already exposed by wrappers inside `Falcon.Net`. No upstream COM server code changes are required.

### 3. gRPC contract is unchanged
`CmmBridge` hooks into `CmmReceiverApiRequetsHandler` callbacks that already exist in `Falcon.Net`. The `CMM.Net.Api` gRPC client/server contracts remain untouched.

### 4. Prism dependency already exists
`Microsoft.Practices.Prism.PubSubEvents` is already referenced and deployed to `bin`. No new NuGet dependency is needed.

### 5. External consumers remain compatible
External consumers such as Cimetrix, SECS/GEM, and external tools continue to receive events through the same `CFalconEvents` COM path. That path remains unchanged; the `Fire*` methods simply become subscribers to event-aggregator events instead of being called directly.

## Caveat
A new test project, or new test files in an existing test project, would still be needed for the 21 unit tests defined in Section 5.6. That is a new addition, but not a change to another production project.

---

## Question
Based on the analyses, what are the risks, and does this change impact performance?

## Answer
Yes  there are real risks, and there is a performance impact, but both are manageable if implemented as designed.

### Key Risks

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Wrong thread dispatch (STA/UI misuse) | COM pump stalls, UI hangs | Medium | Enforce `BackgroundThread` default; never block in callbacks; strict thread tests |
| Event storms (scan/progress high frequency) | CPU/log overhead, queue pressure | High | Throttle/coalesce progress events; avoid per-event heavy logging |
| Subscriber exceptions | Silent data loss or cascade failures | Medium | Wrap all handlers in safe-dispatch with try/catch + diagnostics |
| Ordering/race issues across domains | Inconsistent cross-domain reads | Medium | Sequence numbers + `AoiStateSnapshot` last-known state |
| Memory leaks from subscriptions | Long-run degradation | Medium | Weak subscriptions + deterministic `Dispose()` in adapters |
| Migration coupling to `frmProduction` callbacks | Regression in legacy flows | Medium | Phase migration (alongside to switch-over), parity checks |

### Performance Impact

#### Expected Costs
- Per-event overhead increases slightly (event object creation + aggregator dispatch + snapshot update).
- GC pressure rises under high-frequency domains (especially Scan progress).
- ThreadPool activity increases due to background dispatch.

#### Expected Gains
- Lower STA/UI blocking risk (callbacks return fast; work offloaded).
- Better tail latency stability for COM and UI paths.
- Improved observability (sequence IDs/snapshot) reduces recovery cost from missed events.

#### Net Assessment
- Overall performance: likely neutral to slightly negative raw throughput in high-frequency paths, but positive for responsiveness and stability.
- Critical condition: keep `Publish()` O(1), coalesce noisy events, and avoid synchronous work/logging in callback threads.

> Yes, there is overhead  but with the designed constraints, it should not materially harm system responsiveness and should reduce hang/deadlock risk.
